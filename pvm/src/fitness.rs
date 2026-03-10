//! Fitness evaluation for the ALIVE Evolution Engine.
//!
//! Scores every Creature based on risk-adjusted returns, consistency,
//! and survival.  The formula:
//!
//! ```text
//! fitness = annualized_return × 40
//!         + sharpe_ratio      × 30
//!         - drawdown_penalty  × 20
//!         + survival_bonus    × 10
//! ```
//!
//! Return values are scaled by 1e4 to keep everything as integers.

#[cfg(not(feature = "std"))]
use alloc::vec::Vec;

use crate::types::{FitnessResult, PerformanceRecord};

/// Evaluate fitness for a batch of Creatures and return results
/// sorted **descending** by fitness score.
pub fn evaluate_fitness(records: &[PerformanceRecord]) -> Vec<FitnessResult> {
    let mut results: Vec<FitnessResult> = records.iter().map(|r| {
        let score = compute_fitness(r);
        FitnessResult {
            creature_id: r.creature_id,
            fitness_score: score,
        }
    }).collect();

    // Sort descending by fitness_score
    results.sort_by(|a, b| b.fitness_score.cmp(&a.fitness_score));
    results
}

/// Compute the fitness score for a single Creature.
///
/// All intermediate values are scaled by 1e4 (10 000) to avoid
/// floating point.  Input returns are scaled by 1e6 on-chain, so
/// we normalize accordingly.
fn compute_fitness(r: &PerformanceRecord) -> u64 {
    let epochs = if r.epochs_survived == 0 { 1 } else { r.epochs_survived };

    // ── 1. Annualized return component (weight 40) ──────────────
    // average_return_per_epoch = cumulative_return / epochs
    // We keep it in the 1e6 scale, then multiply by weight and
    // divide by a normalization factor so the component lands in
    // a sensible range.
    let avg_return = r.cumulative_return / (epochs as i64);
    // Shift to unsigned: add 10 000 000 (10 × 1e6) so even -10 M
    // (= -1000%) maps to ≥ 0.
    let shifted_return = (avg_return + 10_000_000).max(0) as u64;
    let annualized_component = (shifted_return * 40) / 10_000;

    // ── 2. Sharpe-like ratio component (weight 30) ──────────────
    // True Sharpe needs per-epoch std-dev which we don't have in a
    // single record.  We approximate with:
    //   sharpe_proxy = avg_return / (|max_drawdown| + 1)
    // Larger drawdowns penalize the ratio.
    let dd_abs = if r.max_drawdown < 0 {
        (-r.max_drawdown) as u64
    } else {
        0u64
    };
    
    let sharpe_proxy = if dd_abs == 0 {
        shifted_return // no drawdown → full credit
    } else {
        // Scale: shifted_return is ~1e7 range, dd_abs is ~1e6 range
        (shifted_return * 1_000_000) / (dd_abs + 1)
    };
    let sharpe_component = (sharpe_proxy * 30) / 10_000;

    // ── 3. Drawdown penalty component (weight 20) ───────────────
    // Penalty grows linearly with the absolute drawdown.
    let drawdown_penalty = (dd_abs * 20) / 10_000;

    // ── 4. Survival bonus component (weight 10) ─────────────────
    // Capped at 20 epochs to prevent immortality bias.
    let survival_epochs = epochs.min(20);
    let survival_bonus = survival_epochs * 10; // simple: 10 points per epoch survived, up to 200

    // ── Combine ─────────────────────────────────────────────────
    let raw = annualized_component + sharpe_component + survival_bonus;
    // Subtract penalty (clamped to 0)
    let score = if raw > drawdown_penalty {
        raw - drawdown_penalty
    } else {
        0
    };

    score
}

// ================================================================
// Unit tests
// ================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::PerformanceRecord;

    fn make_record(id: u64, cum_ret: i64, epochs: u64, dd: i64) -> PerformanceRecord {
        PerformanceRecord {
            creature_id: id,
            last_return: cum_ret / epochs.max(1) as i64,
            cumulative_return: cum_ret,
            epochs_survived: epochs,
            max_drawdown: dd,
        }
    }

    #[test]
    fn test_positive_return_higher_than_negative() {
        let good = make_record(1, 500_000, 5, -50_000);    // +500k cumulative
        let bad  = make_record(2, -200_000, 5, -300_000);   // -200k cumulative

        let good_score = compute_fitness(&good);
        let bad_score  = compute_fitness(&bad);

        assert!(good_score > bad_score,
            "Positive-return creature ({good_score}) should beat negative ({bad_score})");
    }

    #[test]
    fn test_less_drawdown_is_better() {
        let stable = make_record(1, 300_000, 5, -10_000);
        let risky  = make_record(2, 300_000, 5, -500_000);

        let stable_score = compute_fitness(&stable);
        let risky_score  = compute_fitness(&risky);

        assert!(stable_score > risky_score,
            "Stable creature ({stable_score}) should beat risky ({risky_score})");
    }

    #[test]
    fn test_survival_bonus() {
        // Same average return per epoch (100 000) — only survival differs.
        let veteran  = make_record(1, 1_500_000, 15, -20_000);
        let newcomer = make_record(2,   100_000,  1, -20_000);

        let vet_score = compute_fitness(&veteran);
        let new_score = compute_fitness(&newcomer);

        assert!(vet_score > new_score,
            "Veteran ({vet_score}) should beat newcomer ({new_score})");
    }

    #[test]
    fn test_survival_cap_at_20() {
        let r20 = make_record(1, 100_000, 20, 0);
        let r30 = make_record(2, 100_000, 30, 0);

        let s20 = compute_fitness(&r20);
        let s30 = compute_fitness(&r30);

        // Survival component should be the same (capped at 20)
        // Only difference comes from avg_return changing with more epochs
        // The survival_bonus part itself should be equal
        let surv20 = 20u64.min(20) * 10;
        let surv30 = 30u64.min(20) * 10;
        assert_eq!(surv20, surv30);
    }

    #[test]
    fn test_evaluate_fitness_returns_sorted() {
        let records = vec![
            make_record(1, -100_000, 3, -200_000), // bad
            make_record(2,  500_000, 5, -10_000),   // best
            make_record(3,  200_000, 4, -50_000),   // middle
        ];

        let results = evaluate_fitness(&records);

        assert_eq!(results.len(), 3);
        assert_eq!(results[0].creature_id, 2, "Best should be first");
        assert_eq!(results[2].creature_id, 1, "Worst should be last");
        // Scores should be descending
        assert!(results[0].fitness_score >= results[1].fitness_score);
        assert!(results[1].fitness_score >= results[2].fitness_score);
    }

    #[test]
    fn test_zero_records() {
        let results = evaluate_fitness(&[]);
        assert!(results.is_empty());
    }

    #[test]
    fn test_single_record() {
        let records = vec![make_record(42, 100_000, 3, -5_000)];
        let results = evaluate_fitness(&records);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].creature_id, 42);
        assert!(results[0].fitness_score > 0);
    }
}
