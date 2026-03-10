//! ALIVE Evolution Engine — PolkaVM coprocessor for genetic algorithms.
//!
//! Three public entry points mirror the `IEvolutionEngine` Solidity
//! interface:
//!
//! 1. [`evaluate_fitness`] – score a population and return sorted results.
//! 2. [`crossover`]       – combine two parent DNA strands.
//! 3. [`mutate`]          – randomly perturb a DNA strand.
//!
//! The crate compiles as a `cdylib` for the PVM target
//! (`riscv32im-unknown-none-elf`) and as an `rlib` for native tests.

#![cfg_attr(not(feature = "std"), no_std)]

#[cfg(not(feature = "std"))]
extern crate alloc;

pub mod types;
pub mod fitness;
pub mod crossover;
pub mod mutation;

// Re-export public API for convenience.
pub use types::{DNA, DnaFieldRanges, FitnessResult, PerformanceRecord};
pub use fitness::evaluate_fitness;
pub use crossover::crossover;
pub use mutation::mutate;
