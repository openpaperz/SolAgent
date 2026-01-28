// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Bitmap library operating on packed 256-bit buckets (1 bucket = 256 bits).
library LibBitmap {
    /// @notice Defines a Bitmap structure that uses a mapping to store data.
    ///
    /// The structure contains a single field:
    /// - `map`: A mapping from `uint256` keys to `uint256` values, used to store bitmap data.
    struct Bitmap {
        mapping(uint256 => uint256) map;
    }

    /// @notice Sentinel value used when no bit is found.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /// @notice Checks if a specific bit in a bitmap is set.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param index The index of the bit to check.
    /// @return isSet A boolean indicating whether the bit is set (1) or not (0).
    ///
    /// Steps:
    /// 1. Calculate the byte and bit position within the bitmap for the given index.
    /// 2. Extract the bit value from the calculated position.
    /// 3. Use assembly to assign the bit value to the `isSet` variable, ensuring it is either 0 or 1.
    ///
    /// Note: The function is optimized to return a clean boolean value (0 or 1) for efficient reuse.
    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {
        uint256 bucket = bitmap.map[index >> 8];
        uint256 mask = 1 << (index & 0xff);
        assembly {
            isSet := and(gt(and(bucket, mask), 0), 1)
        }
    }

    /// @notice Sets a specific bit in the bitmap to 1.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param index The index of the bit to set.
    ///
    /// Steps:
    /// 1. Calculate the byte in the bitmap where the bit resides by shifting the index right by 8 bits.
    /// 2. Calculate the position of the bit within the byte by masking the index with 0xff.
    /// 3. Use bitwise OR to set the specific bit to 1 in the calculated byte.
    function set(Bitmap storage bitmap, uint256 index) internal {
        uint256 bucketIndex = index >> 8;
        uint256 bitPos = index & 0xff;
        bitmap.map[bucketIndex] |= (uint256(1) << bitPos);
    }

    /// @notice Unsets a specific bit in the bitmap at the given index.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param index The index of the bit to unset.
    ///
    /// Steps:
    /// 1. Calculate the byte position in the bitmap by shifting the index right by 8 bits (`index >> 8`).
    /// 2. Calculate the bit position within the byte by masking the index with `0xff` (`index & 0xff`).
    /// 3. Use bitwise NOT (`~`) and AND (`&`) operations to unset the specific bit in the calculated byte.
    function unset(Bitmap storage bitmap, uint256 index) internal {
        uint256 bucketIndex = index >> 8;
        uint256 bitPos = index & 0xff;
        bitmap.map[bucketIndex] &= ~(uint256(1) << bitPos);
    }

    /// @notice Toggles the state of a specific bit in a bitmap storage and returns the new state.
    ///
    /// @dev This function uses inline assembly to efficiently manipulate the bitmap storage.
    /// The function calculates the storage slot and bit position for the given index, toggles the bit,
    /// and returns the new state of the bit.
    ///
    /// @param bitmap The bitmap storage reference where the bit is to be toggled.
    /// @param index The index of the bit to toggle.
    /// @return newIsSet The new state of the bit after toggling (1 if set, 0 if not set).
    ///
    /// Steps:
    /// 1. Calculate the storage slot and bit position for the given index.
    /// 2. Load the current value from the storage slot.
    /// 3. Toggle the bit at the calculated position using XOR.
    /// 4. Determine the new state of the bit by shifting and masking.
    /// 5. Store the updated value back into the storage slot.
    /// 6. Return the new state of the bit.
    function toggle(Bitmap storage bitmap, uint256 index) internal returns (bool newIsSet) {
        assembly {
            // Compute the base slot of the mapping.
            mstore(0x00, bitmap.slot)
            mstore(0x20, shr(8, index))
            let bucketSlot := keccak256(0x00, 0x40)

            // Load bucket and compute mask.
            let bucket := sload(bucketSlot)
            let mask := shl(and(index, 0xff), 1)

            // Toggle.
            bucket := xor(bucket, mask)
            sstore(bucketSlot, bucket)

            // Extract new bit value and normalize to 0 / 1.
            newIsSet := and(gt(and(bucket, mask), 0), 1)
        }
    }

    /// @notice Sets or unsets a bit at a specific index in a bitmap storage.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param index The index of the bit to set or unset.
    /// @param shouldSet A boolean indicating whether to set (true) or unset (false) the bit.
    ///
    /// Steps:
    /// 1. Calculate the storage slot for the bitmap using the provided index.
    /// 2. Load the current value from the calculated storage slot.
    /// 3. Determine the bit position within the storage slot using the lower 8 bits of the index.
    /// 4. Update the storage slot value by:
    ///    - Clearing the bit at the calculated position using a bitwise AND operation.
    ///    - Setting the bit to the desired value (1 if `shouldSet` is true, 0 otherwise) using a bitwise OR operation.
    /// 5. Store the updated value back into the storage slot.
    ///
    /// @dev This function uses inline assembly for low-level storage manipulation.
    function setTo(Bitmap storage bitmap, uint256 index, bool shouldSet) internal {
        assembly {
            // bucket index = index >> 8
            mstore(0x00, bitmap.slot)
            mstore(0x20, shr(8, index))
            let bucketSlot := keccak256(0x00, 0x40)

            let bucket := sload(bucketSlot)
            let bitPos := and(index, 0xff)
            let mask := shl(bitPos, 1)

            // Clear target bit.
            bucket := and(bucket, not(mask))
            // Conditionally set.
            if shouldSet { bucket := or(bucket, mask) }

            sstore(bucketSlot, bucket)
        }
    }

    /// @notice Sets a batch of bits in a bitmap starting from a specific position.
    ///
    /// @param bitmap The storage reference to the bitmap where bits will be set.
    /// @param start The starting position in the bitmap where the batch of bits will be set.
    /// @param amount The number of bits to set starting from the `start` position.
    ///
    /// Steps:
    /// 1. Calculate the maximum value (all bits set to 1) using `not(0)`.
    /// 2. Determine the shift value based on the starting position (`start & 0xff`).
    /// 3. Store the bitmap's storage slot and the starting bucket in memory.
    ///
    /// 4. If the batch of bits to set spans multiple buckets:
    ///    a. Set the bits in the current bucket using bitwise operations.
    ///    b. Calculate the range of buckets that need to be fully set (all bits to 1).
    ///    c. Iterate through the buckets and set all bits to 1.
    ///    d. Adjust the `amount` and `shift` values for the remaining bits in the last bucket.
    ///
    /// 5. If the batch of bits fits within a single bucket:
    ///    a. Set the bits in the current bucket using bitwise operations, ensuring only the specified bits are set.
    ///
    /// Note: This function uses low-level assembly for efficient bit manipulation.
    function setBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        if (amount == 0) return;
        assembly {
            let allOnes := not(0)
            let shift := and(start, 0xff)
            let bucketIndex := shr(8, start)

            // Prepare base for mapping slot.
            mstore(0x00, bitmap.slot)
            mstore(0x20, bucketIndex)
            let bucketSlot := keccak256(0x00, 0x40)

            // Current bucket mask.
            let remaining := add(shift, amount)
            let bucket := sload(bucketSlot)

            if lt(remaining, 0x100) {
                // Entire range fits into this bucket.
                // mask = ((1 << amount) - 1) << shift
                let mask := shl(shift, sub(shl(amount, 1), 1))
                bucket := or(bucket, mask)
                sstore(bucketSlot, bucket)
            }
            if iszero(lt(remaining, 0x100)) {
                // Fill tail of current bucket.
                let maskTail := shl(shift, allOnes)
                bucket := or(bucket, maskTail)
                sstore(bucketSlot, bucket)

                // Move to next bucket.
                amount := sub(amount, sub(0x100, shift))
                bucketIndex := add(bucketIndex, 1)
                mstore(0x20, bucketIndex)
                bucketSlot := keccak256(0x00, 0x40)

                // Fill full buckets.
                for { } gt(amount, 0x100) { } {
                    sstore(bucketSlot, allOnes)
                    amount := sub(amount, 0x100)
                    bucketIndex := add(bucketIndex, 1)
                    mstore(0x20, bucketIndex)
                    bucketSlot := keccak256(0x00, 0x40)
                }

                // Last partial bucket.
                if gt(amount, 0) {
                    bucket := sload(bucketSlot)
                    let lastMask := sub(shl(amount, 1), 1)
                    bucket := or(bucket, lastMask)
                    sstore(bucketSlot, bucket)
                }
            }
        }
    }

    /// @notice Unsets a batch of bits in a bitmap starting from a specific position.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param start The starting bit position from which to unset bits.
    /// @param amount The number of bits to unset.
    ///
    /// Steps:
    /// 1. Calculate the shift value based on the starting position.
    /// 2. Load the bitmap's storage slot into memory.
    /// 3. If the range of bits to unset spans multiple storage slots:
    ///    - Unset the bits in the current slot.
    ///    - Calculate the range of affected storage slots.
    ///    - Iterate through the affected slots and set them to 0.
    /// 4. If the range of bits to unset is within a single storage slot:
    ///    - Unset the bits in the current slot using a bitmask.
    ///
    /// @dev This function uses low-level assembly for efficient bit manipulation.
    function unsetBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        if (amount == 0) return;
        assembly {
            let shift := and(start, 0xff)
            let bucketIndex := shr(8, start)

            mstore(0x00, bitmap.slot)
            mstore(0x20, bucketIndex)
            let bucketSlot := keccak256(0x00, 0x40)

            let remaining := add(shift, amount)
            let bucket := sload(bucketSlot)

            if lt(remaining, 0x100) {
                // mask for bits to clear: ((1 << amount) - 1) << shift
                let mask := shl(shift, sub(shl(amount, 1), 1))
                bucket := and(bucket, not(mask))
                sstore(bucketSlot, bucket)
            }
            if iszero(lt(remaining, 0x100)) {
                // Clear tail of current bucket.
                let tailMask := shl(shift, not(0))
                bucket := and(bucket, not(tailMask))
                sstore(bucketSlot, bucket)

                // Move to next bucket.
                amount := sub(amount, sub(0x100, shift))
                bucketIndex := add(bucketIndex, 1)
                mstore(0x20, bucketIndex)
                bucketSlot := keccak256(0x00, 0x40)

                // Clear full buckets.
                for { } gt(amount, 0x100) { } {
                    sstore(bucketSlot, 0)
                    amount := sub(amount, 0x100)
                    bucketIndex := add(bucketIndex, 1)
                    mstore(0x20, bucketIndex)
                    bucketSlot := keccak256(0x00, 0x40)
                }

                // Last partial bucket.
                if gt(amount, 0) {
                    bucket := sload(bucketSlot)
                    let lastMask := sub(shl(amount, 1), 1)
                    bucket := and(bucket, not(lastMask))
                    sstore(bucketSlot, bucket)
                }
            }
        }
    }

    /// @notice Calculates the number of set bits (pop count) in a bitmap over a specified range.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param start The starting index from which to begin counting set bits.
    /// @param amount The number of bits to consider for counting.
    /// @return count The total number of set bits within the specified range.
    ///
    /// Steps:
    /// 1. Calculate the bucket index by dividing the start index by 256 (shift right by 8).
    /// 2. Calculate the shift amount within the bucket by taking the start index modulo 256.
    /// 3. Check if the range (amount + shift) exceeds 256 bits.
    ///    - If it does, calculate the pop count for the remaining bits in the current bucket.
    ///    - Increment the bucket index and calculate the pop count for full buckets until the end of the range.
    ///    - Adjust the amount and shift for the final bucket.
    /// 4. Calculate the pop count for the remaining bits in the final bucket.
    /// 5. Return the total count of set bits.
    ///
    /// Note: The function uses unchecked arithmetic for gas optimization.
    function popCount(Bitmap storage bitmap, uint256 start, uint256 amount) internal view returns (uint256 count) {
        if (amount == 0) return 0;

        uint256 bucketIndex = start >> 8;
        uint256 shift = start & 0xff;

        while (amount != 0) {
            uint256 bucket = bitmap.map[bucketIndex];

            uint256 bitsInBucket = 256 - shift;
            if (amount < bitsInBucket) {
                bitsInBucket = amount;
            }

            // Mask the relevant bits in this bucket.
            uint256 mask = ((uint256(1) << bitsInBucket) - 1) << shift;
            uint256 bits = bucket & mask;

            // Count bits using builtin popcount-like algorithm.
            unchecked {
                bits = bits - ((bits >> 1) & 0x5555555555555555555555555555555555555555555555555555555555555555);
                bits = (bits & 0x3333333333333333333333333333333333333333333333333333333333333333) + ((bits >> 2) & 0x3333333333333333333333333333333333333333333333333333333333333333);
                bits = (bits + (bits >> 4)) & 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
                bits = bits * 0x0101010101010101010101010101010101010101010101010101010101010101;
                count += bits >> 248;
            }

            unchecked {
                amount -= bitsInBucket;
                bucketIndex++;
                shift = 0;
            }
        }
    }

    /// @notice Finds the index of the last set bit in a bitmap up to a specified index.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param upTo The maximum index to search for the last set bit.
    /// @return setBitIndex The index of the last set bit, or `NOT_FOUND` if no set bit is found.
    ///
    /// Steps:
    /// 1. Initialize `setBitIndex` to `NOT_FOUND`.
    /// 2. Calculate the bucket index by shifting `upTo` right by 8 bits.
    /// 3. Use assembly to:
    ///    - Load the bucket and bitmap slot into memory.
    ///    - Calculate the offset within the bucket.
    ///    - Extract the relevant bits from the bitmap.
    ///    - If no bits are set in the current bucket, iterate backward through previous buckets until a set bit is found or the first bucket is reached.
    /// 4. If a set bit is found, calculate its index by combining the bucket index and the position of the highest set bit within the bucket.
    /// 5. Adjust the index if it exceeds `upTo` by setting it to `NOT_FOUND`.
    function findLastSet(Bitmap storage bitmap, uint256 upTo) internal view returns (uint256 setBitIndex) {
        setBitIndex = NOT_FOUND;
        uint256 bucketIndex = upTo >> 8;
        uint256 offset = upTo & 0xff;

        assembly {
            // Base for mapping slot
            mstore(0x00, bitmap.slot)

            for { } lt(setBitIndex, 1) { } {
                mstore(0x20, bucketIndex)
                let bucketSlot := keccak256(0x00, 0x40)
                let bucket := sload(bucketSlot)

                // Mask out bits above offset.
                if lt(offset, 0xff) {
                    let mask := sub(shl(add(offset, 1), 1), 1)
                    bucket := and(bucket, mask)
                }

                if gt(bucket, 0) {
                    // Find highest set bit using clz.
                    // Solidity/Yul doesn't have clz directly, but we can scan down by powers of two.
                    let pos := 0
                    let tmp := bucket
                    if gt(shr(128, tmp), 0) { tmp := shr(128, tmp) pos := add(pos, 128) }
                    if gt(shr(64, tmp), 0) { tmp := shr(64, tmp) pos := add(pos, 64) }
                    if gt(shr(32, tmp), 0) { tmp := shr(32, tmp) pos := add(pos, 32) }
                    if gt(shr(16, tmp), 0) { tmp := shr(16, tmp) pos := add(pos, 16) }
                    if gt(shr(8, tmp), 0) { tmp := shr(8, tmp) pos := add(pos, 8) }
                    if gt(shr(4, tmp), 0) { tmp := shr(4, tmp) pos := add(pos, 4) }
                    if gt(shr(2, tmp), 0) { tmp := shr(2, tmp) pos := add(pos, 2) }
                    if gt(shr(1, tmp), 0) { tmp := shr(1, tmp) pos := add(pos, 1) }

                    // Combine bucket index and position.
                    setBitIndex := add(shl(8, bucketIndex), and(pos, 0xff))
                    break
                }

                if eq(bucketIndex, 0) { break }
                bucketIndex := sub(bucketIndex, 1)
                offset := 0xff
            }
        }

        if (setBitIndex > upTo) {
            setBitIndex = NOT_FOUND;
        }
    }

    /// @notice Finds the first unset bit in a bitmap within a specified range.
    ///
    /// @param bitmap The storage reference to the bitmap.
    /// @param begin The starting index to begin searching for an unset bit.
    /// @param upTo The upper limit (exclusive) for the search range.
    /// @return unsetBitIndex The index of the first unset bit found, or `NOT_FOUND` if no unset bit is found within the range.
    ///
    /// Steps:
    /// 1. Initialize `unsetBitIndex` to `NOT_FOUND`.
    /// 2. Calculate the starting bucket based on the `begin` index.
    /// 3. Use assembly to efficiently search for the first unset bit:
    ///    - Load the bitmap data for the current bucket.
    ///    - Check for unset bits in the current bucket.
    ///    - If no unset bits are found, iterate through subsequent buckets until an unset bit is found or the range limit is reached.
    ///    - Adjust the search for the last bucket if necessary.
    /// 4. If an unset bit is found, calculate its index and ensure it falls within the specified range.
    /// 5. Return the index of the first unset bit or `NOT_FOUND` if no unset bit is found.
    function findFirstUnset(Bitmap storage bitmap, uint256 begin, uint256 upTo) internal view returns (uint256 unsetBitIndex) {
        unsetBitIndex = NOT_FOUND;
        if (begin >= upTo) return unsetBitIndex;

        uint256 bucketIndex = begin >> 8;
        uint256 offset = begin & 0xff;
        uint256 endBucket = (upTo - 1) >> 8;

        assembly {
            mstore(0x00, bitmap.slot)

            for { } lt(bucketIndex, add(endBucket, 1)) { } {
                mstore(0x20, bucketIndex)
                let bucketSlot := keccak256(0x00, 0x40)
                let bucket := sload(bucketSlot)

                // Invert bits to look for zeros as ones.
                let inv := not(bucket)

                // Mask out bits before offset.
                if gt(offset, 0) {
                    let maskBefore := sub(shl(offset, 1), 1)
                    inv := and(inv, not(maskBefore))
                }

                // If this is the last bucket, mask out bits >= upTo.
                if eq(bucketIndex, endBucket) {
                    let lastOffset := and(sub(upTo, 1), 0xff)
                    if lt(lastOffset, 0xff) {
                        let maskAfter := not(sub(shl(add(lastOffset, 1), 1), 1))
                        inv := and(inv, not(maskAfter))
                    }
                }

                if gt(inv, 0) {
                    // Find lowest set bit in inv (first unset in original).
                    let pos := 0
                    let tmp := inv
                    if eq(and(tmp, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000), 0) { tmp := shl(128, tmp) pos := add(pos, 128) }
                    if eq(and(tmp, 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000ffffffffffffffffffffffffffffffff00000000000000000000000000000000), 0) { tmp := shl(64, tmp) pos := add(pos, 64) }
                    if eq(and(tmp, 0xffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000), 0) { tmp := shl(32, tmp) pos := add(pos, 32) }
                    if eq(and(tmp, 0xffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000), 0) { tmp := shl(16, tmp) pos := add(pos, 16) }
                    if eq(and(tmp, 0xff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00), 0) { tmp := shl(8, tmp) pos := add(pos, 8) }
                    if eq(and(tmp, 0xf0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0), 0) { tmp := shl(4, tmp) pos := add(pos, 4) }
                    if eq(and(tmp, 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc), 0) { tmp := shl(2, tmp) pos := add(pos, 2) }
                    if eq(and(tmp, 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa), 0) { pos := add(pos, 1) }

                    unsetBitIndex := add(shl(8, bucketIndex), and(pos, 0xff))
                    break
                }

                bucketIndex := add(bucketIndex, 1)
                offset := 0
            }
        }

        if (unsetBitIndex >= upTo) {
            unsetBitIndex = NOT_FOUND;
        }
    }
}