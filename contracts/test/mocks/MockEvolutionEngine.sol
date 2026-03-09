// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEvolutionEngine} from "../../src/interfaces/IEvolutionEngine.sol";

/// @title MockEvolutionEngine
/// @notice Mock PVM Evolution Engine for testing.
///         Implements deterministic behavior:
///         - evaluateFitness: ranks by cumulativeReturn descending
///         - crossover: takes first parent's DNA (simple copy)
///         - mutate: returns DNA unchanged
contract MockEvolutionEngine is IEvolutionEngine {

    /// @notice Evaluate fitness: score = cumulativeReturn + epochsSurvived * 100
    ///         Returns sorted descending by fitness.
    function evaluateFitness(
        PerformanceRecord[] calldata records
    ) external pure override returns (FitnessResult[] memory results) {
        uint256 len = records.length;
        results = new FitnessResult[](len);

        // Compute scores
        for (uint256 i = 0; i < len; i++) {
            uint256 score;
            if (records[i].cumulativeReturn > 0) {
                score = uint256(records[i].cumulativeReturn) + records[i].epochsSurvived * 100;
            } else {
                // Negative returns get low score (just epochsSurvived bonus)
                score = records[i].epochsSurvived * 10;
            }
            results[i] = FitnessResult({
                creatureAddr: records[i].creatureAddr,
                fitnessScore: score
            });
        }

        // Simple bubble sort descending (fine for test sizes)
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (results[j].fitnessScore > results[i].fitnessScore) {
                    FitnessResult memory temp = results[i];
                    results[i] = results[j];
                    results[j] = temp;
                }
            }
        }
    }

    /// @notice Crossover: simple average of parent DNAs (take parent1 bytes).
    function crossover(
        bytes calldata parent1Dna,
        bytes calldata, /* parent2Dna */
        uint256 /* seed */
    ) external pure override returns (bytes memory) {
        // For test simplicity, return parent1's DNA as the offspring
        return parent1Dna;
    }

    /// @notice Mutate: no-op, returns DNA unchanged.
    function mutate(
        bytes calldata dna,
        uint256, /* mutationRate */
        uint256 /* seed */
    ) external pure override returns (bytes memory) {
        return dna;
    }
}
