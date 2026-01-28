// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Standard rounding directions.
 */
enum Rounding {
    Floor, // Toward negative infinity
    Ceil,  // Toward positive infinity
    Trunc, // Toward zero
    Expand // Away from zero
}

/**
 * @dev Collection of functions related to the uint256 type
 */
library SafeCast {
    /**
     * @dev Converts a bool to a uint256 (1 for true, 0 for false).
     */
    function toUint(bool b) internal pure returns (uint256) {
        return b ? 1 : 0;
    }
}

/**
 * @dev Helper library for panic codes.
 */
library Panic {
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    
    function panic(uint256 code) internal pure {
        assembly {
            mstore(0x00, 0x4e487b71) // Panic selector
            mstore(0x04, code)
            revert(0x00, 0x24)
        }
    }
}

/**
 * @dev Standard math utilities missing in Solidity.
 */
library Math {
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
            if (c < a) return (false, 0);
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
            if (b > a) return (false, 0);
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
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
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
            if (b == 0) return (false, 0);
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
            if (b == 0) return (false, 0);
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
        return ternary(a > b, a, b);
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
        return ternary(a < b, a, b);
    }

    /**
     * @notice Calculates the average of two unsigned integers without overflow.
     * @dev Uses bitwise operations to avoid overflow when summing `a` and `b`.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @return The average of `a` and `b`.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a & b) + ((a ^ b) >> 1);
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
        if (b == 0) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        unchecked {
            return (((a - 1) / b) + 1) * SafeCast.toUint(a > 0);
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
     *
     * Steps:
     * 1. Compute the product of x and y, splitting it into two 256-bit parts (prod0 and prod1).
     * 2. Handle non-overflow cases where prod1 is zero by directly dividing prod0 by the denominator.
     * 3. Check for invalid cases where the denominator is zero or less than prod1, and revert with an appropriate error.
     * 4. Perform 512-bit by 256-bit division to ensure precision:
     *    - Subtract the remainder from the product to make the division exact.
     *    - Factor out powers of two from the denominator and adjust the product accordingly.
     * 5. Compute the modular inverse of the denominator using the Newton-Raphson method for high precision.
     * 6. Multiply the adjusted product by the modular inverse to get the final result.
     * 7. Return the result, ensuring it is accurate and within the bounds of 256 bits.
     *
     * Notes:
     * - The function uses assembly for low-level operations to optimize gas usage and ensure precision.
     * - It handles edge cases such as division by zero and overflow gracefully by reverting with appropriate errors.
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
                if (denominator == 0) {
                    Panic.panic(Panic.DIVISION_BY_ZERO);
                }
                return prod0 / denominator;
            }

            if (denominator <= prod1) {
                Panic.panic(Panic.DIVISION_BY_ZERO);
            }

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (0 - denominator);
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
     *
     * Steps:
     * 1. Compute the product of x and y, splitting it into two 256-bit parts (prod0 and prod1).
     * 2. Handle non-overflow cases where prod1 is zero by directly dividing prod0 by the denominator.
     * 3. Check for invalid cases where the denominator is zero or less than prod1, and revert with an appropriate error.
     * 4. Perform 512-bit by 256-bit division to ensure precision:
     *    - Subtract the remainder from the product to make the division exact.
     *    - Factor out powers of two from the denominator and adjust the product accordingly.
     * 5. Compute the modular inverse of the denominator using the Newton-Raphson method for high precision.
     * 6. Multiply the adjusted product by the modular inverse to get the final result.
     * 7. Return the result, ensuring it is accurate and within the bounds of 256 bits.
     *
     * Notes:
     * - The function uses assembly for low-level operations to optimize gas usage and ensure precision.
     * - It handles edge cases such as division by zero and overflow gracefully by reverting with appropriate errors.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @notice Computes the modular inverse of `a` modulo `n` using the Extended Euclidean Algorithm.
     *
     * @param a The number for which the modular inverse is to be computed.
     * @param n The modulus.
     * @return The modular inverse of `a` modulo `n`. Returns 0 if no inverse exists (i.e., if `gcd(a, n) != 1`).
     *
     * Steps:
     * 1. Check if `n` is 0. If so, return 0 immediately as no inverse exists.
     * 2. Initialize variables for the Extended Euclidean Algorithm:
     *    - `remainder` as `a % n`.
     *    - `gcd` as `n`.
     *    - Coefficients `x` and `y` initialized to 0 and 1, respectively.
     * 3. Iterate while `remainder` is not 0:
     *    - Compute the quotient `gcd / remainder`.
     *    - Update `gcd` and `remainder` for the next iteration.
     *    - Update coefficients `x` and `y` to maintain the equation `ax + ny = gcd`.
     * 4. If `gcd` is not 1, return 0 (no inverse exists).
     * 5. If the result `x` is negative, wrap it around to a positive value within the range `[0, n-1]`.
     * 6. Return the computed modular inverse.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n == 0) return 0;

            uint256 remainder = a % n;
            uint256 gcd = n;

            int256 x = 0;
            int256 y = 1;

            while (remainder != 0) {
                uint256 quotient = gcd / remainder;

                (gcd, remainder) = (remainder, gcd - quotient * remainder);
                (x, y) = (y - int256(quotient) * x, x);
            }

            if (gcd != 1) return 0;

            return y < 0 ? n - uint256(-y) : uint256(y);
        }
    }

    /**
     * @notice Computes the modular inverse of `a` modulo a prime `p` using Fermat's Little Theorem.
     * 
     * @param a The number for which the modular inverse is to be computed.
     * @param p The prime modulus.
     * @return The modular inverse of `a` modulo `p`.
     * 
     * Steps:
     * 1. Use Fermat's Little Theorem, which states that `a^(p-1) ≡ 1 mod p` for a prime `p` and `a` not divisible by `p`.
     * 2. Therefore, the modular inverse of `a` is `a^(p-2) mod p`.
     * 3. Compute `a^(p-2) mod p` using the `modExp` function from the Math library.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        unchecked {
            return modExp(a, p - 2, p);
        }
    }

    /**
     * @notice Computes the modular exponentiation of `b^e % m` using the `tryModExp` function.
     * 
     * @param b The base value for the exponentiation.
     * @param e The exponent value.
     * @param m The modulus value.
     * 
     * @return result The result of the modular exponentiation `b^e % m`.
     * 
     * Steps:
     * 1. Attempt to compute the modular exponentiation using `tryModExp`.
     * 2. If the computation fails (e.g., due to division by zero), trigger a panic with the `Panic.DIVISION_BY_ZERO` error.
     * 3. Return the computed result if successful.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
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
     * 
     * Steps:
     * 1. Check if the modulus `m` is zero. If true, return `(false, 0)` immediately.
     * 2. Use inline assembly to perform the following:
     *    a. Load the free memory pointer.
     *    b. Store the sizes of `b`, `e`, and `m` (each 32 bytes) in memory.
     *    c. Store the values of `b`, `e`, and `m` in memory at specific offsets.
     *    d. Perform a static call to the precompiled contract at address `0x05` (modular exponentiation).
     *    e. Retrieve the result from memory and return it along with the success status.
     */
    function tryModExp(uint256 b, uint256 e, uint256 m) internal view returns (bool success, uint256 result) {
        if (m == 0) return (false, 0);
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)
            success := staticcall(gas(), 0x05, ptr, 0xc0, ptr, 0x20)
            result := mload(ptr)
        }
    }

    /**
     * @notice Computes the modular exponentiation of `b^e % m` using the `tryModExp` function.
     * 
     * @param b The base value for the exponentiation.
     * @param e The exponent value.
     * @param m The modulus value.
     * 
     * @return result The result of the modular exponentiation `b^e % m`.
     * 
     * Steps:
     * 1. Attempt to compute the modular exponentiation using `tryModExp`.
     * 2. If the computation fails (e.g., due to division by zero), trigger a panic with the `Panic.DIVISION_BY_ZERO` error.
     * 3. Return the computed result if successful.
     */
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
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
     * 
     * Steps:
     * 1. Check if the modulus `m` is zero. If true, return `(false, 0)` immediately.
     * 2. Use inline assembly to perform the following:
     *    a. Load the free memory pointer.
     *    b. Store the sizes of `b`, `e`, and `m` (each 32 bytes) in memory.
     *    c. Store the values of `b`, `e`, and `m` in memory at specific offsets.
     *    d. Perform a static call to the precompiled contract at address `0x05` (modular exponentiation).
     *    e. Retrieve the result from memory and return it along with the success status.
     */
    function tryModExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) return (false, new bytes(0));
        
        assembly {
            let bLen := mload(b)
            let eLen := mload(e)
            let mLen := mload(m)
            
            let ptr := mload(0x40)
            mstore(ptr, bLen)
            mstore(add(ptr, 0x20), eLen)
            mstore(add(ptr, 0x40), mLen)
            
            let bPtr := add(b, 0x20)
            let ePtr := add(e, 0x20)
            let mPtr := add(m, 0x20)
            
            let inputSize := add(0x60, add(bLen, add(eLen, mLen)))
            
            for { let i := 0 } lt(i, bLen) { i := add(i, 0x20) } {
                mstore(add(add(ptr, 0x60), i), mload(add(bPtr, i)))
            }
            for { let i := 0 } lt(i, eLen) { i := add(i, 0x20) } {
                mstore(add(add(ptr, add(0x60, bLen)), i), mload(add(ePtr, i)))
            }
            for { let i := 0 } lt(i, mLen) { i := add(i, 0x20) } {
                mstore(add(add(ptr, add(0x60, add(bLen, eLen))), i), mload(add(mPtr, i)))
            }
            
            success := staticcall(gas(), 0x05, ptr, inputSize, add(ptr, inputSize), mLen)
            
            if success {
                result := mload(0x40)
                mstore(result, mLen)
                let resultPtr := add(result, 0x20)
                for { let i := 0 } lt(i, mLen) { i := add(i, 0x20) } {
                    mstore(add(resultPtr, i), mload(add(add(ptr, inputSize), i)))
                }
                mstore(0x40, add(resultPtr, mLen))
            }
        }
    }

    /**
     * @notice Checks if a given byte array consists entirely of zero bytes.
     *
     * @param byteArray The byte array to be checked.
     * @return bool Returns true if all bytes in the array are zero, otherwise returns false.
     *
     * Steps:
     * 1. Iterate through each byte in the byte array.
     * 2. If any byte is not zero, return false.
     * 3. If all bytes are zero, return true.
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
     *
     * Steps:
     * 1. Handle edge cases where `a` is 0 or 1, returning `a` directly.
     * 2. Use Newton's method to iteratively approximate the square root of `a`.
     * 3. Initialize `xn` (the initial guess) by finding the smallest power of 2 greater than the square root of `a`.
     * 4. Refine the initial guess by adjusting `xn` to minimize the error.
     * 5. Perform multiple iterations of Newton's method to converge towards the square root:
     *    - Each iteration updates `xn` using the formula: `xn = (xn + a / xn) >> 1`.
     *    - The error decreases quadratically with each iteration.
     * 6. After several iterations, the result is either the exact square root or the square root plus one.
     * 7. Return the final result, ensuring it is the largest integer less than or equal to the square root of `a`.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a <= 1) {
            return a;
        }

        unchecked {
            uint256 xn = 1 << ((log2(a) >> 1) + 1);

            xn = (xn + a / xn) >> 1;
            xn = (xn + a / xn) >> 1;
            xn = (xn + a / xn) >> 1;
            xn = (xn + a / xn) >> 1;
            xn = (xn + a / xn) >> 1;
            xn = (xn + a / xn) >> 1;
            xn = (xn + a / xn) >> 1;

            return min(xn, a / xn);
        }
    }

    /**
     * @notice Computes the square root of a given unsigned integer `a` using Newton's method.
     *
     * @param a The unsigned integer for which the square root is to be computed.
     * @return The square root of `a`, rounded down to the nearest integer.
     *
     * Steps:
     * 1. Handle edge cases where `a` is 0 or 1, returning `a` directly.
     * 2. Use Newton's method to iteratively approximate the square root of `a`.
     * 3. Initialize `xn` (the initial guess) by finding the smallest power of 2 greater than the square root of `a`.
     * 4. Refine the initial guess by adjusting `xn` to minimize the error.
     * 5. Perform multiple iterations of Newton's method to converge towards the square root:
     *    - Each iteration updates `xn` using the formula: `xn = (xn + a / xn) >> 1`.
     *    - The error decreases quadratically with each iteration.
     * 6. After several iterations, the result is either the exact square root or the square root plus one.
     * 7. Return the final result, ensuring it is the largest integer less than or equal to the square root of `a`.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (unsignedRoundsUp(rounding) && result * result < a) {
            result += 1;
        }
        return result;
    }

    /**
     * @notice Computes the base-2 logarithm of a given unsigned integer `x` using a bitwise approach.
     *
     * @param x The unsigned integer for which to compute the logarithm.
     * @return r The base-2 logarithm of `x`, rounded down to the nearest integer.
     *
     * Steps:
     * 1. Initialize `r` by checking if the upper 128 bits of `x` are set. If so, set `r` to 128.
     * 2. Check the upper 64 bits of the remaining 128-bit half. If set, add 64 to `r`.
     * 3. Check the upper 32 bits of the remaining 64-bit half. If set, add 32 to `r`.
     * 4. Check the upper 16 bits of the remaining 32-bit half. If set, add 16 to `r`.
     * 5. Check the upper 8 bits of the remaining 16-bit half. If set, add 8 to `r`.
     * 6. Check the upper 4 bits of the remaining 8-bit half. If set, add 4 to `r`.
     *
     * 7. Use the remaining 4 bits of `x` as an index into a lookup table to determine the final value of `r`.
     *    The lookup table is embedded in the assembly code and maps the 4-bit value to the corresponding MSB position.
     *
     * Assembly:
     * - The lookup table is represented as a 32-byte value, where the last 16 bytes contain the MSB positions for 0-15.
     * - The `byte` instruction is used to extract the appropriate value from the lookup table based on the shifted `x`.
     * - The result is combined with `r` using the `or` instruction to produce the final logarithm value.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, byte(shr(r, x), 0x0000000000000000000000000000000001020304050607070809090a0b0c0d0e0f))
        }
    }

    /**
     * @notice Computes the base-2 logarithm of a given unsigned integer `x` using a bitwise approach.
     *
     * @param x The unsigned integer for which to compute the logarithm.
     * @return r The base-2 logarithm of `x`, rounded down to the nearest integer.
     *
     * Steps:
     * 1. Initialize `r` by checking if the upper 128 bits of `x` are set. If so, set `r` to 128.
     * 2. Check the upper 64 bits of the remaining 128-bit half. If set, add 64 to `r`.
     * 3. Check the upper 32 bits of the remaining 64-bit half. If set, add 32 to `r`.
     * 4. Check the upper 16 bits of the remaining 32-bit half. If set, add 16 to `r`.
     * 5. Check the upper 8 bits of the remaining 16-bit half. If set, add 8 to `r`.
     * 6. Check the upper 4 bits of the remaining 8-bit half. If set, add 4 to `r`.
     *
     * 7. Use the remaining 4 bits of `x` as an index into a lookup table to determine the final value of `r`.
     *    The lookup table is embedded in the assembly code and maps the 4-bit value to the corresponding MSB position.
     *
     * Assembly:
     * - The lookup table is represented as a 32-byte value, where the last 16 bytes contain the MSB positions for 0-15.
     * - The `byte` instruction is used to extract the appropriate value from the lookup table based on the shifted `x`.
     * - The result is combined with `r` using the `or` instruction to produce the final logarithm value.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log2(value);
        if (unsignedRoundsUp(rounding) && (1 << result) < value) {
            result += 1;
        }
        return result;
    }

    /**
     * @notice Computes the base-10 logarithm of a given value.
     *
     * @param value The input value for which the logarithm is to be computed.
     * @return result The base-10 logarithm of the input value, rounded down to the nearest integer.
     *
     * Steps:
     * 1. Initialize `result` to 0.
     * 2. Check if the value is greater than or equal to 10^64, and if so, divide the value by 10^64 and add 64 to `result`.
     * 3. Repeat the process for 10^32, 10^16, 10^8, 10^4, 10^2, and 10^1, updating `result` accordingly.
     * 4. Return the computed `result`.
     *
     * Note: The function uses unchecked arithmetic to avoid overflow checks, assuming the input value is valid.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @notice Computes the base-10 logarithm of a given value.
     *
     * @param value The input value for which the logarithm is to be computed.
     * @return result The base-10 logarithm of the input value, rounded down to the nearest integer.
     *
     * Steps:
     * 1. Initialize `result` to 0.
     * 2. Check if the value is greater than or equal to 10^64, and if so, divide the value by 10^64 and add 64 to `result`.
     * 3. Repeat the process for 10^32, 10^16, 10^8, 10^4, 10^2, and 10^1, updating `result` accordingly.
     * 4. Return the computed `result`.
     *
     * Note: The function uses unchecked arithmetic to avoid overflow checks, assuming the input value is valid.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log10(value);
        if (unsignedRoundsUp(rounding) && 10 ** result < value) {
            result += 1;
        }
        return result;
    }

    /**
     * @notice Computes the base-256 logarithm of a given 256-bit unsigned integer.
     *
     * @param x The 256-bit unsigned integer for which the logarithm is to be computed.
     * @return r The computed base-256 logarithm of `x`, represented as a 256-bit unsigned integer.
     *
     * Steps:
     * 1. Check if the upper 128 bits of `x` are set. If so, set the result `r` to at least 128.
     * 2. Check if the upper 64 bits of the remaining 128 bits are set. If so, add 64 to the result.
     * 3. Check if the upper 32 bits of the remaining 64 bits are set. If so, add 32 to the result.
     * 4. Check if the upper 16 bits of the remaining 32 bits are set. If so, add 16 to the result.
     * 5. Check if the upper 8 bits of the remaining 16 bits are set. If so, add 1 to the result.
     * 6. Return the final result, which is the accumulated value divided by 8.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
        }
        unchecked {
            return r >> 3;
        }
    }

    /**
     * @notice Computes the base-256 logarithm of a given 256-bit unsigned integer.
     *
     * @param x The 256-bit unsigned integer for which the logarithm is to be computed.
     * @return r The computed base-256 logarithm of `x`, represented as a 256-bit unsigned integer.
     *
     * Steps:
     * 1. Check if the upper 128 bits of `x` are set. If so, set the result `r` to at least 128.
     * 2. Check if the upper 64 bits of the remaining 128 bits are set. If so, add 64 to the result.
     * 3. Check if the upper 32 bits of the remaining 64 bits are set. If so, add 32 to the result.
     * 4. Check if the upper 16 bits of the remaining 32 bits are set. If so, add 16 to the result.
     * 5. Check if the upper 8 bits of the remaining 16 bits are set. If so, add 1 to the result.
     * 6. Return the final result, which is the accumulated value divided by 8.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log256(value);
        if (unsignedRoundsUp(rounding) && (1 << (result << 3)) < value) {
            result += 1;
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