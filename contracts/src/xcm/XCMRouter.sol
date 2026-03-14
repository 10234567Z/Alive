// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IXCM} from "../interfaces/IXCM.sol";
import {IPolkadotXcm, XCM_PRECOMPILE_ADDRESS} from "../interfaces/IPolkadotXcm.sol";
import {XCMMessageBuilder} from "./XCMMessageBuilder.sol";

/// @title XCMRouter
/// @notice Production-ready XCM adapter for the ALIVE protocol.
///
///         This contract bridges the gap between ALIVE's simplified IXCM
///         interface (used by Creature.sol) and the real Polkadot Hub XCM
///         precompile. It:
///
///           1. Accepts `transferAssets()` calls from Creatures
///           2. Builds SCALE-encoded XCM V4 messages (WithdrawAsset,
///              TransferReserveAsset, BuyExecution, DepositAsset)
///           3. Calls the real XCM precompile at 0x0...0A0000 to execute
///              cross-chain transfers
///
///         The router supports two operational modes:
///
///           - PRODUCTION: Builds real XCM messages and calls the precompile.
///             Used when deployed on Polkadot Hub (Asset Hub).
///
///           - SIMULATION: Performs local ERC20 transfers to simulate
///             cross-chain capital deployment. Used for local testing
///             (Anvil, Hardhat) where the XCM precompile doesn't exist.
///
///         Architecture:
///         ┌──────────┐      ┌───────────┐      ┌──────────────────┐
///         │ Creature │─────>│ XCMRouter │─────>│ XCM Precompile   │
///         │ (DNA)    │ IXCM │ (adapter) │ IXcm │ (0x...0A0000)    │
///         └──────────┘      └───────────┘      └──────────────────┘
///                                │                     │
///                                │ SCALE-encode        │ Execute XCM V4
///                                │ XCM message         │ on Asset Hub
///                                └─────────────────────┘
///
/// @dev Implements IXCM for drop-in compatibility with existing Creature contracts.
contract XCMRouter is IXCM {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    enum Mode {
        PRODUCTION,
        SIMULATION
    }

    struct Deployment {
        address creature;
        address asset;
        uint256 amount;
    }

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------

    /// @notice Router operational mode.
    Mode public mode;

    /// @notice Owner (deployer) — can switch modes and configure.
    address public owner;

    /// @notice Asset Hub's own parachain ID (1000 on Polkadot/Westend).
    uint32 public assetHubParaId;

    /// @notice Mapping from ERC20 token address to pallet-assets GeneralIndex.
    ///         On Asset Hub, ERC20 precompiles wrap pallet-assets tokens.
    ///         The XCM message needs the asset's GeneralIndex, not the ERC20 address.
    mapping(address => uint128) public assetRegistry;

    /// @notice Reference to the real XCM precompile.
    IPolkadotXcm public immutable xcmPrecompile;

    // --- Simulation-mode state (same as MockXCM for backward compat) ---

    /// @notice Outstanding deployments awaiting return (simulation only).
    Deployment[] internal _deployments;

    /// @notice Deployed capital per creature (simulation only).
    mapping(address => uint256) public deployedCapital;

    /// @notice Total capital deployed across all epochs.
    uint256 public totalDeployed;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when capital is deployed via XCM (both modes).
    event CapitalDeployed(
        address indexed creature,
        address asset,
        uint256 amount,
        uint256 destChainId,
        Mode mode
    );

    /// @notice Emitted when XCM message is built and executed (production).
    event XCMExecuted(
        address indexed creature,
        uint256 destChainId,
        uint256 amount,
        bytes xcmMessage
    );

    /// @notice Emitted when simulated returns are sent back.
    event ReturnsSimulated(
        address indexed creature,
        uint256 principal,
        uint256 yieldAmount,
        uint256 total
    );

    /// @notice Emitted when an asset is registered in the router.
    event AssetRegistered(address indexed token, uint128 assetId);

    /// @notice Emitted when mode is changed.
    event ModeChanged(Mode oldMode, Mode newMode);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error NotOwner();
    error AssetNotRegistered(address token);
    error XCMExecutionFailed();

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @param _mode Initial operational mode (PRODUCTION or SIMULATION).
    /// @param _assetHubParaId Asset Hub's parachain ID (1000 for Polkadot/Westend).
    constructor(Mode _mode, uint32 _assetHubParaId) {
        mode = _mode;
        assetHubParaId = _assetHubParaId;
        owner = msg.sender;
        xcmPrecompile = IPolkadotXcm(XCM_PRECOMPILE_ADDRESS);
    }

    // ---------------------------------------------------------------
    // IXCM Implementation
    // ---------------------------------------------------------------

    /// @inheritdoc IXCM
    /// @dev Routes the transfer to either production XCM or local simulation
    ///      based on the current mode.
    ///
    ///      In PRODUCTION mode:
    ///        1. Pulls tokens from the Creature via safeTransferFrom
    ///        2. Builds a SCALE-encoded XCM V4 TransferReserveAsset message
    ///        3. Calls xcmPrecompile.execute() to send assets cross-chain
    ///
    ///      In SIMULATION mode:
    ///        1. Pulls tokens from the Creature (same as production)
    ///        2. Tracks deployment for later yield simulation
    ///        3. simulateReturns() pushes capital + yield back to Creatures
    function transferAssets(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount,
        bytes calldata /* transactPayload */
    ) external override returns (bool) {
        // Pull tokens from the calling Creature
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        if (mode == Mode.PRODUCTION) {
            return _executeProductionTransfer(destChainId, destAccount, asset, amount);
        } else {
            return _executeSimulationTransfer(destChainId, asset, amount);
        }
    }

    // ---------------------------------------------------------------
    // Production Mode
    // ---------------------------------------------------------------

    /// @dev Build and execute the real XCM transfer via the precompile.
    function _executeProductionTransfer(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount
    ) internal returns (bool) {
        // Look up the pallet-assets GeneralIndex for this ERC20
        uint128 assetId = assetRegistry[asset];
        if (assetId == 0) revert AssetNotRegistered(asset);

        // Build the SCALE-encoded XCM V4 message
        bytes memory xcmMessage = XCMMessageBuilder.buildTransferToParachain(
            assetId,
            amount,
            uint32(destChainId),
            destAccount,
            assetHubParaId
        );

        // Estimate weight
        IPolkadotXcm.Weight memory weight = xcmPrecompile.weighMessage(xcmMessage);

        // Add 10% safety margin to weight estimates
        weight.refTime = weight.refTime + (weight.refTime / 10);
        weight.proofSize = weight.proofSize + (weight.proofSize / 10);

        // Execute the XCM program
        // This will withdraw the assets from this contract's pallet-assets account
        // and send them to the destination parachain
        xcmPrecompile.execute(xcmMessage, weight);

        totalDeployed += amount;

        emit XCMExecuted(msg.sender, destChainId, amount, xcmMessage);
        emit CapitalDeployed(msg.sender, asset, amount, destChainId, Mode.PRODUCTION);

        return true;
    }

    // ---------------------------------------------------------------
    // Simulation Mode (backward-compatible with MockXCM)
    // ---------------------------------------------------------------

    /// @dev Track the deployment locally for later yield simulation.
    function _executeSimulationTransfer(
        uint256 destChainId,
        address asset,
        uint256 amount
    ) internal returns (bool) {
        _deployments.push(Deployment({
            creature: msg.sender,
            asset: asset,
            amount: amount
        }));
        deployedCapital[msg.sender] += amount;
        totalDeployed += amount;

        emit CapitalDeployed(msg.sender, asset, amount, destChainId, Mode.SIMULATION);
        return true;
    }

    /// @notice Simulate cross-chain DeFi returns for all outstanding deployments.
    ///         Sends back each creature's deployed capital plus yield.
    /// @dev Only available in SIMULATION mode. Call AFTER feeding, BEFORE harvesting.
    /// @param yieldBps Yield in basis points (e.g., 500 = 5%).
    function simulateReturns(uint256 yieldBps) external {
        require(mode == Mode.SIMULATION, "XCMRouter: not in simulation mode");

        uint256 len = _deployments.length;
        for (uint256 i = 0; i < len; i++) {
            Deployment memory dep = _deployments[i];
            uint256 yieldAmount = (dep.amount * yieldBps) / 10_000;
            uint256 total = dep.amount + yieldAmount;

            deployedCapital[dep.creature] -= dep.amount;
            IERC20(dep.asset).safeTransfer(dep.creature, total);

            emit ReturnsSimulated(dep.creature, dep.amount, yieldAmount, total);
        }

        delete _deployments;
    }

    /// @notice Simulate returns for a specific creature with a custom yield.
    /// @dev Only available in SIMULATION mode.
    function simulateReturnForCreature(
        address creature,
        address asset,
        uint256 yieldAmount
    ) external {
        require(mode == Mode.SIMULATION, "XCMRouter: not in simulation mode");

        uint256 principal = deployedCapital[creature];
        if (principal == 0) return;

        uint256 total = principal + yieldAmount;
        deployedCapital[creature] = 0;

        // Remove matching deployments
        uint256 len = _deployments.length;
        uint256 writeIdx = 0;
        for (uint256 i = 0; i < len; i++) {
            if (_deployments[i].creature != creature) {
                if (writeIdx != i) {
                    _deployments[writeIdx] = _deployments[i];
                }
                writeIdx++;
            }
        }
        while (_deployments.length > writeIdx) {
            _deployments.pop();
        }

        IERC20(asset).safeTransfer(creature, total);
        emit ReturnsSimulated(creature, principal, yieldAmount, total);
    }

    // ---------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------

    /// @notice Register an ERC20 token address → pallet-assets GeneralIndex mapping.
    /// @dev Required for production mode so the XCM message references the correct asset.
    ///      Common Asset Hub GeneralIndex values:
    ///        - USDT: 1984
    ///        - USDC: 1337
    /// @param token The ERC20 token address (or ERC20 precompile address on Asset Hub).
    /// @param assetId The pallet-assets GeneralIndex for this token.
    function registerAsset(address token, uint128 assetId) external {
        if (msg.sender != owner) revert NotOwner();
        assetRegistry[token] = assetId;
        emit AssetRegistered(token, assetId);
    }

    /// @notice Switch between PRODUCTION and SIMULATION modes.
    /// @dev In PRODUCTION mode, transferAssets() builds and executes real XCM.
    ///      In SIMULATION mode, it does local token transfers for testing.
    function setMode(Mode _mode) external {
        if (msg.sender != owner) revert NotOwner();
        Mode oldMode = mode;
        mode = _mode;
        emit ModeChanged(oldMode, _mode);
    }

    /// @notice Update the Asset Hub parachain ID.
    function setAssetHubParaId(uint32 _paraId) external {
        if (msg.sender != owner) revert NotOwner();
        assetHubParaId = _paraId;
    }

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @notice Preview the XCM message that would be sent for a transfer.
    /// @dev Useful for debugging and verification. Returns the raw bytes
    ///      that would be passed to xcmPrecompile.execute().
    function previewXCMMessage(
        uint128 assetId,
        uint256 amount,
        uint32 destParaId,
        address beneficiary
    ) external view returns (bytes memory) {
        return XCMMessageBuilder.buildTransferToParachain(
            assetId,
            amount,
            destParaId,
            beneficiary,
            assetHubParaId
        );
    }

    function deploymentCount() external view returns (uint256) {
        return _deployments.length;
    }
}
