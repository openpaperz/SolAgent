// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Efficient hashing and memory utilities.
library EfficientHashLib {
    /**
     * @notice Computes the Keccak-256 hash of a single bytes32 value.
     *
     * @param v0 The bytes32 value to be hashed.
     * @return result The resulting bytes32 hash of the input value.
     *
     * Steps:
     * 1. Store the input value `v0` in memory at position 0x00.
     * 2. Compute the Keccak-256 hash of the 32 bytes stored at memory position 0x00.
     * 3. Return the computed hash as the result.
     *
     * @dev This function uses inline assembly for efficient memory handling and hash computation.
     */
    function hash(bytes32 v0) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a single uint256 value.
     */
    function hash(uint256 v0) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of two bytes32 values.
     */
    function hash(bytes32 v0, bytes32 v1) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of two uint256 values.
     */
    function hash(uint256 v0, uint256 v1) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of three bytes32 values.
     */
    function hash(bytes32 v0, bytes32 v1, bytes32 v2) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            result := keccak256(0x00, 0x60)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of three uint256 values.
     */
    function hash(uint256 v0, uint256 v1, uint256 v2) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            result := keccak256(0x00, 0x60)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of four bytes32 values.
     */
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            result := keccak256(0x00, 0x80)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of four uint256 values.
     */
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            result := keccak256(0x00, 0x80)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of five bytes32 values.
     */
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            result := keccak256(0x00, 0xa0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of five uint256 values.
     */
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            result := keccak256(0x00, 0xa0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of six bytes32 values.
     */
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            result := keccak256(0x00, 0xc0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of six uint256 values.
     */
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            result := keccak256(0x00, 0xc0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of seven bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            result := keccak256(0x00, 0xe0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of seven uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            result := keccak256(0x00, 0xe0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of eight bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            result := keccak256(0x00, 0x100)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of eight uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            result := keccak256(0x00, 0x100)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of nine bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            result := keccak256(0x00, 0x120)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of nine uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            result := keccak256(0x00, 0x120)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of ten bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            result := keccak256(0x00, 0x140)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of ten uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            result := keccak256(0x00, 0x140)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of eleven bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            result := keccak256(0x00, 0x160)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of eleven uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            result := keccak256(0x00, 0x160)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of twelve bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10,
        bytes32 v11
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            mstore(0x160, v11)
            result := keccak256(0x00, 0x180)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of twelve uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10,
        uint256 v11
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            mstore(0x160, v11)
            result := keccak256(0x00, 0x180)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of thirteen bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10,
        bytes32 v11,
        bytes32 v12
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            mstore(0x160, v11)
            mstore(0x180, v12)
            result := keccak256(0x00, 0x1a0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of thirteen uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10,
        uint256 v11,
        uint256 v12
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            mstore(0x160, v11)
            mstore(0x180, v12)
            result := keccak256(0x00, 0x1a0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of fourteen bytes32 values.
     */
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10,
        bytes32 v11,
        bytes32 v12,
        bytes32 v13
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            mstore(0x160, v11)
            mstore(0x180, v12)
            mstore(0x1a0, v13)
            result := keccak256(0x00, 0x1c0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of fourteen uint256 values.
     */
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10,
        uint256 v11,
        uint256 v12,
        uint256 v13
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            mstore(0xa0, v5)
            mstore(0xc0, v6)
            mstore(0xe0, v7)
            mstore(0x100, v8)
            mstore(0x120, v9)
            mstore(0x140, v10)
            mstore(0x160, v11)
            mstore(0x180, v12)
            mstore(0x1a0, v13)
            result := keccak256(0x00, 0x1c0)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a dynamic array of bytes32.
     */
    function hash(bytes32[] memory buffer) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let data := add(buffer, 0x20)
            let len := mload(buffer)
            result := keccak256(data, shl(5, len))
        }
    }

    /**
     * @notice Sets a bytes32 value at a specific index in a bytes32 array.
     */
    function set(bytes32[] memory buffer, uint256 i, bytes32 value)
        internal
        pure
        returns (bytes32[] memory)
    {
        assembly ("memory-safe") {
            mstore(add(add(buffer, 0x20), shl(5, i)), value)
        }
        return buffer;
    }

    /**
     * @notice Sets a uint256 value at a specific index in a bytes32 array.
     */
    function set(bytes32[] memory buffer, uint256 i, uint256 value)
        internal
        pure
        returns (bytes32[] memory)
    {
        assembly ("memory-safe") {
            mstore(add(add(buffer, 0x20), shl(5, i)), value)
        }
        return buffer;
    }

    /**
     * @notice Allocates a dynamic array of `bytes32` in memory with a specified length.
     */
    function malloc(uint256 n) internal pure returns (bytes32[] memory buffer) {
        assembly ("memory-safe") {
            buffer := mload(0x40)
            mstore(buffer, n)
            mstore(0x40, add(buffer, shl(5, add(1, n))))
        }
    }

    /**
     * @notice Frees memory allocated for a dynamic array of `bytes32` elements.
     */
    function free(bytes32[] memory buffer) internal pure {
        assembly ("memory-safe") {
            let len := mload(buffer)
            if iszero(len) { leave }
            let size := shl(5, add(1, len))
            let end := add(buffer, size)
            if eq(end, mload(0x40)) {
                mstore(0x40, buffer)
            }
        }
    }

    /**
     * @notice Compares a `bytes32` value with a `bytes` array to check for equality.
     */
    function eq(bytes32 a, bytes memory b) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := and(eq(mload(b), 0x20), eq(a, mload(add(b, 0x20))))
        }
    }

    /**
     * @notice Compares a `bytes` array with a `bytes32` value to check for equality.
     */
    function eq(bytes memory a, bytes32 b) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := and(eq(mload(a), 0x20), eq(mload(add(a, 0x20)), b))
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a slice of bytes memory.
     */
    function hash(bytes memory b, uint256 start, uint256 end)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let len := mload(b)
            if gt(end, len) { end := len }
            if gt(start, end) { start := end }
            let n := sub(end, start)
            result := keccak256(add(add(b, 0x20), start), n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a bytes memory slice from `start` to end.
     */
    function hash(bytes memory b, uint256 start) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := mload(b)
            if gt(start, len) { start := len }
            let n := sub(len, start)
            result := keccak256(add(add(b, 0x20), start), n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of an entire bytes memory array.
     */
    function hash(bytes memory b) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := mload(b)
            result := keccak256(add(b, 0x20), len)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     */
    function hashCalldata(bytes calldata b, uint256 start, uint256 end)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let len := b.length
            if gt(end, len) { end := len }
            if gt(start, end) { start := end }
            let n := sub(end, start)
            let ptr := mload(0x40)
            calldatacopy(ptr, add(b.offset, start), n)
            result := keccak256(ptr, n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of calldata from `start` to end.
     */
    function hashCalldata(bytes calldata b, uint256 start)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let len := b.length
            if gt(start, len) { start := len }
            let n := sub(len, start)
            let ptr := mload(0x40)
            calldatacopy(ptr, add(b.offset, start), n)
            result := keccak256(ptr, n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of entire calldata bytes.
     */
    function hashCalldata(bytes calldata b) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := b.length
            let ptr := mload(0x40)
            calldatacopy(ptr, b.offset, len)
            result := keccak256(ptr, len)
        }
    }

    /**
     * @notice Computes the SHA-2 (SHA-256) hash of a given bytes32 input using inline assembly.
     */
    function sha2(bytes32 b) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, b)
            if iszero(staticcall(gas(), 0x02, 0x00, 0x20, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a slice of bytes memory.
     */
    function sha2(bytes memory b, uint256 start, uint256 end)
        internal
        view
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let len := mload(b)
            if gt(end, len) { end := len }
            if gt(start, end) { start := end }
            let n := sub(end, start)
            let ptr := add(add(b, 0x20), start)
            if iszero(staticcall(gas(), 0x02, ptr, n, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a bytes memory slice from `start` to end.
     */
    function sha2(bytes memory b, uint256 start) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := mload(b)
            if gt(start, len) { start := len }
            let n := sub(len, start)
            let ptr := add(add(b, 0x20), start)
            if iszero(staticcall(gas(), 0x02, ptr, n, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of an entire bytes memory array.
     */
    function sha2(bytes memory b) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := mload(b)
            let ptr := add(b, 0x20)
            if iszero(staticcall(gas(), 0x02, ptr, len, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     */
    function sha2Calldata(bytes calldata b, uint256 start, uint256 end)
        internal
        view
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let len := b.length
            if gt(end, len) { end := len }
            if gt(start, end) { start := end }
            let n := sub(end, start)
            let ptr := mload(0x40)
            calldatacopy(ptr, add(b.offset, start), n)
            if iszero(staticcall(gas(), 0x02, ptr, n, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of calldata from `start` to end.
     */
    function sha2Calldata(bytes calldata b, uint256 start)
        internal
        view
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let len := b.length
            if gt(start, len) { start := len }
            let n := sub(len, start)
            let ptr := mload(0x40)
            calldatacopy(ptr, add(b.offset, start), n)
            if iszero(staticcall(gas(), 0x02, ptr, n, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of entire calldata bytes.
     */
    function sha2Calldata(bytes calldata b) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := b.length
            let ptr := mload(0x40)
            calldatacopy(ptr, b.offset, len)
            if iszero(staticcall(gas(), 0x02, ptr, len, 0x20, 0x20)) {
                revert(0x00, 0x00)
            }
            if iszero(returndatasize()) {
                revert(0x00, 0x00)
            }
            result := mload(0x20)
        }
    }
}