// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEvolutionEngine
/// @notice Interface for the PVM-based Evolution Engine.
/// Called from Solidity via PVM precompile. The implementation
/// runs as Rust compiled to RISC-V on PolkaVM.
interface IEvolutionEngine {
    struct PerformanceRecord {
        address creatureAddr;
        int256 lastReturn;
        int256 cumulativeReturn;
        uint256 epochsSurvived;
        int256 maxDrawdown;
        uint256 balance;  // current USDC balance (6 decimals), used to normalize returns
    }

    struct FitnessResult {
        address creatureAddr;
        uint256 fitnessScore;
    }

    /// @notice Score all Creatures and return ranked fitness results.
    /// @param records Array of performance data, one per Creature.
    /// @return Sorted array (descending by fitnessScore).
    function evaluateFitness(PerformanceRecord[] calldata records)
        external
        view
        returns (FitnessResult[] memory);

    /// @notice Crossover two parent genomes to produce offspring DNA.
    /// @param parent1Dna ABI-encoded DNA of parent 1.
    /// @param parent2Dna ABI-encoded DNA of parent 2.
    /// @param seed Randomness seed (e.g., blockhash-derived).
    /// @return offspringDna ABI-encoded DNA of the offspring.
    function crossover(
        bytes calldata parent1Dna,
        bytes calldata parent2Dna,
        uint256 seed
    ) external view returns (bytes memory offspringDna);

    /// @notice Apply random mutations to a genome.
    /// @param dna ABI-encoded DNA.
    /// @param mutationRate Probability in basis points (0-10000).
    /// @param seed Randomness seed.
    /// @return mutatedDna ABI-encoded mutated DNA.
    function mutate(
        bytes calldata dna,
        uint256 mutationRate,
        uint256 seed
    ) external view returns (bytes memory mutatedDna);
}
