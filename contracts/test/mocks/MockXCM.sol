// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IXCM} from "../../src/interfaces/IXCM.sol";

/// @title MockXCM
/// @notice Realistic XCM precompile simulation for the ALIVE hackathon.
///
///         Unlike a simple mock, this contract ACTUALLY TRANSFERS tokens
///         from the caller when `transferAssets` is called, simulating
///         capital leaving to a destination parachain. It tracks per-creature
///         deployed capital and provides `simulateReturns()` to push back
///         the original capital plus yield, mimicking cross-chain DeFi returns.
///
///         Flow:
///           1. Creature.feed() → approves & calls transferAssets() → tokens
///              move from Creature to MockXCM (simulates cross-chain transfer)
///           2. Epoch-runner calls simulateReturns(yieldBps) → MockXCM sends
///              capital + yield back to each Creature (simulates returns)
///           3. Creature.harvest() → sees real balance change → accurate fitness
contract MockXCM is IXCM {
    using SafeERC20 for IERC20;

    struct XCMCall {
        uint256 destChainId;
        address destAccount;
        address asset;
        uint256 amount;
        bytes transactPayload;
    }

    struct Deployment {
        address creature;
        address asset;
        uint256 amount;
    }

    XCMCall[] public calls;

    /// @notice Outstanding deployments awaiting return.
    Deployment[] internal _deployments;

    /// @notice Total capital currently deployed per creature.
    mapping(address => uint256) public deployedCapital;

    /// @notice Cumulative capital deployed across all epochs (for analytics).
    uint256 public totalDeployed;

    /// @notice Emitted when capital is deployed via XCM.
    event CapitalDeployed(address indexed creature, address asset, uint256 amount);

    /// @notice Emitted when simulated returns are sent back.
    event ReturnsSimulated(
        address indexed creature,
        uint256 principal,
        uint256 yieldAmount,
        uint256 total
    );

    /// @notice Transfer assets to a destination parachain.
    ///         Actually pulls tokens from the calling Creature, simulating
    ///         real cross-chain capital movement.
    function transferAssets(
        uint256 destChainId,
        address destAccount,
        address asset,
        uint256 amount,
        bytes calldata transactPayload
    ) external override returns (bool) {
        // Record the call
        calls.push(XCMCall({
            destChainId: destChainId,
            destAccount: destAccount,
            asset: asset,
            amount: amount,
            transactPayload: transactPayload
        }));

        // ACTUALLY pull tokens from the caller (the Creature contract)
        // The Creature has already called forceApprove(address(xcm), toDeploy)
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Track the deployment
        _deployments.push(Deployment({
            creature: msg.sender,
            asset: asset,
            amount: amount
        }));
        deployedCapital[msg.sender] += amount;
        totalDeployed += amount;

        emit CapitalDeployed(msg.sender, asset, amount);
        return true;
    }

    /// @notice Simulate cross-chain DeFi returns for all outstanding deployments.
    ///         Sends back each creature's deployed capital plus a yield based on
    ///         `yieldBps` (basis points, e.g., 500 = 5%).
    ///
    ///         This should be called by the epoch-runner AFTER feeding and
    ///         BEFORE harvesting. It clears all outstanding deployments.
    ///
    /// @param yieldBps Yield in basis points to add on top of principal.
    ///                 Varies per call to create different performance across epochs.
    function simulateReturns(uint256 yieldBps) external {
        uint256 len = _deployments.length;
        for (uint256 i = 0; i < len; i++) {
            Deployment memory dep = _deployments[i];
            uint256 yieldAmount = (dep.amount * yieldBps) / 10_000;
            uint256 total = dep.amount + yieldAmount;

            // Reset tracking
            deployedCapital[dep.creature] -= dep.amount;

            // Send back principal + yield to the creature
            IERC20(dep.asset).safeTransfer(dep.creature, total);

            emit ReturnsSimulated(dep.creature, dep.amount, yieldAmount, total);
        }

        // Clear all deployments
        delete _deployments;
    }

    /// @notice Simulate returns for a SPECIFIC creature with a specific yield.
    ///         Allows different creatures to earn different amounts (more realistic).
    /// @param creature The creature address.
    /// @param asset The stablecoin address.
    /// @param yieldAmount The signed yield amount (positive = gain, negative = loss).
    function simulateReturnForCreature(
        address creature,
        address asset,
        int256 yieldAmount
    ) external {
        uint256 principal = deployedCapital[creature];
        if (principal == 0) return;

        uint256 total;
        uint256 absYield;
        if (yieldAmount >= 0) {
            absYield = uint256(yieldAmount);
            total = principal + absYield;
        } else {
            absYield = uint256(-yieldAmount);
            total = absYield >= principal ? 0 : principal - absYield;
        }

        deployedCapital[creature] = 0;

        // Remove matching deployments
        uint256 len = _deployments.length;
        uint256 writeIdx = 0;
        for (uint256 i = 0; i < len; i++) {
            if (_deployments[i].creature != creature) {
                if (writeIdx != i) {
                    _deployments[writeIdx] = _deployments[i];
                }
                writeIdx++;
            }
        }
        // Trim array
        while (_deployments.length > writeIdx) {
            _deployments.pop();
        }

        if (total > 0) {
            IERC20(asset).safeTransfer(creature, total);
        }
        emit ReturnsSimulated(creature, principal, absYield, total);
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }

    function deploymentCount() external view returns (uint256) {
        return _deployments.length;
    }
}
