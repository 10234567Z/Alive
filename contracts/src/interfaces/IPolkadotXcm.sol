// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev The on-chain address of the XCM precompile on Polkadot Hub.
///      Reference: https://docs.polkadot.com/smart-contracts/precompiles/xcm/
address constant XCM_PRECOMPILE_ADDRESS = address(0xA0000);

/// @title IPolkadotXcm
/// @notice Low-level interface for the Polkadot Hub XCM precompile.
///         This is the REAL precompile interface as documented by Polkadot.
///         It forwards calls to `pallet_xcm` dispatchable functions,
///         providing access to XCM execution and message passing.
///
/// @dev All XCM messages MUST be SCALE-encoded (Polkadot's standard
///      serialisation format). Use the ScaleCodec library to encode.
///
///      Reference: https://github.com/paritytech/polkadot-sdk/blob/main/polkadot/xcm/pallet-xcm/src/precompiles/IXcm.sol
interface IPolkadotXcm {
    /// @notice Weight v2 — computational cost of an XCM execution.
    struct Weight {
        /// @dev Computational time on reference hardware.
        uint64 refTime;
        /// @dev Size of the proof needed for execution.
        uint64 proofSize;
    }

    /// @notice Execute an XCM message locally with the caller's origin.
    /// @dev Internally calls `pallet_xcm::execute`.
    ///      This is the primary entry-point for cross-chain transfers initiated
    ///      by a smart contract. The XCM program can include instructions like
    ///      WithdrawAsset, TransferReserveAsset, DepositReserveAsset, etc.
    /// @param message SCALE-encoded Versioned XCM message.
    /// @param weight Maximum allowed Weight for execution.
    ///        Call weighMessage() first to obtain the correct weight.
    function execute(bytes calldata message, Weight calldata weight) external;

    /// @notice Send an XCM message to another parachain or consensus system.
    /// @dev Internally calls `pallet_xcm::send`.
    ///      Used when you need to deliver a message to another chain without
    ///      executing locally (e.g., opening HRMP channels).
    /// @param destination SCALE-encoded destination Location.
    /// @param message SCALE-encoded Versioned XCM message.
    function send(bytes calldata destination, bytes calldata message) external;

    /// @notice Estimate the Weight required to execute a given XCM message.
    /// @dev Pure cost estimation — does not execute the message.
    /// @param message SCALE-encoded Versioned XCM message.
    /// @return weight Estimated refTime and proofSize.
    function weighMessage(bytes calldata message) external view returns (Weight memory weight);
}
