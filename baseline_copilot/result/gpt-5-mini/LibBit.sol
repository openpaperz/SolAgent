// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibBit {
    /**
     * @notice Computes the floor log2 of a given unsigned integer `x`.
     * @dev Returns 0 for input 0.
     */
    function fls(uint256 x) internal pure returns (uint256 r) {
        if (x == 0) return 0;
        unchecked {
            if (x >= (uint256(1) << 128)) { x >>= 128; r += 128; }
            if (x >= (uint256(1) << 64))  { x >>= 64;  r += 64; }
            if (x >= (uint256(1) << 32))  { x >>= 32;  r += 32; }
            if (x >= (uint256(1) << 16))  { x >>= 16;  r += 16; }
            if (x >= (uint256(1) << 8))   { x >>= 8;   r += 8; }
            if (x >= (uint256(1) << 4))   { x >>= 4;   r += 4; }
            if (x >= (uint256(1) << 2))   { x >>= 2;   r += 2; }
            if (x >= (uint256(1) << 1))   { /* x >>= 1; */ r += 1; }
        }
    }

    /**
     * @notice Counts the leading zeros in a 256-bit unsigned integer.
     * @dev Returns 256 for input 0.
     */
    function clz(uint256 x) internal pure returns (uint256 r) {
        if (x == 0) return 256;
        // number of leading zeros = 255 - floor_log2(x)
        r = 255 - fls(x);
    }

    /**
     * @notice Finds the position of the least significant bit set to 1 (0-indexed).
     * @dev Returns 256 for input 0.
     */
    function ffs(uint256 x) internal pure returns (uint256 r) {
        if (x == 0) return 256;
        uint256 y = x & (~x + 1); // isolate lowest set bit
        // count trailing zeros
        while (y > 1) {
            y >>= 1;
            r += 1;
        }
    }

    /**
     * @notice Calculates the number of set bits (population count) in a 256-bit unsigned integer.
     */
    function popCount(uint256 x) internal pure returns (uint256 c) {
        while (x != 0) {
            c += (x & 1);
            x >>= 1;
        }
    }

    /**
     * @notice Checks if a given number is a power of two.
     */
    function isPo2(uint256 x) internal pure returns (bool result) {
        assembly {
            // result := and(iszero(iszero(x)), iszero(and(sub(x,1), x)))
            // Return true if x != 0 && (x & (x - 1)) == 0
            result := and(iszero(iszero(x)), iszero(and(sub(x,1), x)))
        }
    }

    /**
     * @notice Reverses the bits of a given 256-bit unsigned integer.
     */
    function reverseBits(uint256 x) internal pure returns (uint256 r) {
        // simple bit-by-bit reversal
        for (uint256 i = 0; i < 256; ++i) {
            r = (r << 1) | (x & 1);
            x >>= 1;
        }
    }

    /**
     * @notice Reverses the byte order of a 256-bit unsigned integer.
     */
    function reverseBytes(uint256 x) internal pure returns (uint256 r) {
        for (uint256 i = 0; i < 32; ++i) {
            r = (r << 8) | (x & 0xff);
            x >>= 8;
        }
    }

    /**
     * @notice Performs a bitwise AND operation on two boolean values using inline assembly.
     */
    function rawAnd(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := and(x, y)
        }
    }

    /**
     * @notice Performs a logical AND operation on two boolean values using inline assembly.
     * @dev Converts booleans to canonical 0/1 using iszero(iszero(...))
     */
    function and(bool x, bool y) internal pure returns (bool z) {
        assembly {
            let a := iszero(iszero(x))
            let b := iszero(iszero(y))
            z := and(a, b)
        }
    }

    /**
     * @notice Performs a bitwise OR operation on two boolean values using inline assembly.
     */
    function rawOr(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := or(x, y)
        }
    }

    /**
     * @notice Performs a logical OR operation on two boolean values using inline assembly.
     * @dev Converts booleans to canonical 0/1 using iszero(iszero(...))
     */
    function or(bool x, bool y) internal pure returns (bool z) {
        assembly {
            let a := iszero(iszero(x))
            let b := iszero(iszero(y))
            z := or(a, b)
        }
    }

    /**
     * @notice Converts a boolean value to a uint256 representation using inline assembly.
     */
    function rawToUint(bool b) internal pure returns (uint256 z) {
        assembly {
            z := b
        }
    }

    /**
     * @notice Converts a boolean value to a uint256 representation.
     */
    function toUint(bool b) internal pure returns (uint256 z) {
        assembly {
            z := iszero(iszero(b))
        }
    }
}