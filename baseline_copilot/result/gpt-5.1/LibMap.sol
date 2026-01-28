// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for densely packed uintX "maps" stored in a mapping(uint256 => uint256).
library LibMap {
    /**
     * @notice Defines a struct `Uint8Map` that contains a mapping from `uint256` to `uint256`.
     *
     * This struct is used to store a mapping where both the keys and values are of type `uint256`.
     */
    struct Uint8Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice Defines a struct `Uint16Map` that contains a mapping from `uint256` to `uint256`.
     *
     * The struct is used to store a mapping where keys and values are both of type `uint256`.
     * This can be useful for storing and retrieving data in a structured way.
     */
    struct Uint16Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice A struct representing a mapping of uint256 keys to uint256 values, specifically designed for storing uint32 values.
     *
     * @dev This struct is used to efficiently store and retrieve uint32 values using a mapping. The mapping is keyed by uint256, but the values are expected to be uint32.
     */
    struct Uint32Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice A struct representing a mapping of uint256 keys to uint256 values, optimized for storage efficiency.
     *
     * @dev This struct is designed to store uint256 values in a way that minimizes storage costs.
     * The mapping is stored in a single storage slot, which can be useful for optimizing gas usage.
     */
    struct Uint40Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice Defines a struct `Uint64Map` that contains a mapping from `uint256` to `uint256`.
     * This struct can be used to store and manage key-value pairs where both keys and values are of type `uint256`.
     */
    struct Uint64Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice Defines a struct `Uint128Map` that contains a mapping from `uint256` keys to `uint256` values.
     *
     * This struct is typically used to store and manage data in a key-value format, where both keys and values are of type `uint256`.
     */
    struct Uint128Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint8Map storage map, uint256 index) internal view returns (uint8 result) {
        result = uint8(get(map.data, index, 8));
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 8-bit unsigned integer value to be stored at the specified index.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint8Map storage map, uint256 index, uint8 value) internal {
        set(map.data, index, value, 8);
    }

    /**
     * @notice Retrieves a value from a Uint16Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint16Map storage map, uint256 index) internal view returns (uint16 result) {
        result = uint16(get(map.data, index, 16));
    }

    /**
     * @notice Sets a value at a specific index in a Uint16Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 16-bit unsigned integer value to be stored at the specified index.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint16Map storage map, uint256 index, uint16 value) internal {
        set(map.data, index, value, 16);
    }

    /**
     * @notice Retrieves a value from a Uint32Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint32Map storage map, uint256 index) internal view returns (uint32 result) {
        result = uint32(get(map.data, index, 32));
    }

    /**
     * @notice Sets a value at a specific index in a Uint32Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 32-bit unsigned integer value to be stored at the specified index.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint32Map storage map, uint256 index, uint32 value) internal {
        set(map.data, index, value, 32);
    }

    /**
     * @notice Retrieves a value from a Uint40Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint40Map storage map, uint256 index) internal view returns (uint40 result) {
        result = uint40(get(map.data, index, 40));
    }

    /**
     * @notice Sets a value at a specific index in a Uint40Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 40-bit unsigned integer value to be stored at the specified index.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint40Map storage map, uint256 index, uint40 value) internal {
        set(map.data, index, value, 40);
    }

    /**
     * @notice Retrieves a value from a Uint64Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint64Map storage map, uint256 index) internal view returns (uint64 result) {
        result = uint64(get(map.data, index, 64));
    }

    /**
     * @notice Sets a value at a specific index in a Uint64Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 64-bit unsigned integer value to be stored at the specified index.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint64Map storage map, uint256 index, uint64 value) internal {
        set(map.data, index, value, 64);
    }

    /**
     * @notice Retrieves a value from a Uint128Map storage at a specific index.
     *
     * @param map The storage map from which to retrieve the value.
     * @param index The index in the map where the value is stored.
     * @return result The value stored at the specified index.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently retrieve the value.
     */
    function get(Uint128Map storage map, uint256 index) internal view returns (uint128 result) {
        result = uint128(get(map.data, index, 128));
    }

    /**
     * @notice Sets a value at a specific index in a Uint128Map storage map.
     *
     * @param map The storage map where the value will be set.
     * @param index The index in the map where the value will be stored.
     * @param value The 128-bit unsigned integer value to be stored at the specified index.
     *
     * @dev This function uses inline assembly to manipulate storage directly for efficiency.
     */
    function set(Uint128Map storage map, uint256 index, uint128 value) internal {
        set(map.data, index, value, 128);
    }

    /**
     * @notice Retrieves a packed value from a generic packed mapping at a specific index.
     *
     * @param map The storage mapping from which to retrieve the value.
     * @param index The logical index in the packed map where the value is stored.
     * @param bitWidth The number of bits used to represent each value.
     * @return result The unpacked value stored at the specified index.
     *
     * @dev Layout:
     *  - Each storage word stores floor(256 / bitWidth) items.
     *  - wordIndex  = index / itemsPerWord
     *  - offsetBits = (index % itemsPerWord) * bitWidth
     */
    function get(
        mapping(uint256 => uint256) storage map,
        uint256 index,
        uint256 bitWidth
    ) internal view returns (uint256 result) {
        unchecked {
            require(bitWidth > 0 && bitWidth <= 256, "LibMap: bad width");

            uint256 itemsPerWord = _rawDiv(256, bitWidth);
            require(itemsPerWord > 0, "LibMap: width too big");

            uint256 wordIndex = _rawDiv(index, itemsPerWord);
            uint256 offset = _rawMod(index, itemsPerWord) * bitWidth;

            uint256 word = map[wordIndex];

            assembly ("memory-safe") {
                // result = (word >> offset) & ((1 << bitWidth) - 1)
                let shifted := shr(offset, word)
                let mask := sub(shl(bitWidth, 1), 1)
                result := and(shifted, mask)
            }
        }
    }

    /**
     * @notice Sets a packed value in a generic packed mapping at a specific index.
     *
     * @param map The storage mapping where the value will be set.
     * @param index The logical index in the packed map where the value will be stored.
     * @param value The value to be stored at the specified index.
     * @param bitWidth The number of bits used to represent each value.
     *
     * @dev Does not mask `value` beyond `bitWidth` bits; high bits are discarded by masking.
     */
    function set(
        mapping(uint256 => uint256) storage map,
        uint256 index,
        uint256 value,
        uint256 bitWidth
    ) internal {
        unchecked {
            require(bitWidth > 0 && bitWidth <= 256, "LibMap: bad width");

            uint256 itemsPerWord = _rawDiv(256, bitWidth);
            require(itemsPerWord > 0, "LibMap: width too big");

            uint256 wordIndex = _rawDiv(index, itemsPerWord);
            uint256 offset = _rawMod(index, itemsPerWord) * bitWidth;

            uint256 word = map[wordIndex];

            assembly ("memory-safe") {
                // mask for field
                let mask := sub(shl(bitWidth, 1), 1)
                // clear existing field
                let cleared := and(
                    word,
                    not(shl(offset, mask))
                )
                // truncated value
                let v := and(value, mask)
                // insert value
                word := or(cleared, shl(offset, v))
            }

            map[wordIndex] = word;
        }
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint8Map` storage map.
     */
    function searchSorted(
        Uint8Map storage map,
        uint8 needle,
        uint256 start,
        uint256 end
    ) internal view returns (bool found, uint256 index) {
        return searchSorted(map.data, uint256(needle), start, end, 8);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint16Map` storage map.
     */
    function searchSorted(
        Uint16Map storage map,
        uint16 needle,
        uint256 start,
        uint256 end
    ) internal view returns (bool found, uint256 index) {
        return searchSorted(map.data, uint256(needle), start, end, 16);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint32Map` storage map.
     */
    function searchSorted(
        Uint32Map storage map,
        uint32 needle,
        uint256 start,
        uint256 end
    ) internal view returns (bool found, uint256 index) {
        return searchSorted(map.data, uint256(needle), start, end, 32);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint40Map` storage map.
     */
    function searchSorted(
        Uint40Map storage map,
        uint40 needle,
        uint256 start,
        uint256 end
    ) internal view returns (bool found, uint256 index) {
        return searchSorted(map.data, uint256(needle), start, end, 40);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint64Map` storage map.
     */
    function searchSorted(
        Uint64Map storage map,
        uint64 needle,
        uint256 start,
        uint256 end
    ) internal view returns (bool found, uint256 index) {
        return searchSorted(map.data, uint256(needle), start, end, 64);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted `Uint128Map` storage map.
     */
    function searchSorted(
        Uint128Map storage map,
        uint128 needle,
        uint256 start,
        uint256 end
    ) internal view returns (bool found, uint256 index) {
        return searchSorted(map.data, uint256(needle), start, end, 128);
    }

    /**
     * @notice Searches for a specific value (`needle`) within a sorted packed map.
     *
     * @param map The packed storage map.
     * @param needle The value to search for within the map.
     * @param start The starting index of the range to search within (inclusive).
     * @param end The ending index of the range to search within (exclusive).
     * @param bitWidth The number of bits per stored element.
     *
     * @return found Whether the value was found.
     * @return index Index of the value if found, or insertion position to maintain sort order.
     */
    function searchSorted(
        mapping(uint256 => uint256) storage map,
        uint256 needle,
        uint256 start,
        uint256 end,
        uint256 bitWidth
    ) internal view returns (bool found, uint256 index) {
        unchecked {
            require(start <= end, "LibMap: bad range");
            uint256 lo = start;
            uint256 hi = end;
            while (lo < hi) {
                uint256 mid = (lo + hi) >> 1;
                uint256 v = get(map, mid, bitWidth);
                if (v < needle) {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            if (lo < end && get(map, lo, bitWidth) == needle) {
                found = true;
                index = lo;
            } else {
                found = false;
                index = lo;
            }
        }
    }

    /**
     * @notice Performs a raw division operation on two unsigned integers using inline assembly.
     * @dev This function uses Solidity's inline assembly to perform the division, which is memory-safe.
     * @param x The dividend.
     * @param y The divisor.
     * @return z The result of the division (x / y).
     */
    function _rawDiv(uint256 x, uint256 y) private pure returns (uint256 z) {
        assembly ("memory-safe") {
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
        assembly ("memory-safe") {
            z := mod(x, y)
        }
    }
}