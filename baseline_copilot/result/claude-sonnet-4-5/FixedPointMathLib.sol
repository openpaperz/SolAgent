// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library FixedPointMathLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error MulWadFailed();
    error SMulWadFailed();
    error DivWadFailed();
    error SDivWadFailed();
    error FullMulDivFailed();
    error MulDivFailed();
    error ExpOverflow();
    error LnWadUndefined();
    error OutOfDomain();
    error MantissaOverflow();
    error DivFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 internal constant WAD = 1e18;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  FIXED POINT OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if mul(y, gt(x, div(not(0), y))) {
                mstore(0x00, 0xbac65e5b)
                revert(0x1c, 0x04)
            }
            z := div(mul(x, y), WAD)
        }
    }

    function sMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            if iszero(or(iszero(x), eq(sdiv(z, x), y))) {
                mstore(0x00, 0xedcd4dd4)
                revert(0x1c, 0x04)
            }
            if and(iszero(iszero(shr(255, x))), eq(y, not(0))) {
                mstore(0x00, 0xedcd4dd4)
                revert(0x1c, 0x04)
            }
            z := sdiv(z, WAD)
        }
    }

    function rawMulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, y), WAD)
        }
    }

    function rawSMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, y), WAD)
        }
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            if iszero(or(iszero(x), eq(div(z, x), y))) {
                mstore(0x00, 0xbac65e5b)
                revert(0x1c, 0x04)
            }
            z := add(div(z, WAD), gt(mod(z, WAD), 0))
        }
    }

    function rawMulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            z := add(div(z, WAD), gt(mod(z, WAD), 0))
        }
    }

    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if or(iszero(y), gt(x, div(not(0), WAD))) {
                mstore(0x00, 0x7c5f487d)
                revert(0x1c, 0x04)
            }
            z := div(mul(x, WAD), y)
        }
    }

    function sDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, WAD)
            if iszero(and(iszero(iszero(y)), or(iszero(x), eq(sdiv(z, x), WAD)))) {
                mstore(0x00, 0x5c43740e)
                revert(0x1c, 0x04)
            }
            z := sdiv(z, y)
        }
    }

    function rawDivWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, WAD), y)
        }
    }

    function rawSDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, WAD), y)
        }
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if or(iszero(y), gt(x, div(not(0), WAD))) {
                mstore(0x00, 0x7c5f487d)
                revert(0x1c, 0x04)
            }
            z := mul(x, WAD)
            z := add(div(z, y), gt(mod(z, y), 0))
        }
    }

    function rawDivWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, WAD)
            z := add(div(z, y), gt(mod(z, y), 0))
        }
    }

    function powWad(int256 x, int256 y) internal pure returns (int256) {
        unchecked {
            return expWad((lnWad(x) * y) / int256(WAD));
        }
    }

    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            if (x <= -41446531673892822313) return 0;
            if (x >= 135305999368893231589) revert ExpOverflow();

            x = (x << 78) / 5 ** 18;

            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >> 96;
            x = x - k * 54916777467707473351141471128;

            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);

            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;

            /// @solidity memory-safe-assembly
            assembly {
                r := sdiv(p, q)
            }

            r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
        }
    }

    function lnWad(int256 x) internal pure returns (int256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            if slt(x, 0) {
                mstore(0x00, 0x1615e638)
                revert(0x1c, 0x04)
            }

            let s := 159
            let k := mul(slt(x, shl(s, 1)), s)
            r := sub(k, 96)
            x := shl(k, x)

            let f := shl(7, gt(x, 0x8000000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := shl(6, gt(x, 0xC000000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := shl(5, gt(x, 0xE000000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := shl(4, gt(x, 0xF000000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := shl(3, gt(x, 0xF800000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := shl(2, gt(x, 0xFC00000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := shl(1, gt(x, 0xFE00000000000000000000000000000000000000000000000000000000000000))
            x := shr(f, x)
            r := or(r, f)

            f := gt(x, 0xFF00000000000000000000000000000000000000000000000000000000000000)
            r := or(r, f)

            let z := mul(sub(x, 0x100000000000000000000000000000000000000000000000000000000000000), sub(x, 0xFF00000000000000000000000000000000000000000000000000000000000000))
            let p := add(z, 0x1C31E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := add(shr(96, mul(p, z)), 0x1B27E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := add(shr(96, mul(p, z)), 0x1A2DE83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := add(shr(96, mul(p, z)), 0x1947E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := add(shr(96, mul(p, z)), 0x186DE83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := add(shr(96, mul(p, z)), 0x179DE83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := add(shr(96, mul(p, z)), 0x16D7E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            p := mul(p, z)

            let q := add(z, 0x1E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x1D91E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x1CB3E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x1BE7E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x1B27E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x1A73E83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x19CBE83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)
            q := add(shr(96, mul(q, z)), 0x192FE83C7F3E17CFBF9A3E8B7D8E8ED1C08C8B9D)

            r := sub(shl(96, r), div(shl(192, 1), q))
            r := add(r, div(p, q))
            r := mul(1677202110996718588342820967067443963516166, add(r, 291339464771989622907027621153398088495))
            r := shr(128, r)
        }
    }

    function lambertW0Wad(int256 x) internal pure returns (int256 w) {
        unchecked {
            if (x < -367879441171442322) revert OutOfDomain();

            int256 wad = int256(WAD);
            int256 p = x;
            uint256 c;
            uint256 i = 4;

            if (x >= 0) {
                if (x <= wad * 2) {
                    i = 1;
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        let s := 159
                        let k := mul(slt(x, shl(s, 1)), s)
                        i := or(shl(3, iszero(k)), shr(sub(249, k), x))
                    }
                    i = (i * i * i) >> 96;
                    i = (i * i * i * 93) >> 96;
                    i = i >> 5;
                }
            } else {
                w = -1000000000000000000;
                if (x <= -330000000000000000) {
                    i = 32;
                }
            }

            for (; i != 0; --i) {
                int256 e = expWad(w);
                int256 t = w * wad + wad - e * wad / (wad + e * wad / (wad + wad));
                if (w <= -wad + 1 && e <= wad * 2) {
                    t = (wad * (e * (w + wad)) - e + wad) / (e * (w + wad) + wad);
                }
                c |= uint256(int256(w ^ p) >> 255);
                w = w - (w - wad * x / e - t) / ((w + wad * (1 + e)) / (1 + e) + t * (w - wad) / (wad + wad * e / (wad + e)));
                if (c == (c & 1) && w == p) break;
                p = w;
            }

            if (w >= -367879441171442322) return w;
            revert OutOfDomain();
        }
    }

    function fullMulEq(uint256 a, uint256 b, uint256 x, uint256 y) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(eq(mul(a, b), mul(x, y)), eq(mulmod(a, b, not(0)), mulmod(x, y, not(0))))
        }
    }

    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            let p1 := mulmod(x, y, not(0))
            p1 := sub(sub(p1, z), lt(p1, z))

            if p1 {
                if iszero(or(d, gt(d, p1))) {
                    mstore(0x00, 0xae47f702)
                    revert(0x1c, 0x04)
                }

                let r := mulmod(x, y, d)
                let t := and(d, sub(0, d))
                d := div(d, t)
                z := div(z, t)
                t := add(div(sub(0, t), t), 1)

                z := sub(z, mul(p1, t))
                p1 := mul(p1, d)

                let inv := xor(mul(3, d), 2)
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))

                z := add(mul(add(z, r), inv), mul(p1, inv))
            }

            if iszero(p1) {
                if iszero(d) {
                    mstore(0x00, 0xae47f702)
                    revert(0x1c, 0x04)
                }
                z := div(z, d)
            }
        }
    }

    function fullMulDivUnchecked(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            let mm := mulmod(x, y, not(0))
            let p1 := sub(sub(mm, z), lt(mm, z))

            let t := and(d, sub(0, d))
            let r := mulmod(x, y, d)
            d := div(d, t)
            z := div(z, t)
            t := add(div(sub(0, t), t), 1)

            z := sub(z, mul(p1, t))
            p1 := mul(p1, d)

            let inv := xor(mul(3, d), 2)
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))

            z := add(mul(add(z, r), inv), mul(p1, inv))
        }
    }

    function fullMulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        z = fullMulDiv(x, y, d);
        /// @solidity memory-safe-assembly
        assembly {
            if mulmod(x, y, d) {
                z := add(z, 1)
                if iszero(z) {
                    mstore(0x00, 0xae47f702)
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    function fullMulDivN(uint256 x, uint256 y, uint8 n) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            if iszero(or(iszero(x), eq(div(z, x), y))) {
                let p1 := mulmod(x, y, not(0))
                p1 := sub(sub(p1, z), lt(p1, z))
                if n {
                    z := or(shl(sub(256, n), p1), shr(n, z))
                    if shr(sub(256, n), p1) {
                        mstore(0x00, 0xae47f702)
                        revert(0x1c, 0x04)
                    }
                }
            }
            if iszero(n) {
                z := shr(n, z)
            }
        }
    }

    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            if iszero(or(iszero(x), eq(div(z, x), y))) {
                mstore(0x00, 0xad251c27)
                revert(0x1c, 0x04)
            }
            if iszero(d) {
                mstore(0x00, 0xad251c27)
                revert(0x1c, 0x04)
            }
            z := div(z, d)
        }
    }

    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            if iszero(d) {
                mstore(0x00, 0xad251c27)
                revert(0x1c, 0x04)
            }
            if iszero(or(iszero(x), eq(div(z, x), y))) {
                mstore(0x00, 0xad251c27)
                revert(0x1c, 0x04)
            }
            z := add(div(z, d), gt(mod(z, d), 0))
        }
    }

    function invMod(uint256 a, uint256 n) internal pure returns (uint256 x) {
        unchecked {
            /// @solidity memory-safe-assembly
            assembly {
                let g := n
                let r := mod(a, n)
                x := 1
                for {} r {} {
                    let t := r
                    r := mod(g, r)
                    g := t
                    let q := div(g, t)
                    let y := x
                    x := sub(g, mul(q, x))
                    if iszero(r) { break }
                    g := x
                    x := y
                }
                if eq(g, 1) {
                    if slt(x, 0) {
                        x := add(x, n)
                    }
                }
                if iszero(eq(g, 1)) {
                    x := 0
                }
            }
        }
    }

    function divUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0x65244e4e)
                revert(0x1c, 0x04)
            }
            z := add(div(x, d), gt(mod(x, d), 0))
        }
    }

    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    function ternary(bool condition, uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), condition))
        }
    }

    function ternary(bool condition, bytes32 x, bytes32 y) internal pure returns (bytes32 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), condition))
        }
    }

    function ternary(bool condition, address x, address y) internal pure returns (address z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(y, mul(xor(x, y), condition))
        }
    }

    function rpow(uint256 x, uint256 y, uint256 b) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(b, iszero(y))

            if x {
                z := xor(b, mul(xor(b, x), and(y, 1)))
                let half := shr(1, b)

                for {
                    y := shr(1, y)
                } y {
                    y := shr(1, y)
                } {
                    let xx := mul(x, x)
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        mstore(0x00, 0x49f7642c)
                        revert(0x1c, 0x04)
                    }
                    x := div(xxRound, b)

                    if and(y, 1) {
                        let zx := mul(z, x)
                        if iszero(eq(div(zx, x), z)) {
                            if iszero(iszero(x)) {
                                mstore(0x00, 0x49f7642c)
                                revert(0x1c, 0x04)
                            }
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            mstore(0x00, 0x49f7642c)
                            revert(0x1c, 0x04)
                        }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := 181

            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffffff, shr(r, x))))
            z := shl(shr(1, r), z)

            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            z := sub(z, lt(div(x, z), z))
        }
    }

    function cbrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))

            z := div(shl(div(r, 3), shl(lt(0xf, shr(r, x)), 0xf)), xor(7, mod(r, 3)))

            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)

            z := sub(z, lt(div(x, mul(z, z)), z))
        }
    }

    function sqrtWad(uint256 x) internal pure returns (uint256 z) {
        unchecked {
            if (x <= type(uint256).max / 1e18) {
                z = sqrt(x * 1e18);
            } else {
                z = sqrt(x) * 1e9;
                z = (z * 1e9 + fullMulDivUnchecked(x, 1e9, z)) >> 1;
            }
            /// @solidity memory-safe-assembly
            assembly {
                z := sub(z, gt(mulmod(z, z, x), 0))
            }
        }
    }

    function cbrtWad(uint256 x) internal pure returns (uint256 z) {
        unchecked {
            if (x <= type(uint256).max / 1e36) {
                z = cbrt(x * 1e36);
            } else {
                z = cbrt(x);
                /// @solidity memory-safe-assembly
                assembly {
                    let f := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
                    z := shl(div(f, 3), z)
                }
                z = (z * 1e12 + (z * z * 1e12 + fullMulDivUnchecked(x, 1e24, z)) / z) / 3;
            }
            /// @solidity memory-safe-assembly
            assembly {
                let t := mul(z, z)
                z := sub(z, gt(mulmod(t, z, x), 0))
            }
        }
    }

    function factorial(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := 1
            if iszero(lt(x, 58)) {
                mstore(0x00, 0xf991a1c7)
                revert(0x1c, 0x04)
            }
            for {} x {} {
                z := mul(z, x)
                x := sub(x, 1)
            }
        }
    }

    function log2(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }
    }

    function log2Up(uint256 x) internal pure returns (uint256 r) {
        r = log2(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(shl(r, 1), x))
        }
    }

    function log10(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(x, 100000000000000000000000000000000000000)) {
                x := div(x, 100000000000000000000000000000000000000)
                r := 38
            }
            if iszero(lt(x, 100000000000000000000)) {
                x := div(x, 100000000000000000000)
                r := add(r, 20)
            }
            if iszero(lt(x, 10000000000)) {
                x := div(x, 10000000000)
                r := add(r, 10)
            }
            if iszero(lt(x, 100000)) {
                x := div(x, 100000)
                r := add(r, 5)
            }
            r := add(r, add(gt(x, 9), add(gt(x, 99), add(gt(x, 999), gt(x, 9999)))))
        }
    }

    function log10Up(uint256 x) internal pure returns (uint256 r) {
        r = log10(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(exp(10, r), x))
        }
    }

    function log256(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := shr(3, r)
        }
    }

    function log256Up(uint256 x) internal pure returns (uint256 r) {
        r = log256(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(shl(shl(3, r), 1), x))
        }
    }

    function sci(uint256 x) internal pure returns (uint256 mantissa, uint256 exponent) {
        /// @solidity memory-safe-assembly
        assembly {
            mantissa := x
            if mantissa {
                if iszero(mod(mantissa, 1000000000000000000000000000000000)) {
                    mantissa := div(mantissa, 1000000000000000000000000000000000)
                    exponent := 33
                }
                if iszero(mod(mantissa, 10000000000000000000)) {
                    mantissa := div(mantissa, 10000000000000000000)
                    exponent := add(exponent, 19)
                }
                if iszero(mod(mantissa, 1000000000000)) {
                    mantissa := div(mantissa, 1000000000000)
                    exponent := add(exponent, 12)
                }
                if iszero(mod(mantissa, 1000000)) {
                    mantissa := div(mantissa, 1000000)
                    exponent := add(exponent, 6)
                }
                if iszero(mod(mantissa, 10000)) {
                    mantissa := div(mantissa, 10000)
                    exponent := add(exponent, 4)
                }
                if iszero(mod(mantissa, 100)) {
                    mantissa := div(mantissa, 100)
                    exponent := add(exponent, 2)
                }
                if iszero(mod(mantissa, 10)) {
                    mantissa := div(mantissa, 10)
                    exponent := add(exponent, 1)
                }
            }
        }
    }

    function packSci(uint256 x) internal pure returns (uint256 packed) {
        (uint256 mantissa, uint256 exponent) = sci(x);
        /// @solidity memory-safe-assembly
        assembly {
            if shr(249, mantissa) {
                mstore(0x00, 0xd0eb7a09)
                revert(0x1c, 0x04)
            }
            packed := or(shl(7, mantissa), and(exponent, 0x7f))
        }
    }

    function unpackSci(uint256 packed) internal pure returns (uint256 unpacked) {
        unchecked {
            unpacked = (packed >> 7) * (10 ** (packed & 0x7f));
        }
    }

    function avg(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }

    function avg(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }

    function abs(int256 x) internal pure returns (uint256 z) {
        unchecked {
            z = uint256(x + (x >> 255)) ^ uint256(x >> 255);
        }
    }

    function dist(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(mul(xor(sub(y, x), sub(x, y)), gt(x, y)), sub(y, x))
        }
    }

    function dist(int256 x, int256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(mul(xor(sub(y, x), sub(x, y)), sgt(x, y)), sub(y, x))
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    function min(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), slt(y, x)))
        }
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    function max(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), sgt(y, x)))
        }
    }

    function clamp(uint256 x, uint256 minValue, uint256 maxValue) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), lt(x, minValue)))
            z := xor(z, mul(xor(z, maxValue), gt(z, maxValue)))
        }
    }

    function clamp(int256 x, int256 minValue, int256 maxValue) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), slt(x, minValue)))
            z := xor(z, mul(xor(z, maxValue), sgt(z, maxValue)))
        }
    }

    function gcd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := x
            for {} y {} {
                let t := y
                y := mod(z, y)
                z := t
            }
        }
    }

    function lerp(uint256 a, uint256 b, uint256 t, uint256 begin, uint256 end) internal pure returns (uint256) {
        unchecked {
            if (begin > end) {
                (t, begin, end) = (~t, ~end, ~begin);
            }
            if (t <= begin) return a;
            if (t >= end) return b;
            if (b >= a) return a + fullMulDiv(b - a, t - begin, end - begin);
            return a - fullMulDiv(a - b, t - begin, end - begin);
        }
    }

    function lerp(int256 a, int256 b, int256 t, int256 begin, int256 end) internal pure returns (int256) {
        unchecked {
            if (begin > end) {
                (t, begin, end) = (~t, ~end, ~begin);
            }
            if (t <= begin) return a;
            if (t >= end) return b;
            if (b >= a) {
                return a + int256(fullMulDiv(uint256(b - a), uint256(t - begin), uint256(end - begin)));
            }
            return a - int256(fullMulDiv(uint256(a - b), uint256(t - begin), uint256(end - begin)));
        }
    }

    function isEven(uint256 x) internal pure returns (bool) {
        return (x & 1) == 0;
    }

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
