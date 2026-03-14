// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ScaleCodec} from "./ScaleCodec.sol";

/// @title XCMMessageBuilder
/// @notice Builds SCALE-encoded XCM V4 programs for common cross-chain operations.
///
///         An XCM program is a sequence of instructions that the XCM virtual machine
///         executes. This library constructs the byte representation that the
///         IPolkadotXcm precompile expects.
///
///         The primary use-case for ALIVE is transferring stablecoins from
///         Polkadot Hub (Asset Hub) to destination parachains for DeFi yield.
///
///         XCM V4 Instruction Reference:
///         https://github.com/polkadot-fellows/xcm-format
library XCMMessageBuilder {
    // ---------------------------------------------------------------
    // XCM Version & Instruction Constants
    // ---------------------------------------------------------------

    uint8 internal constant XCM_VERSION_V4 = 0x04;

    // Instruction variant indices in XCM V4
    uint8 internal constant INSTR_WITHDRAW_ASSET = 0x00;
    uint8 internal constant INSTR_TRANSFER_RESERVE_ASSET = 0x05;
    uint8 internal constant INSTR_DEPOSIT_ASSET = 0x0D;
    uint8 internal constant INSTR_DEPOSIT_RESERVE_ASSET = 0x0E;
    uint8 internal constant INSTR_BUY_EXECUTION = 0x13;

    // Default pallet-assets instance index on Asset Hub
    uint8 internal constant PALLET_ASSETS_INSTANCE = 50;

    // ---------------------------------------------------------------
    // Transfer Builders
    // ---------------------------------------------------------------

    /// @notice Build an XCM V4 program to transfer a pallet-assets token
    ///         from Asset Hub (the reserve chain) to a destination parachain.
    ///
    ///         The program uses `TransferReserveAsset` which is the correct
    ///         instruction when the origin chain IS the reserve for the asset.
    ///         It atomically:
    ///           1. Withdraws the asset from the caller's account
    ///           2. Deposits it in the destination's sovereign account
    ///           3. Sends an XCM to the destination with the inner program
    ///
    ///         Inner program on destination:
    ///           1. BuyExecution (pay for processing with the received asset)
    ///           2. DepositAsset (deposit remaining into the beneficiary account)
    ///
    /// @param assetId The pallet-assets GeneralIndex (e.g., 1984 for USDT on Asset Hub).
    /// @param amount Amount of the fungible asset to transfer.
    /// @param destParaId Destination parachain ID (e.g., 2000 for Acala).
    /// @param beneficiary The 20-byte EVM address on the destination chain.
    /// @param assetHubParaId Asset Hub's own parachain ID (1000 on Polkadot/Westend).
    /// @return message SCALE-encoded VersionedXcm::V4 message ready for execute().
    function buildTransferToParachain(
        uint128 assetId,
        uint256 amount,
        uint32 destParaId,
        address beneficiary,
        uint32 assetHubParaId
    ) internal pure returns (bytes memory message) {
        // --- Encode the asset being transferred ---
        // Location on Asset Hub: { parents: 0, interior: X2(PalletInstance(50), GeneralIndex(assetId)) }
        bytes memory assetLocation = ScaleCodec.encodeLocationX2(
            0, // parents = 0 (local asset)
            ScaleCodec.encodePalletInstanceJunction(PALLET_ASSETS_INSTANCE),
            ScaleCodec.encodeGeneralIndexJunction(assetId)
        );
        bytes memory asset = ScaleCodec.encodeFungibleAsset(assetLocation, amount);
        bytes memory assets = ScaleCodec.encodeSingleAssetVec(asset);

        // --- Encode destination ---
        // { parents: 1, interior: X1(Parachain(destParaId)) }
        bytes memory dest = ScaleCodec.encodeLocationX1(
            1, // parents = 1 (relay chain context)
            ScaleCodec.encodeParachainJunction(destParaId)
        );

        // --- Inner XCM (executes on destination) ---
        bytes memory innerXcm = _buildInnerBuyAndDeposit(
            assetId, amount, beneficiary, assetHubParaId
        );

        // --- Build the TransferReserveAsset instruction ---
        bytes memory instruction = abi.encodePacked(
            uint8(INSTR_TRANSFER_RESERVE_ASSET),
            assets,
            dest,
            innerXcm
        );

        // --- Wrap in VersionedXcm::V4 ---
        message = abi.encodePacked(
            uint8(XCM_VERSION_V4),    // V4
            ScaleCodec.encodeCompact(1), // Vec<Instruction> length = 1
            instruction
        );
    }

    /// @notice Build an XCM V4 program using WithdrawAsset + DepositReserveAsset.
    ///         This is an alternative two-instruction approach that gives more control.
    ///
    ///         Useful when you need to do additional operations between withdraw
    ///         and deposit (e.g., exchange, set topic, etc.).
    ///
    /// @param assetId The pallet-assets GeneralIndex.
    /// @param amount Amount of the fungible asset.
    /// @param destParaId Destination parachain ID.
    /// @param beneficiary The 20-byte EVM address on destination.
    /// @param assetHubParaId Asset Hub's own parachain ID.
    /// @return message SCALE-encoded VersionedXcm::V4 message.
    function buildWithdrawAndTransfer(
        uint128 assetId,
        uint256 amount,
        uint32 destParaId,
        address beneficiary,
        uint32 assetHubParaId
    ) internal pure returns (bytes memory message) {
        // --- Encode asset location ---
        bytes memory assetLocation = ScaleCodec.encodeLocationX2(
            0,
            ScaleCodec.encodePalletInstanceJunction(PALLET_ASSETS_INSTANCE),
            ScaleCodec.encodeGeneralIndexJunction(assetId)
        );
        bytes memory asset = ScaleCodec.encodeFungibleAsset(assetLocation, amount);
        bytes memory assets = ScaleCodec.encodeSingleAssetVec(asset);

        // --- WithdrawAsset instruction ---
        bytes memory withdrawInstr = abi.encodePacked(
            uint8(INSTR_WITHDRAW_ASSET),
            assets
        );

        // --- Destination ---
        bytes memory dest = ScaleCodec.encodeLocationX1(
            1,
            ScaleCodec.encodeParachainJunction(destParaId)
        );

        // --- Inner XCM ---
        bytes memory innerXcm = _buildInnerBuyAndDeposit(
            assetId, amount, beneficiary, assetHubParaId
        );

        // --- DepositReserveAsset instruction ---
        bytes memory depositReserveInstr = abi.encodePacked(
            uint8(INSTR_DEPOSIT_RESERVE_ASSET),
            ScaleCodec.encodeWildAll(), // assets: Wild(All)
            dest,
            innerXcm
        );

        // --- Wrap in V4 with 2 instructions ---
        message = abi.encodePacked(
            uint8(XCM_VERSION_V4),
            ScaleCodec.encodeCompact(2),  // 2 instructions
            withdrawInstr,
            depositReserveInstr
        );
    }

    // ---------------------------------------------------------------
    // Internal Helpers
    // ---------------------------------------------------------------

    /// @dev Build the inner XCM that executes on the destination parachain.
    ///      Contains BuyExecution + DepositAsset.
    function _buildInnerBuyAndDeposit(
        uint128 assetId,
        uint256 amount,
        address beneficiary,
        uint32 assetHubParaId
    ) private pure returns (bytes memory) {
        // --- BuyExecution fees asset ---
        // On the destination, the asset is referenced from the reserve chain's perspective:
        // { parents: 1, interior: X3(Parachain(AssetHubParaId), PalletInstance(50), GeneralIndex(assetId)) }
        bytes memory feeAssetLocation = ScaleCodec.encodeLocationX3(
            1, // parents = 1 (up to relay)
            ScaleCodec.encodeParachainJunction(assetHubParaId),
            ScaleCodec.encodePalletInstanceJunction(PALLET_ASSETS_INSTANCE),
            ScaleCodec.encodeGeneralIndexJunction(assetId)
        );
        bytes memory feeAsset = ScaleCodec.encodeFungibleAsset(feeAssetLocation, amount);

        bytes memory buyExecInstr = abi.encodePacked(
            uint8(INSTR_BUY_EXECUTION),
            feeAsset,
            ScaleCodec.encodeUnlimited() // WeightLimit::Unlimited
        );

        // --- DepositAsset ---
        // Beneficiary: { parents: 0, interior: X1(AccountKey20 { network: None, key: beneficiary }) }
        bytes memory beneficiaryLocation = ScaleCodec.encodeLocationX1(
            0,
            ScaleCodec.encodeAccountKey20Junction(beneficiary)
        );

        bytes memory depositInstr = abi.encodePacked(
            uint8(INSTR_DEPOSIT_ASSET),
            ScaleCodec.encodeWildAll(),   // assets: Wild(All)
            beneficiaryLocation
        );

        // --- Encode as Vec<Instruction> with 2 instructions ---
        return abi.encodePacked(
            ScaleCodec.encodeCompact(2),
            buyExecInstr,
            depositInstr
        );
    }
}
