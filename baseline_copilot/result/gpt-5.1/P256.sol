// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library P256 {
    // Curve parameters for secp256r1 / NIST P-256
    uint256 private constant A = 0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc;
    uint256 private constant B = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b;
    uint256 private constant P = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff;
    uint256 private constant N = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551;
    uint256 private constant HALF_N = (N >> 1) + 1;
    uint256 private constant GX = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    uint256 private constant GY = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

    /**
     * @notice Defines a struct named `JPoint` with three unsigned integer fields: `x`, `y`, and `z`.
     * This struct can be used to represent a point in 3D space or any other context requiring three numerical values.
     */
    struct JPoint {
        uint256 x;
        uint256 y;
        uint256 z;
    }

    /**
     * @notice Verifies a signature using either native or Solidity-based verification.
     *
     * @param h The hash of the message to be verified.
     * @param r The `r` component of the signature.
     * @param s The `s` component of the signature.
     * @param qx The x-coordinate of the public key.
     * @param qy The y-coordinate of the public key.
     * @return bool Returns `true` if the signature is valid, otherwise `false`.
     *
     * Steps:
     * 1. Attempt to verify the signature using native verification (`_tryVerifyNative`).
     * 2. If native verification is supported, return its result.
     * 3. If native verification is not supported, fall back to Solidity-based verification (`verifySolidity`).
     */
    function verify(bytes32 h, bytes32 r, bytes32 s, bytes32 qx, bytes32 qy) internal view returns (bool) {
        (bool valid, bool supported) = _tryVerifyNative(h, r, s, qx, qy);
        if (supported) {
            return valid;
        }
        return verifySolidity(h, r, s, qx, qy);
    }

    /**
     * @notice Verifies a native signature using the provided parameters.
     *
     * Steps:
     * 1. Calls `_tryVerifyNative` with the provided hash (`h`), signature components (`r`, `s`), and public key coordinates (`qx`, `qy`).
     * 2. Checks if the precompile is supported.
     * 3. If supported, returns the validity of the signature.
     * 4. If not supported, reverts with an error indicating the missing precompile at address `0x100`.
     */
    function verifyNative(bytes32 h, bytes32 r, bytes32 s, bytes32 qx, bytes32 qy) internal view returns (bool) {
        (bool valid, bool supported) = _tryVerifyNative(h, r, s, qx, qy);
        if (!supported) {
            revert("P256: missing precompile at 0x100");
        }
        return valid;
    }

    /**
     * @notice Attempts to verify a native signature using the provided parameters.
     *
     * @param h The hash of the message to be verified.
     * @param r The r component of the signature.
     * @param s The s component of the signature.
     * @param qx The x-coordinate of the public key.
     * @param qy The y-coordinate of the public key.
     *
     * @return valid A boolean indicating whether the signature is valid.
     * @return supported A boolean indicating whether the signature verification is supported.
     *
     * Steps:
     * 1. Check if the signature components (r, s) are valid and if the public key (qx, qy) is valid.
     * 2. If either check fails, return (false, true) indicating the signature is invalid but the precompile is supported.
     * 3. Otherwise, perform a static call to the native precompile at address 0x100 with the encoded parameters.
     * 4. If the call is successful and the return data length is 0x20, decode the result and return (valid, true).
     * 5. If the call fails or the return data length is not 0x20, return (false, false) indicating the signature is invalid and the precompile is not supported.
     */
    function _tryVerifyNative(
        bytes32 h,
        bytes32 r,
        bytes32 s,
        bytes32 qx,
        bytes32 qy
    ) private view returns (bool valid, bool supported) {
        if (!_isProperSignature(r, s) || !isValidPublicKey(qx, qy)) {
            return (false, true);
        }

        bytes memory input = abi.encodePacked(h, r, s, qx, qy);
        bytes memory output = new bytes(0x20);

        bool success;
        assembly {
            let inPtr := add(input, 0x20)
            let outPtr := add(output, 0x20)
            success := staticcall(gas(), 0x100, inPtr, mload(input), outPtr, 0x20)
        }

        if (!success || output.length != 0x20) {
            return (false, false);
        }

        uint256 res;
        assembly {
            res := mload(add(output, 0x20))
        }
        return (res != 0, true);
    }

    /**
     * @notice Verifies a Solidity-compatible ECDSA signature using the provided hash, signature components, and public key coordinates.
     *
     * @param h The hash of the message to be verified.
     * @param r The `r` component of the ECDSA signature.
     * @param s The `s` component of the ECDSA signature.
     * @param qx The x-coordinate of the public key.
     * @param qy The y-coordinate of the public key.
     *
     * @return bool Returns `true` if the signature is valid, otherwise `false`.
     *
     * Steps:
     * 1. Check if the signature components (`r` and `s`) are valid using `_isProperSignature`.
     * 2. Check if the public key coordinates (`qx` and `qy`) are valid using `isValidPublicKey`.
     * 3. If either check fails, return `false`.
     *
     * 4. Precompute Jacobian points for the public key coordinates.
     * 5. Compute the modular inverse of `s` modulo the curve order `N`.
     * 6. Calculate `u1` as the product of the hash `h` and the modular inverse `w`, modulo `N`.
     * 7. Calculate `u2` as the product of `r` and the modular inverse `w`, modulo `N`.
     * 8. Use the precomputed Jacobian points and `u1`, `u2` to compute the x-coordinate of the resulting point.
     * 9. Compare the computed x-coordinate modulo `N` with `r`. If they match, the signature is valid.
     */
    function verifySolidity(
        bytes32 h,
        bytes32 r,
        bytes32 s,
        bytes32 qx,
        bytes32 qy
    ) internal view returns (bool) {
        if (!_isProperSignature(r, s) || !isValidPublicKey(qx, qy)) {
            return false;
        }

        uint256 w = _invMod(uint256(s), N);
        uint256 u1 = mulmod(uint256(h), w, N);
        uint256 u2 = mulmod(uint256(r), w, N);

        JPoint[16] memory points = _preComputeJacobianPoints(uint256(qx), uint256(qy));
        (uint256 rx, ) = _jMultShamir(points, u1, u2);

        uint256 v = rx % N;
        return v == uint256(r);
    }

    /**
     * @notice Recovers the public key coordinates (x, y) from a given signature and hash using elliptic curve cryptography.
     *
     * @param h The hash of the message that was signed.
     * @param v The recovery byte of the signature (must be 0 or 1).
     * @param r The r component of the ECDSA signature.
     * @param s The s component of the ECDSA signature.
     * @return x The x-coordinate of the recovered public key.
     * @return y The y-coordinate of the recovered public key.
     *
     * Steps:
     * 1. Check if the signature components (r, s) are valid and if the recovery byte (v) is within the allowed range (0 or 1).
     *    If not, return (0, 0).
     * 2. Compute the y-coordinate of the point on the elliptic curve using the Weierstrass equation: y² = x³ + a.x + b.
     * 3. Use modular exponentiation to compute the square root of the y² value, ensuring it satisfies the curve equation.
     * 4. Perform a sanity check to ensure the computed y-coordinate is valid.
     * 5. Adjust the y-coordinate based on the recovery byte (v) to ensure it matches the correct parity.
     * 6. Precompute Jacobian points for efficient scalar multiplication.
     * 7. Compute the modular inverse of the r component.
     * 8. Calculate the intermediate values u1 and u2 using the hash, signature components, and modular arithmetic.
     * 9. Perform scalar multiplication using the precomputed Jacobian points and the intermediate values to recover the public key coordinates.
     * 10. Return the recovered public key coordinates (x, y).
     */
    function recovery(
        bytes32 h,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bytes32 x, bytes32 y) {
        if (!_isProperSignature(r, s) || (v != 0 && v != 1)) {
            return (bytes32(0), bytes32(0));
        }

        uint256 rx = uint256(r);
        if (rx == 0 || rx >= P) {
            return (bytes32(0), bytes32(0));
        }

        // Compute y^2 = x^3 + a*x + b (mod P)
        uint256 x3 = mulmod(mulmod(rx, rx, P), rx, P);
        uint256 ax = mulmod(A, rx, P);
        uint256 rhs = addmod(addmod(x3, ax, P), B, P);

        // y = sqrt(rhs) mod P
        uint256 y1 = _sqrtMod(rhs);
        if (mulmod(y1, y1, P) != rhs) {
            return (bytes32(0), bytes32(0));
        }

        uint256 yCandidate = y1;
        // Choose y with given parity v
        if ((yCandidate & 1) != uint256(v)) {
            yCandidate = P - yCandidate;
        }

        if (!isValidPublicKey(bytes32(rx), bytes32(yCandidate))) {
            return (bytes32(0), bytes32(0));
        }

        // Standard ECDSA public key recovery
        uint256 rinv = _invMod(uint256(r), N);
        uint256 u1 = mulmod(N - uint256(h) % N, rinv, N);
        uint256 u2 = mulmod(uint256(s), rinv, N);

        JPoint[16] memory points = _preComputeJacobianPoints(rx, yCandidate);
        (uint256 qx, uint256 qy) = _jMultShamir(points, u1, u2);

        return (bytes32(qx), bytes32(qy));
    }

    /**
     * @notice Checks if the given public key coordinates (x, y) are valid on the elliptic curve.
     *
     * Steps:
     * 1. Load the prime modulus `p` of the elliptic curve.
     * 2. Compute the left-hand side (LHS) of the Weierstrass equation: `y^2 mod p`.
     * 3. Compute the right-hand side (RHS) of the Weierstrass equation: `(x^3 + a*x + b) mod p`, where `a` and `b` are curve parameters.
     * 4. Ensure that both `x` and `y` are less than the prime modulus `p`.
     * 5. Check if the LHS equals the RHS, confirming the point lies on the curve.
     * 6. Return `true` if the point is valid, otherwise `false`.
     */
    function isValidPublicKey(bytes32 x, bytes32 y) internal pure returns (bool result) {
        uint256 px = uint256(x);
        uint256 py = uint256(y);

        if (px == 0 || py == 0 || px >= P || py >= P) {
            return false;
        }

        uint256 yy = mulmod(py, py, P);
        uint256 xx = mulmod(px, px, P);
        uint256 x3 = mulmod(xx, px, P);
        uint256 ax = mulmod(A, px, P);
        uint256 rhs = addmod(addmod(x3, ax, P), B, P);

        return yy == rhs;
    }

    /**
     * @notice Checks if the provided signature components (r, s) are valid for ECDSA.
     *
     * @param r The r component of the ECDSA signature.
     * @param s The s component of the ECDSA signature.
     * @return bool Returns true if the signature components are within valid bounds, otherwise false.
     *
     * Conditions:
     * 1. `r` must be greater than 0 and less than the curve order `N`.
     * 2. `s` must be greater than 0 and less than or equal to half of the curve order `HALF_N`.
     */
    function _isProperSignature(bytes32 r, bytes32 s) private pure returns (bool) {
        uint256 rr = uint256(r);
        uint256 ss = uint256(s);
        if (rr == 0 || rr >= N) return false;
        if (ss == 0 || ss > HALF_N) return false;
        return true;
    }

    /**
     * @notice Converts a point from Jacobian coordinates to affine coordinates.
     *
     * Steps:
     * 1. Check if the z-coordinate (jz) is zero. If so, return (0, 0) as the affine coordinates.
     * 2. Cache the prime number P on the stack.
     * 3. Calculate the modular inverse of the z-coordinate (jz) using Math.invModPrime.
     * 4. Use assembly to perform efficient modular arithmetic:
     *    - Compute zzinv as the square of zinv modulo p.
     *    - Compute ax as jx multiplied by zzinv modulo p.
     *    - Compute ay as jy multiplied by zzinv multiplied by zinv modulo p.
     * 5. Return the computed affine coordinates (ax, ay).
     */
    function _affineFromJacobian(
        uint256 jx,
        uint256 jy,
        uint256 jz
    ) private view returns (uint256 ax, uint256 ay) {
        if (jz == 0) {
            return (0, 0);
        }
        uint256 zinv = _invMod(jz, P);
        uint256 z2 = mulmod(zinv, zinv, P);
        ax = mulmod(jx, z2, P);
        uint256 z3 = mulmod(z2, zinv, P);
        ay = mulmod(jy, z3, P);
    }

    /**
     * @notice Performs Jacobian point addition on elliptic curve points.
     *
     * @param p1 The first Jacobian point (x1, y1, z1).
     * @param x2 The x-coordinate of the second point.
     * @param y2 The y-coordinate of the second point.
     * @param z2 The z-coordinate of the second point.
     *
     * @return rx The x-coordinate of the resulting point.
     * @return ry The y-coordinate of the resulting point.
     * @return rz The z-coordinate of the resulting point.
     *
     * Steps:
     * 1. Load the prime field modulus `p`.
     * 2. Compute intermediate values `zz1`, `s1`, `r`, `u1`, and `h` for point addition.
     * 3. Check if the points are identical or different.
     *
     * If points are different:
     * 4. Compute `hh` (h²).
     * 5. Calculate the resulting x-coordinate `rx` using the formula: r² - h³ - 2*u1*h².
     * 6. Calculate the resulting y-coordinate `ry` using the formula: r*(u1*h² - rx) - s1*h³.
     * 7. Calculate the resulting z-coordinate `rz` using the formula: h*z1*z2.
     *
     * If points are identical (doubling):
     * 8. Compute intermediate values `yy`, `zz`, `m`, and `s` for point doubling.
     * 9. Calculate the resulting x-coordinate `rx` using the formula: m² - 2*s.
     * 10. Calculate the resulting y-coordinate `ry` using the formula: m*(s - rx) - 8*y⁴.
     * 11. Calculate the resulting z-coordinate `rz` using the formula: 2*y*z.
     */
    function _jAdd(
        JPoint memory p1,
        uint256 x2,
        uint256 y2,
        uint256 z2
    ) private pure returns (uint256 rx, uint256 ry, uint256 rz) {
        uint256 x1 = p1.x;
        uint256 y1 = p1.y;
        uint256 z1 = p1.z;

        if (z1 == 0) {
            return (x2, y2, z2);
        }
        if (z2 == 0) {
            return (x1, y1, z1);
        }

        uint256 z1z1 = mulmod(z1, z1, P);
        uint256 z2z2 = mulmod(z2, z2, P);
        uint256 u1 = mulmod(x1, z2z2, P);
        uint256 u2 = mulmod(x2, z1z1, P);
        uint256 s1 = mulmod(y1, mulmod(z2, z2z2, P), P);
        uint256 s2 = mulmod(y2, mulmod(z1, z1z1, P), P);

        if (u1 == u2) {
            if (s1 == s2) {
                return _jDouble(x1, y1, z1);
            } else {
                return (0, 0, 0);
            }
        }

        uint256 h = addmod(u2, P - u1, P);
        uint256 r_ = addmod(s2, P - s1, P);
        uint256 hh = mulmod(h, h, P);
        uint256 hhh = mulmod(hh, h, P);
        uint256 v = mulmod(u1, hh, P);

        rx = addmod(mulmod(r_, r_, P), P - hhh, P);
        rx = addmod(rx, P - addmod(v, v, P), P);
        ry = mulmod(r_, addmod(v, P - rx, P), P);
        uint256 s1hhh = mulmod(s1, hhh, P);
        ry = addmod(ry, P - s1hhh, P);
        rz = mulmod(mulmod(z1, z2, P), h, P);
    }

    /**
     * @notice Performs a Jacobian doubling operation on elliptic curve points.
     *
     * @param x The x-coordinate of the point.
     * @param y The y-coordinate of the point.
     * @param z The z-coordinate of the point.
     *
     * @return rx The resulting x-coordinate after doubling.
     * @return ry The resulting y-coordinate after doubling.
     * @return rz The resulting z-coordinate after doubling.
     *
     * Steps:
     * 1. Compute intermediate values:
     *    - `yy` as the square of `y` modulo `p`.
     *    - `zz` as the square of `z` modulo `p`.
     *    - `m` as `3*x² + a*z⁴` modulo `p`.
     *    - `s` as `4*x*y²` modulo `p`.
     *
     * 2. Calculate the resulting coordinates:
     *    - `rx` as `m² - 2*s` modulo `p`.
     *    - `ry` as `m*(s - rx) - 8*y⁴` modulo `p`.
     *    - `rz` as `2*y*z` modulo `p`.
     *
     * The function uses inline assembly for efficient computation.
     */
    function _jDouble(
        uint256 x,
        uint256 y,
        uint256 z
    ) private pure returns (uint256 rx, uint256 ry, uint256 rz) {
        if (z == 0 || y == 0) {
            return (0, 0, 0);
        }

        uint256 yy = mulmod(y, y, P);
        uint256 yyyy = mulmod(yy, yy, P);
        uint256 zz = mulmod(z, z, P);
        uint256 zz2 = mulmod(zz, zz, P);
        uint256 az4 = mulmod(A, zz2, P);

        uint256 xx = mulmod(x, x, P);
        uint256 m = addmod(mulmod(3, xx, P), az4, P);
        uint256 s = mulmod(4, mulmod(x, yy, P), P);

        rx = addmod(mulmod(m, m, P), P - addmod(s, s, P), P);
        uint256 t = addmod(s, P - rx, P);
        ry = addmod(mulmod(m, t, P), P - mulmod(8, yyyy, P), P);
        rz = mulmod(2, mulmod(y, z, P), P);
    }

    /**
     * @notice Performs a Jacobian multiplication using Shamir's trick for elliptic curve points.
     *
     * @param points An array of 16 precomputed Jacobian points.
     * @param u1 A 256-bit scalar value used for the multiplication.
     * @param u2 A 256-bit scalar value used for the multiplication.
     *
     * Steps:
     * 1. Initialize variables `x`, `y`, and `z` to 0.
     * 2. Iterate over 128 steps to process the scalar values `u1` and `u2`:
     *    - If `z` is greater than 0, perform a double operation on the current point twice.
     *    - Extract 2 bits from `u1` and 2 bits from `u2` to determine the lookup index in the `points` array.
     *    - If the lookup point is not at infinity (i.e., `z != 0`):
     *      - If the current point is at infinity (`z == 0`), set the current point to the lookup point.
     *      - Otherwise, add the lookup point to the current point using Jacobian addition.
     *    - Shift `u1` and `u2` left by 2 bits for the next iteration.
     * 3. Convert the final Jacobian point to affine coordinates and return the result.
     *
     * @return rx The x-coordinate of the resulting affine point.
     * @return ry The y-coordinate of the resulting affine point.
     */
    function _jMultShamir(
        JPoint[16] memory points,
        uint256 u1,
        uint256 u2
    ) private view returns (uint256 rx, uint256 ry) {
        uint256 x;
        uint256 y;
        uint256 z;

        for (uint256 i = 0; i < 128; i++) {
            if (z != 0) {
                (x, y, z) = _jDouble(x, y, z);
                (x, y, z) = _jDouble(x, y, z);
            }

            uint256 idx = ((u1 >> 254) << 2) | (u2 >> 254);
            u1 <<= 2;
            u2 <<= 2;

            if (idx != 0) {
                JPoint memory p = points[idx];
                if (p.z != 0) {
                    if (z == 0) {
                        x = p.x;
                        y = p.y;
                        z = p.z;
                    } else {
                        (x, y, z) = _jAdd(JPoint(x, y, z), p.x, p.y, p.z);
                    }
                }
            }
        }

        (rx, ry) = _affineFromJacobian(x, y, z);
    }

    /**
     * @notice Pre-computes Jacobian points for elliptic curve operations.
     *
     * Steps:
     * 1. Initialize an array of 16 JPoint structures.
     * 2. Set the first point (0x00) to the origin (0, 0, 0).
     * 3. Set the second point (0x01) to the input point (px, py, 1).
     * 4. Set the fourth point (0x04) to the generator point (GX, GY, 1).
     * 5. Compute the third point (0x02) by doubling the input point (2p).
     * 6. Compute the eighth point (0x08) by doubling the generator point (2g).
     * 7. Compute the fourth point (0x03) by adding the input point and its double (3p).
     * 8. Compute the fifth point (0x05) by adding the input point and the generator point (p+g).
     * 9. Compute the sixth point (0x06) by adding the doubled input point and the generator point (2p+g).
     * 10. Compute the seventh point (0x07) by adding the tripled input point and the generator point (3p+g).
     * 11. Compute the ninth point (0x09) by adding the input point and the doubled generator point (p+2g).
     * 12. Compute the tenth point (0x0a) by adding the doubled input point and the doubled generator point (2p+2g).
     * 13. Compute the eleventh point (0x0b) by adding the tripled input point and the doubled generator point (3p+2g).
     * 14. Compute the twelfth point (0x0c) by adding the generator point and its double (3g).
     * 15. Compute the thirteenth point (0x0d) by adding the input point and the tripled generator point (p+3g).
     * 16. Compute the fourteenth point (0x0e) by adding the doubled input point and the tripled generator point (2p+3g).
     * 17. Compute the fifteenth point (0x0f) by adding the tripled input point and the tripled generator point (3p+3g).
     */
    function _preComputeJacobianPoints(uint256 px, uint256 py) private pure returns (JPoint[16] memory points) {
        // 0x00: infinity
        points[0x00] = JPoint(0, 0, 0);
        // 0x01: P
        points[0x01] = JPoint(px, py, 1);
        // 0x04: G
        points[0x04] = JPoint(GX, GY, 1);

        // 0x02: 2P
        (points[0x02].x, points[0x02].y, points[0x02].z) = _jDouble(px, py, 1);
        // 0x08: 2G
        (points[0x08].x, points[0x08].y, points[0x08].z) = _jDouble(GX, GY, 1);

        // 0x03: 3P = P + 2P
        (points[0x03].x, points[0x03].y, points[0x03].z) =
            _jAdd(points[0x01], points[0x02].x, points[0x02].y, points[0x02].z);

        // 0x05: P + G
        (points[0x05].x, points[0x05].y, points[0x05].z) =
            _jAdd(points[0x01], GX, GY, 1);

        // 0x06: 2P + G = (2P) + G
        (points[0x06].x, points[0x06].y, points[0x06].z) =
            _jAdd(points[0x02], GX, GY, 1);

        // 0x07: 3P + G = (3P) + G
        (points[0x07].x, points[0x07].y, points[0x07].z) =
            _jAdd(points[0x03], GX, GY, 1);

        // 0x09: P + 2G = P + (2G)
        (points[0x09].x, points[0x09].y, points[0x09].z) =
            _jAdd(points[0x01], points[0x08].x, points[0x08].y, points[0x08].z);

        // 0x0a: 2P + 2G = (2P) + (2G)
        (points[0x0a].x, points[0x0a].y, points[0x0a].z) =
            _jAdd(points[0x02], points[0x08].x, points[0x08].y, points[0x08].z);

        // 0x0b: 3P + 2G = (3P) + (2G)
        (points[0x0b].x, points[0x0b].y, points[0x0b].z) =
            _jAdd(points[0x03], points[0x08].x, points[0x08].y, points[0x08].z);

        // 0x0c: 3G = G + 2G
        (points[0x0c].x, points[0x0c].y, points[0x0c].z) =
            _jAdd(points[0x04], points[0x08].x, points[0x08].y, points[0x08].z);

        // 0x0d: P + 3G = P + (3G)
        (points[0x0d].x, points[0x0d].y, points[0x0d].z) =
            _jAdd(points[0x01], points[0x0c].x, points[0x0c].y, points[0x0c].z);

        // 0x0e: 2P + 3G = (2P) + (3G)
        (points[0x0e].x, points[0x0e].y, points[0x0e].z) =
            _jAdd(points[0x02], points[0x0c].x, points[0x0c].y, points[0x0c].z);

        // 0x0f: 3P + 3G = (3P) + (3G)
        (points[0x0f].x, points[0x0f].y, points[0x0f].z) =
            _jAdd(points[0x03], points[0x0c].x, points[0x0c].y, points[0x0c].z);
    }

    /**
     * @notice Adds two Jacobian points (p1 and p2) and returns the resulting Jacobian point.
     *
     * Steps:
     * 1. Calls the internal `_jAdd` function with the coordinates of p1 and p2.
     * 2. Returns a new JPoint struct with the resulting x, y, and z coordinates.
     */
    function _jAddPoint(JPoint memory p1, JPoint memory p2) private pure returns (JPoint memory) {
        (uint256 rx, uint256 ry, uint256 rz) = _jAdd(p1, p2.x, p2.y, p2.z);
        return JPoint(rx, ry, rz);
    }

    /**
     * @notice Doubles a Jacobian point (x, y, z) and returns the result as a new Jacobian point.
     *
     * @param p The Jacobian point to double.
     * @return A new Jacobian point representing the result of the doubling operation.
     */
    function _jDoublePoint(JPoint memory p) private pure returns (JPoint memory) {
        (uint256 rx, uint256 ry, uint256 rz) = _jDouble(p.x, p.y, p.z);
        return JPoint(rx, ry, rz);
    }

    // ---- Internal math helpers ----

    function _invMod(uint256 a, uint256 m) private view returns (uint256) {
        // Extended Euclidean algorithm
        if (a == 0 || a == m || m == 0) return 0;
        int256 t1;
        int256 t2 = 1;
        uint256 r1 = m;
        uint256 r2 = a;

        while (r2 != 0) {
            uint256 q = r1 / r2;

            uint256 rTemp = r1 - q * r2;
            r1 = r2;
            r2 = rTemp;

            int256 tTemp = t1 - int256(q) * t2;
            t1 = t2;
            t2 = tTemp;
        }

        if (t1 < 0) {
            t1 += int256(m);
        }
        return uint256(t1);
    }

    // Tonelli–Shanks for P-256 (p % 4 == 3, so exponent (p+1)/4 works)
    function _sqrtMod(uint256 a) private view returns (uint256) {
        if (a == 0) return 0;
        // exponent = (P + 1) / 4
        uint256 exp = (P + 1) >> 2;
        return _expMod(a, exp, P);
    }

    function _expMod(uint256 base, uint256 exponent, uint256 modulus) private view returns (uint256 result) {
        if (modulus == 1) return 0;
        result = 1;
        uint256 b = base % modulus;
        uint256 e = exponent;

        while (e > 0) {
            if (e & 1 != 0) {
                result = mulmod(result, b, modulus);
            }
            b = mulmod(b, b, modulus);
            e >>= 1;
        }
    }
}