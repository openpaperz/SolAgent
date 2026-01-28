// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SlotDerivation {
    /**
     * @notice Computes the ERC-7201 storage slot for a given namespace.
     *
     * Steps:
     * 1. Load the namespace string into memory.
     * 2. Compute the keccak256 hash of the namespace.
     * 3. Subtract 1 from the hash to derive the slot.
     * 4. Apply a mask to ensure the slot is aligned to 256 bits.
     *
     * @param namespace The namespace string used to compute the storage slot.
     * @return slot The computed storage slot as a bytes32 value.
     */
    function erc7201Slot(string memory namespace) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let length := mload(namespace)
            let data := add(namespace, 0x20)
            
            // Copy the string data to memory
            for { let i := 0 } lt(i, length) { i := add(i, 0x20) } {
                mstore(add(ptr, i), mload(add(data, i)))
            }
            
            // Compute keccak256 hash and subtract 1
            slot := sub(keccak256(ptr, length), 1)
        }
    }

    /**
     * @notice Calculates the offset of a given slot by adding a position value.
     *
     * @param slot The base slot value to which the position will be added.
     * @param pos The position value to add to the slot.
     * @return result The resulting slot after adding the position to the base slot.
     *
     * Steps:
     * 1. Perform an unchecked addition of the `pos` value to the `slot` value.
     * 2. Return the result as a `bytes32` value.
     */
    function offset(bytes32 slot, uint256 pos) internal pure returns (bytes32 result) {
        unchecked {
            result = bytes32(uint256(slot) + pos);
        }
    }

    /**
     * @notice Derives a storage slot for an array based on the provided base slot.
     *
     * @param slot The base storage slot from which the array's storage slot is derived.
     * @return result The derived storage slot for the array.
     *
     * Steps:
     * 1. Store the provided `slot` value in memory at position `0x00`.
     * 2. Compute the keccak256 hash of the 32 bytes starting at memory position `0x00`.
     * 3. Return the computed hash as the derived storage slot for the array.
     *
     * @dev This function uses inline assembly to perform low-level memory operations.
     */
    function deriveArray(bytes32 slot) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, slot)
            result := keccak256(0x00, 0x20)
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, address key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, bool key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, bytes32 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, uint256 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, int256 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, string memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let length := mload(key)
            let data := add(key, 0x20)
            
            // Copy the string data to memory
            for { let i := 0 } lt(i, length) { i := add(i, 0x20) } {
                mstore(add(ptr, i), mload(add(data, i)))
            }
            
            // Store the slot after the string data
            mstore(add(ptr, length), slot)
            
            // Compute keccak256 hash of key + slot
            result := keccak256(ptr, add(length, 0x20))
        }
    }

    /**
     * @notice Derives the storage slot for a mapping key in a Solidity contract.
     *
     * @param slot The base storage slot of the mapping.
     * @param key The key for which the storage slot is being derived.
     * @return result The derived storage slot as a `bytes32` value.
     *
     * Steps:
     * 1. Use inline assembly to perform low-level operations.
     * 2. Store the key in memory, ensuring it is properly aligned and padded.
     * 3. Store the base slot in memory.
     * 4. Compute the keccak256 hash of the concatenated key and slot to derive the storage slot.
     * 5. Return the derived storage slot.
     *
     * Note: This function is marked as `internal pure` and uses `memory-safe` assembly to ensure safety.
     */
    function deriveMapping(bytes32 slot, bytes memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let length := mload(key)
            let data := add(key, 0x20)
            
            // Copy the bytes data to memory
            for { let i := 0 } lt(i, length) { i := add(i, 0x20) } {
                mstore(add(ptr, i), mload(add(data, i)))
            }
            
            // Store the slot after the bytes data
            mstore(add(ptr, length), slot)
            
            // Compute keccak256 hash of key + slot
            result := keccak256(ptr, add(length, 0x20))
        }
    }
}
