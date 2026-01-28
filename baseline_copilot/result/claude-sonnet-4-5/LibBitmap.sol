// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for storage of packed booleans.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBitmap.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibBitmap.sol)
library LibBitmap {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when a bitmap scan does not find a result.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Defines a Bitmap structure that uses a mapping to store data.
     *
     * The structure contains a single field:
     * - `map`: A mapping from `uint256` keys to `uint256` values, used to store bitmap data.
     */
    struct Bitmap {
        mapping(uint256 => uint256) map;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         OPERATIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Checks if a specific bit in a bitmap is set.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to check.
     * @return isSet A boolean indicating whether the bit is set (1) or not (0).
     *
     * Steps:
     * 1. Calculate the byte and bit position within the bitmap for the given index.
     * 2. Extract the bit value from the calculated position.
     * 3. Use assembly to assign the bit value to the `isSet` variable, ensuring it is either 0 or 1.
     *
     * Note: The function is optimized to return a clean boolean value (0 or 1) for efficient reuse.
     */
    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {
        assembly {
            let bucket := shr(8, index)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let value := sload(keccak256(0x00, 0x40))
            isSet := and(1, shr(and(index, 0xff), value))
        }
    }

    /**
     * @notice Sets a specific bit in the bitmap to 1.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to set.
     *
     * Steps:
     * 1. Calculate the byte in the bitmap where the bit resides by shifting the index right by 8 bits.
     * 2. Calculate the position of the bit within the byte by masking the index with 0xff.
     * 3. Use bitwise OR to set the specific bit to 1 in the calculated byte.
     */
    function set(Bitmap storage bitmap, uint256 index) internal {
        assembly {
            let bucket := shr(8, index)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let slot := keccak256(0x00, 0x40)
            let value := sload(slot)
            sstore(slot, or(value, shl(and(index, 0xff), 1)))
        }
    }

    /**
     * @notice Unsets a specific bit in the bitmap at the given index.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to unset.
     *
     * Steps:
     * 1. Calculate the byte position in the bitmap by shifting the index right by 8 bits (`index >> 8`).
     * 2. Calculate the bit position within the byte by masking the index with `0xff` (`index & 0xff`).
     * 3. Use bitwise NOT (`~`) and AND (`&`) operations to unset the specific bit in the calculated byte.
     */
    function unset(Bitmap storage bitmap, uint256 index) internal {
        assembly {
            let bucket := shr(8, index)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let slot := keccak256(0x00, 0x40)
            let value := sload(slot)
            sstore(slot, and(value, not(shl(and(index, 0xff), 1))))
        }
    }

    /**
     * @notice Toggles the state of a specific bit in a bitmap storage and returns the new state.
     *
     * @dev This function uses inline assembly to efficiently manipulate the bitmap storage.
     * The function calculates the storage slot and bit position for the given index, toggles the bit,
     * and returns the new state of the bit.
     *
     * @param bitmap The bitmap storage reference where the bit is to be toggled.
     * @param index The index of the bit to toggle.
     * @return newIsSet The new state of the bit after toggling (1 if set, 0 if not set).
     *
     * Steps:
     * 1. Calculate the storage slot and bit position for the given index.
     * 2. Load the current value from the storage slot.
     * 3. Toggle the bit at the calculated position using XOR.
     * 4. Determine the new state of the bit by shifting and masking.
     * 5. Store the updated value back into the storage slot.
     * 6. Return the new state of the bit.
     */
    function toggle(Bitmap storage bitmap, uint256 index) internal returns (bool newIsSet) {
        assembly {
            let bucket := shr(8, index)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let slot := keccak256(0x00, 0x40)
            let value := sload(slot)
            let bitMask := shl(and(index, 0xff), 1)
            let newValue := xor(value, bitMask)
            sstore(slot, newValue)
            newIsSet := and(1, shr(and(index, 0xff), newValue))
        }
    }

    /**
     * @notice Sets or unsets a bit at a specific index in a bitmap storage.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param index The index of the bit to set or unset.
     * @param shouldSet A boolean indicating whether to set (true) or unset (false) the bit.
     *
     * Steps:
     * 1. Calculate the storage slot for the bitmap using the provided index.
     * 2. Load the current value from the calculated storage slot.
     * 3. Determine the bit position within the storage slot using the lower 8 bits of the index.
     * 4. Update the storage slot value by:
     *    - Clearing the bit at the calculated position using a bitwise AND operation.
     *    - Setting the bit to the desired value (1 if `shouldSet` is true, 0 otherwise) using a bitwise OR operation.
     * 5. Store the updated value back into the storage slot.
     *
     * @dev This function uses inline assembly for low-level storage manipulation.
     */
    function setTo(Bitmap storage bitmap, uint256 index, bool shouldSet) internal {
        assembly {
            let bucket := shr(8, index)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let slot := keccak256(0x00, 0x40)
            let value := sload(slot)
            let shift := and(index, 0xff)
            let bitMask := shl(shift, 1)
            let newValue := and(value, not(bitMask))
            newValue := or(newValue, shl(shift, iszero(iszero(shouldSet))))
            sstore(slot, newValue)
        }
    }

    /**
     * @notice Sets a batch of bits in a bitmap starting from a specific position.
     *
     * @param bitmap The storage reference to the bitmap where bits will be set.
     * @param start The starting position in the bitmap where the batch of bits will be set.
     * @param amount The number of bits to set starting from the `start` position.
     *
     * Steps:
     * 1. Calculate the maximum value (all bits set to 1) using `not(0)`.
     * 2. Determine the shift value based on the starting position (`start & 0xff`).
     * 3. Store the bitmap's storage slot and the starting bucket in memory.
     *
     * 4. If the batch of bits to set spans multiple buckets:
     *    a. Set the bits in the current bucket using bitwise operations.
     *    b. Calculate the range of buckets that need to be fully set (all bits to 1).
     *    c. Iterate through the buckets and set all bits to 1.
     *    d. Adjust the `amount` and `shift` values for the remaining bits in the last bucket.
     *
     * 5. If the batch of bits fits within a single bucket:
     *    a. Set the bits in the current bucket using bitwise operations, ensuring only the specified bits are set.
     *
     * Note: This function uses low-level assembly for efficient bit manipulation.
     */
    function setBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        assembly {
            let max := not(0)
            let shift := and(start, 0xff)
            mstore(0x20, bitmap.slot)
            let bucket := shr(8, start)
            mstore(0x00, bucket)
            let slot := keccak256(0x00, 0x40)
            
            if gt(add(amount, shift), 256) {
                let value := sload(slot)
                sstore(slot, or(value, shl(shift, max)))
                
                let lastBucket := shr(8, add(start, amount))
                amount := and(add(add(start, amount), 0xff), 0xff)
                shift := 0
                bucket := add(bucket, 1)
                
                for {} lt(bucket, lastBucket) {} {
                    mstore(0x00, bucket)
                    sstore(keccak256(0x00, 0x40), max)
                    bucket := add(bucket, 1)
                }
                
                mstore(0x00, bucket)
                slot := keccak256(0x00, 0x40)
            }
            
            let value := sload(slot)
            let mask := shl(shift, shr(sub(256, amount), max))
            sstore(slot, or(value, mask))
        }
    }

    /**
     * @notice Unsets a batch of bits in a bitmap starting from a specific position.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param start The starting bit position from which to unset bits.
     * @param amount The number of bits to unset.
     *
     * Steps:
     * 1. Calculate the shift value based on the starting position.
     * 2. Load the bitmap's storage slot into memory.
     * 3. If the range of bits to unset spans multiple storage slots:
     *    - Unset the bits in the current slot.
     *    - Calculate the range of affected storage slots.
     *    - Iterate through the affected slots and set them to 0.
     * 4. If the range of bits to unset is within a single storage slot:
     *    - Unset the bits in the current slot using a bitmask.
     *
     * @dev This function uses low-level assembly for efficient bit manipulation.
     */
    function unsetBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        assembly {
            let max := not(0)
            let shift := and(start, 0xff)
            mstore(0x20, bitmap.slot)
            let bucket := shr(8, start)
            mstore(0x00, bucket)
            let slot := keccak256(0x00, 0x40)
            
            if gt(add(amount, shift), 256) {
                let value := sload(slot)
                sstore(slot, and(value, not(shl(shift, max))))
                
                let lastBucket := shr(8, add(start, amount))
                amount := and(add(add(start, amount), 0xff), 0xff)
                shift := 0
                bucket := add(bucket, 1)
                
                for {} lt(bucket, lastBucket) {} {
                    mstore(0x00, bucket)
                    sstore(keccak256(0x00, 0x40), 0)
                    bucket := add(bucket, 1)
                }
                
                mstore(0x00, bucket)
                slot := keccak256(0x00, 0x40)
            }
            
            let value := sload(slot)
            let mask := shl(shift, shr(sub(256, amount), max))
            sstore(slot, and(value, not(mask)))
        }
    }

    /**
     * @notice Calculates the number of set bits (pop count) in a bitmap over a specified range.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param start The starting index from which to begin counting set bits.
     * @param amount The number of bits to consider for counting.
     * @return count The total number of set bits within the specified range.
     *
     * Steps:
     * 1. Calculate the bucket index by dividing the start index by 256 (shift right by 8).
     * 2. Calculate the shift amount within the bucket by taking the start index modulo 256.
     * 3. Check if the range (amount + shift) exceeds 256 bits.
     *    - If it does, calculate the pop count for the remaining bits in the current bucket.
     *    - Increment the bucket index and calculate the pop count for full buckets until the end of the range.
     *    - Adjust the amount and shift for the final bucket.
     * 4. Calculate the pop count for the remaining bits in the final bucket.
     * 5. Return the total count of set bits.
     *
     * Note: The function uses unchecked arithmetic for gas optimization.
     */
    function popCount(Bitmap storage bitmap, uint256 start, uint256 amount) internal view returns (uint256 count) {
        unchecked {
            uint256 bucket = start >> 8;
            uint256 shift = start & 0xff;
            
            if (amount + shift > 256) {
                count = _popCount(bitmap.map[bucket] >> shift);
                
                uint256 lastBucket = (start + amount) >> 8;
                amount = ((start + amount) & 0xff);
                
                for (++bucket; bucket < lastBucket; ++bucket) {
                    count += _popCount(bitmap.map[bucket]);
                }
                
                shift = 0;
            }
            
            count += _popCount((bitmap.map[bucket] >> shift) << (256 - amount));
        }
    }

    /**
     * @notice Finds the index of the last set bit in a bitmap up to a specified index.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param upTo The maximum index to search for the last set bit.
     * @return setBitIndex The index of the last set bit, or `NOT_FOUND` if no set bit is found.
     *
     * Steps:
     * 1. Initialize `setBitIndex` to `NOT_FOUND`.
     * 2. Calculate the bucket index by shifting `upTo` right by 8 bits.
     * 3. Use assembly to:
     *    - Load the bucket and bitmap slot into memory.
     *    - Calculate the offset within the bucket.
     *    - Extract the relevant bits from the bitmap.
     *    - If no bits are set in the current bucket, iterate backward through previous buckets until a set bit is found or the first bucket is reached.
     * 4. If a set bit is found, calculate its index by combining the bucket index and the position of the highest set bit within the bucket.
     * 5. Adjust the index if it exceeds `upTo` by setting it to `NOT_FOUND`.
     */
    function findLastSet(Bitmap storage bitmap, uint256 upTo) internal view returns (uint256 setBitIndex) {
        assembly {
            setBitIndex := not(0)
            let bucket := shr(8, upTo)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let slot := keccak256(0x00, 0x40)
            let value := sload(slot)
            let offset := and(upTo, 0xff)
            value := shl(sub(255, offset), value)
            
            for {} iszero(value) {} {
                if iszero(bucket) { break }
                bucket := sub(bucket, 1)
                mstore(0x00, bucket)
                value := sload(keccak256(0x00, 0x40))
            }
            
            if value {
                setBitIndex := or(shl(8, bucket), shr(1, add(offset, sub(255, shr(1, log2(value))))))
                if gt(setBitIndex, upTo) {
                    setBitIndex := not(0)
                }
            }
        }
    }

    /**
     * @notice Finds the first unset bit in a bitmap within a specified range.
     *
     * @param bitmap The storage reference to the bitmap.
     * @param begin The starting index to begin searching for an unset bit.
     * @param upTo The upper limit (exclusive) for the search range.
     * @return unsetBitIndex The index of the first unset bit found, or `NOT_FOUND` if no unset bit is found within the range.
     *
     * Steps:
     * 1. Initialize `unsetBitIndex` to `NOT_FOUND`.
     * 2. Calculate the starting bucket based on the `begin` index.
     * 3. Use assembly to efficiently search for the first unset bit:
     *    - Load the bitmap data for the current bucket.
     *    - Check for unset bits in the current bucket.
     *    - If no unset bits are found, iterate through subsequent buckets until an unset bit is found or the range limit is reached.
     *    - Adjust the search for the last bucket if necessary.
     * 4. If an unset bit is found, calculate its index and ensure it falls within the specified range.
     * 5. Return the index of the first unset bit or `NOT_FOUND` if no unset bit is found.
     */
    function findFirstUnset(Bitmap storage bitmap, uint256 begin, uint256 upTo) internal view returns (uint256 unsetBitIndex) {
        assembly {
            unsetBitIndex := not(0)
            if lt(begin, upTo) {
                let bucket := shr(8, begin)
                let lastBucket := shr(8, upTo)
                mstore(0x00, bucket)
                mstore(0x20, bitmap.slot)
                let slot := keccak256(0x00, 0x40)
                let value := sload(slot)
                let offset := and(begin, 0xff)
                value := shr(offset, shl(offset, value))
                
                for {} and(eq(value, not(0)), lt(bucket, lastBucket)) {} {
                    bucket := add(bucket, 1)
                    mstore(0x00, bucket)
                    value := sload(keccak256(0x00, 0x40))
                    offset := 0
                }
                
                if eq(bucket, lastBucket) {
                    let lastOffset := and(upTo, 0xff)
                    if iszero(lastOffset) {
                        value := not(0)
                    }
                    if lastOffset {
                        value := or(value, shl(lastOffset, not(0)))
                    }
                }
                
                if iszero(eq(value, not(0))) {
                    unsetBitIndex := or(shl(8, bucket), shr(1, sub(255, shr(1, log2(not(value))))))
                    if iszero(lt(unsetBitIndex, upTo)) {
                        unsetBitIndex := not(0)
                    }
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the population count (number of set bits) in `x`.
    function _popCount(uint256 x) private pure returns (uint256 count) {
        assembly {
            x := sub(x, and(shr(1, x), 0x5555555555555555555555555555555555555555555555555555555555555555))
            x := add(and(x, 0x3333333333333333333333333333333333333333333333333333333333333333), and(shr(2, x), 0x3333333333333333333333333333333333333333333333333333333333333333))
            x := and(add(x, shr(4, x)), 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f)
            count := shr(248, mul(x, 0x0101010101010101010101010101010101010101010101010101010101010101))
        }
    }
}