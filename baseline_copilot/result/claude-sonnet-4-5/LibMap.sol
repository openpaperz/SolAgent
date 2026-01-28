// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for storage efficient maps.
library LibMap {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Defines a struct `Uint8Map` that contains a mapping from `uint256` to `uint256`.
     *
     * This struct is used to store a mapping where both the keys and values are of type `uint256`.
     */
    struct Uint8Map {
        mapping(uint256 => uint256) map;
    }

    /**
     * @notice Defines a struct `Uint16Map` that contains a mapping from `uint256` to `uint256`.
     *
     * The struct is used to store a mapping where keys and values are both of type `uint256`.
     * This can be useful for storing and retrieving data in a structured way.
     */
    struct Uint16Map {
        mapping(uint256 => uint256) map;
    }

    /**
     * @notice A struct representing a mapping of uint256 keys to uint256 values, specifically designed for storing uint32 values.
     *
     * @dev This struct is used to efficiently store and retrieve uint32 values using a mapping. The mapping is keyed by uint256, but the values are expected to be uint32.
     */
    struct Uint32Map {
        mapping(uint256 => uint256) map;
    }

    /**
     * @notice A struct representing a mapping of uint256 keys to uint256 values, optimized for storage efficiency.
     *
     * @dev This struct is designed to store uint256 values in a way that minimizes storage costs.
     * The mapping is stored in a single storage slot, which can be useful for optimizing gas usage.
     */
    struct Uint40Map {
        mapping(uint256 => uint256) map;
    }

    /**
     * @notice Defines a struct `Uint64Map` that contains a mapping from `uint256` to `uint256`.
     * This struct can be used to store and manage key-value pairs where both keys and values are of type `uint256`.
     */
    struct Uint64Map {
        mapping(uint256 => uint256) map;
    }

    /**
     * @notice Defines a struct `Uint128Map` that contains a mapping from `uint256` keys to `uint256` values.
     *
     * This struct is typically used to store and manage data in a key-value format, where both keys and values are of type `uint256`.
     */
    struct Uint128Map {
        mapping(uint256 => uint256) map;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UINT8 OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint8Map storage map, uint256 index) internal view returns (uint8 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(5, index))
            result := byte(and(31, not(index)), sload(keccak256(0x00, 0x40)))
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint8Map storage map, uint256 index, uint8 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(5, index))
            let s := keccak256(0x00, 0x40)
            let o := shl(3, and(31, not(index)))
            sstore(s, or(and(sload(s), not(shl(o, 0xff))), shl(o, value)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UINT16 OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint16Map storage map, uint256 index) internal view returns (uint16 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(4, index))
            result := and(0xffff, shr(shl(4, and(15, not(index))), sload(keccak256(0x00, 0x40))))
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint16Map storage map, uint256 index, uint16 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(4, index))
            let s := keccak256(0x00, 0x40)
            let o := shl(4, and(15, not(index)))
            sstore(s, or(and(sload(s), not(shl(o, 0xffff))), shl(o, value)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UINT32 OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint32Map storage map, uint256 index) internal view returns (uint32 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(3, index))
            result := and(0xffffffff, shr(shl(5, and(7, not(index))), sload(keccak256(0x00, 0x40))))
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint32Map storage map, uint256 index, uint32 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(3, index))
            let s := keccak256(0x00, 0x40)
            let o := shl(5, and(7, not(index)))
            sstore(s, or(and(sload(s), not(shl(o, 0xffffffff))), shl(o, value)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UINT40 OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint40Map storage map, uint256 index) internal view returns (uint40 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, div(index, 6))
            result :=
                and(0xffffffffff, shr(mul(40, mod(sub(5, index), 6)), sload(keccak256(0x00, 0x40))))
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint40Map storage map, uint256 index, uint40 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, div(index, 6))
            let s := keccak256(0x00, 0x40)
            let o := mul(40, mod(sub(5, index), 6))
            sstore(s, or(and(sload(s), not(shl(o, 0xffffffffff))), shl(o, value)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UINT64 OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint64Map storage map, uint256 index) internal view returns (uint64 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(2, index))
            result :=
                and(0xffffffffffffffff, shr(shl(6, and(3, not(index))), sload(keccak256(0x00, 0x40))))
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint64Map storage map, uint256 index, uint64 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(2, index))
            let s := keccak256(0x00, 0x40)
            let o := shl(6, and(3, not(index)))
            sstore(s, or(and(sload(s), not(shl(o, 0xffffffffffffffff))), shl(o, value)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   UINT128 OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint128Map storage map, uint256 index) internal view returns (uint128 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(1, index))
            result :=
                and(
                    0xffffffffffffffffffffffffffffffff,
                    shr(shl(7, and(1, not(index))), sload(keccak256(0x00, 0x40)))
                )
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint128Map storage map, uint256 index, uint128 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(1, index))
            let s := keccak256(0x00, 0x40)
            let o := shl(7, and(1, not(index)))
            sstore(
                s, or(and(sload(s), not(shl(o, 0xffffffffffffffffffffffffffffffff))), shl(o, value))
            )
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  GENERIC OPERATIONS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * Steps:
     * 1. Store the slot of the map in memory at position 0x20.
     * 2. Store the shifted index (divided by 32) in memory at position 0x00.
     * 3. Calculate the storage slot using `keccak256` with the memory range 0x00 to 0x40.
     * 4. Load the value from the calculated storage slot.
     * 5. Extract the specific byte from the loaded value using bitwise operations.
     * 6. Return the extracted byte as the result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(mapping(uint256 => uint256) storage map, uint256 index, uint256 bitWidth)
        internal
        view
        returns (uint256 result)
    {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, div(index, div(256, bitWidth)))
            result :=
                and(
                    sub(shl(bitWidth, 1), 1),
                    shr(mul(bitWidth, mod(sub(div(256, bitWidth), index), div(256, bitWidth))), sload(keccak256(0x00, 0x40)))
                )
        }
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * Steps:
     * 1. Calculate the storage slot for the given index in the map.
     * 2. Load the current value from the calculated storage slot.
     * 3. Update the specific byte within the loaded value corresponding to the index.
     * 4. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(
        mapping(uint256 => uint256) storage map,
        uint256 index,
        uint256 value,
        uint256 bitWidth
    ) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, div(index, div(256, bitWidth)))
            let s := keccak256(0x00, 0x40)
            let o := mul(bitWidth, mod(sub(div(256, bitWidth), index), div(256, bitWidth)))
            let m := sub(shl(bitWidth, 1), 1)
            sstore(s, or(and(sload(s), not(shl(o, m))), shl(o, and(m, value))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BINARY SEARCH                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(Uint8Map storage map, uint8 needle, uint256 start, uint256 end)
        internal
        view
        returns (bool found, uint256 index)
    {
        return searchSorted(map.map, needle, start, end, 8);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(Uint16Map storage map, uint16 needle, uint256 start, uint256 end)
        internal
        view
        returns (bool found, uint256 index)
    {
        return searchSorted(map.map, needle, start, end, 16);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(Uint32Map storage map, uint32 needle, uint256 start, uint256 end)
        internal
        view
        returns (bool found, uint256 index)
    {
        return searchSorted(map.map, needle, start, end, 32);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(Uint40Map storage map, uint40 needle, uint256 start, uint256 end)
        internal
        view
        returns (bool found, uint256 index)
    {
        return searchSorted(map.map, needle, start, end, 40);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(Uint64Map storage map, uint64 needle, uint256 start, uint256 end)
        internal
        view
        returns (bool found, uint256 index)
    {
        return searchSorted(map.map, needle, start, end, 64);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(Uint128Map storage map, uint128 needle, uint256 start, uint256 end)
        internal
        view
        returns (bool found, uint256 index)
    {
        return searchSorted(map.map, needle, start, end, 128);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     * The search is performed within a specified range (`start` to `end`) using binary search.
     *
     * @param map The storage map of type `Uint8Map` to search within.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within.
     * @param end The ending index of the range to search within.
     *
     * @return found A boolean indicating whether the value was found.
     * @return index The index of the value if found, or the index where it should be inserted to maintain order.
     *
     * Steps:
     * 1. Calls an internal `searchSorted` function with the map's underlying data, the value to search for,
     *    the start and end indices, and the bit length (8 bits for `uint8`).
     * 2. Returns the result of the internal search, which includes whether the value was found and its index.
     */
    function searchSorted(
        mapping(uint256 => uint256) storage map,
        uint256 needle,
        uint256 start,
        uint256 end,
        uint256 bitWidth
    ) internal view returns (bool found, uint256 index) {
        assembly {
            let m := shl(bitWidth, 1)
            let t := div(256, bitWidth)
            mstore(0x20, map.slot)
            for {} 1 {} {
                index := shr(1, add(start, end))
                mstore(0x00, div(index, t))
                let v :=
                    and(
                        sub(m, 1),
                        shr(mul(bitWidth, mod(sub(t, index), t)), sload(keccak256(0x00, 0x40)))
                    )
                if or(gt(v, needle), eq(v, needle)) {
                    found := eq(v, needle)
                    if iszero(lt(start, end)) { break }
                    end := index
                    continue
                }
                start := add(index, 1)
                if iszero(lt(start, end)) { break }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  PRIVATE HELPERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Performs a raw division operation on two unsigned integers using inline assembly.
     * @dev This function uses Solidity's inline assembly to perform the division, which is memory-safe.
     * @param x The dividend.
     * @param y The divisor.
     * @return z The result of the division (x / y).
     */
    function _rawDiv(uint256 x, uint256 y) private pure returns (uint256 z) {
        assembly {
            z := div(x, y)
        }
    }

    /**
     * @notice A private pure function that performs a raw modulo operation on two unsigned integers.
     * 
     * @param x The dividend.
     * @param y The divisor.
     * @return z The remainder of the division of `x` by `y`.
     * 
     * @dev Uses inline assembly to perform the modulo operation directly, ensuring memory safety.
     */
    function _rawMod(uint256 x, uint256 y) private pure returns (uint256 z) {
        assembly {
            z := mod(x, y)
        }
    }
}
