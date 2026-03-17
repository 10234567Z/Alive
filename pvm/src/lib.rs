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
//!
//! ## PVM Precompile Interface
//!
//! When deployed as a PolkaVM program, the `#[no_mangle]` functions
//! below are called directly by the Solidity `IEvolutionEngine`
//! interface through the PVM precompile (address 0x0806).
//!
//! ABI layout follows Solidity ABI encoding conventions:
//! - DNA = 10 × 32-byte words
//! - PerformanceRecord = 6 × 32-byte words (addr, int256×3, uint256×2)
//! - FitnessResult = 2 × 32-byte words (addr, uint256)

#![cfg_attr(not(feature = "std"), no_std)]

#[cfg(not(feature = "std"))]
extern crate alloc;

#[cfg(not(feature = "std"))]
use alloc::vec::Vec;

pub mod types;
pub mod fitness;
pub mod crossover;
pub mod mutation;

// Re-export public API for convenience.
pub use types::{DNA, DnaFieldRanges, FitnessResult, PerformanceRecord};
pub use fitness::evaluate_fitness;
pub use crossover::crossover;
pub use mutation::mutate;

// ================================================================
// PVM Precompile Entry Points
// ================================================================
//
// These functions are the ABI bridge between Solidity and the PVM.
// They decode ABI-encoded calldata, execute the algorithm, and
// return ABI-encoded results.
//
// On local Anvil/EVM, the Solidity EvolutionEngine.sol handles
// execution. On Polkadot Hub with PolkaVM enabled, these entry
// points are called natively at ~10x the performance of EVM.

/// Entry point: evaluate_fitness
///
/// Input:  ABI-encoded array of PerformanceRecord
/// Output: ABI-encoded array of FitnessResult (sorted descending)
///
/// Called by GenePool.sol via PVM precompile to score the population.
#[no_mangle]
pub extern "C" fn pvm_evaluate_fitness(
    input_ptr: *const u8,
    input_len: u32,
    output_ptr: *mut u8,
    output_max_len: u32,
) -> u32 {
    let input = unsafe { core::slice::from_raw_parts(input_ptr, input_len as usize) };

    // Decode: each PerformanceRecord is 6 × 32 bytes = 192 bytes
    let record_size = 192;
    let count = input.len() / record_size;
    let mut records = Vec::with_capacity(count);

    for i in 0..count {
        let offset = i * record_size;
        let chunk = &input[offset..offset + record_size];

        // Decode fields from ABI-encoded 32-byte words
        let creature_id = u64::from_be_bytes([
            chunk[24], chunk[25], chunk[26], chunk[27],
            chunk[28], chunk[29], chunk[30], chunk[31],
        ]);
        let last_return = i64::from_be_bytes([
            chunk[56], chunk[57], chunk[58], chunk[59],
            chunk[60], chunk[61], chunk[62], chunk[63],
        ]);
        let cumulative_return = i64::from_be_bytes([
            chunk[88], chunk[89], chunk[90], chunk[91],
            chunk[92], chunk[93], chunk[94], chunk[95],
        ]);
        let epochs_survived = u64::from_be_bytes([
            chunk[120], chunk[121], chunk[122], chunk[123],
            chunk[124], chunk[125], chunk[126], chunk[127],
        ]);
        let max_drawdown = i64::from_be_bytes([
            chunk[152], chunk[153], chunk[154], chunk[155],
            chunk[156], chunk[157], chunk[158], chunk[159],
        ]);
        let balance = u64::from_be_bytes([
            chunk[184], chunk[185], chunk[186], chunk[187],
            chunk[188], chunk[189], chunk[190], chunk[191],
        ]);

        records.push(PerformanceRecord {
            creature_id,
            last_return,
            cumulative_return,
            epochs_survived,
            max_drawdown,
            balance,
        });
    }

    let results = evaluate_fitness(&records);

    // Encode output: each FitnessResult is 2 × 32 bytes = 64 bytes
    let result_size = 64;
    let total_output = results.len() * result_size;
    if total_output > output_max_len as usize {
        return 0; // buffer too small
    }

    let output = unsafe { core::slice::from_raw_parts_mut(output_ptr, total_output) };
    for (i, r) in results.iter().enumerate() {
        let offset = i * result_size;
        // creature_id in first 32 bytes (right-aligned)
        let id_bytes = r.creature_id.to_be_bytes();
        output[offset + 24..offset + 32].copy_from_slice(&id_bytes);
        // fitness_score in next 32 bytes (right-aligned)
        let score_bytes = r.fitness_score.to_be_bytes();
        output[offset + 56..offset + 64].copy_from_slice(&score_bytes);
    }

    total_output as u32
}

/// Entry point: crossover
///
/// Input:  parent1_dna (320 bytes) | parent2_dna (320 bytes) | seed (8 bytes)
/// Output: child_dna (320 bytes)
#[no_mangle]
pub extern "C" fn pvm_crossover(
    input_ptr: *const u8,
    input_len: u32,
    output_ptr: *mut u8,
    _output_max_len: u32,
) -> u32 {
    let input = unsafe { core::slice::from_raw_parts(input_ptr, input_len as usize) };

    if input.len() < 320 + 320 + 8 {
        return 0;
    }

    let p1 = match DNA::from_abi_bytes(&input[0..320]) {
        Some(d) => d,
        None => return 0,
    };
    let p2 = match DNA::from_abi_bytes(&input[320..640]) {
        Some(d) => d,
        None => return 0,
    };
    let seed = u64::from_be_bytes([
        input[640], input[641], input[642], input[643],
        input[644], input[645], input[646], input[647],
    ]);

    let child = crossover(&p1, &p2, seed);
    let child_bytes = child.to_abi_bytes();

    let output = unsafe { core::slice::from_raw_parts_mut(output_ptr, 320) };
    output.copy_from_slice(&child_bytes);

    320
}

/// Entry point: mutate
///
/// Input:  dna (320 bytes) | mutation_rate (2 bytes) | seed (8 bytes)
/// Output: mutated_dna (320 bytes)
#[no_mangle]
pub extern "C" fn pvm_mutate(
    input_ptr: *const u8,
    input_len: u32,
    output_ptr: *mut u8,
    _output_max_len: u32,
) -> u32 {
    let input = unsafe { core::slice::from_raw_parts(input_ptr, input_len as usize) };

    if input.len() < 320 + 2 + 8 {
        return 0;
    }

    let dna = match DNA::from_abi_bytes(&input[0..320]) {
        Some(d) => d,
        None => return 0,
    };
    let mutation_rate = u16::from_be_bytes([input[320], input[321]]);
    let seed = u64::from_be_bytes([
        input[322], input[323], input[324], input[325],
        input[326], input[327], input[328], input[329],
    ]);

    let mutated = mutate(&dna, mutation_rate, seed);
    let mutated_bytes = mutated.to_abi_bytes();

    let output = unsafe { core::slice::from_raw_parts_mut(output_ptr, 320) };
    output.copy_from_slice(&mutated_bytes);

    320
}
