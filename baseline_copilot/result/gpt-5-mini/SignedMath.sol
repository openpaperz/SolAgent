// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SignedMath {
    /**
     * @notice Implements a branchless ternary operation to return one of two values based on a condition.
     *
     * @param condition The boolean condition to evaluate.
     * @param a The value to return if the condition is true.
     * @param b The value to return if the condition is false.
     * @return The result of the ternary operation, which is either `a` or `b` based on the condition.
     *
     * Details:
     * - The function uses bitwise XOR (`^`) and multiplication to achieve a branchless ternary operation.
     * - If `condition` is true, the result is `a` because `b ^ ((a ^ b) * 1) = a`.
     * - If `condition` is false, the result is `b` because `b ^ ((a ^ b) * 0) = b`.
     * - The `unchecked` block is used to avoid overflow checks, as the operation is safe within the given context.
     */
    function ternary(bool condition, int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            int256 mask = condition ? int256(1) : int256(0);
            return b ^ ((a ^ b) * mask);
        }
    }

    /**
     * @notice Returns the maximum of two integers `a` and `b`.
     *
     * @param a The first integer to compare.
     * @param b The second integer to compare.
     * @return The larger of the two integers.
     *
     * Steps:
     * 1. Use the `ternary` function to compare `a` and `b`.
     * 2. Return the larger value between `a` and `b`.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return ternary(a >= b, a, b);
    }

    /**
     * @notice Returns the minimum of two integers.
     *
     * @param a The first integer to compare.
     * @param b The second integer to compare.
     * @return The smaller of the two integers.
     *
     * Steps:
     * 1. Compare `a` and `b` using the ternary operator.
     * 2. Return the smaller value.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return ternary(a < b, a, b);
    }

    /**
     * @notice Calculates the average of two signed integers using a formula from "Hacker's Delight".
     *
     * @param a The first signed integer.
     * @param b The second signed integer.
     * @return The average of the two integers, rounded towards zero.
     *
     * Steps:
     * 1. Compute the average using the formula: (a & b) + ((a ^ b) >> 1).
     * 2. Adjust the result to handle overflow or underflow by adding a correction term:
     *    - The correction term is derived from the sign bit of the intermediate result.
     *    - It ensures the result is accurate even when the sum of a and b overflows.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            // Hacker's Delight formula for average without overflow:
            // average = (a & b) + ((a ^ b) >> 1)
            int256 x = (a & b) + ((a ^ b) >> 1);

            // Correction term:
            // If (a ^ b) has its least significant bit set and (a & b) is negative,
            // we need to add 1 to correct rounding towards zero.
            int256 correction = (((a ^ b) & int256(1)) & ((a & b) >> 255));
            return x + correction;
        }
    }

    /**
     * @notice Computes the absolute value of a signed integer `n` and returns it as an unsigned integer.
     *
     * @param n The signed integer for which the absolute value is to be computed.
     * @return The absolute value of `n` as an unsigned integer.
     *
     * Steps:
     * 1. Calculate the mask using the formula from "Bit Twiddling Hacks" by Sean Eron Anderson.
     *    - The mask is computed by shifting `n` right by 255 bits, which results in either `0` (if `n` is positive) or `~0` (if `n` is negative).
     * 2. Compute the absolute value using the formula `(n + mask) ^ mask`.
     *    - If `n` is positive, the mask is `0`, so the result is `n`.
     *    - If `n` is negative, the mask is `~0`, which effectively flips the bits of `n` and adds 1 to get the absolute value.
     * 3. Return the result as an unsigned integer.
     *
     * Note: The function uses `unchecked` to avoid overflow checks, assuming that the input `n` is within the valid range for the operation.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            int256 mask = n >> 255;
            return uint256(uint256(uint256(uint256(0) + uint256((n + mask) ^ mask))));
        }
    }
}