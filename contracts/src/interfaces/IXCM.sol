// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IXCM
/// @notice High-level interface for XCM-based cross-chain asset transfers.
///
///         This is ALIVE's abstraction over Polkadot's XCM. It provides a
///         simplified `transferAssets()` function that Creature contracts call
///         to deploy capital to destination parachains.
///
///         Implementations:
///           - XCMRouter (production): Builds SCALE-encoded XCM V4 messages
///             and calls the real Polkadot Hub precompile at 0x0...0A0000.
///           - XCMRouter (simulation): Local ERC20 transfers for testing.
///           - MockXCM (legacy test mock): Simple transfer simulation.
///
///         The real Polkadot Hub XCM precompile uses a different, lower-level
///         interface (IPolkadotXcm) with execute/send/weighMessage. This
///         interface is the adapter layer that hides XCM complexity from
///         individual Creature strategy contracts.
///
/// @dev See IPolkadotXcm.sol for the actual precompile interface.
///      See XCMRouter.sol for the production implementation.
interface IXCM {
    /// @notice Transfer assets to a destination parachain and optionally
    ///         execute a remote call (e.g., deposit into a yield pool).
    ///
    ///         Under the hood (production mode), this:
    ///           1. Pulls tokens from the caller via SafeERC20
    ///           2. Builds an XCM V4 TransferReserveAsset program
    ///           3. Calls the Polkadot Hub XCM precompile to execute
    ///
    /// @param destChainId The parachain ID of the destination (from Creature DNA).
    /// @param destAccount The account on the destination chain to receive assets.
    /// @param asset The ERC20 token address on the Hub (e.g., USDC, USDT).
    /// @param amount The amount of the asset to transfer.
    /// @param transactPayload Encoded call to execute on the destination chain.
    ///        Pass empty bytes for a simple transfer with no remote execution.
    /// @return success Whether the XCM transfer was successfully initiated.
    function transferAssets(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount,
        bytes calldata transactPayload
    ) external returns (bool success);
}
