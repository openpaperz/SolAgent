// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Math {
    enum Rounding {
        Down,
        Up,
        Zero
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
        if (b > a) return (false, 0);
        return (true, a - b);
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
        if (b == 0) return (false, 0);
        return (true, a / b);
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
        if (b == 0) return (false, 0);
        unchecked {
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
            uint256 c = condition ? 1 : 0;
            return b ^ ((a ^ b) * c);
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
        return a >= b ? a : b;
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
        return a <= b ? a : b;
    }

    /**
     * @notice Calculates the average of two unsigned integers without overflow.
     * @dev Uses bitwise operations to avoid overflow when summing `a` and `b`.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @return The average of `a` and `b`.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a & b) + (a ^ b) / 2 is safe from overflow
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
        require(b != 0, "Math: division by zero");
        unchecked {
            if (a == 0) return 0;
            return ((a - 1) / b) + 1;
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
            // 512-bit multiply [prod1 prod0] = x * y
            uint256 prod0; // Least significant 256 bits
            uint256 prod1; // Most significant 256 bits
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                // no overflow in multiplication
                require(denominator != 0, "Math: division by zero");
                return prod0 / denominator;
            }

            require(denominator > prod1, "Math: overflow");

            // Make division exact by subtracting the remainder from [prod1 prod0]
            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
            }
            // Subtract remainder from [prod1 prod0]
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by twos
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift bits from prod1 into prod0. Calculate shift = 256 - log2(twos)
            uint256 shift = 256 - _log2(twos);
            prod0 = prod0 | (prod1 << shift);

            // Compute inverse of denominator modulo 2^256 using Newton-Raphson
            uint256 inv = _modInverse(denominator);
            // Result is prod0 * inv mod 2^256 (since exact division holds, this yields the result)
            result = prod0 * inv;
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
        if (unsignedRoundsUp(rounding)) {
            // if there is a remainder, round up
            uint256 prodMod = mulmod(x, y, denominator);
            if (prodMod != 0) {
                unchecked {
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
        if (n == 0) return 0;
        uint256 t = 0;
        uint256 newT = 1;
        uint256 r = n;
        uint256 newR = a % n;
        while (newR != 0) {
            uint256 q = r / newR;
            (t, newT) = (newT, addmod(t, (type(uint256).max - mulmod(q, newT, type(uint256).max)) + 1, type(uint256).max)); // t - q*newT mod 2^256
            // The above uses modular arithmetic to avoid signed ints; we'll keep track of r values normally.
            (r, newR) = (newR, r - q * newR);
        }
        if (r != 1) return 0; // inverse does not exist
        // newT now holds the modular inverse in mod 2^256 semantics; recover positive value modulo n using extended algorithm simpler path:
        // Recompute proper inverse using classical extended algorithm with signed ints in int256 domain
        int256 s0 = 1;
        int256 s1 = 0;
        int256 r0 = int256(a % n);
        int256 r1 = int256(n);
        while (r1 != 0) {
            int256 q = r0 / r1;
            (r0, r1) = (r1, r0 - q * r1);
            (s0, s1) = (s1, s0 - q * s1);
        }
        if (r0 != 1) return 0;
        int256 invSigned = s0;
        if (invSigned < 0) invSigned += int256(n);
        return uint256(invSigned);
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
        // For prime p, inverse is a^(p-2) mod p
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
     * 
     * Steps:
     * 1. Attempt to compute the modular exponentiation using `tryModExp`.
     * 2. If the computation fails (e.g., due to division by zero), trigger a panic with the `Panic.DIVISION_BY_ZERO` error.
     * 3. Return the computed result if successful.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256 result) {
        (bool success, uint256 r) = tryModExp(b, e, m);
        require(success, "Math: modExp failed");
        return r;
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
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            // lengths
            mstore(ptr, 0x20) // len(b)
            mstore(add(ptr, 0x20), 0x20) // len(e)
            mstore(add(ptr, 0x40), 0x20) // len(m)
            // values
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)
            // call precompile 0x05
            success := staticcall(gas(), 0x05, ptr, 0xc0, add(ptr, 0xc0), 0x20)
            result := mload(add(ptr, 0xc0))
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
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory result) {
        (bool success, bytes memory r) = tryModExp(b, e, m);
        require(success, "Math: modExp failed");
        return r;
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
        if (m.length == 0 || _zeroBytes(m)) {
            return (false, bytes(""));
        }
        assembly {
            let ptr := mload(0x40)
            // store lengths
            mstore(ptr, mload(b))          // len(b)
            mstore(add(ptr, 0x20), mload(e)) // len(e)
            mstore(add(ptr, 0x40), mload(m)) // len(m)

            // copy b bytes
            let offset := add(ptr, 0x60)
            let bLen := mload(b)
            for { let i := 0 } lt(i, bLen) { i := add(i, 0x20) } {
                mstore(add(offset, i), mload(add(add(b, 0x20), i)))
            }
            // copy e bytes
            let eLen := mload(e)
            let eOffset := add(offset, mul(add(0, bLen), 1))
            // round up to 32 for offsets: compute aligned b size
            let bSize := mul(div(add(bLen, 0x1f), 0x20), 0x20)
            eOffset := add(offset, bSize)
            for { let i := 0 } lt(i, eLen) { i := add(i, 0x20) } {
                mstore(add(eOffset, i), mload(add(add(e, 0x20), i)))
            }
            // copy m bytes
            let mLen := mload(m)
            let mOffset := add(eOffset, mul(div(add(eLen, 0x1f), 0x20), 0x20))
            for { let i := 0 } lt(i, mLen) { i := add(i, 0x20) } {
                mstore(add(mOffset, i), mload(add(add(m, 0x20), i)))
            }

            // total input length = 96 + aligned b + aligned e + aligned m
            let inputLen := add(0x60, add(mul(div(add(bLen, 0x1f), 0x20), 0x20), add(mul(div(add(eLen, 0x1f), 0x20), 0x20), mul(div(add(mLen, 0x1f), 0x20), 0x20))))
            // output will be mLen bytes, place after input
            let outPtr := add(ptr, inputLen)
            // perform staticcall to precompile 0x05
            success := staticcall(gas(), 0x05, ptr, inputLen, outPtr, mLen)
            // set result to bytes memory with length mLen and copy
            result := mload(0x40)
            mstore(result, mLen)
            // copy output into result payload
            for { let i := 0 } lt(i, mLen) { i := add(i, 0x20) } {
                mstore(add(result, add(0x20, i)), mload(add(outPtr, i)))
            }
            // update free memory pointer
            mstore(0x40, add(result, add(0x20, mul(div(add(mLen, 0x1f), 0x20), 0x20))))
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
        uint256 len = byteArray.length;
        if (len == 0) return true;
        uint256 i = 0;
        // check 32 bytes at a time
        for (; i + 32 <= len; i += 32) {
            uint256 word;
            assembly {
                word := mload(add(byteArray, add(0x20, i)))
            }
            if (word != 0) return false;
        }
        // tail
        if (i < len) {
            uint256 mask;
            assembly {
                mask := not(sub(exp(256, sub(32, sub(len, i))), 1))
            }
            uint256 word;
            assembly {
                word := and(mload(add(byteArray, add(0x20, i))), mask)
            }
            if (word != 0) return false;
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
        if (a == 0) return 0;
        // initial guess: 1 << (floor(log2(a)) / 2)
        uint256 x = 1 << (log2(a) >> 1);
        // Newton iterations (enough to converge for 256-bit numbers)
        unchecked {
            for (uint8 i = 0; i < 7; i++) {
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
        uint256 base = sqrt(a);
        if (unsignedRoundsUp(rounding) && base * base < a) {
            unchecked {
                return base + 1;
            }
        }
        return base;
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
        if (x == 0) return 0;
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
                // x >>= 1;
                r += 1;
            }
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
        uint256 r = log2(value);
        if (unsignedRoundsUp(rounding) && (1 << r) < value) {
            unchecked {
                return r + 1;
            }
        }
        return r;
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
        uint256 r = log10(value);
        if (unsignedRoundsUp(rounding)) {
            // check if 10^r < value for rounding up
            uint256 pow10 = _pow10(r);
            if (pow10 < value) {
                unchecked {
                    return r + 1;
                }
            }
        }
        return r;
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
        if (x == 0) return 0;
        while (x >> 8 != 0) {
            x >>= 8;
            r++;
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
        uint256 r = log256(value);
        if (unsignedRoundsUp(rounding)) {
            // check if 256^r < value
            uint256 pow = 1;
            for (uint256 i = 0; i < r; i++) {
                pow *= 256;
            }
            if (pow < value) {
                unchecked {
                    return r + 1;
                }
            }
        }
        return r;
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
        return (uint256(rounding) & 1) == 1;
    }

    /* ===========================
       Internal helper functions
       =========================== */

    // compute integer log2 of a power-of-two-aligned value (helper)
    function _log2(uint256 x) private pure returns (uint256 r) {
        // returns floor(log2(x))
        if (x == 0) return 0;
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
                r += 2;
            }
            if (x >> 1 > 0) {
                r += 1;
            }
        }
    }

    // modular inverse for odd denominator modulo 2^256 using Newton-Raphson
    function _modInverse(uint256 d) private pure returns (uint256 inv) {
        // Initial approximation
        inv = (3 * d) ^ 2;
        // Newton iterations to improve inverse modulo 2^256
        unchecked {
            inv = inv * (2 - d * inv);
            inv = inv * (2 - d * inv);
            inv = inv * (2 - d * inv);
            inv = inv * (2 - d * inv);
            inv = inv * (2 - d * inv);
            inv = inv * (2 - d * inv);
        }
    }

    // compute 10^exp (small exponent) - used only for rounding checks
    function _pow10(uint256 exp) private pure returns (uint256 r) {
        r = 1;
        for (uint256 i = 0; i < exp; ++i) {
            r *= 10;
        }
    }
}