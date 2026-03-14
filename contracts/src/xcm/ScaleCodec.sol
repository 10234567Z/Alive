// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ScaleCodec
/// @notice SCALE (Simple Concatenated Aggregate Little-Endian) encoding library
///         for constructing XCM messages in Solidity.
///
///         SCALE is Polkadot's standard serialisation format. This library
///         provides the encoding primitives needed to build XCM V4 programs
///         that the IPolkadotXcm precompile can execute.
///
///         Reference: https://docs.polkadot.com/reference/parachains/data-encoding/
library ScaleCodec {
    // ---------------------------------------------------------------
    // Compact Encoding
    // ---------------------------------------------------------------

    /// @notice Encode a uint256 value using SCALE compact encoding.
    /// @dev Compact encoding rules:
    ///      - [0, 63]:           1 byte  → (value << 2) | 0b00
    ///      - [64, 16_383]:      2 bytes → (value << 2) | 0b01  (LE)
    ///      - [16_384, 2^30-1]:  4 bytes → (value << 2) | 0b10  (LE)
    ///      - [2^30, ...]:       BigInt  → ((byteLen-4) << 2) | 0b11, then value LE
    function encodeCompact(uint256 value) internal pure returns (bytes memory) {
        if (value < 64) {
            // Single-byte mode
            return abi.encodePacked(uint8(value << 2));
        } else if (value < 16384) {
            // Two-byte mode (LE)
            uint16 encoded = uint16(value << 2) | 0x01;
            return abi.encodePacked(uint8(encoded & 0xFF), uint8(encoded >> 8));
        } else if (value < 1073741824) {
            // Four-byte mode (LE)
            uint32 encoded = uint32(value << 2) | 0x02;
            return abi.encodePacked(
                uint8(encoded & 0xFF),
                uint8((encoded >> 8) & 0xFF),
                uint8((encoded >> 16) & 0xFF),
                uint8(encoded >> 24)
            );
        } else {
            // Big-integer mode
            uint256 temp = value;
            uint8 byteLen = 0;
            while (temp > 0) {
                byteLen++;
                temp >>= 8;
            }
            if (byteLen < 4) byteLen = 4;

            bytes memory result = new bytes(1 + byteLen);
            result[0] = bytes1(uint8(((byteLen - 4) << 2) | 0x03));
            uint256 v = value;
            for (uint8 i = 0; i < byteLen; i++) {
                result[1 + i] = bytes1(uint8(v & 0xFF));
                v >>= 8;
            }
            return result;
        }
    }

    // ---------------------------------------------------------------
    // Fixed-Width Integers (Little-Endian)
    // ---------------------------------------------------------------

    /// @notice Encode a uint32 in little-endian format.
    function encodeU32LE(uint32 value) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(value & 0xFF),
            uint8((value >> 8) & 0xFF),
            uint8((value >> 16) & 0xFF),
            uint8(value >> 24)
        );
    }

    /// @notice Encode a uint64 in little-endian format.
    function encodeU64LE(uint64 value) internal pure returns (bytes memory) {
        bytes memory result = new bytes(8);
        for (uint8 i = 0; i < 8; i++) {
            result[i] = bytes1(uint8(value & 0xFF));
            value >>= 8;
        }
        return result;
    }

    // ---------------------------------------------------------------
    // XCM Location Encoding
    // ---------------------------------------------------------------

    /// @notice Encode an XCM V4 Location with no junctions (Here).
    /// @param parents Number of parent hops (0 = current chain, 1 = relay).
    function encodeLocationHere(uint8 parents) internal pure returns (bytes memory) {
        return abi.encodePacked(parents, uint8(0x00)); // Interior::Here
    }

    /// @notice Encode a Location with 1 junction (X1).
    function encodeLocationX1(
        uint8 parents,
        bytes memory junction
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(parents, uint8(0x01), junction);
    }

    /// @notice Encode a Location with 2 junctions (X2).
    function encodeLocationX2(
        uint8 parents,
        bytes memory junction1,
        bytes memory junction2
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(parents, uint8(0x02), junction1, junction2);
    }

    /// @notice Encode a Location with 3 junctions (X3).
    function encodeLocationX3(
        uint8 parents,
        bytes memory junction1,
        bytes memory junction2,
        bytes memory junction3
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(parents, uint8(0x03), junction1, junction2, junction3);
    }

    // ---------------------------------------------------------------
    // XCM Junction Encoding
    // ---------------------------------------------------------------

    /// @notice Encode a Parachain junction (variant 0).
    function encodeParachainJunction(uint32 paraId) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0x00), encodeU32LE(paraId));
    }

    /// @notice Encode a PalletInstance junction (variant 4).
    function encodePalletInstanceJunction(uint8 palletIndex) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0x04), palletIndex);
    }

    /// @notice Encode a GeneralIndex junction (variant 5).
    function encodeGeneralIndexJunction(uint128 index) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0x05), encodeCompact(uint256(index)));
    }

    /// @notice Encode an AccountKey20 junction (variant 3) for EVM addresses.
    /// @param account The 20-byte EVM address.
    function encodeAccountKey20Junction(address account) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(0x03),    // AccountKey20 variant
            bytes20(account), // key (20 bytes)
            uint8(0x00)     // network = None
        );
    }

    /// @notice Encode an AccountId32 junction (variant 1) for Substrate addresses.
    /// @param accountId The 32-byte account ID.
    function encodeAccountId32Junction(bytes32 accountId) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(0x01),    // AccountId32 variant
            accountId,      // id (32 bytes)
            uint8(0x00)     // network = None
        );
    }

    // ---------------------------------------------------------------
    // XCM Asset Encoding
    // ---------------------------------------------------------------

    /// @notice Encode a fungible Asset (AssetId + Fungibility::Fungible).
    /// @param assetLocation SCALE-encoded Location identifying the asset.
    /// @param amount The fungible amount (compact-encoded).
    function encodeFungibleAsset(
        bytes memory assetLocation,
        uint256 amount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            assetLocation,  // AssetId = Location
            uint8(0x00),    // Fungibility::Fungible variant
            encodeCompact(amount)
        );
    }

    /// @notice Encode Assets (Vec<Asset>) with a single asset.
    function encodeSingleAssetVec(bytes memory asset) internal pure returns (bytes memory) {
        return abi.encodePacked(
            encodeCompact(1), // Vec length = 1
            asset
        );
    }

    // ---------------------------------------------------------------
    // XCM AssetFilter Encoding
    // ---------------------------------------------------------------

    /// @notice Encode AssetFilter::Wild(WildAsset::All).
    function encodeWildAll() internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(0x01),  // AssetFilter::Wild
            uint8(0x00)   // WildAsset::All
        );
    }

    // ---------------------------------------------------------------
    // XCM Weight Limit Encoding
    // ---------------------------------------------------------------

    /// @notice Encode WeightLimit::Unlimited.
    function encodeUnlimited() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0x00));
    }
}
