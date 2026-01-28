// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibBit {
    /**
     * @notice Computes the floor log2 of a given unsigned integer `x` using bitwise operations.
     *
     * @dev This function uses inline assembly to efficiently calculate the floor of the base-2 logarithm of `x`.
     * The result is the largest integer `r` such that `2^r <= x`.
     *
     * @param x The unsigned integer for which to compute the floor log2.
     * @return r The floor log2 of `x`.
     *
     * Steps:
     * 1. Use bitwise operations to determine the highest set bit in `x`.
     * 2. Combine the results of multiple shifts and comparisons to narrow down the value of `r`.
     * 3. Use a lookup table (encoded in a byte sequence) to finalize the result.
     *
     * Note: This function is marked as `internal pure`, meaning it can only be called internally and does not modify the state.
     */
    function fls(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            r := or(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0x0706060506020504060203020504030106050205030304010505030400000000))
        }
    }

    /**
     * @notice Counts the leading zeros in a 256-bit unsigned integer.
     *
     * @param x The 256-bit unsigned integer to count leading zeros for.
     * @return r The number of leading zeros in `x`.
     *
     * Steps:
     * 1. Use assembly to perform bitwise operations to count leading zeros.
     * 2. Shift and compare bits to determine the number of leading zeros.
     * 3. Return the count of leading zeros.
     *
     * Note: This function uses low-level assembly for optimization and is memory-safe.
     */
    function clz(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            r := add(xor(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0xf8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fdfafdfcfdfdfaf8fdfdfdfafffffc)), 0xff), iszero(x))
        }
    }

    /**
     * @notice Finds the position of the least significant bit set to 1 in a 256-bit unsigned integer.
     * @dev This function uses assembly for optimized performance and employs a De Bruijn sequence-based lookup.
     * 
     * @param x The input 256-bit unsigned integer.
     * @return r The position of the least significant bit set to 1 (0-indexed).
     * 
     * Steps:
     * 1. Isolate the least significant bit set to 1 in `x` using bitwise operations.
     * 2. Use a De Bruijn-like lookup for the upper 3 bits of the result.
     * 3. Use a De Bruijn lookup for the lower 5 bits of the result.
     * 4. Combine the results to get the final position of the least significant bit.
     */
    function ffs(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Isolate the least significant bit.
            x := and(x, add(not(x), 1))
            // For the upper 3 bits of the result, use a De Bruijn-like lookup.
            // forgefmt: disable-next-item
            r := shl(5, shr(252, shl(shr(250, mul(x,
                0xb6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6d)),
                0x7171717171717171716f6f6f6f6e6e6e6e6d6d6d6d6c6c6c6c6b6b6b6b6b6b6b)))
            // For the lower 5 bits of the result, use a De Bruijn lookup.
            // forgefmt: disable-next-item
            r := or(r, byte(and(div(0xd76453e0, shr(r, x)), 0x1f),
                0x001f0d1e100c1d070f090b19131c1706010e11080a1a141802121b1503160405))
        }
    }

    /**
     * @notice Calculates the number of set bits (population count) in a 256-bit unsigned integer.
     *
     * @param x The input 256-bit unsigned integer for which the population count is calculated.
     * @return c The number of set bits in the input integer.
     *
     * Steps:
     * 1. Initialize `max` as the maximum value for a 256-bit unsigned integer (all bits set to 1).
     * 2. Check if `x` is equal to `max`. If true, set `isMax` to 1, otherwise 0.
     * 3. Reduce `x` by removing every second bit using bitwise operations.
     * 4. Further reduce `x` by combining bits in groups of 2 and 4.
     * 5. Calculate the final population count by combining the results of the previous steps.
     * 6. Return the population count, adjusting for the case where `x` was initially `max`.
     *
     * @dev This function uses low-level assembly for optimized performance.
     */
    function popCount(uint256 x) internal pure returns (uint256 c) {
        /// @solidity memory-safe-assembly
        assembly {
            let max := not(0)
            let isMax := eq(x, max)
            x := sub(x, and(shr(1, x), div(max, 3)))
            x := add(and(x, div(max, 5)), and(shr(2, x), div(max, 5)))
            x := and(add(x, shr(4, x)), div(max, 17))
            c := or(shl(8, isMax), shr(248, mul(x, div(max, 255))))
        }
    }

    /**
     * @notice Checks if a given number is a power of two.
     *
     * @param x The number to check.
     * @return result A boolean indicating whether the number is a power of two.
     *
     * Steps:
     * 1. Use inline assembly to perform the check.
     * 2. The assembly logic checks if `x` is non-zero and if `x & (x - 1)` is zero.
     * 3. If both conditions are true, the number is a power of two.
     *
     * Note: This function uses low-level assembly for optimization.
     */
    function isPo2(uint256 x) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := iszero(and(x, sub(x, 1)))
        }
    }

    /**
     * @notice Reverses the bits of a given 256-bit unsigned integer.
     *
     * @param x The input 256-bit unsigned integer whose bits are to be reversed.
     * @return r The resulting 256-bit unsigned integer with reversed bits.
     *
     * Steps:
     * 1. Define a mask `m0` with alternating 4-bit patterns.
     * 2. Create mask `m1` by XORing `m0` with a left-shifted version of itself by 2 bits.
     * 3. Create mask `m2` by XORing `m1` with a left-shifted version of itself by 1 bit.
     * 4. Reverse the bytes of the input `x` using the `reverseBytes` function.
     * 5. Use masks `m2`, `m1`, and `m0` to reverse the bits of the input in stages:
     *    - First, reverse pairs of bits using `m2`.
     *    - Then, reverse groups of 2 bits using `m1`.
     *    - Finally, reverse groups of 4 bits using `m0`.
     * 6. Return the final result `r` with all bits reversed.
     */
    function reverseBits(uint256 x) internal pure returns (uint256 r) {
        uint256 m0 = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
        uint256 m1 = m0 ^ (m0 << 2);
        uint256 m2 = m1 ^ (m1 << 1);
        r = reverseBytes(x);
        r = ((r & m2) >> 1) | ((r & (m2 << 1)) >> 1);
        r = ((r & m1) >> 2) | ((r & (m1 << 2)) >> 2);
        r = ((r & m0) >> 4) | ((r & (m0 << 4)) >> 4);
    }

    /**
     * @notice Reverses the byte order of a 256-bit unsigned integer.
     *
     * @param x The input 256-bit unsigned integer whose byte order is to be reversed.
     * @return r The resulting 256-bit unsigned integer with reversed byte order.
     *
     * Steps:
     * 1. Compute masks dynamically to reduce bytecode size.
     * 2. Create a mask `m0` based on the input value `x`.
     * 3. Generate subsequent masks `m1`, `m2`, and `m3` by shifting and XORing the previous masks.
     * 4. Reverse the byte order of `x` by applying the masks and shifting operations.
     * 5. Return the final reversed value `r`.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function reverseBytes(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            // Computing masks on the fly reduces bytecode size by about 500 bytes.
            uint256 m0 = 0x100000000000000000000000000000001 * (~toUint(x == 0) >> 192);
            uint256 m1 = m0 ^ (m0 << 32);
            uint256 m2 = m1 ^ (m1 << 16);
            uint256 m3 = m2 ^ (m2 << 8);
            r = ((x & m3) << 8) | ((x & (m3 << 8)) >> 8);
            r = ((r & m2) << 16) | ((r & (m2 << 16)) >> 16);
            r = ((r & m1) << 32) | ((r & (m1 << 32)) >> 32);
            r = ((r & m0) << 64) | ((r & (m0 << 64)) >> 64);
            r = (r << 128) | (r >> 128);
        }
    }

    /**
     * @notice Performs a bitwise AND operation on two boolean values using inline assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the bitwise AND operation between `x` and `y`.
     *
     * Steps:
     * 1. Use inline assembly to perform the bitwise AND operation on `x` and `y`.
     * 2. Store the result in `z` and return it.
     *
     * @dev This function is marked as `internal pure` and uses `memory-safe-assembly` to ensure safety.
     */
    function rawAnd(bool x, bool y) internal pure returns (bool z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := and(x, y)
        }
    }

    /**
     * @notice Performs a logical AND operation on two boolean values using inline assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the logical AND operation between `x` and `y`.
     *
     * Steps:
     * 1. Use inline assembly to perform the AND operation.
     * 2. Convert `x` and `y` to non-zero values using `iszero(iszero(...))`.
     * 3. Perform the AND operation on the converted values.
     * 4. Return the result as a boolean.
     */
    function and(bool x, bool y) internal pure returns (bool z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := and(iszero(iszero(x)), iszero(iszero(y)))
        }
    }

    /**
     * @notice Performs a logical OR operation on two boolean values using low-level assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the logical OR operation between `x` and `y`.
     *
     * Steps:
     * 1. Use inline assembly to perform the OR operation on the two boolean values.
     * 2. Return the result of the OR operation.
     *
     * @dev This function uses `assembly` for gas optimization and memory safety.
     */
    function rawOr(bool x, bool y) internal pure returns (bool z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(x, y)
        }
    }

    /**
     * @notice Performs a logical OR operation on two boolean values using inline assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the logical OR operation between `x` and `y`.
     *
     * Steps:
     * 1. Use inline assembly to perform the logical OR operation.
     * 2. Convert `x` and `y` to non-zero values using `iszero(iszero(...))`.
     * 3. Perform the OR operation on the converted values.
     * 4. Return the result as a boolean.
     */
    function or(bool x, bool y) internal pure returns (bool z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(iszero(iszero(x)), iszero(iszero(y)))
        }
    }

    /**
     * @notice Converts a boolean value to a uint256 representation.
     *
     * @dev This function uses inline assembly to convert a boolean value (`true` or `false`) 
     *      into a uint256 value. In Solidity, `true` is represented as `1` and `false` as `0`.
     *
     * @param b The boolean value to convert.
     * @return z The uint256 representation of the boolean value (1 for `true`, 0 for `false`).
     *
     * Steps:
     * 1. Use inline assembly to directly assign the boolean value to the uint256 variable `z`.
     */
    function rawToUint(bool b) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := b
        }
    }

    /**
     * @notice Converts a boolean value to a uint256 representation.
     *
     * @param b The boolean value to convert.
     * @return z The uint256 representation of the boolean value (1 for true, 0 for false).
     *
     * Steps:
     * 1. Use inline assembly to check if the boolean value is true or false.
     * 2. If the boolean is true, return 1; otherwise, return 0.
     */
    function toUint(bool b) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := iszero(iszero(b))
        }
    }
}
