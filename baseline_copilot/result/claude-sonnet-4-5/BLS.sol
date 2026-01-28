// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BLS {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error G1AddFailed();
    error G1MulFailed();
    error G1MSMFailed();
    error G2AddFailed();
    error G2MulFailed();
    error G2MSMFailed();
    error PairingFailed();
    error MapFpToG1Failed();
    error MapFp2ToG2Failed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 private constant BLS12_G1ADD = 0x0b;
    uint256 private constant BLS12_G1MUL = 0x0c;
    uint256 private constant BLS12_G1MSM = 0x0d;
    uint256 private constant BLS12_G2ADD = 0x0e;
    uint256 private constant BLS12_G2MUL = 0x0f;
    uint256 private constant BLS12_G2MSM = 0x10;
    uint256 private constant BLS12_PAIRING = 0x11;
    uint256 private constant BLS12_MAP_FP_TO_G1 = 0x12;
    uint256 private constant BLS12_MAP_FP2_TO_G2 = 0x13;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Defines a struct `Fp` representing a fixed-point number or a large integer split into two parts.
     *
     * @param a The upper 32 bytes of the value.
     * @param b The lower 32 bytes of the value.
     *
     * This struct is typically used to handle large numbers or fixed-point arithmetic by splitting the value into two 32-byte chunks.
     */
    struct Fp {
        bytes32 a;
        bytes32 b;
    }

    /**
     * @notice Defines a struct `Fp2` representing a field element in the Fp2 field.
     *
     * The struct contains four `bytes32` fields:
     * - `c0_a`: The first component of the first coefficient.
     * - `c0_b`: The second component of the first coefficient.
     * - `c1_a`: The first component of the second coefficient.
     * - `c1_b`: The second component of the second coefficient.
     *
     * This struct is typically used in cryptographic operations involving field elements in the Fp2 field.
     */
    struct Fp2 {
        bytes32 c0_a;
        bytes32 c0_b;
        bytes32 c1_a;
        bytes32 c1_b;
    }

    /**
     * @notice Defines a struct `G1Point` representing a point in a cryptographic curve (likely related to elliptic curve cryptography).
     *
     * The struct contains four fields:
     * 1. `x_a`: The first part of the x-coordinate of the point.
     * 2. `x_b`: The second part of the x-coordinate of the point.
     * 3. `y_a`: The first part of the y-coordinate of the point.
     * 4. `y_b`: The second part of the y-coordinate of the point.
     *
     * This structure is typically used in cryptographic operations where points on a curve are represented in a split format.
     */
    struct G1Point {
        bytes32 x_a;
        bytes32 x_b;
        bytes32 y_a;
        bytes32 y_b;
    }

    /**
     * @notice Defines a struct representing a G2Point, which is used in cryptographic operations.
     *
     * The struct contains the following fields:
     * - x_c0_a: The first component of the x-coordinate (part 1).
     * - x_c0_b: The second component of the x-coordinate (part 1).
     * - x_c1_a: The first component of the x-coordinate (part 2).
     * - x_c1_b: The second component of the x-coordinate (part 2).
     * - y_c0_a: The first component of the y-coordinate (part 1).
     * - y_c0_b: The second component of the y-coordinate (part 1).
     * - y_c1_a: The first component of the y-coordinate (part 2).
     * - y_c1_b: The second component of the y-coordinate (part 2).
     *
     * This struct is typically used in pairing-based cryptography, such as zk-SNARKs or zk-STARKs.
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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      G1 OPERATIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Adds two G1 elliptic curve points using the BLS12-381 curve's G1 addition operation.
     *
     * @param point0 The first G1 point to be added.
     * @param point1 The second G1 point to be added.
     * @return result The resulting G1 point after addition.
     *
     * Steps:
     * 1. Copy the first G1 point (`point0`) into the result memory location.
     * 2. Copy the second G1 point (`point1`) into the memory location immediately following the first point.
     * 3. Perform a static call to the BLS12-381 G1 addition precompile (`BLS12_G1ADD`) with the combined points as input.
     * 4. Check if the static call was successful:
     *    - If successful, the result is stored in the `result` memory location.
     *    - If unsuccessful, revert with the error `G1AddFailed()`.
     *
     * @dev This function uses inline assembly for low-level memory operations and interacts with the BLS12-381 precompile.
     *      The function assumes the input points are valid G1 points on the BLS12-381 curve.
     */
    function add(G1Point memory point0, G1Point memory point1)
        internal
        view
        returns (G1Point memory result)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(point0))
            mstore(add(ptr, 0x20), mload(add(point0, 0x20)))
            mstore(add(ptr, 0x40), mload(add(point0, 0x40)))
            mstore(add(ptr, 0x60), mload(add(point0, 0x60)))
            mstore(add(ptr, 0x80), mload(point1))
            mstore(add(ptr, 0xa0), mload(add(point1, 0x20)))
            mstore(add(ptr, 0xc0), mload(add(point1, 0x40)))
            mstore(add(ptr, 0xe0), mload(add(point1, 0x60)))
            
            result := mload(0x40)
            if iszero(staticcall(gas(), BLS12_G1ADD, ptr, 0x100, result, 0x80)) {
                mstore(0x00, 0x07c1a4e7) // `G1AddFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x80))
        }
    }

    /**
     * @notice Multiplies a G1 elliptic curve point by a scalar value using the BLS12_G1MUL precompile.
     *
     * @param point The G1Point to be multiplied.
     * @param scalar The scalar value to multiply the G1Point by.
     * @return result The resulting G1Point after multiplication.
     *
     * Steps:
     * 1. Copy the input G1Point into the result memory location.
     * 2. Store the scalar value in the memory location adjacent to the G1Point.
     * 3. Perform a static call to the BLS12_G1MUL precompile to multiply the G1Point by the scalar.
     * 4. Check if the operation was successful by verifying the return data size and the call result.
     * 5. If the operation fails, revert with the error `G1MulFailed()`.
     *
     * @dev This function uses inline assembly for low-level memory operations and precompile interaction.
     */
    function mul(G1Point memory point, bytes32 scalar)
        internal
        view
        returns (G1Point memory result)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(point))
            mstore(add(ptr, 0x20), mload(add(point, 0x20)))
            mstore(add(ptr, 0x40), mload(add(point, 0x40)))
            mstore(add(ptr, 0x60), mload(add(point, 0x60)))
            mstore(add(ptr, 0x80), scalar)
            
            result := mload(0x40)
            if iszero(staticcall(gas(), BLS12_G1MUL, ptr, 0xa0, result, 0x80)) {
                mstore(0x00, 0x66ab95d7) // `G1MulFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x80))
        }
    }

    /**
     * @notice Performs a multi-scalar multiplication (MSM) operation on G2 points.
     *
     * @param points An array of G2 points to be multiplied.
     * @param scalars An array of scalars to multiply the G2 points by.
     * @return result The resulting G2 point after the multi-scalar multiplication.
     *
     * Steps:
     * 1. Load the number of points from the `points` array.
     * 2. Calculate the offset between the `scalars` and `points` arrays.
     * 3. Iterate over each point and scalar:
     *    - Update the `points` pointer to the next element.
     *    - Calculate the output offset for the result.
     *    - Copy the point data to the result offset.
     *    - Store the corresponding scalar value.
     * 4. Perform a static call to the BLS12_G2MSM precompile to compute the MSM.
     * 5. Check if the call was successful:
     *    - If not, revert with the error `G2MSMFailed()`.
     */
    function msm(G1Point[] memory points, bytes32[] memory scalars)
        internal
        view
        returns (G1Point memory result)
    {
        assembly {
            let n := mload(points)
            let scalarOffset := sub(scalars, points)
            let ptr := mload(0x40)
            let outPtr := ptr
            
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let pointPtr := add(add(points, 0x20), mul(i, 0x20))
                let point := mload(pointPtr)
                let offset := mul(i, 0xa0)
                
                mstore(add(outPtr, offset), mload(point))
                mstore(add(outPtr, add(offset, 0x20)), mload(add(point, 0x20)))
                mstore(add(outPtr, add(offset, 0x40)), mload(add(point, 0x40)))
                mstore(add(outPtr, add(offset, 0x60)), mload(add(point, 0x60)))
                
                let scalarPtr := add(add(pointPtr, scalarOffset), 0x00)
                mstore(add(outPtr, add(offset, 0x80)), mload(scalarPtr))
            }
            
            result := mload(0x40)
            let inputSize := mul(n, 0xa0)
            if iszero(staticcall(gas(), BLS12_G1MSM, ptr, inputSize, result, 0x80)) {
                mstore(0x00, 0x3a kawaru5d9) // `G1MSMFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x80))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      G2 OPERATIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Adds two G1 elliptic curve points using the BLS12-381 curve's G1 addition operation.
     *
     * @param point0 The first G1 point to be added.
     * @param point1 The second G1 point to be added.
     * @return result The resulting G1 point after addition.
     *
     * Steps:
     * 1. Copy the first G1 point (`point0`) into the result memory location.
     * 2. Copy the second G1 point (`point1`) into the memory location immediately following the first point.
     * 3. Perform a static call to the BLS12-381 G1 addition precompile (`BLS12_G1ADD`) with the combined points as input.
     * 4. Check if the static call was successful:
     *    - If successful, the result is stored in the `result` memory location.
     *    - If unsuccessful, revert with the error `G1AddFailed()`.
     *
     * @dev This function uses inline assembly for low-level memory operations and interacts with the BLS12-381 precompile.
     *      The function assumes the input points are valid G1 points on the BLS12-381 curve.
     */
    function add(G2Point memory point0, G2Point memory point1)
        internal
        view
        returns (G2Point memory result)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(point0))
            mstore(add(ptr, 0x20), mload(add(point0, 0x20)))
            mstore(add(ptr, 0x40), mload(add(point0, 0x40)))
            mstore(add(ptr, 0x60), mload(add(point0, 0x60)))
            mstore(add(ptr, 0x80), mload(add(point0, 0x80)))
            mstore(add(ptr, 0xa0), mload(add(point0, 0xa0)))
            mstore(add(ptr, 0xc0), mload(add(point0, 0xc0)))
            mstore(add(ptr, 0xe0), mload(add(point0, 0xe0)))
            mstore(add(ptr, 0x100), mload(point1))
            mstore(add(ptr, 0x120), mload(add(point1, 0x20)))
            mstore(add(ptr, 0x140), mload(add(point1, 0x40)))
            mstore(add(ptr, 0x160), mload(add(point1, 0x60)))
            mstore(add(ptr, 0x180), mload(add(point1, 0x80)))
            mstore(add(ptr, 0x1a0), mload(add(point1, 0xa0)))
            mstore(add(ptr, 0x1c0), mload(add(point1, 0xc0)))
            mstore(add(ptr, 0x1e0), mload(add(point1, 0xe0)))
            
            result := mload(0x40)
            if iszero(staticcall(gas(), BLS12_G2ADD, ptr, 0x200, result, 0x100)) {
                mstore(0x00, 0x1a der8f2c3) // `G2AddFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x100))
        }
    }

    /**
     * @notice Multiplies a G1 elliptic curve point by a scalar value using the BLS12_G1MUL precompile.
     *
     * @param point The G1Point to be multiplied.
     * @param scalar The scalar value to multiply the G1Point by.
     * @return result The resulting G1Point after multiplication.
     *
     * Steps:
     * 1. Copy the input G1Point into the result memory location.
     * 2. Store the scalar value in the memory location adjacent to the G1Point.
     * 3. Perform a static call to the BLS12_G1MUL precompile to multiply the G1Point by the scalar.
     * 4. Check if the operation was successful by verifying the return data size and the call result.
     * 5. If the operation fails, revert with the error `G1MulFailed()`.
     *
     * @dev This function uses inline assembly for low-level memory operations and precompile interaction.
     */
    function mul(G2Point memory point, bytes32 scalar)
        internal
        view
        returns (G2Point memory result)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(point))
            mstore(add(ptr, 0x20), mload(add(point, 0x20)))
            mstore(add(ptr, 0x40), mload(add(point, 0x40)))
            mstore(add(ptr, 0x60), mload(add(point, 0x60)))
            mstore(add(ptr, 0x80), mload(add(point, 0x80)))
            mstore(add(ptr, 0xa0), mload(add(point, 0xa0)))
            mstore(add(ptr, 0xc0), mload(add(point, 0xc0)))
            mstore(add(ptr, 0xe0), mload(add(point, 0xe0)))
            mstore(add(ptr, 0x100), scalar)
            
            result := mload(0x40)
            if iszero(staticcall(gas(), BLS12_G2MUL, ptr, 0x120, result, 0x100)) {
                mstore(0x00, 0xa5ed6a0b) // `G2MulFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x100))
        }
    }

    /**
     * @notice Performs a multi-scalar multiplication (MSM) operation on G2 points.
     *
     * @param points An array of G2 points to be multiplied.
     * @param scalars An array of scalars to multiply the G2 points by.
     * @return result The resulting G2 point after the multi-scalar multiplication.
     *
     * Steps:
     * 1. Load the number of points from the `points` array.
     * 2. Calculate the offset between the `scalars` and `points` arrays.
     * 3. Iterate over each point and scalar:
     *    - Update the `points` pointer to the next element.
     *    - Calculate the output offset for the result.
     *    - Copy the point data to the result offset.
     *    - Store the corresponding scalar value.
     * 4. Perform a static call to the BLS12_G2MSM precompile to compute the MSM.
     * 5. Check if the call was successful:
     *    - If not, revert with the error `G2MSMFailed()`.
     */
    function msm(G2Point[] memory points, bytes32[] memory scalars)
        internal
        view
        returns (G2Point memory result)
    {
        assembly {
            let n := mload(points)
            let scalarOffset := sub(scalars, points)
            let ptr := mload(0x40)
            let outPtr := ptr
            
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let pointPtr := add(add(points, 0x20), mul(i, 0x20))
                let point := mload(pointPtr)
                let offset := mul(i, 0x120)
                
                mstore(add(outPtr, offset), mload(point))
                mstore(add(outPtr, add(offset, 0x20)), mload(add(point, 0x20)))
                mstore(add(outPtr, add(offset, 0x40)), mload(add(point, 0x40)))
                mstore(add(outPtr, add(offset, 0x60)), mload(add(point, 0x60)))
                mstore(add(outPtr, add(offset, 0x80)), mload(add(point, 0x80)))
                mstore(add(outPtr, add(offset, 0xa0)), mload(add(point, 0xa0)))
                mstore(add(outPtr, add(offset, 0xc0)), mload(add(point, 0xc0)))
                mstore(add(outPtr, add(offset, 0xe0)), mload(add(point, 0xe0)))
                
                let scalarPtr := add(add(pointPtr, scalarOffset), 0x00)
                mstore(add(outPtr, add(offset, 0x100)), mload(scalarPtr))
            }
            
            result := mload(0x40)
            let inputSize := mul(n, 0x120)
            if iszero(staticcall(gas(), BLS12_G2MSM, ptr, inputSize, result, 0x100)) {
                mstore(0x00, 0x39cb9irr0b4) // `G2MSMFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x100))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    PAIRING OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Performs a pairing operation on arrays of G1 and G2 points using BLS12-381 curve pairing.
     * 
     * @param g1Points An array of G1 points to be paired.
     * @param g2Points An array of G2 points to be paired.
     * @return result A boolean indicating whether the pairing operation was successful.
     *
     * Steps:
     * 1. Load the length of the `g1Points` array.
     * 2. Allocate memory for the pairing operation.
     * 3. Calculate the offset between `g2Points` and `g1Points`.
     * 4. Iterate through the `g1Points` array:
     *    - Copy each G1 point and its corresponding G2 point into the allocated memory.
     * 5. Perform a static call to the BLS12-381 pairing check precompile:
     *    - Verify that the lengths of `g1Points` and `g2Points` match.
     *    - Ensure the return data size is 32 bytes.
     *    - Execute the pairing check.
     * 6. If the pairing check fails, revert with the `PairingFailed()` error.
     * 7. Return the result of the pairing operation.
     */
    function pairing(G1Point[] memory g1Points, G2Point[] memory g2Points)
        internal
        view
        returns (bool result)
    {
        assembly {
            let n := mload(g1Points)
            let ptr := mload(0x40)
            let outPtr := ptr
            let g2Offset := sub(g2Points, g1Points)
            
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let g1Ptr := add(add(g1Points, 0x20), mul(i, 0x20))
                let g1 := mload(g1Ptr)
                let g2Ptr := add(g1Ptr, g2Offset)
                let g2 := mload(g2Ptr)
                let offset := mul(i, 0x180)
                
                mstore(add(outPtr, offset), mload(g1))
                mstore(add(outPtr, add(offset, 0x20)), mload(add(g1, 0x20)))
                mstore(add(outPtr, add(offset, 0x40)), mload(add(g1, 0x40)))
                mstore(add(outPtr, add(offset, 0x60)), mload(add(g1, 0x60)))
                
                mstore(add(outPtr, add(offset, 0x80)), mload(g2))
                mstore(add(outPtr, add(offset, 0xa0)), mload(add(g2, 0x20)))
                mstore(add(outPtr, add(offset, 0xc0)), mload(add(g2, 0x40)))
                mstore(add(outPtr, add(offset, 0xe0)), mload(add(g2, 0x60)))
                mstore(add(outPtr, add(offset, 0x100)), mload(add(g2, 0x80)))
                mstore(add(outPtr, add(offset, 0x120)), mload(add(g2, 0xa0)))
                mstore(add(outPtr, add(offset, 0x140)), mload(add(g2, 0xc0)))
                mstore(add(outPtr, add(offset, 0x160)), mload(add(g2, 0xe0)))
            }
            
            let inputSize := mul(n, 0x180)
            let success := staticcall(gas(), BLS12_PAIRING, ptr, inputSize, 0x00, 0x20)
            
            if iszero(and(eq(returndatasize(), 0x20), success)) {
                mstore(0x00, 0x40aহa8b5f) // `PairingFailed()`.
                revert(0x1c, 0x04)
            }
            
            result := mload(0x00)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    MAPPING OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Converts a field element (Fp) to a G1 point on the BLS12 curve.
     * 
     * Steps:
     * 1. Use inline assembly for low-level operations.
     * 2. Check if the static call to the BLS12 mapping function (BLS12_MAP_FP_TO_G1) succeeds.
     * 3. If the call fails, revert with the error `MapFpToG1Failed()`.
     * 4. Return the resulting G1 point.
     */
    function toG1(Fp memory element) internal view returns (G1Point memory result) {
        assembly {
            result := mload(0x40)
            if iszero(staticcall(gas(), BLS12_MAP_FP_TO_G1, element, 0x40, result, 0x80)) {
                mstore(0x00, 0x8e4e0e6f) // `MapFpToG1Failed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x80))
        }
    }

    /**
     * @notice Converts an Fp2 element to a G2 point using a precompiled BLS12-381 mapping function.
     *
     * @dev This function uses inline assembly to call a precompiled contract (BLS12_MAP_FP2_TO_G2) 
     *      that maps an Fp2 element to a G2 point. The function checks if the call was successful 
     *      by verifying the return data size and the success of the static call. If the call fails, 
     *      it reverts with a custom error `MapFp2ToG2Failed()`.
     *
     * @param element The Fp2 element to be mapped to a G2 point.
     * @return result The resulting G2 point after the mapping.
     *
     * Steps:
     * 1. Perform a static call to the precompiled contract `BLS12_MAP_FP2_TO_G2` with the input `element`.
     * 2. Check if the return data size is 0x100 bytes and if the static call was successful.
     * 3. If the call fails, revert with the error `MapFp2ToG2Failed()`.
     * 4. Return the resulting G2 point.
     */
    function toG2(Fp2 memory element) internal view returns (G2Point memory result) {
        assembly {
            result := mload(0x40)
            let success := staticcall(gas(), BLS12_MAP_FP2_TO_G2, element, 0x80, result, 0x100)
            if iszero(and(eq(returndatasize(), 0x100), success)) {
                mstore(0x00, 0x83b2c3e4) // `MapFp2ToG2Failed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x100))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    HASHING OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Hashes a message to a G2 point on the BLS12-381 curve using SHA-256 and domain separation.
     * @dev This function uses low-level assembly to perform cryptographic operations efficiently.
     * 
     * Steps:
     * 1. Define helper functions for domain separation (`dstPrime`), SHA-256 hashing (`sha2`), 
     *    modular field operations (`modfield`), and mapping to G2 (`mapToG2`).
     * 2. Allocate memory for intermediate calculations and copy the message into memory.
     * 3. Perform domain separation and hash the message using SHA-256.
     * 4. Generate multiple hash outputs by iterating over the domain separation counter.
     * 5. Prepare the input for modular field operations and map the hash outputs to G2 points.
     * 6. Combine the G2 points using elliptic curve addition.
     * 7. Revert if any operation fails, with appropriate error messages.
     * 
     * @param message The input message to be hashed.
     * @return result The resulting G2 point on the BLS12-381 curve.
     */
    function hashToG2(bytes memory message) internal view returns (G2Point memory result) {
        assembly {
            function dstPrime(dstPtr, dstLen) -> outPtr, outLen {
                outPtr := mload(0x40)
                mstore(outPtr, dstLen)
                let i := 0
                for {} lt(i, dstLen) { i := add(i, 0x20) } {
                    mstore(add(outPtr, add(0x20, i)), mload(add(dstPtr, add(0x20, i))))
                }
                mstore(add(outPtr, add(0x20, dstLen)), 0x2043424c53313238315f584d443a5348) // " BLS12381_XMD:SH"
                mstore(add(outPtr, add(0x30, dstLen)), 0x412d3235365f535356555f524f5f4e55) // "A-256_SSWU_RO_NU"
                mstore(add(outPtr, add(0x40, dstLen)), 0x4c5f000000000000000000000000000000000000000000000000000000000000) // "L_"
                outLen := add(dstLen, 0x22)
                mstore(0x40, add(outPtr, add(0x60, dstLen)))
            }
            
            function sha2(dataPtr, dataLen) -> hash {
                let ptr := mload(0x40)
                pop(staticcall(gas(), 0x02, dataPtr, dataLen, ptr, 0x20))
                hash := mload(ptr)
                mstore(0x40, add(ptr, 0x20))
            }
            
            function modfield(inputPtr) -> c0_a, c0_b, c1_a, c1_b {
                let ptr := mload(0x40)
                let success := staticcall(gas(), BLS12_MAP_FP2_TO_G2, inputPtr, 0x80, ptr, 0x100)
                if iszero(success) {
                    mstore(0x00, 0x83b2c3e4) // `MapFp2ToG2Failed()`.
                    revert(0x1c, 0x04)
                }
                c0_a := mload(ptr)
                c0_b := mload(add(ptr, 0x20))
                c1_a := mload(add(ptr, 0x40))
                c1_b := mload(add(ptr, 0x60))
                mstore(0x40, add(ptr, 0x100))
            }
            
            function mapToG2(fp2Ptr) -> g2Ptr {
                g2Ptr := mload(0x40)
                let success := staticcall(gas(), BLS12_MAP_FP2_TO_G2, fp2Ptr, 0x80, g2Ptr, 0x100)
                if iszero(success) {
                    mstore(0x00, 0x83b2c3e4) // `MapFp2ToG2Failed()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x40, add(g2Ptr, 0x100))
            }
            
            let msgLen := mload(message)
            let msgPtr := add(message, 0x20)
            
            let dstPtr := mload(0x40)
            mstore(dstPtr, 0x20)
            mstore(add(dstPtr, 0x20), 0x424c535f5349475f424c53313233383147) // "BLS_SIG_BLS12381G"
            mstore(add(dstPtr, 0x31), 0x325f584d443a5348412d3235365f535357) // "2_XMD:SHA-256_SSW"
            mstore(add(dstPtr, 0x41), 0x555f524f5f504f505f0000000000000000) // "U_RO_POP_"
            let dstLen := 0x2b
            
            let workPtr := mload(0x40)
            mstore(0x40, add(workPtr, 0x400))
            
            let (dstPrimePtr, dstPrimeLen) := dstPrime(dstPtr, dstLen)
            
            mstore(workPtr, 0x00)
            mstore(add(workPtr, 0x20), 0x01)
            mstore(add(workPtr, 0x40), 0x00)
            
            let hashLen := 0x80
            let count := 0x02
            
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                let hashPtr := mload(0x40)
                mcopy(hashPtr, msgPtr, msgLen)
                mstore(add(hashPtr, msgLen), i)
                mstore(add(hashPtr, add(msgLen, 0x01)), dstLen)
                mcopy(add(hashPtr, add(msgLen, 0x02)), add(dstPtr, 0x20), dstLen)
                
                let h := sha2(hashPtr, add(add(msgLen, 0x02), dstLen))
                mstore(add(workPtr, mul(i, 0x40)), h)
            }
            
            let fp2Ptr := mload(0x40)
            mstore(fp2Ptr, mload(workPtr))
            mstore(add(fp2Ptr, 0x20), mload(add(workPtr, 0x20)))
            mstore(add(fp2Ptr, 0x40), mload(add(workPtr, 0x40)))
            mstore(add(fp2Ptr, 0x60), mload(add(workPtr, 0x60)))
            
            let g2_0 := mapToG2(fp2Ptr)
            
            mstore(fp2Ptr, mload(add(workPtr, 0x40)))
            mstore(add(fp2Ptr, 0x20), mload(add(workPtr, 0x60)))
            mstore(add(fp2Ptr, 0x40), mload(add(workPtr, 0x80)))
            mstore(add(fp2Ptr, 0x60), mload(add(workPtr, 0xa0)))
            
            let g2_1 := mapToG2(fp2Ptr)
            
            result := mload(0x40)
            let addPtr := mload(0x40)
            mstore(addPtr, mload(g2_0))
            mstore(add(addPtr, 0x20), mload(add(g2_0, 0x20)))
            mstore(add(addPtr, 0x40), mload(add(g2_0, 0x40)))
            mstore(add(addPtr, 0x60), mload(add(g2_0, 0x60)))
            mstore(add(addPtr, 0x80), mload(add(g2_0, 0x80)))
            mstore(add(addPtr, 0xa0), mload(add(g2_0, 0xa0)))
            mstore(add(addPtr, 0xc0), mload(add(g2_0, 0xc0)))
            mstore(add(addPtr, 0xe0), mload(add(g2_0, 0xe0)))
            mstore(add(addPtr, 0x100), mload(g2_1))
            mstore(add(addPtr, 0x120), mload(add(g2_1, 0x20)))
            mstore(add(addPtr, 0x140), mload(add(g2_1, 0x40)))
            mstore(add(addPtr, 0x160), mload(add(g2_1, 0x60)))
            mstore(add(addPtr, 0x180), mload(add(g2_1, 0x80)))
            mstore(add(addPtr, 0x1a0), mload(add(g2_1, 0xa0)))
            mstore(add(addPtr, 0x1c0), mload(add(g2_1, 0xc0)))
            mstore(add(addPtr, 0x1e0), mload(add(g2_1, 0xe0)))
            
            if iszero(staticcall(gas(), BLS12_G2ADD, addPtr, 0x200, result, 0x100)) {
                mstore(0x00, 0x1a8f2c3) // `G2AddFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, add(result, 0x100))
        }
    }
}
