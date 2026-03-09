// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IXCM
/// @notice Interface for the XCM precompile on Polkadot Hub.
/// Allows Solidity contracts to send cross-consensus messages
/// to other parachains for asset transfers and remote execution.
interface IXCM {
    /// @notice Transfer assets to a destination parachain and optionally
    ///         execute a remote call (e.g., deposit into a yield pool).
    /// @param destChainId The parachain ID of the destination.
    /// @param destAccount The account on the destination chain to receive assets.
    /// @param asset The ERC20 token address on the Hub (e.g., USDC).
    /// @param amount The amount of the asset to transfer.
    /// @param transactPayload Encoded call to execute on the destination chain.
    ///        Pass empty bytes for a simple transfer with no remote execution.
    /// @return success Whether the XCM message was successfully queued.
    function transferAssets(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount,
        bytes calldata transactPayload
    ) external returns (bool success);
}
