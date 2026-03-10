//! Shared types for the ALIVE Evolution Engine.
//!
//! These types mirror the Solidity ABI-encoded structs used by
//! `IEvolutionEngine.sol`. When called via the PVM precompile,
//! data is ABI-decoded from calldata into these structs.

#[cfg(not(feature = "std"))]
use alloc::{vec, vec::Vec};

/// Strategy genome for a single Creature.
///
/// Each field encodes one behavioral parameter. Crossover swaps
/// fields between parents; mutation perturbs fields within their
/// valid ranges.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DNA {
    /// Target parachain ID (0–255).
    pub target_chain_id: u8,
    /// Pool / strategy type.
    ///   0 = AMM_LP, 1 = LENDING, 2 = STAKING,
    ///   3 = VAULT,  4 = STABLE_SWAP, 5 = RESTAKING
    pub pool_type: u8,
    /// Fraction of capital to deploy (basis points, 1000–10000).
    pub allocation_ratio: u16,
    /// Drift threshold before rebalancing (basis points, 100–2000).
    pub rebalance_threshold: u16,
    /// Max acceptable slippage (basis points, 10–500).
    pub max_slippage: u16,
    /// Minimum annualized yield worth pursuing (basis points, 100–5000).
    pub yield_floor: u16,
    /// Risk tolerance on a 1–10 scale.
    pub risk_ceiling: u8,
    /// Epoch offset before entering a position (0–5).
    pub entry_timing: u8,
    /// Epochs to hold before harvesting (1–10).
    pub exit_timing: u8,
    /// Capital kept as reserve hedge (basis points, 0–5000).
    pub hedge_ratio: u16,
}

/// Performance record for a Creature at the end of an epoch.
///
/// Collected on-chain by `GenePool.sol` and forwarded to the
/// Evolution Engine for fitness scoring.
#[derive(Debug, Clone)]
pub struct PerformanceRecord {
    /// On-chain address of the Creature (as a 20-byte value
    /// packed into u64 for PVM; the full address is unnecessary
    /// for ranking—only used to tag results back).
    pub creature_id: u64,
    /// Return from the most recent epoch (signed, scaled by 1e6).
    pub last_return: i64,
    /// Cumulative return across all epochs (signed, scaled by 1e6).
    pub cumulative_return: i64,
    /// Number of epochs this Creature has survived.
    pub epochs_survived: u64,
    /// Worst single-epoch loss (signed, scaled by 1e6, ≤ 0 for losses).
    pub max_drawdown: i64,
}

/// Result of fitness evaluation for one Creature.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FitnessResult {
    /// Same id as the input `PerformanceRecord::creature_id`.
    pub creature_id: u64,
    /// Fitness score (higher = better).  Unitless, scaled by 1e4.
    pub fitness_score: u64,
}

// ----------------------------------------------------------------
// DNA field ranges (for mutation bounds)
// ----------------------------------------------------------------

/// Valid ranges for each DNA field: (min, max) inclusive.
pub struct DnaFieldRanges;

impl DnaFieldRanges {
    pub const TARGET_CHAIN_ID: (u8, u8) = (0, 255);
    pub const POOL_TYPE: (u8, u8) = (0, 5);
    pub const ALLOCATION_RATIO: (u16, u16) = (1000, 10000);
    pub const REBALANCE_THRESHOLD: (u16, u16) = (100, 2000);
    pub const MAX_SLIPPAGE: (u16, u16) = (10, 500);
    pub const YIELD_FLOOR: (u16, u16) = (100, 5000);
    pub const RISK_CEILING: (u8, u8) = (1, 10);
    pub const ENTRY_TIMING: (u8, u8) = (0, 5);
    pub const EXIT_TIMING: (u8, u8) = (1, 10);
    pub const HEDGE_RATIO: (u16, u16) = (0, 5000);
}

// ----------------------------------------------------------------
// ABI encoding / decoding helpers
// ----------------------------------------------------------------

impl DNA {
    /// Number of fields in the DNA struct.
    pub const FIELD_COUNT: usize = 10;

    /// Encode DNA into a flat byte vector matching the Solidity
    /// `abi.encode(DNA)` layout: 10 × 32-byte words.
    pub fn to_abi_bytes(&self) -> Vec<u8> {
        let mut buf = vec![0u8; 32 * Self::FIELD_COUNT];
        // Each field occupies a right-aligned 32-byte slot.
        buf[31] = self.target_chain_id;
        buf[63] = self.pool_type;
        buf[94] = (self.allocation_ratio >> 8) as u8;
        buf[95] = self.allocation_ratio as u8;
        buf[126] = (self.rebalance_threshold >> 8) as u8;
        buf[127] = self.rebalance_threshold as u8;
        buf[158] = (self.max_slippage >> 8) as u8;
        buf[159] = self.max_slippage as u8;
        buf[190] = (self.yield_floor >> 8) as u8;
        buf[191] = self.yield_floor as u8;
        buf[223] = self.risk_ceiling;
        buf[255] = self.entry_timing;
        buf[287] = self.exit_timing;
        buf[318] = (self.hedge_ratio >> 8) as u8;
        buf[319] = self.hedge_ratio as u8;
        buf
    }

    /// Decode DNA from a 320-byte ABI-encoded blob.
    pub fn from_abi_bytes(data: &[u8]) -> Option<Self> {
        if data.len() < 32 * Self::FIELD_COUNT {
            return None;
        }
        Some(DNA {
            target_chain_id: data[31],
            pool_type: data[63],
            allocation_ratio: u16::from_be_bytes([data[94], data[95]]),
            rebalance_threshold: u16::from_be_bytes([data[126], data[127]]),
            max_slippage: u16::from_be_bytes([data[158], data[159]]),
            yield_floor: u16::from_be_bytes([data[190], data[191]]),
            risk_ceiling: data[223],
            entry_timing: data[255],
            exit_timing: data[287],
            hedge_ratio: u16::from_be_bytes([data[318], data[319]]),
        })
    }
}
