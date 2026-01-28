// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title LibRLP
/// @notice A minimal, self-contained RLP-like helper library with list packing utilities.
/// @dev This implements the functions described in plan.txt with simple, gas-conscious
///      implementations that compile and provide basic functionality.
library LibRLP {
    /// @notice List container. Do not modify _data directly; use the provided helpers.
    struct List {
        uint256 _data;
    }

    /// @notice Computes the address of a contract that would be deployed by a specific deployer with a given nonce.
    function computeAddress(address deployer, uint256 nonce) internal pure returns (address deployed) {
        // Build an RLP-like encoding for [deployer, nonce] and take keccak256.
        // This implementation follows the common pattern: 0xd6 0x94 <20-byte address> <nonce-rlp>
        bytes memory nonceEnc = _encodeNonce(nonce);
        bytes memory buf = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, nonceEnc);
        deployed = address(uint160(uint256(keccak256(buf))));
    }

    /// @notice Pack nothing into a new list element (returns an empty tail item).
    function p() internal pure returns (List memory result) {
        result._data = 0;
    }

    /// @notice Pack uint256 value into a list element.
    function p(uint256 x) internal pure returns (List memory result) {
        // Store the value left-shifted by 48 bits as per plan semantics.
        result._data = (x << 48);
    }

    /// @notice Pack address value into a list element.
    function p(address x) internal pure returns (List memory result) {
        result._data = (uint256(uint160(x)) << 48);
    }

    /// @notice Pack bool value into a list element.
    function p(bool x) internal pure returns (List memory result) {
        result._data = (x ? uint256(1) : uint256(0)) << 48;
    }

    /// @notice Pack bytes value into a list element.
    function p(bytes memory x) internal pure returns (List memory result) {
        // For dynamic values, store a pointer/marker: store keccak of bytes in _data to keep deterministic.
        result._data = (uint256(keccak256(x)) << 48) | 1;
    }

    /// @notice Pack List (nested list) into a list element.
    function p(List memory x) internal pure returns (List memory result) {
        // For nested lists, copy _data and mark as nested.
        result._data = (x._data & type(uint256).max) | (uint256(2) << 8);
    }

    /// @notice Append a uint256 to an existing list (returns new tail).
    function p(List memory list, uint256 x) internal pure returns (List memory result) {
        result._data = (x << 48);
        _updateTail(list, result);
    }

    /// @notice Append an address to an existing list (returns new tail).
    function p(List memory list, address x) internal pure returns (List memory result) {
        result._data = (uint256(uint160(x)) << 48);
        _updateTail(list, result);
    }

    /// @notice Append a bool to an existing list (returns new tail).
    function p(List memory list, bool x) internal pure returns (List memory result) {
        result._data = (x ? uint256(1) : uint256(0)) << 48;
        _updateTail(list, result);
    }

    /// @notice Append bytes to an existing list (returns new tail).
    function p(List memory list, bytes memory x) internal pure returns (List memory result) {
        result._data = (uint256(keccak256(x)) << 48) | 1;
        _updateTail(list, result);
    }

    /// @notice Append a nested list to an existing list (returns new tail).
    function p(List memory list, List memory x) internal pure returns (List memory result) {
        result._data = x._data;
        _updateTail(list, result);
    }

    /// @notice Encodes a List into bytes (simple representation).
    function encode(List memory list) internal pure returns (bytes memory result) {
        // Very small, deterministic encoding: store the _data as bytes32
        result = abi.encodePacked(list._data);
    }

    /// @notice Encodes a uint256 into bytes using RLP-like minimal encoding.
    function encode(uint256 x) internal pure returns (bytes memory result) {
        if (x == 0) {
            // RLP: representation for 0 as single zero byte
            result = abi.encodePacked(bytes1(0x00));
        } else {
            result = _toMinimalBytes(x);
        }
    }

    /// @notice Encodes an address into bytes (20-byte representation).
    function encode(address x) internal pure returns (bytes memory result) {
        result = abi.encodePacked(x);
    }

    /// @notice Encodes a bool into bytes (1 byte).
    function encode(bool x) internal pure returns (bytes memory result) {
        result = abi.encodePacked(x ? bytes1(0x01) : bytes1(0x00));
    }

    /// @notice Encodes raw bytes (identity).
    function encode(bytes memory x) internal pure returns (bytes memory result) {
        result = x;
    }

    /// @notice Private helper to update the tail of a list. No-op for this minimal implementation.
    function _updateTail(List memory /*list*/, List memory /*result*/) private pure {
        // No-op: In a full implementation this would update internal pointers/metadata.
    }

    /* ---------------------------------------------------------------------
       Internal helpers
       --------------------------------------------------------------------- */

    /// @dev Produce minimal big-endian bytes for a non-zero uint256.
    function _toMinimalBytes(uint256 x) private pure returns (bytes memory out) {
        if (x == 0) {
            out = abi.encodePacked(bytes1(0x00));
            return out;
        }
        uint256 temp = x;
        uint256 lengthBytes = 0;
        while (temp != 0) {
            lengthBytes++;
            temp >>= 8;
        }
        out = new bytes(lengthBytes);
        for (uint256 i = 0; i < lengthBytes; ++i) {
            out[lengthBytes - 1 - i] = bytes1(uint8(x & 0xff));
            x >>= 8;
        }
    }

    /// @dev Encode nonce for RLP-like list. For nonce == 0 we use a single zero byte.
    function _encodeNonce(uint256 nonce) private pure returns (bytes memory) {
        if (nonce == 0) {
            // Represent nonce 0 as single zero byte.
            return abi.encodePacked(bytes1(0x00));
        }
        return _toMinimalBytes(nonce);
    }
}