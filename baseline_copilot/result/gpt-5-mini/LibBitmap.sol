// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibBitmap {
    /// @notice Special value returned when a search yields no result.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /**
     * @notice Defines a Bitmap structure that uses a mapping to store data.
     *
     * The structure contains a single field:
     * - `map`: A mapping from `uint256` keys to `uint256` values, used to store bitmap data.
     */
    struct Bitmap {
        mapping(uint256 => uint256) map;
    }

    /* ------------------------------------------------------------------------
       Basic single-bit operations
       ------------------------------------------------------------------------ */

    /**
     * @notice Checks if a specific bit in a bitmap is set.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to check.
     * @return isSet A boolean indicating whether the bit is set (1) or not (0).
     */
    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {
        uint256 bucket = index >> 8; // index / 256
        uint256 pos = index & 0xff;  // index % 256
        uint256 word = bitmap.map[bucket];
        isSet = ((word >> pos) & 1) == 1;
    }

    /**
     * @notice Sets a specific bit in the bitmap to 1.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to set.
     */
    function set(Bitmap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 pos = index & 0xff;
        bitmap.map[bucket] |= (uint256(1) << pos);
    }

    /**
     * @notice Unsets a specific bit in the bitmap at the given index.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to unset.
     */
    function unset(Bitmap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 pos = index & 0xff;
        bitmap.map[bucket] &= ~(uint256(1) << pos);
    }

    /**
     * @notice Toggles the state of a specific bit in a bitmap storage and returns the new state.
     *
     * @param bitmap The bitmap storage reference where the bit is to be toggled.
     * @param index The index of the bit to toggle.
     * @return newIsSet The new state of the bit after toggling (1 if set, 0 if not set).
     */
    function toggle(Bitmap storage bitmap, uint256 index) internal returns (bool newIsSet) {
        uint256 bucket = index >> 8;
        uint256 pos = index & 0xff;
        uint256 mask = uint256(1) << pos;
        uint256 newVal = bitmap.map[bucket] ^ mask;
        bitmap.map[bucket] = newVal;
        newIsSet = ((newVal >> pos) & 1) == 1;
    }

    /**
     * @notice Sets or unsets a bit at a specific index in a bitmap storage.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to set or unset.
     * @param shouldSet A boolean indicating whether to set (true) or unset (false) the bit.
     */
    function setTo(Bitmap storage bitmap, uint256 index, bool shouldSet) internal {
        if (shouldSet) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /* ------------------------------------------------------------------------
       Batch operations
       ------------------------------------------------------------------------ */

    /**
     * @dev Safe left mask for up to 256 bits.
     */
    function _maskL(uint256 bits) private pure returns (uint256) {
        // avoid shifting by 256
        if (bits == 256) return type(uint256).max;
        return (uint256(1) << bits) - 1;
    }

    /**
     * @notice Sets a batch of bits in a bitmap starting from a specific position.
     *
     * @param bitmap The storage reference to the bitmap where bits will be set.
     * @param start The starting position in the bitmap where the batch of bits will be set.
     * @param amount The number of bits to set starting from the `start` position.
     */
    function setBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        if (amount == 0) return;
        uint256 bucket = start >> 8;
        uint256 shift = start & 0xff;

        // fits within single bucket
        if (shift + amount <= 256) {
            uint256 mask = _maskL(amount) << shift;
            bitmap.map[bucket] |= mask;
            return;
        }

        // first partial bucket
        uint256 firstMask = (~uint256(0)) << shift;
        bitmap.map[bucket] |= firstMask;
        amount -= (256 - shift);
        bucket++;

        // full buckets
        while (amount >= 256) {
            bitmap.map[bucket] = type(uint256).max;
            amount -= 256;
            bucket++;
        }

        // final partial
        if (amount > 0) {
            uint256 mask = _maskL(amount);
            bitmap.map[bucket] |= mask;
        }
    }

    /**
     * @notice Unsets a batch of bits in a bitmap starting from a specific position.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param start The starting bit position from which to unset bits.
     * @param amount The number of bits to unset.
     */
    function unsetBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        if (amount == 0) return;
        uint256 bucket = start >> 8;
        uint256 shift = start & 0xff;

        // fits within single bucket
        if (shift + amount <= 256) {
            uint256 mask = _maskL(amount) << shift;
            bitmap.map[bucket] &= ~mask;
            return;
        }

        // first partial bucket
        uint256 firstMask = (~uint256(0)) << shift;
        bitmap.map[bucket] &= ~firstMask;
        amount -= (256 - shift);
        bucket++;

        // full buckets
        while (amount >= 256) {
            bitmap.map[bucket] = 0;
            amount -= 256;
            bucket++;
        }

        // final partial
        if (amount > 0) {
            uint256 mask = _maskL(amount);
            bitmap.map[bucket] &= ~mask;
        }
    }

    /* ------------------------------------------------------------------------
       Queries
       ------------------------------------------------------------------------ */

    /**
     * @notice Calculates the number of set bits (pop count) in a bitmap over a specified range.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param start The starting index from which to begin counting set bits.
     * @param amount The number of bits to consider for counting.
     * @return count The total number of set bits within the specified range.
     */
    function popCount(Bitmap storage bitmap, uint256 start, uint256 amount) internal view returns (uint256 count) {
        if (amount == 0) return 0;
        uint256 bucket = start >> 8;
        uint256 shift = start & 0xff;

        // single-bucket case
        if (shift + amount <= 256) {
            uint256 mask = _maskL(amount) << shift;
            uint256 val = bitmap.map[bucket] & mask;
            return _popcount(val);
        }

        // first partial
        uint256 firstMask = (~uint256(0)) << shift;
        uint256 valFirst = bitmap.map[bucket] & firstMask;
        count += _popcount(valFirst);
        amount -= (256 - shift);
        bucket++;

        // full buckets
        while (amount >= 256) {
            count += _popcount(bitmap.map[bucket]);
            amount -= 256;
            bucket++;
        }

        // final partial
        if (amount > 0) {
            uint256 mask = _maskL(amount);
            uint256 val = bitmap.map[bucket] & mask;
            count += _popcount(val);
        }
    }

    /**
     * @notice Finds the index of the last set bit in a bitmap up to a specified index.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param upTo The maximum index to search for the last set bit.
     * @return setBitIndex The index of the last set bit, or `NOT_FOUND` if no set bit is found.
     */
    function findLastSet(Bitmap storage bitmap, uint256 upTo) internal view returns (uint256 setBitIndex) {
        // upTo treated as inclusive index; if upTo is 0 we check bit 0
        // If upTo is zero and bit 0 not set, return NOT_FOUND
        uint256 bucket = upTo >> 8;
        uint256 offset = upTo & 0xff;
        uint256 word = bitmap.map[bucket];

        // Mask off bits higher than offset
        if (offset < 255) {
            uint256 mask = (uint256(1) << (offset + 1)) - 1;
            word &= mask;
        }

        while (word == 0) {
            if (bucket == 0) return NOT_FOUND;
            bucket--;
            word = bitmap.map[bucket];
        }

        uint256 pos = _msb(word);
        setBitIndex = (bucket << 8) | pos;
        if (setBitIndex > upTo) return NOT_FOUND;
        return setBitIndex;
    }

    /**
     * @notice Finds the first unset bit in a bitmap within a specified range.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param begin The starting index to begin searching for an unset bit.
     * @param upTo The upper limit (exclusive) for the search range.
     * @return unsetBitIndex The index of the first unset bit found, or `NOT_FOUND` if no unset bit is found within the range.
     */
    function findFirstUnset(Bitmap storage bitmap, uint256 begin, uint256 upTo) internal view returns (uint256 unsetBitIndex) {
        if (begin >= upTo) return NOT_FOUND;

        uint256 startBucket = begin >> 8;
        uint256 startShift = begin & 0xff;
        uint256 lastBucket = (upTo - 1) >> 8;
        uint256 lastOffset = (upTo - 1) & 0xff;

        for (uint256 bucket = startBucket; bucket <= lastBucket; bucket++) {
            uint256 maskStart = bucket == startBucket ? ~((uint256(1) << startShift) - 1) : type(uint256).max;
            uint256 maskEnd = bucket == lastBucket ? _maskL(lastOffset + 1) : type(uint256).max;
            uint256 mask = maskStart & maskEnd;

            uint256 unsets = (~bitmap.map[bucket]) & mask;
            if (unsets != 0) {
                uint256 lowest = unsets & (~unsets + 1); // isolate LSB set
                uint256 pos = _msb(lowest); // msb of isolated LSB gives its index
                uint256 idx = (bucket << 8) | pos;
                if (idx >= upTo) return NOT_FOUND;
                return idx;
            }
        }

        return NOT_FOUND;
    }

    /* ------------------------------------------------------------------------
       Internal helpers
       ------------------------------------------------------------------------ */

    function _popcount(uint256 x) private pure returns (uint256 c) {
        // Kernighan's method: loops per set bit
        while (x != 0) {
            x &= x - 1;
            c++;
        }
    }

    function _msb(uint256 x) private pure returns (uint256 r) {
        // returns index of most-significant set bit (0-based). x must be > 0.
        require(x > 0, "msb(0)");
        if (x >> 128 > 0) { x >>= 128; r += 128; }
        if (x >> 64 > 0)  { x >>= 64;  r += 64; }
        if (x >> 32 > 0)  { x >>= 32;  r += 32; }
        if (x >> 16 > 0)  { x >>= 16;  r += 16; }
        if (x >> 8 > 0)   { x >>= 8;   r += 8; }
        if (x >> 4 > 0)   { x >>= 4;   r += 4; }
        if (x >> 2 > 0)   { x >>= 2;   r += 2; }
        if (x >> 1 > 0)   { r += 1; }
    }
}