//! Genome mutation for the ALIVE Evolution Engine.
//!
//! For each DNA field, a pseudo-random check determines whether to
//! mutate.  If triggered, the field is replaced with a random value
//! drawn uniformly from its valid range.
//!
//! Randomness is derived from a 64-bit seed via a simple xorshift
//! PRNG to avoid external dependencies (crucial for `no_std` / PVM).

use crate::types::{DnaFieldRanges, DNA};

// ----------------------------------------------------------------
// Minimal xorshift64 PRNG (no_std friendly)
// ----------------------------------------------------------------

struct Rng {
    state: u64,
}

impl Rng {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 1 } else { seed },
        }
    }

    /// Return the next pseudo-random u64.
    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }

    /// Return a value in `[0, max)`.
    fn next_bounded(&mut self, max: u64) -> u64 {
        if max == 0 {
            return 0;
        }
        self.next_u64() % max
    }

    /// Return a u8 in `[lo, hi]` inclusive.
    fn rand_u8(&mut self, lo: u8, hi: u8) -> u8 {
        let range = (hi as u64) - (lo as u64) + 1;
        lo + self.next_bounded(range) as u8
    }

    /// Return a u16 in `[lo, hi]` inclusive.
    fn rand_u16(&mut self, lo: u16, hi: u16) -> u16 {
        let range = (hi as u64) - (lo as u64) + 1;
        lo + self.next_bounded(range) as u16
    }

    /// Return `true` with probability `rate / 10_000`.
    fn should_mutate(&mut self, rate: u16) -> bool {
        let roll = self.next_bounded(10_000) as u16;
        roll < rate
    }
}

// ----------------------------------------------------------------
// Public API
// ----------------------------------------------------------------

/// Mutate a DNA struct in place.
///
/// `mutation_rate` – probability per field (basis points, 0–10 000).
/// `seed` – 64-bit seed for the PRNG (from on-chain randomness).
///
/// Returns a new DNA with zero or more fields randomly replaced.
pub fn mutate(dna: &DNA, mutation_rate: u16, seed: u64) -> DNA {
    let mut rng = Rng::new(seed);
    let mut out = dna.clone();

    // Field 0: target_chain_id
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::TARGET_CHAIN_ID;
        out.target_chain_id = rng.rand_u8(lo, hi);
    }

    // Field 1: pool_type
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::POOL_TYPE;
        out.pool_type = rng.rand_u8(lo, hi);
    }

    // Field 2: allocation_ratio
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::ALLOCATION_RATIO;
        out.allocation_ratio = rng.rand_u16(lo, hi);
    }

    // Field 3: rebalance_threshold
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::REBALANCE_THRESHOLD;
        out.rebalance_threshold = rng.rand_u16(lo, hi);
    }

    // Field 4: max_slippage
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::MAX_SLIPPAGE;
        out.max_slippage = rng.rand_u16(lo, hi);
    }

    // Field 5: yield_floor
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::YIELD_FLOOR;
        out.yield_floor = rng.rand_u16(lo, hi);
    }

    // Field 6: risk_ceiling
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::RISK_CEILING;
        out.risk_ceiling = rng.rand_u8(lo, hi);
    }

    // Field 7: entry_timing
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::ENTRY_TIMING;
        out.entry_timing = rng.rand_u8(lo, hi);
    }

    // Field 8: exit_timing
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::EXIT_TIMING;
        out.exit_timing = rng.rand_u8(lo, hi);
    }

    // Field 9: hedge_ratio
    if rng.should_mutate(mutation_rate) {
        let (lo, hi) = DnaFieldRanges::HEDGE_RATIO;
        out.hedge_ratio = rng.rand_u16(lo, hi);
    }

    out
}

// ================================================================
// Unit tests
// ================================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_dna() -> DNA {
        DNA {
            target_chain_id: 10,
            pool_type: 2,
            allocation_ratio: 5000,
            rebalance_threshold: 800,
            max_slippage: 200,
            yield_floor: 1500,
            risk_ceiling: 5,
            entry_timing: 2,
            exit_timing: 4,
            hedge_ratio: 1000,
        }
    }

    #[test]
    fn test_zero_mutation_rate_no_change() {
        let dna = sample_dna();
        let mutated = mutate(&dna, 0, 42);
        assert_eq!(mutated, dna, "Zero mutation rate should produce no changes");
    }

    #[test]
    fn test_full_mutation_rate_changes_something() {
        let dna = sample_dna();
        // With rate = 10000 (100%) every field should mutate
        let mutated = mutate(&dna, 10_000, 12345);
        // Very unlikely (essentially impossible) that all 10 fields
        // randomly land on their original values.
        assert_ne!(mutated, dna, "100% mutation rate should change at least one field");
    }

    #[test]
    fn test_mutation_is_deterministic() {
        let dna = sample_dna();
        let m1 = mutate(&dna, 5000, 99);
        let m2 = mutate(&dna, 5000, 99);
        assert_eq!(m1, m2, "Same seed should produce identical mutations");
    }

    #[test]
    fn test_mutated_fields_in_range() {
        let dna = sample_dna();
        // Run many mutations and verify bounds
        for seed in 0..100 {
            let m = mutate(&dna, 10_000, seed * 7 + 1);

            let (lo, hi) = DnaFieldRanges::POOL_TYPE;
            assert!(m.pool_type >= lo && m.pool_type <= hi,
                "pool_type {} out of range [{}, {}]", m.pool_type, lo, hi);

            let (lo, hi) = DnaFieldRanges::ALLOCATION_RATIO;
            assert!(m.allocation_ratio >= lo && m.allocation_ratio <= hi,
                "allocation_ratio {} out of range [{}, {}]", m.allocation_ratio, lo, hi);

            let (lo, hi) = DnaFieldRanges::REBALANCE_THRESHOLD;
            assert!(m.rebalance_threshold >= lo && m.rebalance_threshold <= hi);

            let (lo, hi) = DnaFieldRanges::MAX_SLIPPAGE;
            assert!(m.max_slippage >= lo && m.max_slippage <= hi);

            let (lo, hi) = DnaFieldRanges::YIELD_FLOOR;
            assert!(m.yield_floor >= lo && m.yield_floor <= hi);

            let (lo, hi) = DnaFieldRanges::RISK_CEILING;
            assert!(m.risk_ceiling >= lo && m.risk_ceiling <= hi);

            let (lo, hi) = DnaFieldRanges::ENTRY_TIMING;
            assert!(m.entry_timing >= lo && m.entry_timing <= hi);

            let (lo, hi) = DnaFieldRanges::EXIT_TIMING;
            assert!(m.exit_timing >= lo && m.exit_timing <= hi);

            let (lo, hi) = DnaFieldRanges::HEDGE_RATIO;
            assert!(m.hedge_ratio >= lo && m.hedge_ratio <= hi);
        }
    }

    #[test]
    fn test_different_seeds_different_results() {
        let dna = sample_dna();
        let m1 = mutate(&dna, 10_000, 111);
        let m2 = mutate(&dna, 10_000, 222);
        // Not guaranteed to differ, but with 100% rate and 10 fields
        // the probability of identical output from different seeds is
        // astronomically low.
        assert_ne!(m1, m2, "Different seeds should (almost certainly) produce different mutations");
    }
}
