// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library MerkleProofLib {
    /**
     * @notice Verifies a Merkle proof by computing the root hash from the provided proof and leaf.
     *
     * @param proof An array of bytes32 values representing the Merkle proof.
     * @param root The expected root hash of the Merkle tree.
     * @param leaf The leaf node to verify against the Merkle proof.
     * @return isValid A boolean indicating whether the computed root matches the provided root.
     *
     * Steps:
     * 1. Check if the proof array is not empty.
     * 2. Initialize the offset to the start of the proof array in memory.
     * 3. Calculate the end of the proof array in memory.
     * 4. Iterate over each element in the proof array:
     *    a. Compare the current leaf with the proof element.
     *    b. Store the leaf and proof element in scratch space for hashing.
     *    c. Compute the hash of the concatenated leaf and proof element.
     *    d. Update the leaf to the computed hash.
     *    e. Move to the next proof element.
     * 5. After processing all proof elements, compare the final computed leaf with the provided root.
     * 6. Return true if they match, otherwise false.
     *
     * @dev This function uses low-level assembly for efficient memory manipulation and hashing.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf)
        internal
        pure
        returns (bool isValid)
    {
        assembly {
            if mload(proof) {
                let end := add(proof, shl(5, mload(proof)))
                let offset := add(proof, 0x20)
                for {} 1 {} {
                    let a := leaf
                    let b := mload(offset)
                    if iszero(lt(a, b)) {
                        mstore(0x00, b)
                        mstore(0x20, a)
                    }
                    if lt(a, b) {
                        mstore(0x00, a)
                        mstore(0x20, b)
                    }
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }

    /**
     * @notice Verifies a Merkle proof by reconstructing the root hash from the provided proof and leaf.
     *
     * @param proof An array of bytes32 representing the Merkle proof.
     * @param root The expected root hash of the Merkle tree.
     * @param leaf The leaf node to be verified against the root.
     * @return isValid A boolean indicating whether the reconstructed root matches the provided root.
     *
     * Steps:
     * 1. Check if the proof array is non-empty.
     * 2. Calculate the end offset of the proof array in calldata.
     * 3. Initialize the offset to the start of the proof array in calldata.
     * 4. Iterate over each element in the proof array:
     *    a. Determine the position in scratch space to store the leaf and proof element.
     *    b. Store the leaf and proof element contiguously in scratch space.
     *    c. Compute the hash of the concatenated leaf and proof element.
     *    d. Update the leaf to the computed hash for the next iteration.
     *    e. Increment the offset to process the next proof element.
     *    f. Break the loop if the end of the proof array is reached.
     * 5. Compare the final computed leaf with the provided root.
     * 6. Return true if they match, otherwise false.
     *
     * @dev This function uses low-level assembly for efficient memory and stack operations.
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf)
        internal
        pure
        returns (bool isValid)
    {
        assembly {
            if proof.length {
                let end := add(proof.offset, shl(5, proof.length))
                let offset := proof.offset
                for {} 1 {} {
                    let a := leaf
                    let b := calldataload(offset)
                    if iszero(lt(a, b)) {
                        mstore(0x00, b)
                        mstore(0x20, a)
                    }
                    if lt(a, b) {
                        mstore(0x00, a)
                        mstore(0x20, b)
                    }
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }

    /**
     * @notice Verifies a multi-proof for a Merkle tree using a given set of leaves, proof, and flags.
     *
     * @param proof An array of proof elements used to verify the Merkle tree.
     * @param root The root of the Merkle tree to verify against.
     * @param leaves An array of leaves to be verified.
     * @param flags An array of boolean flags indicating whether to pop from the queue or the proof.
     * @return isValid A boolean indicating whether the multi-proof is valid.
     *
     * Steps:
     * 1. Cache the lengths of the input arrays (proof, leaves, flags).
     * 2. Advance the pointers of the arrays to point to their respective data.
     * 3. Check if the number of flags is correct relative to the lengths of the proof and leaves.
     * 4. If the number of flags is zero, validate the proof or leaf directly against the root.
     * 5. Otherwise, compute the required final proof offset and initialize the queue for hashes.
     * 6. Copy the leaves into the hashes queue.
     * 7. Iterate through the flags to process the proof and queue:
     *    - Pop elements from the hashes queue or proof based on the flag.
     *    - Hash the elements and push the result back onto the queue.
     * 8. Validate the last element in the queue against the root and ensure all proofs are used.
     * 9. Return whether the multi-proof is valid.
     *
     * @dev This function uses low-level assembly for gas optimization and memory safety.
     */
    function verifyMultiProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32[] memory leaves,
        bool[] memory flags
    ) internal pure returns (bool isValid) {
        assembly {
            let leavesLength := mload(leaves)
            let proofLength := mload(proof)
            let flagsLength := mload(flags)
            
            leaves := add(leaves, 0x20)
            proof := add(proof, 0x20)
            flags := add(flags, 0x20)
            
            if iszero(eq(add(leavesLength, proofLength), add(flagsLength, 1))) {
                mstore(0x00, 0)
                return(0x00, 0x20)
            }
            
            if iszero(flagsLength) {
                if proofLength {
                    isValid := eq(mload(proof), root)
                    mstore(0x00, isValid)
                    return(0x00, 0x20)
                }
                if leavesLength {
                    isValid := eq(mload(leaves), root)
                    mstore(0x00, isValid)
                    return(0x00, 0x20)
                }
            }
            
            let proofEnd := add(proof, shl(5, proofLength))
            let hashedPtr := mload(0x40)
            let hashedEnd := add(hashedPtr, shl(5, leavesLength))
            
            for { let leavesEnd := add(leaves, shl(5, leavesLength)) } lt(leaves, leavesEnd) {} {
                mstore(hashedPtr, mload(leaves))
                leaves := add(leaves, 0x20)
                hashedPtr := add(hashedPtr, 0x20)
            }
            
            hashedPtr := mload(0x40)
            let flagsEnd := add(flags, shl(5, flagsLength))
            
            for {} lt(flags, flagsEnd) {} {
                let a := mload(hashedPtr)
                hashedPtr := add(hashedPtr, 0x20)
                
                let b := 0
                if mload(flags) {
                    b := mload(hashedPtr)
                    hashedPtr := add(hashedPtr, 0x20)
                }
                if iszero(mload(flags)) {
                    b := mload(proof)
                    proof := add(proof, 0x20)
                }
                
                if iszero(lt(a, b)) {
                    mstore(0x00, b)
                    mstore(0x20, a)
                }
                if lt(a, b) {
                    mstore(0x00, a)
                    mstore(0x20, b)
                }
                
                mstore(hashedEnd, keccak256(0x00, 0x40))
                hashedEnd := add(hashedEnd, 0x20)
                flags := add(flags, 0x20)
            }
            
            isValid := and(eq(mload(sub(hashedEnd, 0x20)), root), eq(proof, proofEnd))
        }
    }

    /**
     * @notice Verifies a Merkle multi-proof using calldata for efficiency.
     *
     * @param proof An array of Merkle proof elements.
     * @param root The Merkle root to verify against.
     * @param leaves An array of leaf nodes to verify.
     * @param flags An array of boolean flags indicating whether to pop from the queue or the proof.
     * @return isValid A boolean indicating whether the proof is valid.
     *
     * Steps:
     * 1. Check if the number of flags matches the expected value (leaves.length + proof.length == flags.length + 1).
     * 2. If there are no flags, validate the single leaf or proof against the root.
     * 3. Otherwise, initialize the queue with the leaves and process the proof and flags:
     *    - Pop two elements from the queue.
     *    - If the flag is false, use the next proof element; otherwise, use the next queue element.
     *    - Hash the two elements and push the result back into the queue.
     * 4. Verify that the last element in the queue matches the root and that all proof elements were used.
     * 5. Return the validity of the proof.
     *
     * @dev This function uses low-level assembly for gas efficiency and memory safety.
     */
    function verifyMultiProofCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32[] calldata leaves,
        bool[] calldata flags
    ) internal pure returns (bool isValid) {
        assembly {
            let leavesLength := leaves.length
            let proofLength := proof.length
            let flagsLength := flags.length
            
            if iszero(eq(add(leavesLength, proofLength), add(flagsLength, 1))) {
                mstore(0x00, 0)
                return(0x00, 0x20)
            }
            
            if iszero(flagsLength) {
                if proofLength {
                    isValid := eq(calldataload(proof.offset), root)
                    mstore(0x00, isValid)
                    return(0x00, 0x20)
                }
                if leavesLength {
                    isValid := eq(calldataload(leaves.offset), root)
                    mstore(0x00, isValid)
                    return(0x00, 0x20)
                }
            }
            
            let proofEnd := add(proof.offset, shl(5, proofLength))
            let proofOffset := proof.offset
            
            let hashedPtr := mload(0x40)
            let hashedEnd := add(hashedPtr, shl(5, leavesLength))
            
            for { let i := 0 } lt(i, leavesLength) { i := add(i, 1) } {
                mstore(add(hashedPtr, shl(5, i)), calldataload(add(leaves.offset, shl(5, i))))
            }
            
            hashedPtr := mload(0x40)
            let flagsOffset := flags.offset
            let flagsEnd := add(flagsOffset, shl(5, flagsLength))
            
            for {} lt(flagsOffset, flagsEnd) {} {
                let a := mload(hashedPtr)
                hashedPtr := add(hashedPtr, 0x20)
                
                let b := 0
                if calldataload(flagsOffset) {
                    b := mload(hashedPtr)
                    hashedPtr := add(hashedPtr, 0x20)
                }
                if iszero(calldataload(flagsOffset)) {
                    b := calldataload(proofOffset)
                    proofOffset := add(proofOffset, 0x20)
                }
                
                if iszero(lt(a, b)) {
                    mstore(0x00, b)
                    mstore(0x20, a)
                }
                if lt(a, b) {
                    mstore(0x00, a)
                    mstore(0x20, b)
                }
                
                mstore(hashedEnd, keccak256(0x00, 0x40))
                hashedEnd := add(hashedEnd, 0x20)
                flagsOffset := add(flagsOffset, 0x20)
            }
            
            isValid := and(eq(mload(sub(hashedEnd, 0x20)), root), eq(proofOffset, proofEnd))
        }
    }

    /**
     * @notice Returns an empty proof array.
     *
     * @dev This function uses inline assembly to set the length of the proof array to 0.
     * It is marked as `internal pure` and returns a `bytes32[] calldata` array.
     *
     * Steps:
     * 1. Use inline assembly to set the length of the `proof` array to 0.
     * 2. Return the empty `proof` array.
     */
    function emptyProof() internal pure returns (bytes32[] calldata proof) {
        assembly {
            proof.length := 0
        }
    }

    /**
     * @notice Returns an empty array of `bytes32` leaves.
     *
     * @return leaves An empty array of `bytes32` elements.
     *
     * Steps:
     * 1. Use inline assembly to set the length of the `leaves` array to 0.
     * 2. Return the empty array.
     */
    function emptyLeaves() internal pure returns (bytes32[] calldata leaves) {
        assembly {
            leaves.length := 0
        }
    }

    /**
     * @notice Returns an empty array of boolean flags.
     *
     * @return flags An empty array of boolean flags.
     *
     * Steps:
     * 1. Use inline assembly to set the length of the `flags` array to 0.
     * 2. Return the empty array.
     */
    function emptyFlags() internal pure returns (bool[] calldata flags) {
        assembly {
            flags.length := 0
        }
    }
}
