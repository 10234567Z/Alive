// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Creature} from "./Creature.sol";
import {ICreature} from "./interfaces/ICreature.sol";

/// @title CreatureFactory
/// @notice Deploys new Creature contract instances using CREATE2 for
///         deterministic addressing. Only the GenePool or Ecosystem
///         should call deploy().
contract CreatureFactory {
    // ----------------------------------------------------------------
    // State
    // ----------------------------------------------------------------

    address public ecosystem;
    address public genePool;
    address public stablecoin;
    address public xcmPrecompile;
    uint256 public nonce;

    // ----------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------

    event CreatureDeployed(
        address indexed creature,
        uint256 generation,
        address parent1,
        address parent2,
        uint256 nonce
    );

    // ----------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------

    modifier onlyAuthorized() {
        require(
            msg.sender == ecosystem || msg.sender == genePool,
            "CreatureFactory: unauthorized"
        );
        _;
    }

    // ----------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------

    constructor(
        address _stablecoin,
        address _xcmPrecompile
    ) {
        stablecoin = _stablecoin;
        xcmPrecompile = _xcmPrecompile;
    }

    /// @notice Set the Ecosystem address. Called once after Ecosystem is deployed.
    function setEcosystem(address _ecosystem) external {
        require(ecosystem == address(0), "CreatureFactory: ecosystem already set");
        ecosystem = _ecosystem;
    }

    /// @notice Set the GenePool address. Called once after GenePool is deployed.
    function setGenePool(address _genePool) external {
        require(genePool == address(0), "CreatureFactory: genePool already set");
        genePool = _genePool;
    }

    // ----------------------------------------------------------------
    // Deployment
    // ----------------------------------------------------------------

    /// @notice Deploy a new Creature with the given DNA and metadata.
    /// @param dna The strategy genome for the new Creature.
    /// @param gen Generation number (0 for seeds, parent.gen+1 for offspring).
    /// @param p1 Address of parent 1 (address(0) for seed Creatures).
    /// @param p2 Address of parent 2 (address(0) for seed Creatures).
    /// @param epoch The current epoch at time of birth.
    /// @return creature The address of the newly deployed Creature.
    function deploy(
        ICreature.DNA memory dna,
        uint256 gen,
        address p1,
        address p2,
        uint256 epoch
    ) external onlyAuthorized returns (address creature) {
        bytes32 salt = keccak256(abi.encodePacked(nonce, block.timestamp, block.prevrandao));
        nonce++;

        Creature c = new Creature{salt: salt}();
        c.initialize(dna, gen, p1, p2, epoch, ecosystem, stablecoin, xcmPrecompile);

        creature = address(c);
        emit CreatureDeployed(creature, gen, p1, p2, nonce - 1);
    }

    /// @notice Compute the deterministic address for a Creature deployment
    ///         given a specific nonce value (for off-chain prediction).
    function computeAddress(uint256 _nonce) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_nonce, block.timestamp, block.prevrandao));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(type(Creature).creationCode)
            )
        );
        return address(uint160(uint256(hash)));
    }
}
