// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for efficient Keccak-256 and SHA-256 hashing operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/EfficientHashLib.sol)
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
        assembly {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

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
    function hash(uint256 v0) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

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
    function hash(uint256 v0, uint256 v1) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            result := keccak256(0x00, 0x60)
        }
    }

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
    function hash(uint256 v0, uint256 v1, uint256 v2) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            result := keccak256(0x00, 0x60)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            result := keccak256(0x00, 0x80)
        }
    }

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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            result := keccak256(0x00, 0x80)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            result := keccak256(0x00, 0xa0)
        }
    }

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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            result := keccak256(0x00, 0xa0)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11, bytes32 v12) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11, uint256 v12) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11, bytes32 v12, bytes32 v13) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11, uint256 v12, uint256 v13) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32[] memory buffer) internal pure returns (bytes32 result) {
        assembly {
            result := keccak256(add(buffer, 0x20), shl(5, mload(buffer)))
        }
    }

    /**
     * @notice Sets a value at a specific index in a bytes32 array.
     *
     * @param buffer The bytes32 array to modify.
     * @param i The index at which to set the value.
     * @param value The value to set at the specified index.
     * @return buffer The modified bytes32 array with the new value set at the specified index.
     *
     * Steps:
     * 1. Use inline assembly to safely modify the array in memory.
     * 2. Calculate the memory offset for the specified index.
     * 3. Store the provided value at the calculated memory offset.
     * 4. Return the modified array.
     */
    function set(bytes32[] memory buffer, uint256 i, bytes32 value) internal pure returns (bytes32[] memory) {
        assembly {
            mstore(add(add(buffer, 0x20), shl(5, i)), value)
        }
        return buffer;
    }

    /**
     * @notice Sets a value at a specific index in a bytes32 array.
     *
     * @param buffer The bytes32 array to modify.
     * @param i The index at which to set the value.
     * @param value The value to set at the specified index.
     * @return buffer The modified bytes32 array with the new value set at the specified index.
     *
     * Steps:
     * 1. Use inline assembly to safely modify the array in memory.
     * 2. Calculate the memory offset for the specified index.
     * 3. Store the provided value at the calculated memory offset.
     * 4. Return the modified array.
     */
    function set(bytes32[] memory buffer, uint256 i, uint256 value) internal pure returns (bytes32[] memory) {
        assembly {
            mstore(add(add(buffer, 0x20), shl(5, i)), value)
        }
        return buffer;
    }

    /**
     * @notice Allocates a dynamic array of `bytes32` in memory with a specified length.
     *
     * @param n The length of the array to allocate.
     * @return buffer A dynamically allocated array of `bytes32` with the specified length.
     *
     * Steps:
     * 1. Load the current free memory pointer (0x40) into `buffer`.
     * 2. Store the length `n` at the start of the allocated memory (first word of the array).
     * 3. Update the free memory pointer to point to the next available memory slot after the allocated array.
     *    - The calculation `shl(5, add(1, n))` computes the size of the array in bytes (32 bytes per element).
     *    - The new free memory pointer is set to `buffer + size of the array`.
     *
     * @dev This function uses inline assembly to directly manipulate memory, ensuring efficient allocation.
     */
    function malloc(uint256 n) internal pure returns (bytes32[] memory buffer) {
        assembly {
            buffer := mload(0x40)
            mstore(buffer, n)
            mstore(0x40, add(buffer, shl(5, add(1, n))))
        }
    }

    /**
     * @notice Frees memory allocated for a dynamic array of `bytes32` elements.
     *
     * @param buffer The dynamic array of `bytes32` elements to be freed.
     *
     * Steps:
     * 1. Retrieve the length of the `buffer` array.
     * 2. Use inline assembly to manipulate memory:
     *    - Check if the array length is zero or if the array is located at the free memory pointer.
     *    - Adjust the memory pointer to free the allocated space for the array.
     *
     * @dev This function uses low-level assembly to optimize memory management and ensure memory safety.
     */
    function free(bytes32[] memory buffer) internal pure {
        assembly {
            let n := mload(buffer)
            if iszero(or(iszero(n), xor(mload(0x40), add(buffer, shl(5, add(1, n)))))) {
                mstore(0x40, buffer)
            }
        }
    }

    /**
     * @notice Compares a `bytes32` value with a `bytes` array to check for equality.
     *
     * @param a The `bytes32` value to compare.
     * @param b The `bytes` array to compare against.
     * @return result A boolean indicating whether the `bytes32` value matches the first 32 bytes of the `bytes` array.
     *
     * Steps:
     * 1. Use inline assembly for efficient memory comparison.
     * 2. Check if the length of the `bytes` array is 32 bytes (`0x20` in hexadecimal).
     * 3. Compare the `bytes32` value `a` with the first 32 bytes of the `bytes` array `b`.
     * 4. Return `true` if both conditions are met, otherwise `false`.
     */
    function eq(bytes32 a, bytes memory b) internal pure returns (bool result) {
        assembly {
            result := and(eq(mload(b), 0x20), eq(a, mload(add(b, 0x20))))
        }
    }

    /**
     * @notice Compares a `bytes32` value with a `bytes` array to check for equality.
     *
     * @param a The `bytes32` value to compare.
     * @param b The `bytes` array to compare against.
     * @return result A boolean indicating whether the `bytes32` value matches the first 32 bytes of the `bytes` array.
     *
     * Steps:
     * 1. Use inline assembly for efficient memory comparison.
     * 2. Check if the length of the `bytes` array is 32 bytes (`0x20` in hexadecimal).
     * 3. Compare the `bytes32` value `a` with the first 32 bytes of the `bytes` array `b`.
     * 4. Return `true` if both conditions are met, otherwise `false`.
     */
    function eq(bytes memory a, bytes32 b) internal pure returns (bool result) {
        assembly {
            result := and(eq(mload(a), 0x20), eq(mload(add(a, 0x20)), b))
        }
    }

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
    function hash(bytes memory b, uint256 start, uint256 end) internal pure returns (bytes32 result) {
        assembly {
            let n := mload(b)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            result := keccak256(add(add(b, 0x20), start), sub(end, start))
        }
    }

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
    function hash(bytes memory b, uint256 start) internal pure returns (bytes32 result) {
        assembly {
            let n := mload(b)
            start := xor(start, mul(xor(start, n), lt(n, start)))
            result := keccak256(add(add(b, 0x20), start), sub(n, start))
        }
    }

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
    function hash(bytes memory b) internal pure returns (bytes32 result) {
        assembly {
            result := keccak256(add(b, 0x20), mload(b))
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The Keccak-256 hash of the specified segment of calldata.
     *
     * Steps:
     * 1. Adjust the `end` index to ensure it does not exceed the length of the calldata.
     * 2. Adjust the `start` index to ensure it does not exceed the length of the calldata.
     * 3. Calculate the length of the segment to be hashed (`n`).
     * 4. Copy the specified segment of calldata into memory.
     * 5. Compute the Keccak-256 hash of the copied segment and return the result.
     *
     * @dev This function uses inline assembly for efficient memory manipulation and hashing.
     */
    function hashCalldata(bytes calldata b, uint256 start, uint256 end) internal pure returns (bytes32 result) {
        assembly {
            let n := b.length
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            n := sub(end, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            result := keccak256(m, n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The Keccak-256 hash of the specified segment of calldata.
     *
     * Steps:
     * 1. Adjust the `end` index to ensure it does not exceed the length of the calldata.
     * 2. Adjust the `start` index to ensure it does not exceed the length of the calldata.
     * 3. Calculate the length of the segment to be hashed (`n`).
     * 4. Copy the specified segment of calldata into memory.
     * 5. Compute the Keccak-256 hash of the copied segment and return the result.
     *
     * @dev This function uses inline assembly for efficient memory manipulation and hashing.
     */
    function hashCalldata(bytes calldata b, uint256 start) internal pure returns (bytes32 result) {
        assembly {
            let n := b.length
            start := xor(start, mul(xor(start, n), lt(n, start)))
            n := sub(n, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            result := keccak256(m, n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The Keccak-256 hash of the specified segment of calldata.
     *
     * Steps:
     * 1. Adjust the `end` index to ensure it does not exceed the length of the calldata.
     * 2. Adjust the `start` index to ensure it does not exceed the length of the calldata.
     * 3. Calculate the length of the segment to be hashed (`n`).
     * 4. Copy the specified segment of calldata into memory.
     * 5. Compute the Keccak-256 hash of the copied segment and return the result.
     *
     * @dev This function uses inline assembly for efficient memory manipulation and hashing.
     */
    function hashCalldata(bytes calldata b) internal pure returns (bytes32 result) {
        assembly {
            let m := mload(0x40)
            calldatacopy(m, b.offset, b.length)
            result := keccak256(m, b.length)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes32 b) internal view returns (bytes32 result) {
        assembly {
            mstore(0x00, b)
            if iszero(staticcall(gas(), 2, 0x00, 0x20, 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes memory b, uint256 start, uint256 end) internal view returns (bytes32 result) {
        assembly {
            let n := mload(b)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            if iszero(staticcall(gas(), 2, add(add(b, 0x20), start), sub(end, start), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes memory b, uint256 start) internal view returns (bytes32 result) {
        assembly {
            let n := mload(b)
            start := xor(start, mul(xor(start, n), lt(n, start)))
            if iszero(staticcall(gas(), 2, add(add(b, 0x20), start), sub(n, start), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes memory b) internal view returns (bytes32 result) {
        assembly {
            if iszero(staticcall(gas(), 2, add(b, 0x20), mload(b), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The SHA-256 hash of the specified segment.
     *
     * Steps:
     * 1. Adjust the `end` and `start` indices to ensure they are within the bounds of the calldata length.
     * 2. Calculate the length of the segment (`n`) to be hashed.
     * 3. Copy the specified segment of calldata into memory.
     * 4. Compute the SHA-256 hash of the segment using the `staticcall` opcode.
     * 5. Return the computed hash.
     * 6. If the `returndatasize` is zero, revert the transaction (invalid operation).
     *
     * @dev This function uses inline assembly for low-level memory manipulation and gas optimization.
     */
    function sha2Calldata(bytes calldata b, uint256 start, uint256 end) internal view returns (bytes32 result) {
        assembly {
            let n := b.length
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            n := sub(end, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            if iszero(staticcall(gas(), 2, m, n, 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The SHA-256 hash of the specified segment.
     *
     * Steps:
     * 1. Adjust the `end` and `start` indices to ensure they are within the bounds of the calldata length.
     * 2. Calculate the length of the segment (`n`) to be hashed.
     * 3. Copy the specified segment of calldata into memory.
     * 4. Compute the SHA-256 hash of the segment using the `staticcall` opcode.
     * 5. Return the computed hash.
     * 6. If the `returndatasize` is zero, revert the transaction (invalid operation).
     *
     * @dev This function uses inline assembly for low-level memory manipulation and gas optimization.
     */
    function sha2Calldata(bytes calldata b, uint256 start) internal view returns (bytes32 result) {
        assembly {
            let n := b.length
            start := xor(start, mul(xor(start, n), lt(n, start)))
            n := sub(n, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            if iszero(staticcall(gas(), 2, m, n, 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The SHA-256 hash of the specified segment.
     *
     * Steps:
     * 1. Adjust the `end` and `start` indices to ensure they are within the bounds of the calldata length.
     * 2. Calculate the length of the segment (`n`) to be hashed.
     * 3. Copy the specified segment of calldata into memory.
     * 4. Compute the SHA-256 hash of the segment using the `staticcall` opcode.
     * 5. Return the computed hash.
     * 6. If the `returndatasize` is zero, revert the transaction (invalid operation).
     *
     * @dev This function uses inline assembly for low-level memoryEfficientHashLib.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for efficient Keccak-256 and SHA-256 hashing operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/EfficientHashLib.sol)
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
        assembly {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

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
    function hash(uint256 v0) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

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
    function hash(uint256 v0, uint256 v1) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            result := keccak256(0x00, 0x60)
        }
    }

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
    function hash(uint256 v0, uint256 v1, uint256 v2) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            result := keccak256(0x00, 0x60)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            result := keccak256(0x00, 0x80)
        }
    }

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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            result := keccak256(0x00, 0x80)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            result := keccak256(0x00, 0xa0)
        }
    }

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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            mstore(0x40, v2)
            mstore(0x60, v3)
            mstore(0x80, v4)
            result := keccak256(0x00, 0xa0)
        }
    }

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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11, bytes32 v12) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11, uint256 v12) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11, bytes32 v12, bytes32 v13) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11, uint256 v12, uint256 v13) internal pure returns (bytes32 result) {
        assembly {
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
    function hash(bytes32[] memory buffer) internal pure returns (bytes32 result) {
        assembly {
            result := keccak256(add(buffer, 0x20), shl(5, mload(buffer)))
        }
    }

    /**
     * @notice Sets a value at a specific index in a bytes32 array.
     *
     * @param buffer The bytes32 array to modify.
     * @param i The index at which to set the value.
     * @param value The value to set at the specified index.
     * @return buffer The modified bytes32 array with the new value set at the specified index.
     *
     * Steps:
     * 1. Use inline assembly to safely modify the array in memory.
     * 2. Calculate the memory offset for the specified index.
     * 3. Store the provided value at the calculated memory offset.
     * 4. Return the modified array.
     */
    function set(bytes32[] memory buffer, uint256 i, bytes32 value) internal pure returns (bytes32[] memory) {
        assembly {
            mstore(add(add(buffer, 0x20), shl(5, i)), value)
        }
        return buffer;
    }

    /**
     * @notice Sets a value at a specific index in a bytes32 array.
     *
     * @param buffer The bytes32 array to modify.
     * @param i The index at which to set the value.
     * @param value The value to set at the specified index.
     * @return buffer The modified bytes32 array with the new value set at the specified index.
     *
     * Steps:
     * 1. Use inline assembly to safely modify the array in memory.
     * 2. Calculate the memory offset for the specified index.
     * 3. Store the provided value at the calculated memory offset.
     * 4. Return the modified array.
     */
    function set(bytes32[] memory buffer, uint256 i, uint256 value) internal pure returns (bytes32[] memory) {
        assembly {
            mstore(add(add(buffer, 0x20), shl(5, i)), value)
        }
        return buffer;
    }

    /**
     * @notice Allocates a dynamic array of `bytes32` in memory with a specified length.
     *
     * @param n The length of the array to allocate.
     * @return buffer A dynamically allocated array of `bytes32` with the specified length.
     *
     * Steps:
     * 1. Load the current free memory pointer (0x40) into `buffer`.
     * 2. Store the length `n` at the start of the allocated memory (first word of the array).
     * 3. Update the free memory pointer to point to the next available memory slot after the allocated array.
     *    - The calculation `shl(5, add(1, n))` computes the size of the array in bytes (32 bytes per element).
     *    - The new free memory pointer is set to `buffer + size of the array`.
     *
     * @dev This function uses inline assembly to directly manipulate memory, ensuring efficient allocation.
     */
    function malloc(uint256 n) internal pure returns (bytes32[] memory buffer) {
        assembly {
            buffer := mload(0x40)
            mstore(buffer, n)
            mstore(0x40, add(buffer, shl(5, add(1, n))))
        }
    }

    /**
     * @notice Frees memory allocated for a dynamic array of `bytes32` elements.
     *
     * @param buffer The dynamic array of `bytes32` elements to be freed.
     *
     * Steps:
     * 1. Retrieve the length of the `buffer` array.
     * 2. Use inline assembly to manipulate memory:
     *    - Check if the array length is zero or if the array is located at the free memory pointer.
     *    - Adjust the memory pointer to free the allocated space for the array.
     *
     * @dev This function uses low-level assembly to optimize memory management and ensure memory safety.
     */
    function free(bytes32[] memory buffer) internal pure {
        assembly {
            let n := mload(buffer)
            if iszero(or(iszero(n), xor(mload(0x40), add(buffer, shl(5, add(1, n)))))) {
                mstore(0x40, buffer)
            }
        }
    }

    /**
     * @notice Compares a `bytes32` value with a `bytes` array to check for equality.
     *
     * @param a The `bytes32` value to compare.
     * @param b The `bytes` array to compare against.
     * @return result A boolean indicating whether the `bytes32` value matches the first 32 bytes of the `bytes` array.
     *
     * Steps:
     * 1. Use inline assembly for efficient memory comparison.
     * 2. Check if the length of the `bytes` array is 32 bytes (`0x20` in hexadecimal).
     * 3. Compare the `bytes32` value `a` with the first 32 bytes of the `bytes` array `b`.
     * 4. Return `true` if both conditions are met, otherwise `false`.
     */
    function eq(bytes32 a, bytes memory b) internal pure returns (bool result) {
        assembly {
            result := and(eq(mload(b), 0x20), eq(a, mload(add(b, 0x20))))
        }
    }

    /**
     * @notice Compares a `bytes32` value with a `bytes` array to check for equality.
     *
     * @param a The `bytes32` value to compare.
     * @param b The `bytes` array to compare against.
     * @return result A boolean indicating whether the `bytes32` value matches the first 32 bytes of the `bytes` array.
     *
     * Steps:
     * 1. Use inline assembly for efficient memory comparison.
     * 2. Check if the length of the `bytes` array is 32 bytes (`0x20` in hexadecimal).
     * 3. Compare the `bytes32` value `a` with the first 32 bytes of the `bytes` array `b`.
     * 4. Return `true` if both conditions are met, otherwise `false`.
     */
    function eq(bytes memory a, bytes32 b) internal pure returns (bool result) {
        assembly {
            result := and(eq(mload(a), 0x20), eq(mload(add(a, 0x20)), b))
        }
    }

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
    function hash(bytes memory b, uint256 start, uint256 end) internal pure returns (bytes32 result) {
        assembly {
            let n := mload(b)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            result := keccak256(add(add(b, 0x20), start), sub(end, start))
        }
    }

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
    function hash(bytes memory b, uint256 start) internal pure returns (bytes32 result) {
        assembly {
            let n := mload(b)
            start := xor(start, mul(xor(start, n), lt(n, start)))
            result := keccak256(add(add(b, 0x20), start), sub(n, start))
        }
    }

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
    function hash(bytes memory b) internal pure returns (bytes32 result) {
        assembly {
            result := keccak256(add(b, 0x20), mload(b))
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The Keccak-256 hash of the specified segment of calldata.
     *
     * Steps:
     * 1. Adjust the `end` index to ensure it does not exceed the length of the calldata.
     * 2. Adjust the `start` index to ensure it does not exceed the length of the calldata.
     * 3. Calculate the length of the segment to be hashed (`n`).
     * 4. Copy the specified segment of calldata into memory.
     * 5. Compute the Keccak-256 hash of the copied segment and return the result.
     *
     * @dev This function uses inline assembly for efficient memory manipulation and hashing.
     */
    function hashCalldata(bytes calldata b, uint256 start, uint256 end) internal pure returns (bytes32 result) {
        assembly {
            let n := b.length
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            n := sub(end, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            result := keccak256(m, n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The Keccak-256 hash of the specified segment of calldata.
     *
     * Steps:
     * 1. Adjust the `end` index to ensure it does not exceed the length of the calldata.
     * 2. Adjust the `start` index to ensure it does not exceed the length of the calldata.
     * 3. Calculate the length of the segment to be hashed (`n`).
     * 4. Copy the specified segment of calldata into memory.
     * 5. Compute the Keccak-256 hash of the copied segment and return the result.
     *
     * @dev This function uses inline assembly for efficient memory manipulation and hashing.
     */
    function hashCalldata(bytes calldata b, uint256 start) internal pure returns (bytes32 result) {
        assembly {
            let n := b.length
            start := xor(start, mul(xor(start, n), lt(n, start)))
            n := sub(n, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            result := keccak256(m, n)
        }
    }

    /**
     * @notice Computes the Keccak-256 hash of a segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The Keccak-256 hash of the specified segment of calldata.
     *
     * Steps:
     * 1. Adjust the `end` index to ensure it does not exceed the length of the calldata.
     * 2. Adjust the `start` index to ensure it does not exceed the length of the calldata.
     * 3. Calculate the length of the segment to be hashed (`n`).
     * 4. Copy the specified segment of calldata into memory.
     * 5. Compute the Keccak-256 hash of the copied segment and return the result.
     *
     * @dev This function uses inline assembly for efficient memory manipulation and hashing.
     */
    function hashCalldata(bytes calldata b) internal pure returns (bytes32 result) {
        assembly {
            let m := mload(0x40)
            calldatacopy(m, b.offset, b.length)
            result := keccak256(m, b.length)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes32 b) internal view returns (bytes32 result) {
        assembly {
            mstore(0x00, b)
            if iszero(staticcall(gas(), 2, 0x00, 0x20, 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes memory b, uint256 start, uint256 end) internal view returns (bytes32 result) {
        assembly {
            let n := mload(b)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            if iszero(staticcall(gas(), 2, add(add(b, 0x20), start), sub(end, start), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes memory b, uint256 start) internal view returns (bytes32 result) {
        assembly {
            let n := mload(b)
            start := xor(start, mul(xor(start, n), lt(n, start)))
            if iszero(staticcall(gas(), 2, add(add(b, 0x20), start), sub(n, start), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-2 hash of a given bytes32 input using inline assembly.
     *
     * @param b The input bytes32 value to be hashed.
     * @return result The resulting SHA-2 hash as a bytes32 value.
     *
     * Steps:
     * 1. Store the input bytes32 value `b` in memory at position 0x00.
     * 2. Use the `staticcall` opcode to invoke the SHA-2 precompiled contract (address 2) with the input data.
     * 3. Load the result from memory at position 0x01 and return it.
     * 4. If the `returndatasize` is zero, revert the transaction to ensure the operation was successful.
     *
     * @dev This function uses inline assembly for low-level operations and is marked as memory-safe.
     */
    function sha2(bytes memory b) internal view returns (bytes32 result) {
        assembly {
            if iszero(staticcall(gas(), 2, add(b, 0x20), mload(b), 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The SHA-256 hash of the specified segment.
     *
     * Steps:
     * 1. Adjust the `end` and `start` indices to ensure they are within the bounds of the calldata length.
     * 2. Calculate the length of the segment (`n`) to be hashed.
     * 3. Copy the specified segment of calldata into memory.
     * 4. Compute the SHA-256 hash of the segment using the `staticcall` opcode.
     * 5. Return the computed hash.
     * 6. If the `returndatasize` is zero, revert the transaction (invalid operation).
     *
     * @dev This function uses inline assembly for low-level memory manipulation and gas optimization.
     */
    function sha2Calldata(bytes calldata b, uint256 start, uint256 end) internal view returns (bytes32 result) {
        assembly {
            let n := b.length
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, end), lt(end, start)))
            n := sub(end, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            if iszero(staticcall(gas(), 2, m, n, 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The SHA-256 hash of the specified segment.
     *
     * Steps:
     * 1. Adjust the `end` and `start` indices to ensure they are within the bounds of the calldata length.
     * 2. Calculate the length of the segment (`n`) to be hashed.
     * 3. Copy the specified segment of calldata into memory.
     * 4. Compute the SHA-256 hash of the segment using the `staticcall` opcode.
     * 5. Return the computed hash.
     * 6. If the `returndatasize` is zero, revert the transaction (invalid operation).
     *
     * @dev This function uses inline assembly for low-level memory manipulation and gas optimization.
     */
    function sha2Calldata(bytes calldata b, uint256 start) internal view returns (bytes32 result) {
        assembly {
            let n := b.length
            start := xor(start, mul(xor(start, n), lt(n, start)))
            n := sub(n, start)
            let m := mload(0x40)
            calldatacopy(m, add(b.offset, start), n)
            if iszero(staticcall(gas(), 2, m, n, 0x00, 0x20)) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    /**
     * @notice Computes the SHA-256 hash of a specified segment of calldata.
     *
     * @param b The calldata bytes from which the segment is extracted.
     * @param start The starting index of the segment within the calldata.
     * @param end The ending index of the segment within the calldata.
     * @return result The SHA-256 hash of the specified segment.
     *
     * Steps:
     * 1. Adjust the `end` and `start` indices to ensure they are within the bounds of the calldata length.
     * 2. Calculate the length of the segment (`n`) to be hashed.
     * 3. Copy the specified segment of calldata into memory.
     * 4. Compute the SHA-256 hash of the segment using the `staticcall` opcode.
     * 5. Return the computed hash.
     * 6. If the `returndatasize` is zero, revert the transaction (invalid operation).
     *
     * @dev This function uses inline assembly for low-level memorySorry, the response hit the length limit. Please rephrase your prompt.