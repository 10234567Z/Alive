//! Genome crossover for the ALIVE Evolution Engine.
//!
//! Implements **uniform crossover**: for each field in the DNA struct,
//! one bit of the seed determines whether the child inherits from
//! parent 1 or parent 2.  This produces maximal recombination while
//! remaining fully deterministic for a given seed.

use crate::types::DNA;

/// Uniform crossover of two parent DNAs.
///
/// For each of the 10 DNA fields, bit `i` of `seed` selects the
/// donor parent:
///   - bit = 1 → take from `parent1`
///   - bit = 0 → take from `parent2`
///
/// The seed is expected to come from on-chain randomness (e.g.
/// `keccak256(prevrandao, timestamp, parents)`).
pub fn crossover(parent1: &DNA, parent2: &DNA, seed: u64) -> DNA {
    DNA {
        target_chain_id: if seed & (1 << 0) != 0 {
            parent1.target_chain_id
        } else {
            parent2.target_chain_id
        },
        pool_type: if seed & (1 << 1) != 0 {
            parent1.pool_type
        } else {
            parent2.pool_type
        },
        allocation_ratio: if seed & (1 << 2) != 0 {
            parent1.allocation_ratio
        } else {
            parent2.allocation_ratio
        },
        rebalance_threshold: if seed & (1 << 3) != 0 {
            parent1.rebalance_threshold
        } else {
            parent2.rebalance_threshold
        },
        max_slippage: if seed & (1 << 4) != 0 {
            parent1.max_slippage
        } else {
            parent2.max_slippage
        },
        yield_floor: if seed & (1 << 5) != 0 {
            parent1.yield_floor
        } else {
            parent2.yield_floor
        },
        risk_ceiling: if seed & (1 << 6) != 0 {
            parent1.risk_ceiling
        } else {
            parent2.risk_ceiling
        },
        entry_timing: if seed & (1 << 7) != 0 {
            parent1.entry_timing
        } else {
            parent2.entry_timing
        },
        exit_timing: if seed & (1 << 8) != 0 {
            parent1.exit_timing
        } else {
            parent2.exit_timing
        },
        hedge_ratio: if seed & (1 << 9) != 0 {
            parent1.hedge_ratio
        } else {
            parent2.hedge_ratio
        },
    }
}

// ================================================================
// Unit tests
// ================================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn parent_a() -> DNA {
        DNA {
            target_chain_id: 1,
            pool_type: 0,
            allocation_ratio: 8000,
            rebalance_threshold: 500,
            max_slippage: 100,
            yield_floor: 1000,
            risk_ceiling: 3,
            entry_timing: 0,
            exit_timing: 5,
            hedge_ratio: 2000,
        }
    }

    fn parent_b() -> DNA {
        DNA {
            target_chain_id: 200,
            pool_type: 4,
            allocation_ratio: 3000,
            rebalance_threshold: 1500,
            max_slippage: 400,
            yield_floor: 4000,
            risk_ceiling: 9,
            entry_timing: 5,
            exit_timing: 1,
            hedge_ratio: 500,
        }
    }

    #[test]
    fn test_all_bits_set_returns_parent1() {
        // seed = all 1s → every field from parent1
        let seed = u64::MAX;
        let child = crossover(&parent_a(), &parent_b(), seed);
        assert_eq!(child, parent_a());
    }

    #[test]
    fn test_no_bits_set_returns_parent2() {
        // seed = 0 → every field from parent2
        let seed = 0;
        let child = crossover(&parent_a(), &parent_b(), seed);
        assert_eq!(child, parent_b());
    }

    #[test]
    fn test_mixed_seed_produces_hybrid() {
        // seed = 0b0101010101 → alternating fields
        let seed = 0b0101010101;
        let child = crossover(&parent_a(), &parent_b(), seed);

        // Bit 0 = 1 → target_chain_id from parent_a
        assert_eq!(child.target_chain_id, parent_a().target_chain_id);
        // Bit 1 = 0 → pool_type from parent_b
        assert_eq!(child.pool_type, parent_b().pool_type);
        // Bit 2 = 1 → allocation_ratio from parent_a
        assert_eq!(child.allocation_ratio, parent_a().allocation_ratio);
        // Bit 3 = 0 → rebalance_threshold from parent_b
        assert_eq!(child.rebalance_threshold, parent_b().rebalance_threshold);
        // Bit 4 = 1 → max_slippage from parent_a
        assert_eq!(child.max_slippage, parent_a().max_slippage);
        // Bit 5 = 0 → yield_floor from parent_b
        assert_eq!(child.yield_floor, parent_b().yield_floor);
        // Bit 6 = 1 → risk_ceiling from parent_a
        assert_eq!(child.risk_ceiling, parent_a().risk_ceiling);
        // Bit 7 = 0 → entry_timing from parent_b
        assert_eq!(child.entry_timing, parent_b().entry_timing);
        // Bit 8 = 1 → exit_timing from parent_a
        assert_eq!(child.exit_timing, parent_a().exit_timing);
        // Bit 9 = 0 → hedge_ratio from parent_b
        assert_eq!(child.hedge_ratio, parent_b().hedge_ratio);
    }

    #[test]
    fn test_crossover_is_deterministic() {
        let a = parent_a();
        let b = parent_b();
        let seed = 12345u64;

        let c1 = crossover(&a, &b, seed);
        let c2 = crossover(&a, &b, seed);

        assert_eq!(c1, c2, "Same seed should produce identical offspring");
    }

    #[test]
    fn test_crossover_same_parents_returns_same() {
        let a = parent_a();
        let child = crossover(&a, &a, 42);
        assert_eq!(child, a, "Crossing a parent with itself should return itself");
    }
}
