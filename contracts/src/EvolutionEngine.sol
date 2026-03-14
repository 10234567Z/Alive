// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEvolutionEngine} from "./interfaces/IEvolutionEngine.sol";
import {ICreature} from "./interfaces/ICreature.sol";

/// @title EvolutionEngine
/// @notice Production evolution engine implementing the same algorithms as
///         the PVM Rust engine (pvm/src/fitness.rs, crossover.rs, mutation.rs).
///
///         Fitness formula (matching Rust):
///           fitness = annualized_return × 40
///                   + sharpe_proxy      × 30
///                   - drawdown_penalty  × 20
///                   + survival_bonus    × 10
///
///         Crossover: Uniform crossover using seed bits per DNA field.
///         Mutation:  xorshift64 PRNG with per-field range-bounded mutation.
///
///         This contract runs on EVM. The identical logic is also compiled
///         to RISC-V via pvm/ for native PolkaVM execution on Polkadot Hub.
contract EvolutionEngine is IEvolutionEngine {

    // ================================================================
    // Fitness Evaluation
    // ================================================================

    /// @inheritdoc IEvolutionEngine
    function evaluateFitness(
        PerformanceRecord[] calldata records
    ) external pure override returns (FitnessResult[] memory results) {
        uint256 len = records.length;
        results = new FitnessResult[](len);

        // Compute fitness scores
        for (uint256 i = 0; i < len; i++) {
            results[i] = FitnessResult({
                creatureAddr: records[i].creatureAddr,
                fitnessScore: _computeFitness(records[i])
            });
        }

        // Bubble sort descending by fitnessScore (fine for population sizes < 100)
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

    /// @dev Multi-factor fitness scoring, ported from pvm/src/fitness.rs::compute_fitness.
    ///
    ///      All intermediate values are scaled to avoid floating point.
    ///      Input returns are in raw stablecoin units (USDC 6 decimals).
    ///
    ///      Components:
    ///        1. Annualized return (weight 40) — avg return per epoch, shifted positive
    ///        2. Sharpe proxy    (weight 30) — avg return / (|maxDrawdown| + 1)
    ///        3. Drawdown penalty (weight 20) — penalizes worst-epoch losses
    ///        4. Survival bonus   (weight 10) — rewards longevity, capped at 20 epochs
    function _computeFitness(PerformanceRecord calldata r) internal pure returns (uint256) {
        uint256 epochs = r.epochsSurvived == 0 ? 1 : r.epochsSurvived;

        // ── 1. Annualized return component (weight 40) ──────────────
        //
        // average_return_per_epoch = cumulativeReturn / epochs
        // Shift by +10_000_000 (10 USDC) so even moderately negative returns > 0
        int256 avgReturn = r.cumulativeReturn / int256(epochs);
        int256 shiftedSigned = avgReturn + 10_000_000;
        if (shiftedSigned < 0) shiftedSigned = 0;
        uint256 shiftedReturn = uint256(shiftedSigned);
        uint256 annualizedComponent = (shiftedReturn * 40) / 10_000;

        // ── 2. Sharpe-like ratio component (weight 30) ──────────────
        //
        // sharpe_proxy = shiftedReturn / (|maxDrawdown| + 1)
        // Larger drawdowns penalize the ratio.
        uint256 ddAbs;
        if (r.maxDrawdown < 0) {
            ddAbs = uint256(-r.maxDrawdown);
        }
        // else ddAbs = 0

        uint256 sharpeProxy;
        if (ddAbs == 0) {
            sharpeProxy = shiftedReturn; // no drawdown → full credit
        } else {
            // Scale to maintain precision
            sharpeProxy = (shiftedReturn * 1_000_000) / (ddAbs + 1);
        }
        uint256 sharpeComponent = (sharpeProxy * 30) / 10_000;

        // ── 3. Drawdown penalty component (weight 20) ───────────────
        uint256 drawdownPenalty = (ddAbs * 20) / 10_000;

        // ── 4. Survival bonus component (weight 10) ─────────────────
        //    Capped at 20 epochs to prevent immortality bias.
        uint256 survivalEpochs = epochs > 20 ? 20 : epochs;
        uint256 survivalBonus = survivalEpochs * 10;

        // ── Combine ─────────────────────────────────────────────────
        uint256 raw = annualizedComponent + sharpeComponent + survivalBonus;
        if (raw > drawdownPenalty) {
            return raw - drawdownPenalty;
        }
        return 0;
    }

    // ================================================================
    // Crossover — Uniform crossover (matching pvm/src/crossover.rs)
    // ================================================================

    /// @inheritdoc IEvolutionEngine
    /// @dev For each of the 10 DNA fields, one bit of the seed selects
    ///      which parent contributes that field:
    ///        bit = 1 → parent1,  bit = 0 → parent2
    function crossover(
        bytes calldata parent1Dna,
        bytes calldata parent2Dna,
        uint256 seed
    ) external pure override returns (bytes memory) {
        ICreature.DNA memory p1 = abi.decode(parent1Dna, (ICreature.DNA));
        ICreature.DNA memory p2 = abi.decode(parent2Dna, (ICreature.DNA));

        ICreature.DNA memory child;

        // Field 0: targetChainId
        child.targetChainId = (seed & (1 << 0)) != 0
            ? p1.targetChainId : p2.targetChainId;

        // Field 1: poolType
        child.poolType = (seed & (1 << 1)) != 0
            ? p1.poolType : p2.poolType;

        // Field 2: allocationRatio
        child.allocationRatio = (seed & (1 << 2)) != 0
            ? p1.allocationRatio : p2.allocationRatio;

        // Field 3: rebalanceThreshold
        child.rebalanceThreshold = (seed & (1 << 3)) != 0
            ? p1.rebalanceThreshold : p2.rebalanceThreshold;

        // Field 4: maxSlippage
        child.maxSlippage = (seed & (1 << 4)) != 0
            ? p1.maxSlippage : p2.maxSlippage;

        // Field 5: yieldFloor
        child.yieldFloor = (seed & (1 << 5)) != 0
            ? p1.yieldFloor : p2.yieldFloor;

        // Field 6: riskCeiling
        child.riskCeiling = (seed & (1 << 6)) != 0
            ? p1.riskCeiling : p2.riskCeiling;

        // Field 7: entryTiming
        child.entryTiming = (seed & (1 << 7)) != 0
            ? p1.entryTiming : p2.entryTiming;

        // Field 8: exitTiming
        child.exitTiming = (seed & (1 << 8)) != 0
            ? p1.exitTiming : p2.exitTiming;

        // Field 9: hedgeRatio
        child.hedgeRatio = (seed & (1 << 9)) != 0
            ? p1.hedgeRatio : p2.hedgeRatio;

        return abi.encode(child);
    }

    // ================================================================
    // Mutation — xorshift64 PRNG (matching pvm/src/mutation.rs)
    // ================================================================

    /// @inheritdoc IEvolutionEngine
    /// @dev For each DNA field, a pseudo-random check (xorshift64)
    ///      determines whether to mutate. If triggered, the field is
    ///      replaced with a random value in its valid range.
    function mutate(
        bytes calldata dna,
        uint256 mutationRate,
        uint256 seed
    ) external pure override returns (bytes memory) {
        ICreature.DNA memory d = abi.decode(dna, (ICreature.DNA));

        // Initialize xorshift64 state (must not be zero)
        uint256 state = seed == 0 ? 1 : seed;

        // Field 0: targetChainId (range 0–255)
        (state, d.targetChainId) = _maybeMutateU8(
            state, mutationRate, d.targetChainId, 0, 255
        );

        // Field 1: poolType (range 0–5)
        (state, d.poolType) = _maybeMutateU8(
            state, mutationRate, d.poolType, 0, 5
        );

        // Field 2: allocationRatio (range 1000–10000)
        (state, d.allocationRatio) = _maybeMutateU16(
            state, mutationRate, d.allocationRatio, 1000, 10000
        );

        // Field 3: rebalanceThreshold (range 100–2000)
        (state, d.rebalanceThreshold) = _maybeMutateU16(
            state, mutationRate, d.rebalanceThreshold, 100, 2000
        );

        // Field 4: maxSlippage (range 10–500)
        (state, d.maxSlippage) = _maybeMutateU16(
            state, mutationRate, d.maxSlippage, 10, 500
        );

        // Field 5: yieldFloor (range 100–5000)
        (state, d.yieldFloor) = _maybeMutateU16(
            state, mutationRate, d.yieldFloor, 100, 5000
        );

        // Field 6: riskCeiling (range 1–10)
        (state, d.riskCeiling) = _maybeMutateU8(
            state, mutationRate, d.riskCeiling, 1, 10
        );

        // Field 7: entryTiming (range 0–5)
        (state, d.entryTiming) = _maybeMutateU8(
            state, mutationRate, d.entryTiming, 0, 5
        );

        // Field 8: exitTiming (range 1–10)
        (state, d.exitTiming) = _maybeMutateU8(
            state, mutationRate, d.exitTiming, 1, 10
        );

        // Field 9: hedgeRatio (range 0–5000)
        (state, d.hedgeRatio) = _maybeMutateU16(
            state, mutationRate, d.hedgeRatio, 0, 5000
        );

        return abi.encode(d);
    }

    // ================================================================
    // Internal: xorshift64 PRNG helpers
    // ================================================================

    /// @dev Advance xorshift64 state and return the new pseudo-random value.
    ///      Exact same shifts as pvm/src/mutation.rs: <<13, >>7, <<17.
    function _xorshift64(uint256 state) internal pure returns (uint256) {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        // Mask to u64 to match Rust's u64 overflow behavior
        return state & 0xFFFFFFFFFFFFFFFF;
    }

    /// @dev Check if mutation should occur (rate/10000 probability),
    ///      optionally mutate a uint8 field.
    function _maybeMutateU8(
        uint256 state,
        uint256 mutationRate,
        uint8 currentValue,
        uint8 lo,
        uint8 hi
    ) internal pure returns (uint256 newState, uint8 result) {
        // Advance RNG for the mutation check
        newState = _xorshift64(state);
        uint256 roll = newState % 10_000;

        if (roll < mutationRate) {
            // Mutate: generate a random value in [lo, hi]
            newState = _xorshift64(newState);
            uint256 range = uint256(hi) - uint256(lo) + 1;
            result = uint8(lo + (newState % range));
        } else {
            result = currentValue;
        }
    }

    /// @dev Check if mutation should occur, optionally mutate a uint16 field.
    function _maybeMutateU16(
        uint256 state,
        uint256 mutationRate,
        uint16 currentValue,
        uint16 lo,
        uint16 hi
    ) internal pure returns (uint256 newState, uint16 result) {
        newState = _xorshift64(state);
        uint256 roll = newState % 10_000;

        if (roll < mutationRate) {
            newState = _xorshift64(newState);
            uint256 range = uint256(hi) - uint256(lo) + 1;
            result = uint16(lo + (newState % range));
        } else {
            result = currentValue;
        }
    }
}
