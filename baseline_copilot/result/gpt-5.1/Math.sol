// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeCast} from "utils/math/SafeCast.sol";

library Math {
    enum Rounding {
        Down,
        Up,
        Zero,
        NegativeInfinity
    }

    /**
     * @notice Safely adds two unsigned integers and checks for overflow.
     *
     * Steps:
     * 1. Perform unchecked addition of `a` and `b` to get `c`.
     * 2. Check if `c` is less than `a` to detect overflow.
     * 3. If overflow is detected, return `false` and `0`.
     * 4. If no overflow, return `true` and the result of the addition `c`.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a + b;
            if (c < a) {
                return (false, 0);
            }
            return (true, c);
        }
    }

    /**
     * @notice Safely subtracts two unsigned integers and returns a boolean indicating success or failure.
     *
     * Steps:
     * 1. Check if the second number `b` is greater than the first number `a`.
     * 2. If `b` is greater than `a`, return `false` and `0` to indicate subtraction would result in underflow.
     * 3. Otherwise, return `true` and the result of `a - b`.
     *
     * @param a The first unsigned integer (minuend).
     * @param b The second unsigned integer (subtrahend).
     * @return success A boolean indicating whether the subtraction was successful.
     * @return result The result of the subtraction if successful, otherwise `0`.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b > a) {
                return (false, 0);
            }
            return (true, a - b);
        }
    }

    /**
     * @notice Safely multiplies two unsigned integers and returns the result along with a success flag.
     *
     * @dev This function uses unchecked arithmetic to optimize gas usage. It checks for overflow by verifying
     *      that the product divided by the first operand equals the second operand. If overflow occurs, it
     *      returns `false` and `0`. If the first operand is `0`, it immediately returns `true` and `0`.
     *
     * @param a The first unsigned integer to multiply.
     * @param b The second unsigned integer to multiply.
     *
     * @return success A boolean indicating whether the multiplication was successful (true) or overflowed (false).
     * @return result The result of the multiplication if successful, otherwise `0`.
     *
     * Steps:
     * 1. If `a` is `0`, return `(true, 0)` since any number multiplied by `0` is `0`.
     * 2. Multiply `a` and `b` and store the result in `c`.
     * 3. Check for overflow by verifying if `c / a` equals `b`. If not, return `(false, 0)`.
     * 4. If no overflow, return `(true, c)`.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (a == 0) {
                return (true, 0);
            }
            uint256 c = a * b;
            if (c / a != b) {
                return (false, 0);
            }
            return (true, c);
        }
    }

    /**
     * @notice Attempts to divide two unsigned integers and returns the result along with a success flag.
     *
     * Steps:
     * 1. Check if the divisor `b` is zero.
     * 2. If `b` is zero, return `false` and `0` to indicate division by zero.
     * 3. Otherwise, perform the division and return `true` along with the result of `a / b`.
     *
     * @param a The dividend.
     * @param b The divisor.
     * @return success A boolean indicating whether the division was successful.
     * @return result The result of the division if successful, otherwise `0`.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) {
                return (false, 0);
            }
            return (true, a / b);
        }
    }

    /**
     * @notice Attempts to perform a modulo operation on two unsigned integers.
     *
     * @param a The dividend in the modulo operation.
     * @param b The divisor in the modulo operation.
     *
     * @return success A boolean indicating whether the modulo operation was successful (true if `b` is not zero).
     * @return result The result of the modulo operation (`a % b`), or 0 if `b` is zero.
     *
     * Steps:
     * 1. Check if `b` is zero.
     *    - If `b` is zero, return `(false, 0)` to indicate failure.
     * 2. If `b` is not zero, return `(true, a % b)` to indicate success and the result of the modulo operation.
     *
     * Note: The function uses `unchecked` to disable overflow checks, which is safe since the modulo operation
     * does not involve arithmetic that could overflow.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) {
                return (false, 0);
            }
            return (true, a % b);
        }
    }

    /**
     * @notice A branchless ternary function that returns one of two values based on a condition.
     *
     * @param condition A boolean condition that determines which value to return.
     * @param a The value to return if the condition is true.
     * @param b The value to return if the condition is false.
     * @return The result of the ternary operation, either `a` or `b`.
     *
     * Details:
     * - The function uses bitwise operations to achieve a branchless ternary operation.
     * - If `condition` is true, the function returns `a`.
     * - If `condition` is false, the function returns `b`.
     * - The operation is performed in an `unchecked` block to avoid overflow checks.
     * - The logic works as follows:
     *   - `b ^ ((a ^ b) * SafeCast.toUint(condition))`:
     *     - If `condition` is true, `SafeCast.toUint(condition)` returns 1, so the result is `b ^ (a ^ b) = a`.
     *     - If `condition` is false, `SafeCast.toUint(condition)` returns 0, so the result is `b ^ 0 = b`.
     */
    function ternary(bool condition, uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return b ^ ((a ^ b) * SafeCast.toUint(condition));
        }
    }

    /**
     * @notice Returns the maximum of two unsigned integers.
     *
     * @param a The first unsigned integer to compare.
     * @param b The second unsigned integer to compare.
     * @return The larger of the two input values.
     *
     * Steps:
     * 1. Compare `a` and `b` using the ternary operator.
     * 2. Return `a` if it is greater than `b`, otherwise return `b`.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Returns the minimum of two unsigned integers.
     *
     * @param a The first unsigned integer to compare.
     * @param b The second unsigned integer to compare.
     * @return The smaller of the two integers, `a` or `b`.
     *
     * Steps:
     * 1. Compare `a` and `b` using the ternary operator.
     * 2. Return the smaller value.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Calculates the average of two unsigned integers without overflow.
     * @dev Uses bitwise operations to avoid overflow when summing `a` and `b`.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @return The average of `a` and `b`.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a & b) + ((a ^ b) >> 1);
        }
    }

    /**
     * @notice Performs ceiling division of two unsigned integers.
     *
     * @param a The dividend.
     * @param b The divisor.
     * @return The result of the ceiling division of `a` by `b`.
     *
     * Steps:
     * 1. Check if `b` is zero. If true, revert with a division by zero error.
     * 2. Perform the ceiling division calculation:
     *    - Subtract 1 from `a` and divide by `b`.
     *    - Add 1 to the result to ensure the ceiling effect.
     *    - Multiply by `SafeCast.toUint(a > 0)` to handle the case where `a` is zero.
     * 3. The calculation is performed in an unchecked block to avoid overflow checks.
     *
     * Note: This function ensures accurate ceiling division without overflow, even for large values of `a` and `b`.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert();
        unchecked {
            if (a == 0) return 0;
            return ((a - 1) / b + 1);
        }
    }

    /**
     * @notice Performs a multiplication and division operation on three unsigned integers (x, y, denominator)
     *         with precision and safety checks. The function ensures that the result is accurate and handles
     *         edge cases such as division by zero or overflow.
     *
     * @param x The multiplicand.
     * @param y The multiplier.
     * @param denominator The divisor.
     * @return result The result of the operation (x * y) / denominator.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(denominator > 0);
                return prod0 / denominator;
            }

            require(denominator > prod1);

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }

            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;

            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Performs a multiplication and division operation on three unsigned integers (x, y, denominator)
     *         with precision and safety checks. The function ensures that the result is accurate and handles
     *         edge cases such as division by zero or overflow.
     *
     * @param x The multiplicand.
     * @param y The multiplier.
     * @param denominator The divisor.
     * @return result The result of the operation (x * y) / denominator.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding)) {
            unchecked {
                if (mulmod(x, y, denominator) > 0) {
                    result += 1;
                }
            }
        }
        return result;
    }

    /**
     * @notice Computes the modular inverse of `a` modulo `n` using the Extended Euclidean Algorithm.
     *
     * @param a The number for which the modular inverse is to be computed.
     * @param n The modulus.
     * @return The modular inverse of `a` modulo `n`. Returns 0 if no inverse exists (i.e., if `gcd(a, n) != 1`).
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        if (n == 0) return 0;

        int256 t = 0;
        int256 newT = 1;
        int256 r = int256(uint256(n));
        int256 newR = int256(uint256(a % n));

        while (newR != 0) {
            uint256 q = uint256(r) / uint256(newR);

            (t, newT) = (newT, t - int256(q) * newT);
            (r, newR) = (newR, r - int256(q) * newR);
        }

        if (r != 1) {
            return 0;
        }

        if (t < 0) {
            t += int256(uint256(n));
        }

        return uint256(t);
    }

    /**
     * @notice Computes the modular inverse of `a` modulo a prime `p` using Fermat's Little Theorem.
     *
     * @param a The number for which the modular inverse is to be computed.
     * @param p The prime modulus.
     * @return The modular inverse of `a` modulo `p`.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        return modExp(a, p - 2, p);
    }

    /**
     * @notice Computes the modular exponentiation of `b^e % m` using the `tryModExp` function.
     *
     * @param b The base value for the exponentiation.
     * @param e The exponent value.
     * @param m The modulus value.
     *
     * @return result The result of the modular exponentiation `b^e % m`.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            assert(false);
        }
        return result;
    }

    /**
     * @notice Attempts to compute the modular exponentiation of `b^e % m` using inline assembly.
     *
     * @param b The base value for the exponentiation.
     * @param e The exponent value.
     * @param m The modulus value.
     *
     * @return success A boolean indicating whether the operation was successful.
     * @return result The result of the modular exponentiation if successful, otherwise 0.
     */
    function tryModExp(uint256 b, uint256 e, uint256 m) internal view returns (bool success, uint256 result) {
        if (m == 0) {
            return (false, 0);
        }

        uint256[6] memory input;
        input[0] = 32;
        input[1] = 32;
        input[2] = 32;
        input[3] = b;
        input[4] = e;
        input[5] = m;

        uint256 output;
        bool ok;
        assembly {
            ok := staticcall(gas(), 0x05, input, 0xc0, output, 0x20)
        }
        return (ok, output);
    }

    /**
     * @notice Computes the modular exponentiation of `b^e % m` using the `tryModExp` function.
     *
     * @param b The base value for the exponentiation.
     * @param e The exponent value.
     * @param m The modulus value.
     *
     * @return result The result of the modular exponentiation `b^e % m`.
     */
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            assert(false);
        }
        return result;
    }

    /**
     * @notice Attempts to compute the modular exponentiation of `b^e % m` using inline assembly.
     *
     * @param b The base value for the exponentiation.
     * @param e The exponent value.
     * @param m The modulus value.
     *
     * @return success A boolean indicating whether the operation was successful.
     * @return result The result of the modular exponentiation if successful, otherwise 0.
     */
    function tryModExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) {
            return (false, new bytes(0));
        }

        uint256 bl = b.length;
        uint256 el = e.length;
        uint256 ml = m.length;

        bytes memory input = new bytes(96 + bl + el + ml);
        assembly {
            let ptr := add(input, 32)
            mstore(ptr, bl)
            mstore(add(ptr, 32), el)
            mstore(add(ptr, 64), ml)

            calldatacopy(add(ptr, 96), add(b, 32), bl)
            calldatacopy(add(add(ptr, 96), bl), add(e, 32), el)
            calldatacopy(add(add(add(ptr, 96), bl), el), add(m, 32), ml)
        }

        bytes memory output = new bytes(ml);
        bool ok;
        assembly {
            ok := staticcall(gas(), 0x05, add(input, 32), mload(input), add(output, 32), ml)
        }
        return (ok, output);
    }

    /**
     * @notice Checks if a given byte array consists entirely of zero bytes.
     *
     * @param byteArray The byte array to be checked.
     * @return bool Returns true if all bytes in the array are zero, otherwise returns false.
     */
    function _zeroBytes(bytes memory byteArray) private pure returns (bool) {
        for (uint256 i = 0; i < byteArray.length; i++) {
            if (byteArray[i] != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Computes the square root of a given unsigned integer `a` using Newton's method.
     *
     * @param a The unsigned integer for which the square root is to be computed.
     * @return The square root of `a`, rounded down to the nearest integer.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 x = 1 << (log2(a) >> 1);
        unchecked {
            for (uint256 i = 0; i < 7; i++) {
                x = (x + a / x) >> 1;
            }
            uint256 y = a / x;
            return x < y ? x : y;
        }
    }

    /**
     * @notice Computes the square root of a given unsigned integer `a` using Newton's method.
     *
     * @param a The unsigned integer for which the square root is to be computed.
     * @return The square root of `a`, rounded down to the nearest integer.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (unsignedRoundsUp(rounding)) {
            unchecked {
                if (result * result < a) {
                    result += 1;
                }
            }
        }
        return result;
    }

    /**
     * @notice Computes the base-2 logarithm of a given unsigned integer `x` using a bitwise approach.
     *
     * @param x The unsigned integer for which to compute the logarithm.
     * @return r The base-2 logarithm of `x`, rounded down to the nearest integer.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            if (x >> 128 > 0) {
                x >>= 128;
                r += 128;
            }
            if (x >> 64 > 0) {
                x >>= 64;
                r += 64;
            }
            if (x >> 32 > 0) {
                x >>= 32;
                r += 32;
            }
            if (x >> 16 > 0) {
                x >>= 16;
                r += 16;
            }
            if (x >> 8 > 0) {
                x >>= 8;
                r += 8;
            }
            if (x >> 4 > 0) {
                x >>= 4;
                r += 4;
            }
            if (x >> 2 > 0) {
                x >>= 2;
                r += 2;
            }
            if (x >> 1 > 0) {
                r += 1;
            }
        }
    }

    /**
     * @notice Computes the base-2 logarithm of a given unsigned integer `x` using a bitwise approach.
     *
     * @param value The unsigned integer for which to compute the logarithm.
     * @return r The base-2 logarithm of `x`, rounded down to the nearest integer.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log2(value);
        if (unsignedRoundsUp(rounding)) {
            unchecked {
                if (1 << result < value) {
                    result += 1;
                }
            }
        }
        return result;
    }

    /**
     * @notice Computes the base-10 logarithm of a given value.
     *
     * @param value The input value for which the logarithm is to be computed.
     * @return result The base-10 logarithm of the input value, rounded down to the nearest integer.
     */
    function log10(uint256 value) internal pure returns (uint256 result) {
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
    }

    /**
     * @notice Computes the base-10 logarithm of a given value.
     *
     * @param value The input value for which the logarithm is to be computed.
     * @return result The base-10 logarithm of the input value, rounded down to the nearest integer.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log10(value);
        if (unsignedRoundsUp(rounding)) {
            unchecked {
                if (10**result < value) {
                    result += 1;
                }
            }
        }
        return result;
    }

    /**
     * @notice Computes the base-256 logarithm of a given 256-bit unsigned integer.
     *
     * @param x The 256-bit unsigned integer for which the logarithm is to be computed.
     * @return r The computed base-256 logarithm of `x`, represented as a 256-bit unsigned integer.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            if (x >> 128 > 0) {
                x >>= 128;
                r += 16;
            }
            if (x >> 64 > 0) {
                x >>= 64;
                r += 8;
            }
            if (x >> 32 > 0) {
                x >>= 32;
                r += 4;
            }
            if (x >> 16 > 0) {
                x >>= 16;
                r += 2;
            }
            if (x >> 8 > 0) {
                r += 1;
            }
        }
    }

    /**
     * @notice Computes the base-256 logarithm of a given 256-bit unsigned integer.
     *
     * @param value The 256-bit unsigned integer for which the logarithm is to be computed.
     * @return r The computed base-256 logarithm of `x`, represented as a 256-bit unsigned integer.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log256(value);
        if (unsignedRoundsUp(rounding)) {
            unchecked {
                if (1 << (result * 8) < value) {
                    result += 1;
                }
            }
        }
        return result;
    }

    /**
     * @notice Determines if the given rounding mode rounds up for unsigned numbers.
     *
     * @param rounding The rounding mode to check.
     * @return bool Returns `true` if the rounding mode rounds up for unsigned numbers, otherwise `false`.
     *
     * Logic:
     * - The function checks if the integer value of the `rounding` parameter modulo 2 equals 1.
     * - If true, it indicates that the rounding mode rounds up for unsigned numbers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}