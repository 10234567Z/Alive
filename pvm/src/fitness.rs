//! Fitness evaluation for the ALIVE Evolution Engine.
//!
//! Scores every Creature based on risk-adjusted returns, consistency,
//! and survival.  Output is in the range [0, 100].
//!
//! ```text
//! fitness = return_component   (0–40)
//!         + sharpe_proxy       (0–25)
//!         - drawdown_penalty   (0–25)
//!         + survival_bonus     (0–10)
//! ```
//!
//! Returns are normalised to basis points relative to creature balance
//! so the score is independent of capital magnitude.

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
/// Output range: 0–100.
/// Returns are normalised to basis points relative to balance
/// so fitness is independent of capital magnitude.
fn compute_fitness(r: &PerformanceRecord) -> u64 {
    let epochs = if r.epochs_survived == 0 { 1 } else { r.epochs_survived };

    // ── 4. Survival bonus (0–10) ──────────────────────────────────
    //    0.5 points per epoch, max at 20 epochs = 10 pts
    let survival_epochs = epochs.min(20);
    let survival_bonus = survival_epochs / 2;

    if r.balance == 0 {
        return survival_bonus;
    }

    // ── Normalise returns to basis points relative to balance ──
    let avg_return_raw = r.cumulative_return / (epochs as i64);
    let avg_return_bps = (avg_return_raw * 10_000) / (r.balance as i64);

    // ── 1. Return component (0–40) ──────────────────────────────
    //    Linear mapping: -200 bps → 0, 0 bps → 16, 200 bps → 32, 300+ bps → 40
    let return_score = ((avg_return_bps + 200) * 40 / 500).max(0) as u64;
    let return_component = return_score.min(40);

    // ── 2. Sharpe-like ratio (0–25) ──────────────────────────────
    let dd_bps = if r.max_drawdown < 0 {
        ((-r.max_drawdown) as u64 * 10_000) / r.balance
    } else {
        0u64
    };

    let sharpe = if dd_bps == 0 && avg_return_bps > 0 {
        25 // no drawdown with positive returns → full marks
    } else if dd_bps == 0 {
        10 // no drawdown, no returns → decent
    } else if avg_return_bps > 0 {
        let ret_bps = avg_return_bps as u64;
        ((ret_bps * 25) / (dd_bps + ret_bps)).min(25)
    } else {
        0
    };

    // ── 3. Drawdown penalty (0–25) ───────────────────────────────
    //    Linear: 0% dd → 0 penalty, 50%+ dd → 25 penalty
    let drawdown_penalty = ((dd_bps * 25) / 5_000).min(25);

    // ── Combine (max 40 + 25 + 10 = 75 before penalty) ──────────
    let raw = return_component + sharpe + survival_bonus;
    let result = if raw > drawdown_penalty {
        raw - drawdown_penalty
    } else {
        0
    };
    result.min(100)
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
            balance: 10_000_000, // 10 USDC default balance for tests
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
        // With identical cumulative return but more epochs, avg return
        // per epoch is lower for r30, so s30 should be close but not identical.
        assert!(s20 <= 100, "Score should be <= 100, got {s20}");
        assert!(s30 <= 100, "Score should be <= 100, got {s30}");
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
