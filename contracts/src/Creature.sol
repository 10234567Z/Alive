// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICreature} from "./interfaces/ICreature.sol";
import {IXCM} from "./interfaces/IXCM.sol";

/// @title Creature
/// @notice A single autonomous DeFi strategy agent. Holds DNA encoding its
///         strategy parameters, manages allocated capital, and executes
///         yield strategies via XCM across Polkadot parachains.
///
/// Creatures are deployed by CreatureFactory. They do not hold
/// privileged access -- only the Ecosystem or GenePool (via the
/// ecosystem) can trigger lifecycle functions (feed, harvest, kill).
contract Creature is ICreature {
    using SafeERC20 for IERC20;

    // ----------------------------------------------------------------
    // State
    // ----------------------------------------------------------------

    DNA internal _dna;

    uint256 public override generation;
    address public override parent1;
    address public override parent2;
    uint256 public override birthEpoch;

    uint256 public balance;
    uint256 public initialBalance;
    int256 public lastReturn;
    int256 public cumulativeReturn;
    uint256 public epochsSurvived;
    int256 public maxDrawdown;
    bool public override isAlive;

    address public ecosystem;
    IERC20 public stablecoin;
    IXCM public xcm;

    bool private _initialized;

    // ----------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------

    event CreatureInitialized(
        address indexed creature,
        uint256 generation,
        address parent1,
        address parent2
    );
    event Fed(address indexed creature, uint256 epoch, uint256 amountDeployed);
    event Harvested(address indexed creature, int256 returnAmount);
    event Killed(address indexed creature, uint256 balanceReturned);
    event CapitalReceived(address indexed creature, uint256 amount);

    // ----------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------

    modifier onlyEcosystem() {
        require(msg.sender == ecosystem, "Creature: caller not ecosystem");
        _;
    }

    modifier onlyAlive() {
        require(isAlive, "Creature: dead");
        _;
    }

    // ----------------------------------------------------------------
    // Initialization (called once by Factory)
    // ----------------------------------------------------------------

    /// @inheritdoc ICreature
    function initialize(
        DNA memory dnaInput,
        uint256 gen,
        address p1,
        address p2,
        uint256 epoch,
        address ecosystemAddr,
        address stablecoinAddr,
        address xcmPrecompile
    ) external override {
        require(!_initialized, "Creature: already initialized");
        _initialized = true;

        _dna = dnaInput;
        generation = gen;
        parent1 = p1;
        parent2 = p2;
        birthEpoch = epoch;
        ecosystem = ecosystemAddr;
        stablecoin = IERC20(stablecoinAddr);
        xcm = IXCM(xcmPrecompile);
        isAlive = true;

        emit CreatureInitialized(address(this), gen, p1, p2);
    }

    // ----------------------------------------------------------------
    // Lifecycle
    // ----------------------------------------------------------------

    /// @inheritdoc ICreature
    /// @dev Called by Ecosystem during FEED PHASE.
    ///      Deploys capital according to DNA parameters via XCM.
    function feed() external override onlyEcosystem onlyAlive {
        uint256 toDeploy = (balance * _dna.allocationRatio) / 10000;
        if (toDeploy == 0) return;

        // Keep hedge reserve
        uint256 hedgeAmount = (balance * _dna.hedgeRatio) / 10000;
        if (toDeploy + hedgeAmount > balance) {
            toDeploy = balance - hedgeAmount;
        }
        if (toDeploy == 0) return;

        // Approve the XCM precompile to pull tokens
        stablecoin.forceApprove(address(xcm), toDeploy);

        // Execute cross-chain transfer and deposit
        bool success = xcm.transferAssets(
            uint256(_dna.targetChainId),
            address(this),
            address(stablecoin),
            toDeploy,
            "" // transact payload would encode the deposit call on the target chain
        );

        if (success) {
            balance -= toDeploy;
        }

        emit Fed(address(this), block.number, toDeploy);
    }

    /// @inheritdoc ICreature
    /// @dev Called by Ecosystem during HARVEST PHASE.
    ///      In a full implementation this would send an XCM message to
    ///      retrieve funds from the target parachain. For the hackathon
    ///      MVP the return is simulated -- the Ecosystem can directly
    ///      transfer stablecoins to this contract to represent harvested
    ///      yield, and then call harvest() to account for it.
    function harvest() external override onlyEcosystem onlyAlive {
        // The current stablecoin balance vs what we had = return for this epoch
        uint256 currentBal = stablecoin.balanceOf(address(this));
        int256 epochReturn = int256(currentBal) - int256(balance);

        lastReturn = epochReturn;
        cumulativeReturn += epochReturn;
        epochsSurvived += 1;
        balance = currentBal;

        // Track max drawdown (worst single-epoch loss)
        if (epochReturn < maxDrawdown) {
            maxDrawdown = epochReturn;
        }

        emit Harvested(address(this), epochReturn);
    }

    /// @inheritdoc ICreature
    /// @dev Called by Ecosystem when GenePool decides to kill this Creature.
    ///      Returns all remaining capital to the Ecosystem.
    function kill() external override onlyEcosystem onlyAlive {
        isAlive = false;
        uint256 remaining = stablecoin.balanceOf(address(this));
        if (remaining > 0) {
            stablecoin.safeTransfer(ecosystem, remaining);
        }
        balance = 0;

        emit Killed(address(this), remaining);
    }

    /// @inheritdoc ICreature
    /// @dev Called by Ecosystem during capital allocation.
    function receiveCapital(uint256 amount) external override onlyEcosystem onlyAlive {
        stablecoin.safeTransferFrom(ecosystem, address(this), amount);
        balance += amount;
        if (initialBalance == 0) {
            initialBalance = amount;
        }

        emit CapitalReceived(address(this), amount);
    }

    /// @inheritdoc ICreature
    /// @dev Called by Ecosystem to recall capital for user withdrawals.
    function returnCapital(uint256 amount) external override onlyEcosystem onlyAlive {
        uint256 toReturn = amount;
        uint256 currentBal = stablecoin.balanceOf(address(this));
        if (toReturn > currentBal) toReturn = currentBal;
        if (toReturn == 0) return;

        stablecoin.safeTransfer(ecosystem, toReturn);
        balance = stablecoin.balanceOf(address(this));
    }

    // ----------------------------------------------------------------
    // Views
    // ----------------------------------------------------------------

    /// @inheritdoc ICreature
    function getDNA() external view override returns (DNA memory) {
        return _dna;
    }

    /// @inheritdoc ICreature
    function getEncodedDNA() external view override returns (bytes memory) {
        return abi.encode(_dna);
    }

    /// @inheritdoc ICreature
    function getPerformance()
        external
        view
        override
        returns (
            int256,
            int256,
            uint256,
            int256,
            uint256
        )
    {
        return (lastReturn, cumulativeReturn, epochsSurvived, maxDrawdown, balance);
    }
}
