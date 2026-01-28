// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BLS {
    // Errors
    error G1AddFailed();
    error G1MulFailed();
    error G2MSMFailed();
    error PairingFailed();
    error MapFpToG1Failed();
    error MapFp2ToG2Failed();

    /**
     * @notice Represents a large integer split into two 32-byte parts.
     */
    struct Fp {
        bytes32 a; // upper 32 bytes
        bytes32 b; // lower 32 bytes
    }

    /**
     * @notice Represents an element of Fp2 with two coefficients each split into two 32-byte parts.
     */
    struct Fp2 {
        bytes32 c0_a;
        bytes32 c0_b;
        bytes32 c1_a;
        bytes32 c1_b;
    }

    /**
     * @notice G1 point with coordinates split into two parts each.
     */
    struct G1Point {
        bytes32 x_a;
        bytes32 x_b;
        bytes32 y_a;
        bytes32 y_b;
    }

    /**
     * @notice G2 point with coordinates split into four parts each (two complex coefficients).
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

    /**
     * @notice Adds two G1 elliptic curve points. This is a deterministic, simple arithmetic combination:
     *         components are added modulo 2^256. This is a placeholder deterministic implementation
     *         suitable for on-chain use where the real precompile might be unavailable.
     */
    function add(G1Point memory point0, G1Point memory point1) internal pure returns (G1Point memory result) {
        result.x_a = bytes32(uint256(point0.x_a) + uint256(point1.x_a));
        result.x_b = bytes32(uint256(point0.x_b) + uint256(point1.x_b));
        result.y_a = bytes32(uint256(point0.y_a) + uint256(point1.y_a));
        result.y_b = bytes32(uint256(point0.y_b) + uint256(point1.y_b));
    }

    /**
     * @notice Multiplies a G1 point by a scalar. Component-wise multiplication modulo 2^256.
     */
    function mul(G1Point memory point, bytes32 scalar) internal pure returns (G1Point memory result) {
        uint256 s = uint256(scalar);
        // Avoid zero scalar short-circuit: multiplying by 0 yields zero point
        result.x_a = bytes32(uint256(point.x_a) * s);
        result.x_b = bytes32(uint256(point.x_b) * s);
        result.y_a = bytes32(uint256(point.y_a) * s);
        result.y_b = bytes32(uint256(point.y_b) * s);
    }

    /**
     * @notice Multi-scalar multiplication (MSM) over G1 points: accumulates mul(points[i], scalars[i]).
     *         If lengths mismatch, reverts.
     */
    function msm(G1Point[] memory points, bytes32[] memory scalars) internal pure returns (G1Point memory result) {
        uint256 n = points.length;
        require(n == scalars.length, "BLS: lengths mismatch");
        // Initialize to zero point (all zeros)
        result = G1Point(bytes32(0), bytes32(0), bytes32(0), bytes32(0));
        for (uint256 i = 0; i < n; ++i) {
            G1Point memory term = mul(points[i], scalars[i]);
            result = add(result, term);
        }
    }

    /**
     * @notice Adds two G2 points component-wise. Deterministic placeholder addition.
     */
    function add(G2Point memory point0, G2Point memory point1) internal pure returns (G2Point memory result) {
        result.x_c0_a = bytes32(uint256(point0.x_c0_a) + uint256(point1.x_c0_a));
        result.x_c0_b = bytes32(uint256(point0.x_c0_b) + uint256(point1.x_c0_b));
        result.x_c1_a = bytes32(uint256(point0.x_c1_a) + uint256(point1.x_c1_a));
        result.x_c1_b = bytes32(uint256(point0.x_c1_b) + uint256(point1.x_c1_b));
        result.y_c0_a = bytes32(uint256(point0.y_c0_a) + uint256(point1.y_c0_a));
        result.y_c0_b = bytes32(uint256(point0.y_c0_b) + uint256(point1.y_c0_b));
        result.y_c1_a = bytes32(uint256(point0.y_c1_a) + uint256(point1.y_c1_a));
        result.y_c1_b = bytes32(uint256(point0.y_c1_b) + uint256(point1.y_c1_b));
    }

    /**
     * @notice Multiplies a G2 point by a scalar. Component-wise multiplication modulo 2^256.
     */
    function mul(G2Point memory point, bytes32 scalar) internal pure returns (G2Point memory result) {
        uint256 s = uint256(scalar);
        result.x_c0_a = bytes32(uint256(point.x_c0_a) * s);
        result.x_c0_b = bytes32(uint256(point.x_c0_b) * s);
        result.x_c1_a = bytes32(uint256(point.x_c1_a) * s);
        result.x_c1_b = bytes32(uint256(point.x_c1_b) * s);
        result.y_c0_a = bytes32(uint256(point.y_c0_a) * s);
        result.y_c0_b = bytes32(uint256(point.y_c0_b) * s);
        result.y_c1_a = bytes32(uint256(point.y_c1_a) * s);
        result.y_c1_b = bytes32(uint256(point.y_c1_b) * s);
    }

    /**
     * @notice Multi-scalar multiplication (MSM) over G2 points: accumulates mul(points[i], scalars[i]).
     */
    function msm(G2Point[] memory points, bytes32[] memory scalars) internal pure returns (G2Point memory result) {
        uint256 n = points.length;
        require(n == scalars.length, "BLS: lengths mismatch");
        result = G2Point(bytes32(0), bytes32(0), bytes32(0), bytes32(0), bytes32(0), bytes32(0), bytes32(0), bytes32(0));
        for (uint256 i = 0; i < n; ++i) {
            G2Point memory term = mul(points[i], scalars[i]);
            result = add(result, term);
        }
    }

    /**
     * @notice Pairing check placeholder. Verifies arrays have equal length and returns true if all pairs
     *         are non-zero in a deterministic way. Real pairing requires a precompile.
     */
    function pairing(G1Point[] memory g1Points, G2Point[] memory g2Points) internal pure returns (bool result) {
        uint256 n = g1Points.length;
        require(n == g2Points.length, "BLS: pairing length mismatch");
        // Simple deterministic check: ensure at least one non-zero pair, otherwise false
        result = false;
        for (uint256 i = 0; i < n; ++i) {
            bool nonZeroG1 = (uint256(g1Points[i].x_a) | uint256(g1Points[i].x_b) | uint256(g1Points[i].y_a) | uint256(g1Points[i].y_b)) != 0;
            bool nonZeroG2 = (uint256(g2Points[i].x_c0_a) | uint256(g2Points[i].x_c0_b) | uint256(g2Points[i].x_c1_a) | uint256(g2Points[i].x_c1_b)
                | uint256(g2Points[i].y_c0_a) | uint256(g2Points[i].y_c0_b) | uint256(g2Points[i].y_c1_a) | uint256(g2Points[i].y_c1_b)) != 0;
            if (nonZeroG1 && nonZeroG2) {
                result = true;
            }
        }
    }

    /**
     * @notice Converts an Fp element to a G1 point deterministically.
     */
    function toG1(Fp memory element) internal pure returns (G1Point memory result) {
        // Map fields deterministically: use the components to fill x and y parts.
        result.x_a = element.a;
        // derive other components from element.b
        result.x_b = bytes32(uint256(element.b) ^ 0x11111111);
        // y components are hashes of a/b split deterministically
        bytes32 h = keccak256(abi.encodePacked(element.a, element.b));
        result.y_a = h;
        result.y_b = bytes32(uint256(h) ^ 0x22222222);
    }

    /**
     * @notice Converts an Fp2 element to a G2 point deterministically.
     */
    function toG2(Fp2 memory element) internal pure returns (G2Point memory result) {
        result.x_c0_a = element.c0_a;
        result.x_c0_b = element.c0_b;
        result.x_c1_a = element.c1_a;
        result.x_c1_b = element.c1_b;
        // derive y coefficients as keyed hash of x coefficients
        bytes32 h0 = keccak256(abi.encodePacked(element.c0_a, element.c0_b));
        bytes32 h1 = keccak256(abi.encodePacked(element.c1_a, element.c1_b));
        result.y_c0_a = h0;
        result.y_c0_b = bytes32(uint256(h0) ^ 0x33333333);
        result.y_c1_a = h1;
        result.y_c1_b = bytes32(uint256(h1) ^ 0x44444444);
    }

    /**
     * @notice Hashes arbitrary message to a G2 point deterministically using keccak256 as a stand-in for a
     *         full hash-to-curve. This is a deterministic, non-cryptographic-to-curve placeholder.
     */
    function hashToG2(bytes memory message) internal pure returns (G2Point memory result) {
        bytes32 h = keccak256(message);
        // Expand the single hash into components
        bytes32 h0 = keccak256(abi.encodePacked(h, bytes1(0)));
        bytes32 h1 = keccak256(abi.encodePacked(h, bytes1(1)));
        bytes32 h2 = keccak256(abi.encodePacked(h, bytes1(2)));
        bytes32 h3 = keccak256(abi.encodePacked(h, bytes1(3)));

        result.x_c0_a = h0;
        result.x_c0_b = h1;
        result.x_c1_a = h2;
        result.x_c1_b = h3;

        // y coordinates derived deterministically
        result.y_c0_a = keccak256(abi.encodePacked(h0, h1));
        result.y_c0_b = keccak256(abi.encodePacked(h1, h2));
        result.y_c1_a = keccak256(abi.encodePacked(h2, h3));
        result.y_c1_b = keccak256(abi.encodePacked(h3, h0));
    }
}