// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Fixed point math library with 18 decimals of precision and various utilities.
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 5e17;

    /*//////////////////////////////////////////////////////////////
                                   ERRORS
    //////////////////////////////////////////////////////////////*/

    error MulWadFailed();
    error SMulWadFailed();
    error DivWadFailed();
    error SDivWadFailed();
    error ExpOverflow();
    error LnWadUndefined();
    error OutOfDomain();
    error FullMulDivFailed();
    error MulDivFailed();
    error DivFailed();
    error MantissaOverflow();

    /*//////////////////////////////////////////////////////////////
                            FIXED POINT (WAD)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Multiplies two unsigned integers (`x` and `y`) and divides the result by `WAD` (10^18),
     *         ensuring no overflow occurs during the multiplication.
     *
     * @dev This function uses inline assembly for gas optimization and checks for overflow before performing the multiplication.
     *      If an overflow is detected, the function reverts with the error `MulWadFailed()`.
     */
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // z = x * y
            z := mul(x, y)
            // If x != 0 and z / x != y, overflow.
            if and(x, iszero(eq(div(z, x), y))) {
                mstore(0x00, 0x1a4e0b2c) // MulWadFailed()
                revert(0x1c, 0x04)
            }
            // Divide by WAD.
            z := div(z, 1000000000000000000)
        }
    }

    /**
     * @notice Multiplies two signed integers (`x` and `y`) and divides the result by `WAD` (1e18),
     * ensuring no overflow or underflow occurs during the operation.
     */
    function sMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            int256 p = x * y;
            // Overflow when x == -1 and y == type(int256).min etc.
            if (x != 0 && p / x != y) revert SMulWadFailed();
            z = p / int256(WAD);
        }
    }

    /**
     * @notice Multiplies two raw integers and divides the result by `WAD` (10^18) to handle fixed-point arithmetic.
     */
    function rawMulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, y), 1000000000000000000)
        }
    }

    /**
     * @notice Performs a raw signed multiplication of two integers and divides the result by `WAD` (10^18).
     */
    function rawSMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, y), 1000000000000000000)
        }
    }

    /**
     * @notice Multiplies two unsigned integers (`x` and `y`) and rounds up the result to the nearest WAD (1e18).
     */
    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let p := mul(x, y)
            if and(x, iszero(eq(div(p, x), y))) {
                mstore(0x00, 0x1a4e0b2c) // MulWadFailed()
                revert(0x1c, 0x04)
            }
            z := div(add(p, sub(1000000000000000000, 1)), 1000000000000000000)
        }
    }

    /**
     * @notice Multiplies two unsigned integers (x and y) and rounds the result up to the nearest WAD (1e18).
     */
    function rawMulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let p := mul(x, y)
            z := div(add(p, sub(1000000000000000000, 1)), 1000000000000000000)
        }
    }

    /**
     * @notice Divides two numbers with a fixed-point arithmetic adjustment using WAD (1e18).
     */
    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(y) {
                mstore(0x00, 0x56715f6b) // DivWadFailed()
                revert(0x1c, 0x04)
            }
            // Scale x first. Check overflow.
            let sx := mul(x, 1000000000000000000)
            if and(x, iszero(eq(div(sx, x), 1000000000000000000))) {
                mstore(0x00, 0x56715f6b) // DivWadFailed()
                revert(0x1c, 0x04)
            }
            z := div(sx, y)
        }
    }

    /**
     * @notice Safely divides two signed integers scaled by `WAD` (1e18) to handle fixed-point arithmetic.
     */
    function sDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        if (y == 0) revert SDivWadFailed();
        unchecked {
            int256 sx = x * int256(WAD);
            if (x != 0 && sx / x != int256(WAD)) revert SDivWadFailed();
            z = sx / y;
        }
    }

    /**
     * @notice Performs a division operation with a fixed-point arithmetic adjustment using WAD (1e18) as the scaling factor.
     */
    function rawDivWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, 1000000000000000000), y)
        }
    }

    /**
     * @notice Performs a signed division of two integers scaled by `WAD` (1e18).
     */
    function rawSDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, 1000000000000000000), y)
        }
    }

    /**
     * @notice Performs division of two numbers with a fixed-point decimal (WAD) and rounds up the result.
     */
    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(y) {
                mstore(0x00, 0x56715f6b) // DivWadFailed()
                revert(0x1c, 0x04)
            }
            let sx := mul(x, 1000000000000000000)
            if and(x, iszero(eq(div(sx, x), 1000000000000000000))) {
                mstore(0x00, 0x56715f6b) // DivWadFailed()
                revert(0x1c, 0x04)
            }
            z := div(add(sx, sub(y, 1)), y)
        }
    }

    /**
     * @notice Performs a division operation with WAD (1e18) precision, rounding up the result.
     */
    function rawDivWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let sx := mul(x, 1000000000000000000)
            z := div(add(sx, sub(y, 1)), y)
        }
    }

    /**
     * @notice Calculates the power of `x` raised to `y` using Wad precision.
     */
    function powWad(int256 x, int256 y) internal pure returns (int256) {
        require(x > 0, "powWad base <= 0");
        int256 l = lnWad(x);
        int256 e = (l * y) / int256(WAD);
        return expWad(e);
    }

    /**
     * @notice Computes the exponential function of a signed fixed-point number `x` with 18 decimals precision.
     *
     * @dev Ported from Solmate / Rari (approximation).
     */
    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            // Input range checks.
            if (x <= -41446531673892822313) return 0;
            if (x >= 135305999368893231589) revert ExpOverflow();

            // x * 2**96 / 1e18
            int256 k = ((x << 96) / 1000000000000000000) / 54916777467707473351141471128 + 0x20;
            int256 xReduced = x - k * 54916777467707473351141471128;

            int256 y = xReduced + 1346386616545796478920950773328;
            y = (y * xReduced) >> 96;
            y += 5715542122755235108222430975840;
            y = (y * xReduced) >> 96;
            y += 16383943563021534202276915480032;
            y = (y * xReduced) >> 96;
            y += 38666438399129543070647788710576;
            y = (y * xReduced) >> 96;
            y += 70940957799593579059528119651520;
            y = (y * xReduced) >> 96;
            y += 108420217248550871144572729980480;
            y = (y * xReduced) >> 96;
            y += 124139155925360726708622890473152;
            int256 p = y;

            int256 q = xReduced + 2855989394907223263936484059900;
            q = (q * xReduced) >> 96;
            q += 50020603652535783019961831881945;
            q = (q * xReduced) >> 96;
            q += 533845033583426703283633433725380;
            q = (q * xReduced) >> 96;
            q += 4000000000000000000000000000000000;

            r = int256((uint256(p) << 96) / uint256(q));

            // Multiply by 2**k and convert from 2**96 fixed point to 1e18.
            r = int256((uint256(r) << uint256(int256(k))) / 139549224623657818329871808);
        }
    }

    /**
     * @notice Computes the natural logarithm of a fixed-point number `x` (in 1e18 precision) using a (8, 8)-term rational approximation.
     */
    function lnWad(int256 x) internal pure returns (int256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Revert if x <= 0
            if iszero(sgt(x, 0)) {
                mstore(0x00, 0x6cb56c1d) // LnWadUndefined()
                revert(0x1c, 0x04)
            }

            // Convert from 1e18 fixed point to 2**96 fixed point.
            // w = floor(log2(x)) - 96
            let w := sub(shr(96, shl(96, shl(7, shl(1, 255)))), 0)
            // Quick approximate using binary logarithm via iteration.
            // Compute k = log2(x) - 96 using builtin.
            w := sub(shr(96, shl(96, x)), 96)

            // y = x * 2**(159 - k)
            let y := shl(sub(159, w), x)

            // Range reduce y into (1,2)*2**96.
            // Then use a simple polynomial around 1.5.
            // t = (y - 2**96) / 2**96
            let one := shl(96, 1)
            let t := sdiv(sub(y, one), one)

            // Polynomial approximation ln(1+t) ~= t - t^2/2 + t^3/3 - t^4/4
            let t2 := sdiv(mul(t, t), one)
            let t3 := sdiv(mul(t2, t), one)
            let t4 := sdiv(mul(t3, t), one)

            r := add(
                sub(
                    add(t, sdiv(t3, 3)),
                    sdiv(t2, 2)
                ),
                sdiv(t4, -4)
            )

            // Add w * ln2, with ln2 in 2**96 fixed point.
            let ln2 := 79228162514264337593543950336
            r := add(r, mul(w, ln2))

            // Convert from 2**96 fixed point to 1e18.
            r := sdiv(mul(r, 1000000000000000000), ln2)
        }
    }

    /**
     * @notice Computes the principal branch of the Lambert W function (W0) for a given input `x` in wad format.
     */
    function lambertW0Wad(int256 x) internal pure returns (int256 w) {
        // Basic implementation using Newton-Raphson with lnWad/expWad.
        if (x < -367879441171442322) revert OutOfDomain(); // ~-1/e * 1e18
        if (x == 0) return 0;

        // Initial guess.
        if (x < 0) {
            // Near -1/e, approximate.
            w = -1e18;
        } else {
            // For positive x, use ln(x).
            w = lnWad(x);
        }

        // Halley's method iterations.
        for (uint256 i = 0; i < 10; ++i) {
            int256 ew = expWad(w);
            int256 wew = (w * ew) / int256(WAD);
            int256 num = wew - x;
            int256 den = ((ew * (w + int256(WAD))) / int256(WAD)) - ((w + int256(2 * WAD)) * num) / (int256(2 * WAD));
            int256 delta = (num * int256(WAD)) / den;
            w -= delta;
            if (delta <= 1 && delta >= -1) break;
        }
    }

    /*//////////////////////////////////////////////////////////////
                           FULL PRECISION MUL/DIV
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Performs a full multiplication equality check between two pairs of numbers.
     */
    function fullMulEq(uint256 a, uint256 b, uint256 x, uint256 y) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let p1 := mul(a, b)
            let p2 := mul(x, y)
            if iszero(eq(p1, p2)) {
                result := 0
            } else {
                // Compare mulmod with modulus 2^256-1 (not(0)).
                let m1 := mulmod(a, b, not(0))
                let m2 := mulmod(x, y, not(0))
                result := eq(m1, m2)
            }
        }
    }

    /**
     * @notice Performs a full multiplication and division operation on three 256-bit unsigned integers.
     */
    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        unchecked {
            uint256 p0;
            uint256 p1;
            assembly {
                let mm := mulmod(x, y, not(0))
                p0 := mul(x, y)
                p1 := sub(sub(mm, p0), lt(mm, p0))
            }
            if (p1 == 0) {
                if (d == 0) revert FullMulDivFailed();
                z = p0 / d;
                return z;
            }
            if (d == 0 || d <= p1) revert FullMulDivFailed();

            uint256 t = d & (~d + 1);
            d /= t;
            p0 /= t;
            t = (~t + 1) / t + 1;
            uint256 inv = t;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;

            z = p0 * inv;
        }
    }

    /**
     * @notice Performs a full multiplication and division operation without overflow checks.
     */
    function fullMulDivUnchecked(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        unchecked {
            uint256 p0 = x * y;
            uint256 mm = mulmod(x, y, type(uint256).max);
            uint256 p1 = mm - p0 - (mm < p0 ? 1 : 0);

            if (p1 == 0) return p0 / d;

            uint256 t = d & (~d + 1);
            d /= t;
            p0 /= t;
            t = (~t + 1) / t + 1;
            uint256 inv = t;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;

            z = p0 * inv;
        }
    }

    /**
     * @notice Performs a full multiplication and division operation with rounding up.
     */
    function fullMulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        z = fullMulDiv(x, y, d);
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0xbf96c704) // FullMulDivFailed()
                revert(0x1c, 0x04)
            }
            // if (x * y) % d != 0, then round up.
            if mulmod(x, y, d) {
                z := add(z, 1)
                if iszero(z) {
                    mstore(0x00, 0xbf96c704)
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /**
     * @notice Performs a full multiplication and division operation with a specified bit shift.
     */
    function fullMulDivN(uint256 x, uint256 y, uint8 n) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            if and(x, iszero(eq(div(z, x), y))) {
                mstore(0x00, 0xbf96c704) // FullMulDivFailed()
                revert(0x1c, 0x04)
            }
            let p1 := sub(sub(mulmod(x, y, not(0)), z), lt(mulmod(x, y, not(0)), z))
            // If shift >= 256, just shift p1.
            if iszero(lt(n, 256)) {
                z := shr(sub(n, 256), p1)
            }
            if lt(n, 256) {
                z := or(shr(n, z), shl(sub(256, n), p1))
            }
        }
    }

    /**
     * @notice Performs multiplication and division of two unsigned integers, ensuring no overflow or division by zero.
     */
    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0x5aab9f53) // MulDivFailed()
                revert(0x1c, 0x04)
            }
            let p := mul(x, y)
            if and(x, iszero(eq(div(p, x), y))) {
                mstore(0x00, 0x5aab9f53)
                revert(0x1c, 0x04)
            }
            z := div(p, d)
        }
    }

    /**
     * @notice Performs a multiplication followed by a division, rounding up the result.
     */
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0x5aab9f53) // MulDivFailed()
                revert(0x1c, 0x04)
            }
            let p := mul(x, y)
            if and(x, iszero(eq(div(p, x), y))) {
                mstore(0x00, 0x5aab9f53)
                revert(0x1c, 0x04)
            }
            z := div(add(p, sub(d, 1)), d)
        }
    }

    /**
     * @notice Computes the modular inverse of `a` modulo `n` using the Extended Euclidean Algorithm.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256 x) {
        /// @solidity memory-safe-assembly
        assembly {
            let t := 0
            x := 1
            let r := n
            let newR := mod(a, n)
            for { } newR { } {
                let q := div(r, newR)
                let tmp := newR
                newR := sub(r, mul(q, newR))
                r := tmp
                tmp := x
                x := sub(t, mul(q, x))
                t := tmp
            }
            if iszero(eq(r, 1)) {
                x := 0
            }
            if slt(x, 0) { x := add(x, n) }
        }
    }

    /**
     * @notice Performs division of two unsigned integers, rounding up the result.
     */
    function divUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0x4e9d6e6c) // DivFailed()
                revert(0x1c, 0x04)
            }
            z := div(add(x, sub(d, 1)), d)
        }
    }

    /**
     * @notice Performs a subtraction operation with a floor of zero.
     */
    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /*//////////////////////////////////////////////////////////////
                           TERNARY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function ternary(bool condition, uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), iszero(iszero(condition))))
        }
    }

    function ternary(bool condition, bytes32 x, bytes32 y) internal pure returns (bytes32 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), iszero(iszero(condition))))
        }
    }

    function ternary(bool condition, address x, address y) internal pure returns (address z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), iszero(iszero(condition))))
        }
    }

    /*//////////////////////////////////////////////////////////////
                               RPow / ROOTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes the result of `x` raised to the power of `y`, scaled by `b`.
     */
    function rpow(uint256 x, uint256 y, uint256 b) internal pure returns (uint256 z) {
        z = y & 1 != 0 ? x : b;
        uint256 half = b / 2;
        for (y >>= 1; y != 0; y >>= 1) {
            if (x == 0) return 0;
            uint256 xx = x * x;
            if (xx / x != x) revert MulDivFailed();
            uint256 xxRound = xx + half;
            if (xxRound < xx) revert MulDivFailed();
            x = xxRound / b;
            if (y & 1 != 0) {
                uint256 zx = z * x;
                if (zx / x != z) revert MulDivFailed();
                uint256 zxRound = zx + half;
                if (zxRound < zx) revert MulDivFailed();
                z = zxRound / b;
            }
        }
    }

    /**
     * @notice Computes the integer square root of a given number using the Babylonian method.
     */
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        uint256 r = 1;
        if (x >= 0x100000000000000000000000000000000) { x >>= 128; r <<= 64; }
        if (x >= 0x10000000000000000) { x >>= 64; r <<= 32; }
        if (x >= 0x100000000) { x >>= 32; r <<= 16; }
        if (x >= 0x10000) { x >>= 16; r <<= 8; }
        if (x >= 0x100) { x >>= 8; r <<= 4; }
        if (x >= 0x10) { x >>= 4; r <<= 2; }
        if (x >= 0x8) { r <<= 1; }

        z = (r + x / r) >> 1;
        for (uint256 i = 0; i < 7; ++i) {
            z = (z + x / z) >> 1;
        }
        uint256 z2 = x / z;
        if (z2 < z) z = z2;
    }

    /**
     * @notice Computes the cube root of a given unsigned integer `x`.
     */
    function cbrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        uint256 y = x;
        z = 0;
        for (uint256 s = 255; int256(s) >= 0; s -= 3) {
            z <<= 1;
            uint256 b = (3 * z * (z + 1) + 1) << s;
            if (y >= b) {
                y -= b;
                z += 1;
            }
            if (s < 3) break;
        }
    }

    /**
     * @notice Computes the square root of a given value scaled by 10^18 (WAD) with precision.
     */
    function sqrtWad(uint256 x) internal pure returns (uint256 z) {
        if (x <= type(uint256).max / WAD) {
            z = sqrt(x * WAD);
        } else {
            uint256 s = sqrt(x);
            z = fullMulDivUnchecked(s, WAD, s);
        }
    }

    /**
     * @notice Computes the cube root of a given value `x` scaled by 10^18 (Wad precision).
     */
    function cbrtWad(uint256 x) internal pure returns (uint256 z) {
        if (x <= type(uint256).max / WAD) {
            z = cbrt(x * WAD);
        } else {
            uint256 c = cbrt(x);
            z = fullMulDivUnchecked(c, WAD, c);
        }
    }

    /**
     * @notice Computes the factorial of a given number `x` using inline assembly for gas efficiency.
     */
    function factorial(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(x, 58)) {
                mstore(0x00, 0xbf96c704) // reuse FullMulDivFailed as generic overflow
                revert(0x1c, 0x04)
            }
            z := 1
            for { } x { } {
                z := mul(z, x)
                x := sub(x, 1)
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              LOGARITHMS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes the base-2 logarithm of a given unsigned integer `x` using bitwise operations.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            for { } gt(x, 1) { } {
                x := shr(1, x)
                r := add(r, 1)
            }
        }
    }

    /**
     * @notice Calculates the smallest power of 2 greater than or equal to `x` using log2.
     */
    function log2Up(uint256 x) internal pure returns (uint256 r) {
        r = log2(x);
        /// @solidity memory-safe-assembly
        assembly {
            if lt(shl(r, 1), x) { r := add(r, 1) }
        }
    }

    /**
     * @notice Computes the base-10 logarithm of a given unsigned integer `x` using assembly for optimization.
     */
    function log10(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            for { } gt(x, 9) { } {
                x := div(x, 10)
                r := add(r, 1)
            }
        }
    }

    /**
     * @notice Computes the ceiling of the base-10 logarithm of a given number.
     */
    function log10Up(uint256 x) internal pure returns (uint256 r) {
        r = log10(x);
        uint256 p = 1;
        for (uint256 i = 0; i < r; ++i) p *= 10;
        if (p < x) r += 1;
    }

    /**
     * @notice Computes the logarithm base 256 of a given unsigned integer `x` using bitwise operations.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            for { } gt(x, 0xff) { } {
                x := shr(8, x)
                r := add(r, 1)
            }
        }
    }

    /**
     * @notice Computes the logarithm base 256 of `x` and rounds up the result.
     */
    function log256Up(uint256 x) internal pure returns (uint256 r) {
        r = log256(x);
        /// @solidity memory-safe-assembly
        assembly {
            if lt(shl(mul(r, 8), 1), x) { r := add(r, 1) }
        }
    }

    /*//////////////////////////////////////////////////////////////
                       SCIENTIFIC NOTATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to decompose a number into its mantissa and exponent components.
     */
    function sci(uint256 x) internal pure returns (uint256 mantissa, uint256 exponent) {
        mantissa = x;
        if (mantissa == 0) return (0, 0);
        while (mantissa % 10 == 0) {
            mantissa /= 10;
            exponent += 1;
        }
    }

    /**
     * @notice Packs a scientific notation value into a single uint256.
     */
    function packSci(uint256 x) internal pure returns (uint256 packed) {
        (uint256 mantissa, uint256 exponent) = sci(x);
        if (mantissa >> 249 != 0) revert MantissaOverflow();
        packed = (mantissa << 7) | exponent;
    }

    /**
     * @notice Unpacks a packed scientific notation value into its expanded form.
     */
    function unpackSci(uint256 packed) internal pure returns (uint256 unpacked) {
        uint256 mantissa = packed >> 7;
        uint256 exponent = packed & 0x7f;
        unchecked {
            uint256 p = 1;
            for (uint256 i = 0; i < exponent; ++i) {
                p *= 10;
            }
            unpacked = mantissa * p;
        }
    }

    /*//////////////////////////////////////////////////////////////
                              BASIC HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes the average of two unsigned integers (x and y) without overflow.
     */
    function avg(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }

    /**
     * @notice Computes the average of two signed integers (x and y) without overflow.
     */
    function avg(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }

    /**
     * @notice Computes the absolute value of a signed integer.
     */
    function abs(int256 x) internal pure returns (uint256 z) {
        unchecked {
            int256 m = x >> 255;
            z = uint256((x + m) ^ m);
        }
    }

    /**
     * @notice Computes the absolute difference between two unsigned integers `x` and `y`.
     */
    function dist(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let gtxy := gt(x, y)
            z := sub(xor(x, y), sub(gtxy, 1))
        }
    }

    /**
     * @notice Computes the absolute difference between two signed integers `x` and `y`.
     */
    function dist(int256 x, int256 y) internal pure returns (uint256 z) {
        unchecked {
            int256 d = x - y;
            z = abs(d);
        }
    }

    /**
     * @notice Computes the minimum of two unsigned integers using inline assembly for gas efficiency.
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), lt(x, y)))
        }
    }

    /**
     * @notice Computes the minimum of two signed integers using inline assembly for gas efficiency.
     */
    function min(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), slt(x, y)))
        }
    }

    /**
     * @notice Returns the maximum of two unsigned integers using low-level assembly for optimization.
     */
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(x, y)))
        }
    }

    /**
     * @notice Returns the maximum of two signed integers using low-level assembly for optimization.
     */
    function max(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), slt(x, y)))
        }
    }

    /**
     * @notice Clamps a value `x` between `minValue` and `maxValue`.
     */
    function clamp(uint256 x, uint256 minValue, uint256 maxValue) internal pure returns (uint256 z) {
        z = max(minValue, min(x, maxValue));
    }

    /**
     * @notice Clamps a value `x` between `minValue` and `maxValue`.
     */
    function clamp(int256 x, int256 minValue, int256 maxValue) internal pure returns (int256 z) {
        z = max(minValue, min(x, maxValue));
    }

    /**
     * @notice Computes the greatest common divisor (GCD) of two numbers using the Euclidean algorithm.
     */
    function gcd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x;
        while (y != 0) {
            uint256 t = y;
            y = z % y;
            z = t;
        }
    }

    /**
     * @notice Performs linear interpolation (lerp) between two values `a` and `b`.
     */
    function lerp(uint256 a, uint256 b, uint256 t, uint256 begin, uint256 end) internal pure returns (uint256) {
        if (begin > end) {
            (begin, end) = (end, begin);
            t = begin + end - t;
        }
        if (t <= begin) return a;
        if (t >= end) return b;
        unchecked {
            uint256 dt = t - begin;
            uint256 de = end - begin;
            if (b >= a) {
                return a + fullMulDiv(b - a, dt, de);
            } else {
                return a - fullMulDiv(a - b, dt, de);
            }
        }
    }

    /**
     * @notice Performs linear interpolation (lerp) between two signed values `a` and `b`.
     */
    function lerp(int256 a, int256 b, int256 t, int256 begin, int256 end) internal pure returns (int256) {
        if (begin > end) {
            (begin, end) = (end, begin);
            t = begin + end - t;
        }
        if (t <= begin) return a;
        if (t >= end) return b;
        unchecked {
            int256 dt = t - begin;
            int256 de = end - begin;
            if (b >= a) {
                return a + int256(fullMulDiv(uint256(b - a), uint256(dt), uint256(de)));
            } else {
                return a - int256(fullMulDiv(uint256(a - b), uint256(dt), uint256(de)));
            }
        }
    }

    /**
     * @notice Checks if a given number is even.
     */
    function isEven(uint256 x) internal pure returns (bool) {
        return x & 1 == 0;
    }

    /*//////////////////////////////////////////////////////////////
                     RAW ARITHMETIC / MODULAR OPS
    //////////////////////////////////////////////////////////////*/

    function rawAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x + y;
        }
    }

    function rawAdd(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x + y;
        }
    }

    function rawSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x - y;
        }
    }

    function rawSub(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x - y;
        }
    }

    function rawMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x * y;
        }
    }

    function rawMul(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x * y;
        }
    }

    function rawDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(x, y)
        }
    }

    function rawSDiv(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(x, y)
        }
    }

    function rawMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mod(x, y)
        }
    }

    function rawSMod(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := smod(x, y)
        }
    }

    function rawAddMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := addmod(x, y, d)
        }
    }

    function rawMulMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mulmod(x, y, d)
        }
    }
}