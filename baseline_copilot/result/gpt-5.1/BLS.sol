// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BLS12-381 Helpers
/// @notice Thin wrappers around the Cancun BLS12-381 precompiles.
/// @dev This library assumes the presence of the EIP-2537 style BLS12-381 precompiles
///      at the canonical addresses used in the Cancun upgrade.
///      All functions revert with custom errors on precompile failure.
library BLS {
    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    /**
     * @notice Represents a field element in Fp as 2x32-byte limbs.
     *
     * @param a The upper 32 bytes of the value.
     * @param b The lower 32 bytes of the value.
     */
    struct Fp {
        bytes32 a;
        bytes32 b;
    }

    /**
     * @notice Represents a field element in Fp2.
     *
     * @param c0_a The first component of the first coefficient.
     * @param c0_b The second component of the first coefficient.
     * @param c1_a The first component of the second coefficient.
     * @param c1_b The second component of the second coefficient.
     */
    struct Fp2 {
        bytes32 c0_a;
        bytes32 c0_b;
        bytes32 c1_a;
        bytes32 c1_b;
    }

    /**
     * @notice Represents a point in G1.
     *
     * @param x_a First part of the x-coordinate.
     * @param x_b Second part of the x-coordinate.
     * @param y_a First part of the y-coordinate.
     * @param y_b Second part of the y-coordinate.
     */
    struct G1Point {
        bytes32 x_a;
        bytes32 x_b;
        bytes32 y_a;
        bytes32 y_b;
    }

    /**
     * @notice Represents a point in G2.
     *
     * @param x_c0_a First component of x (part 1).
     * @param x_c0_b Second component of x (part 1).
     * @param x_c1_a First component of x (part 2).
     * @param x_c1_b Second component of x (part 2).
     * @param y_c0_a First component of y (part 1).
     * @param y_c0_b Second component of y (part 1).
     * @param y_c1_a First component of y (part 2).
     * @param y_c1_b Second component of y (part 2).
     */
    struct G2Point {
        bytes32 x_c0_a;
        bytes32 x_c0_b;
        bytes32 x_c1_a;
        bytes32 x_c1_b;
        bytes32 y_c0_a;
        bytes32 y_c0_b;
        bytes32 y_c1_a;
        bytes32 y_c1_b;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error G1AddFailed();
    error G1MulFailed();
    error G1MSMFailed();
    error G2AddFailed();
    error G2MulFailed();
    error G2MSMFailed();
    error PairingFailed();
    error MapFpToG1Failed();
    error MapFp2ToG2Failed();
    error HashToG2Failed();
    error LengthMismatch();

    // -------------------------------------------------------------------------
    // Precompile addresses (Cancun / EIP-2537 like)
    // -------------------------------------------------------------------------

    uint256 private constant BLS12_G1ADD = 0x0a;
    uint256 private constant BLS12_G1MUL = 0x0b;
    uint256 private constant BLS12_G1MSM = 0x0c;
    uint256 private constant BLS12_G2ADD = 0x0d;
    uint256 private constant BLS12_G2MUL = 0x0e;
    uint256 private constant BLS12_G2MSM = 0x0f;
    uint256 private constant BLS12_PAIRING = 0x10;
    uint256 private constant BLS12_MAP_FP_TO_G1 = 0x11;
    uint256 private constant BLS12_MAP_FP2_TO_G2 = 0x12;

    // -------------------------------------------------------------------------
    // G1 operations
    // -------------------------------------------------------------------------

    /**
     * @notice Adds two G1 elliptic curve points using the BLS12-381 curve's G1 addition operation.
     */
    function add(G1Point memory point0, G1Point memory point1) internal view returns (G1Point memory result) {
        assembly {
            // Layout: [point0 (128 bytes) | point1 (128 bytes)]
            mstore(result, mload(point0))
            mstore(add(result, 0x20), mload(add(point0, 0x20)))
            mstore(add(result, 0x40), mload(add(point0, 0x40)))
            mstore(add(result, 0x60), mload(add(point0, 0x60)))

            let second := add(result, 0x80)
            mstore(second, mload(point1))
            mstore(add(second, 0x20), mload(add(point1, 0x20)))
            mstore(add(second, 0x40), mload(add(point1, 0x40)))
            mstore(add(second, 0x60), mload(add(point1, 0x60)))

            // call(gas, addr, value, in, insize, out, outsize)
            if iszero(staticcall(gas(), BLS12_G1ADD, result, 0x100, result, 0x80)) {
                mstore(0x00, 0x6f40c5f7) // keccak256("G1AddFailed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Multiplies a G1 elliptic curve point by a scalar value using the BLS12_G1MUL precompile.
     */
    function mul(G1Point memory point, bytes32 scalar) internal view returns (G1Point memory result) {
        assembly {
            // Layout: [point (128 bytes) | scalar (32 bytes)] => 160 bytes
            mstore(result, mload(point))
            mstore(add(result, 0x20), mload(add(point, 0x20)))
            mstore(add(result, 0x40), mload(add(point, 0x40)))
            mstore(add(result, 0x60), mload(add(point, 0x60)))
            mstore(add(result, 0x80), scalar)

            if iszero(staticcall(gas(), BLS12_G1MUL, result, 0xa0, result, 0x80)) {
                mstore(0x00, 0x5a9e4aaf) // keccak256("G1MulFailed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Performs a multi-scalar multiplication (MSM) operation on G1 points.
     */
    function msm(G1Point[] memory points, bytes32[] memory scalars) internal view returns (G1Point memory result) {
        uint256 n = points.length;
        if (n != scalars.length) revert LengthMismatch();
        if (n == 0) {
            return result;
        }

        assembly {
            // Each input element: G1 (128) + scalar (32) = 160 bytes
            let inSizePer := 0xa0
            let input := mload(0x40)
            let ptr := input

            let pPtr := add(points, 0x20)
            let sPtr := add(scalars, 0x20)

            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // copy G1
                mstore(ptr, mload(pPtr))
                mstore(add(ptr, 0x20), mload(add(pPtr, 0x20)))
                mstore(add(ptr, 0x40), mload(add(pPtr, 0x40)))
                mstore(add(ptr, 0x60), mload(add(pPtr, 0x60)))

                // scalar
                mstore(add(ptr, 0x80), mload(sPtr))

                ptr := add(ptr, inSizePer)
                pPtr := add(pPtr, 0x80)
                sPtr := add(sPtr, 0x20)
            }

            let inSize := mul(inSizePer, n)
            mstore(0x40, add(input, inSize))

            if iszero(staticcall(gas(), BLS12_G1MSM, input, inSize, result, 0x80)) {
                mstore(0x00, 0x0af1f2d2) // keccak256("G1MSMFailed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    // -------------------------------------------------------------------------
    // G2 operations
    // -------------------------------------------------------------------------

    /**
     * @notice Adds two G2 elliptic curve points using the BLS12-381 curve's G2 addition operation.
     */
    function add(G2Point memory point0, G2Point memory point1) internal view returns (G2Point memory result) {
        assembly {
            // G2 point is 8 * 32 = 256 bytes.
            mstore(result, mload(point0))
            mstore(add(result, 0x20), mload(add(point0, 0x20)))
            mstore(add(result, 0x40), mload(add(point0, 0x40)))
            mstore(add(result, 0x60), mload(add(point0, 0x60)))
            mstore(add(result, 0x80), mload(add(point0, 0x80)))
            mstore(add(result, 0xa0), mload(add(point0, 0xa0)))
            mstore(add(result, 0xc0), mload(add(point0, 0xc0)))
            mstore(add(result, 0xe0), mload(add(point0, 0xe0)))

            let second := add(result, 0x100)
            mstore(second, mload(point1))
            mstore(add(second, 0x20), mload(add(point1, 0x20)))
            mstore(add(second, 0x40), mload(add(point1, 0x40)))
            mstore(add(second, 0x60), mload(add(point1, 0x60)))
            mstore(add(second, 0x80), mload(add(point1, 0x80)))
            mstore(add(second, 0xa0), mload(add(point1, 0xa0)))
            mstore(add(second, 0xc0), mload(add(point1, 0xc0)))
            mstore(add(second, 0xe0), mload(add(point1, 0xe0)))

            if iszero(staticcall(gas(), BLS12_G2ADD, result, 0x200, result, 0x100)) {
                mstore(0x00, 0x78d0e28a) // keccak256("G2AddFailed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Multiplies a G2 elliptic curve point by a scalar value using the BLS12_G2MUL precompile.
     */
    function mul(G2Point memory point, bytes32 scalar) internal view returns (G2Point memory result) {
        assembly {
            // [G2 (256) | scalar (32)] = 288 bytes.
            mstore(result, mload(point))
            mstore(add(result, 0x20), mload(add(point, 0x20)))
            mstore(add(result, 0x40), mload(add(point, 0x40)))
            mstore(add(result, 0x60), mload(add(point, 0x60)))
            mstore(add(result, 0x80), mload(add(point, 0x80)))
            mstore(add(result, 0xa0), mload(add(point, 0xa0)))
            mstore(add(result, 0xc0), mload(add(point, 0xc0)))
            mstore(add(result, 0xe0), mload(add(point, 0xe0)))
            mstore(add(result, 0x100), scalar)

            if iszero(staticcall(gas(), BLS12_G2MUL, result, 0x120, result, 0x100)) {
                mstore(0x00, 0x9d4c5c3c) // keccak256("G2MulFailed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Performs a multi-scalar multiplication (MSM) operation on G2 points.
     */
    function msm(G2Point[] memory points, bytes32[] memory scalars) internal view returns (G2Point memory result) {
        uint256 n = points.length;
        if (n != scalars.length) revert LengthMismatch();
        if (n == 0) {
            return result;
        }

        assembly {
            // Each element: G2 (256) + scalar (32) = 288 bytes.
            let inSizePer := 0x120
            let input := mload(0x40)
            let ptr := input

            let pPtr := add(points, 0x20)
            let sPtr := add(scalars, 0x20)

            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // copy G2
                mstore(ptr, mload(pPtr))
                mstore(add(ptr, 0x20), mload(add(pPtr, 0x20)))
                mstore(add(ptr, 0x40), mload(add(pPtr, 0x40)))
                mstore(add(ptr, 0x60), mload(add(pPtr, 0x60)))
                mstore(add(ptr, 0x80), mload(add(pPtr, 0x80)))
                mstore(add(ptr, 0xa0), mload(add(pPtr, 0xa0)))
                mstore(add(ptr, 0xc0), mload(add(pPtr, 0xc0)))
                mstore(add(ptr, 0xe0), mload(add(pPtr, 0xe0)))

                // scalar
                mstore(add(ptr, 0x100), mload(sPtr))

                ptr := add(ptr, inSizePer)
                pPtr := add(pPtr, 0x100)
                sPtr := add(sPtr, 0x20)
            }

            let inSize := mul(inSizePer, n)
            mstore(0x40, add(input, inSize))

            if iszero(staticcall(gas(), BLS12_G2MSM, input, inSize, result, 0x100)) {
                mstore(0x00, 0x45e3f2c7) // keccak256("G2MSMFailed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Pairing
    // -------------------------------------------------------------------------

    /**
     * @notice Performs a pairing operation on arrays of G1 and G2 points using BLS12-381 curve pairing.
     */
    function pairing(G1Point[] memory g1Points, G2Point[] memory g2Points) internal view returns (bool result) {
        uint256 n = g1Points.length;
        if (n != g2Points.length) revert LengthMismatch();
        if (n == 0) {
            // Empty pairing is conventionally true.
            return true;
        }

        assembly {
            // Each pair: G1 (128) + G2 (256) = 384 bytes.
            let inSizePer := 0x180
            let input := mload(0x40)
            let ptr := input

            let g1Ptr := add(g1Points, 0x20)
            let g2Ptr := add(g2Points, 0x20)

            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // copy G1
                mstore(ptr, mload(g1Ptr))
                mstore(add(ptr, 0x20), mload(add(g1Ptr, 0x20)))
                mstore(add(ptr, 0x40), mload(add(g1Ptr, 0x40)))
                mstore(add(ptr, 0x60), mload(add(g1Ptr, 0x60)))

                // copy G2
                let g2Out := add(ptr, 0x80)
                mstore(g2Out, mload(g2Ptr))
                mstore(add(g2Out, 0x20), mload(add(g2Ptr, 0x20)))
                mstore(add(g2Out, 0x40), mload(add(g2Ptr, 0x40)))
                mstore(add(g2Out, 0x60), mload(add(g2Ptr, 0x60)))
                mstore(add(g2Out, 0x80), mload(add(g2Ptr, 0x80)))
                mstore(add(g2Out, 0xa0), mload(add(g2Ptr, 0xa0)))
                mstore(add(g2Out, 0xc0), mload(add(g2Ptr, 0xc0)))
                mstore(add(g2Out, 0xe0), mload(add(g2Ptr, 0xe0)))

                ptr := add(ptr, inSizePer)
                g1Ptr := add(g1Ptr, 0x80)
                g2Ptr := add(g2Ptr, 0x100)
            }

            let inSize := mul(inSizePer, n)
            mstore(0x40, add(input, inSize))

            // Output: 32-byte boolean-like field element (0 or 1).
            if iszero(staticcall(gas(), BLS12_PAIRING, input, inSize, 0x00, 0x20)) {
                mstore(0x00, 0x5a1f9a0c) // keccak256("PairingFailed()")[0:4]
                revert(0x1c, 0x04)
            }

            result := iszero(iszero(mload(0x00)))
        }
    }

    // -------------------------------------------------------------------------
    // Mapping
    // -------------------------------------------------------------------------

    /**
     * @notice Converts a field element (Fp) to a G1 point on the BLS12 curve.
     */
    function toG1(Fp memory element) internal view returns (G1Point memory result) {
        assembly {
            // Fp is 64 bytes (2 limbs).
            if iszero(staticcall(gas(), BLS12_MAP_FP_TO_G1, element, 0x40, result, 0x80)) {
                mstore(0x00, 0x9b7a3b92) // keccak256("MapFpToG1Failed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Converts an Fp2 element to a G2 point using a precompiled BLS12-381 mapping function.
     */
    function toG2(Fp2 memory element) internal view returns (G2Point memory result) {
        assembly {
            // Fp2 is 128 bytes (4 limbs).
            if iszero(staticcall(gas(), BLS12_MAP_FP2_TO_G2, element, 0x80, result, 0x100)) {
                mstore(0x00, 0x2c4b7d0c) // keccak256("MapFp2ToG2Failed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Hash to G2
    // -------------------------------------------------------------------------

    /**
     * @notice Hashes a message to a G2 point on the BLS12-381 curve using SHA-256 and domain separation.
     *
     * @dev This is a simple construction using:
     *      - SHA-256 for hashing
     *      - Reduction mod Fp2 by truncation
     *      - Two independent hashes mapped to G2 and then added.
     *      This is not a complete RFC 9380 implementation but follows the high-level
     *      description in the plan.
     */
    function hashToG2(bytes memory message) internal view returns (G2Point memory result) {
        bytes32 t0;
        bytes32 t1;
        bytes32 t2;
        bytes32 t3;

        unchecked {
            // Domain separation tag.
            bytes32 domain = keccak256("BLS_HASH_TO_G2_DOMAIN");

            // First hash: H(domain || 0x00 || msg)
            {
                bytes memory buf0 = new bytes(1 + 32 + message.length);
                uint256 ptr;
                assembly {
                    ptr := add(buf0, 0x20)
                }
                assembly {
                    mstore(ptr, domain)
                    mstore(add(ptr, 0x20), 0x00)
                }
                for (uint256 i = 0; i < message.length; ++i) {
                    buf0[33 + i] = message[i];
                }
                bytes32 h0 = sha256(buf0);
                // Split into two limbs for Fp
                t0 = h0;
                t1 = sha256(abi.encodePacked(h0, uint8(0x01)));
            }

            // Second hash: H(domain || 0x01 || msg)
            {
                bytes memory buf1 = new bytes(1 + 32 + message.length);
                uint256 ptr2;
                assembly {
                    ptr2 := add(buf1, 0x20)
                }
                assembly {
                    mstore(ptr2, domain)
                    mstore(add(ptr2, 0x20), 0x01)
                }
                for (uint256 i = 0; i < message.length; ++i) {
                    buf1[33 + i] = message[i];
                }
                bytes32 h1 = sha256(buf1);
                t2 = h1;
                t3 = sha256(abi.encodePacked(h1, uint8(0x02)));
            }
        }

        // Construct two Fp2 elements from hashes, then map each to G2 and add.
        Fp2 memory e0 = Fp2({c0_a: t0, c0_b: t1, c1_a: bytes32(0), c1_b: bytes32(0)});
        Fp2 memory e1 = Fp2({c0_a: t2, c0_b: t3, c1_a: bytes32(0), c1_b: bytes32(0)});

        G2Point memory p0 = toG2(e0);
        G2Point memory p1 = toG2(e1);
        result = add(p0, p1);

        // Basic sanity check: if the precompile somehow failed silently, revert.
        assembly {
            // If all coordinates are zero, treat as failure.
            if and(
                and(iszero(mload(result)), iszero(mload(add(result, 0x20)))),
                and(
                    and(iszero(mload(add(result, 0x40))), iszero(mload(add(result, 0x60)))),
                    and(
                        and(iszero(mload(add(result, 0x80))), iszero(mload(add(result, 0xa0)))),
                        and(iszero(mload(add(result, 0xc0))), iszero(mload(add(result, 0xe0))))
                    )
                )
            ) {
                mstore(0x00, 0x8f8e92b5) // keccak256("HashToG2Failed()")[0:4]
                revert(0x1c, 0x04)
            }
        }
    }
}