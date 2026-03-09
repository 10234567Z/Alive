// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXCM} from "../../src/interfaces/IXCM.sol";

/// @title MockXCM
/// @notice Mock XCM precompile that always succeeds.
///         In tests we don't actually transfer cross-chain; we just
///         record the calls for assertion.
contract MockXCM is IXCM {
    struct XCMCall {
        uint256 destChainId;
        address destAccount;
        address asset;
        uint256 amount;
        bytes transactPayload;
    }

    XCMCall[] public calls;

    function transferAssets(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount,
        bytes calldata transactPayload
    ) external override returns (bool) {
        calls.push(XCMCall({
            destChainId: destChainId,
            destAccount: destAccount,
            asset: asset,
            amount: amount,
            transactPayload: transactPayload
        }));
        return true;
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }
}
