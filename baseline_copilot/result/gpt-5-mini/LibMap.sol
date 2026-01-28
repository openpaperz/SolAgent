// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibMap {
    struct Uint8Map {
        mapping(uint256 => uint256) data;
    }

    struct Uint16Map {
        mapping(uint256 => uint256) data;
    }

    struct Uint32Map {
        mapping(uint256 => uint256) data;
    }

    struct Uint40Map {
        mapping(uint256 => uint256) data;
    }

    struct Uint64Map {
        mapping(uint256 => uint256) data;
    }

    struct Uint128Map {
        mapping(uint256 => uint256) data;
    }

    /**
     * @notice Retrieves a value from a Uint8Map storage at a specific index.
     */
    function get(Uint8Map storage map, uint256 index) internal view returns (uint8 result) {
        uint256 raw = get(map.data, index, 8);
        return uint8(raw);
    }

    /**
     * @notice Sets a value at a specific index in a Uint8Map storage map.
     */
    function set(Uint8Map storage map, uint256 index, uint8 value) internal {
        set(map.data, index, value, 8);
    }

    /**
     * @notice Retrieves a value from a Uint16Map storage at a specific index.
     */
    function get(Uint16Map storage map, uint256 index) internal view returns (uint16 result) {
        uint256 raw = get(map.data, index, 16);
        return uint16(raw);
    }

    /**
     * @notice Sets a value at a specific index in a Uint16Map storage map.
     */
    function set(Uint16Map storage map, uint256 index, uint16 value) internal {
        set(map.data, index, value, 16);
    }

    /**
     * @notice Retrieves a value from a Uint32Map storage at a specific index.
     */
    function get(Uint32Map storage map, uint256 index) internal view returns (uint32 result) {
        uint256 raw = get(map.data, index, 32);
        return uint32(raw);
    }

    /**
     * @notice Sets a value at a specific index in a Uint32Map storage map.
     */
    function set(Uint32Map storage map, uint256 index, uint32 value) internal {
        set(map.data, index, value, 32);
    }

    /**
     * @notice Retrieves a value from a Uint40Map storage at a specific index.
     */
    function get(Uint40Map storage map, uint256 index) internal view returns (uint40 result) {
        uint256 raw = get(map.data, index, 40);
        return uint40(raw);
    }

    /**
     * @notice Sets a value at a specific index in a Uint40Map storage map.
     */
    function set(Uint40Map storage map, uint256 index, uint40 value) internal {
        set(map.data, index, value, 40);
    }

    /**
     * @notice Retrieves a value from a Uint64Map storage at a specific index.
     */
    function get(Uint64Map storage map, uint256 index) internal view returns (uint64 result) {
        uint256 raw = get(map.data, index, 64);
        return uint64(raw);
    }

    /**
     * @notice Sets a value at a specific index in a Uint64Map storage map.
     */
    function set(Uint64Map storage map, uint256 index, uint64 value) internal {
        set(map.data, index, value, 64);
    }

    /**
     * @notice Retrieves a value from a Uint128Map storage at a specific index.
     */
    function get(Uint128Map storage map, uint256 index) internal view returns (uint128 result) {
        uint256 raw = get(map.data, index, 128);
        return uint128(raw);
    }

    /**
     * @notice Sets a value at a specific index in a Uint128Map storage map.
     */
    function set(Uint128Map storage map, uint256 index, uint128 value) internal {
        set(map.data, index, value, 128);
    }

    /**
     * @notice Retrieves a value from a packed mapping with a given bitWidth.
     *
     * The mapping stores packed values per 256-bit storage word. bitWidth must be > 0 and <= 256.
     */
    function get(mapping(uint256 => uint256) storage map, uint256 index, uint256 bitWidth) internal view returns (uint256 result) {
        require(bitWidth > 0 && bitWidth <= 256, "LibMap: invalid bitWidth");
        uint256 valuesPerSlot = 256 / bitWidth;
        uint256 slotIndex = _rawDiv(index, valuesPerSlot);

        // compute keccak256(slotIndex, mapSlot)
        bytes32 slot;
        assembly {
            // store slot (mapping pointer) at 0x20 and slotIndex at 0x00 then keccak256(0x00, 0x40)
            mstore(0x00, slotIndex)
            mstore(0x20, map.slot)
            slot := keccak256(0x00, 0x40)
        }

        uint256 packed;
        assembly {
            packed := sload(slot)
        }

        uint256 pos = index - slotIndex * valuesPerSlot; // index % valuesPerSlot
        uint256 shift = pos * bitWidth;
        if (bitWidth == 256) {
            result = packed;
        } else {
            uint256 mask = (uint256(1) << bitWidth) - 1;
            result = (packed >> shift) & mask;
        }
    }

    /**
     * @notice Sets a value into a packed mapping with a given bitWidth.
     */
    function set(mapping(uint256 => uint256) storage map, uint256 index, uint256 value, uint256 bitWidth) internal {
        require(bitWidth > 0 && bitWidth <= 256, "LibMap: invalid bitWidth");
        if (bitWidth < 256) {
            uint256 max = (uint256(1) << bitWidth) - 1;
            require(value <= max, "LibMap: value overflow");
        }

        uint256 valuesPerSlot = 256 / bitWidth;
        uint256 slotIndex = _rawDiv(index, valuesPerSlot);

        bytes32 slot;
        assembly {
            mstore(0x00, slotIndex)
            mstore(0x20, map.slot)
            slot := keccak256(0x00, 0x40)
        }

        uint256 packed;
        assembly {
            packed := sload(slot)
        }

        uint256 pos = index - slotIndex * valuesPerSlot;
        uint256 shift = pos * bitWidth;

        if (bitWidth == 256) {
            packed = value;
        } else {
            uint256 mask = ((uint256(1) << bitWidth) - 1) << shift;
            packed = (packed & (~mask)) | ((value & ((uint256(1) << bitWidth) - 1)) << shift);
        }

        assembly {
            sstore(slot, packed)
        }
    }

    /**
     * @notice Searches for a specific value within a sorted Uint8Map using binary search.
     */
    function searchSorted(Uint8Map storage map, uint8 needle, uint256 start, uint256 end) internal view returns (bool found, uint256 index) {
        (found, index) = searchSorted(map.data, uint256(needle), start, end, 8);
    }

    /**
     * @notice Searches for a specific value within a sorted Uint16Map using binary search.
     */
    function searchSorted(Uint16Map storage map, uint16 needle, uint256 start, uint256 end) internal view returns (bool found, uint256 index) {
        (found, index) = searchSorted(map.data, uint256(needle), start, end, 16);
    }

    /**
     * @notice Searches for a specific value within a sorted Uint32Map using binary search.
     */
    function searchSorted(Uint32Map storage map, uint32 needle, uint256 start, uint256 end) internal view returns (bool found, uint256 index) {
        (found, index) = searchSorted(map.data, uint256(needle), start, end, 32);
    }

    /**
     * @notice Searches for a specific value within a sorted Uint40Map using binary search.
     */
    function searchSorted(Uint40Map storage map, uint40 needle, uint256 start, uint256 end) internal view returns (bool found, uint256 index) {
        (found, index) = searchSorted(map.data, uint256(needle), start, end, 40);
    }

    /**
     * @notice Searches for a specific value within a sorted Uint64Map using binary search.
     */
    function searchSorted(Uint64Map storage map, uint64 needle, uint256 start, uint256 end) internal view returns (bool found, uint256 index) {
        (found, index) = searchSorted(map.data, uint256(needle), start, end, 64);
    }

    /**
     * @notice Searches for a specific value within a sorted Uint128Map using binary search.
     */
    function searchSorted(Uint128Map storage map, uint128 needle, uint256 start, uint256 end) internal view returns (bool found, uint256 index) {
        (found, index) = searchSorted(map.data, uint256(needle), start, end, 128);
    }

    /**
     * @notice Searches for a specific value within a sorted packed mapping using binary search.
     *
     * The search assumes the range [start, end) (end is exclusive). Returns (true, idx) if found,
     * otherwise (false, insertionIndex) where insertionIndex is the index where the value should be inserted.
     */
    function searchSorted(mapping(uint256 => uint256) storage map, uint256 needle, uint256 start, uint256 end, uint256 bitWidth) internal view returns (bool found, uint256 index) {
        require(start <= end, "LibMap: invalid range");
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
        index = lo;
        if (index < end) {
            uint256 v = get(map, index, bitWidth);
            found = (v == needle);
        } else {
            found = false;
        }
    }

    /**
     * @notice Performs a raw division operation on two unsigned integers using inline assembly.
     */
    function _rawDiv(uint256 x, uint256 y) private pure returns (uint256 z) {
        assembly {
            z := div(x, y)
        }
    }

    /**
     * @notice Performs a raw modulo operation on two unsigned integers using inline assembly.
     */
    function _rawMod(uint256 x, uint256 y) private pure returns (uint256 z) {
        assembly {
            z := mod(x, y)
        }
    }
}