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
     */
    function fls(uint256 x) internal pure returns (uint256 r) {
        assembly ("memory-safe") {
            if x {
                let v := x
                // Propagate highest set bit to all lower bits.
                v := or(v, shr(1, v))
                v := or(v, shr(2, v))
                v := or(v, shr(4, v))
                v := or(v, shr(8, v))
                v := or(v, shr(16, v))
                v := or(v, shr(32, v))
                v := or(v, shr(64, v))
                v := or(v, shr(128, v))
                // Multiply by De Bruijn constant and take top 5 bits as index.
                let index := shr(251, mul(v, 0x07c4acdd)) // 256 - 5 = 251
                // 32‑entry De Bruijn table packed in 32 bytes.
                // Values are positions of the highest set bit for all possible 5‑bit indices.
                // This specific table works together with the constant above.
                let table :=
                    0x000103020604070a05080c0b0f09110e10131415121a16181d1c1f1e171b191
                // Shift table so that desired 8‑bit value is at lowest byte, then mask.
                r := and(shr(mul(index, 8), table), 0xff)
            }
        }
    }

    /**
     * @notice Counts the leading zeros in a 256-bit unsigned integer.
     *
     * @param x The 256-bit unsigned integer to count leading zeros for.
     * @return r The number of leading zeros in `x`.
     */
    function clz(uint256 x) internal pure returns (uint256 r) {
        if (x == 0) return 256;
        unchecked {
            r = 255 - fls(x);
        }
    }

    /**
     * @notice Finds the position of the least significant bit set to 1 in a 256-bit unsigned integer.
     * @dev This function uses assembly for optimized performance and employs a De Bruijn sequence-based lookup.
     * 
     * @param x The input 256-bit unsigned integer.
     * @return r The position of the least significant bit set to 1 (0-indexed).
     */
    function ffs(uint256 x) internal pure returns (uint256 r) {
        assembly ("memory-safe") {
            if iszero(x) {
                r := 256
            }
            if x {
                // Isolate least significant 1 bit.
                let lsb := and(x, sub(0, x))
                // Use De Bruijn sequence for 256‑bit to get index of that bit.
                // Constant chosen so that each bit position maps to unique top 8 bits.
                let idx := shr(248, mul(lsb, 0x9fbfe4a1f0c9c5ab32b39a2fc9f3c7d2c4b))
                // Packed 32‑entry table with offsets for groups of 8 bits.
                let table :=
                    0x000807010e02150a031c0b041305051a0c06110d0718090f1017161d1b1412
                r := and(shr(mul(idx, 8), table), 0xff)
            }
        }
    }

    /**
     * @notice Calculates the number of set bits (population count) in a 256-bit unsigned integer.
     *
     * @param x The input 256-bit unsigned integer for which the population count is calculated.
     * @return c The number of set bits in the input integer.
     */
    function popCount(uint256 x) internal pure returns (uint256 c) {
        unchecked {
            assembly ("memory-safe") {
                let max := not(0)
                let isMax := eq(x, max)

                // Standard SWAR (SIMD within a register) population count.
                // Remove every 2nd bit.
                x := sub(x, and(shr(1, x), 0x5555555555555555555555555555555555555555555555555555555555555555))
                // Sum bits in 2‑bit groups.
                x :=
                    and(x, 0x3333333333333333333333333333333333333333333333333333333333333333)
                x :=
                    add(
                        x,
                        and(
                            shr(2, x),
                            0x3333333333333333333333333333333333333333333333333333333333333333
                        )
                    )
                // Sum 4‑bit groups.
                x :=
                    and(
                        add(x, shr(4, x)),
                        0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f
                    )
                // Multiply by magic and shift to get total.
                x := shr(
                    248,
                    mul(
                        x,
                        0x0101010101010101010101010101010101010101010101010101010101010101
                    )
                )
                c := add(x, isMax)
            }
        }
    }

    /**
     * @notice Checks if a given number is a power of two.
     *
     * @param x The number to check.
     * @return result A boolean indicating whether the number is a power of two.
     */
    function isPo2(uint256 x) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := and(iszero(and(x, sub(x, 1))), iszero(iszero(x)))
        }
    }

    /**
     * @notice Reverses the bits of a given 256-bit unsigned integer.
     *
     * @param x The input 256-bit unsigned integer whose bits are to be reversed.
     * @return r The resulting 256-bit unsigned integer with reversed bits.
     */
    function reverseBits(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            // Masks for nibble/bit reversal.
            uint256 m0 = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
            uint256 m1 = m0 ^ (m0 << 2);
            uint256 m2 = m1 ^ (m1 << 1);

            r = reverseBytes(x);
            // Reverse pairs of bits.
            r = ((r >> 1) & m2) | ((r & m2) << 1);
            // Reverse 2‑bit groups.
            r = ((r >> 2) & m1) | ((r & m1) << 2);
            // Reverse 4‑bit groups.
            r = ((r >> 4) & m0) | ((r & m0) << 4);
        }
    }

    /**
     * @notice Reverses the byte order of a 256-bit unsigned integer.
     *
     * @param x The input 256-bit unsigned integer whose byte order is to be reversed.
     * @return r The resulting 256-bit unsigned integer with reversed byte order.
     */
    function reverseBytes(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            uint256 m0 = 0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff;
            uint256 m1 = m0 ^ (m0 << 8);
            uint256 m2 = m1 ^ (m1 << 4);
            uint256 m3 = m2 ^ (m2 << 2);

            r = x;
            // Swap adjacent bytes.
            r = ((r >> 8) & m0) | ((r & m0) << 8);
            // Swap 2‑byte groups.
            r = ((r >> 16) & m1) | ((r & m1) << 16);
            // Swap 4‑byte groups.
            r = ((r >> 32) & m2) | ((r & m2) << 32);
            // Swap 8‑byte groups.
            r = ((r >> 64) & m3) | ((r & m3) << 64);
            // Swap 16‑byte halves.
            r = (r >> 128) | (r << 128);
        }
    }

    /**
     * @notice Performs a bitwise AND operation on two boolean values using inline assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the bitwise AND operation between `x` and `y`.
     */
    function rawAnd(bool x, bool y) internal pure returns (bool z) {
        assembly ("memory-safe") {
            z := and(x, y)
        }
    }

    /**
     * @notice Performs a logical AND operation on two boolean values using inline assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the logical AND operation between `x` and `y`.
     */
    function and(bool x, bool y) internal pure returns (bool z) {
        assembly ("memory-safe") {
            z := and(iszero(iszero(x)), iszero(iszero(y)))
        }
    }

    /**
     * @notice Performs a logical OR operation on two boolean values using low-level assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the logical OR operation between `x` and `y`.
     */
    function rawOr(bool x, bool y) internal pure returns (bool z) {
        assembly ("memory-safe") {
            z := or(x, y)
        }
    }

    /**
     * @notice Performs a logical OR operation on two boolean values using inline assembly.
     *
     * @param x The first boolean value.
     * @param y The second boolean value.
     * @return z The result of the logical OR operation between `x` and `y`.
     */
    function or(bool x, bool y) internal pure returns (bool z) {
        assembly ("memory-safe") {
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
     */
    function rawToUint(bool b) internal pure returns (uint256 z) {
        assembly ("memory-safe") {
            z := b
        }
    }

    /**
     * @notice Converts a boolean value to a uint256 representation.
     *
     * @param b The boolean value to convert.
     * @return z The uint256 representation of the boolean value (1 for true, 0 for false).
     */
    function toUint(bool b) internal pure returns (uint256 z) {
        assembly ("memory-safe") {
            z := iszero(iszero(b))
        }
    }
}