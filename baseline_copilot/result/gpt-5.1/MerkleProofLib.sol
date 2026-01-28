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
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool isValid) {
        assembly {
            // if proof.length == 0, just compare leaf and root
            let len := mload(proof)
            if iszero(len) {
                isValid := eq(leaf, root)
            }
            // pointer to first element
            let p := add(proof, 0x20)
            // end pointer
            let end := add(p, shl(5, len)) // len * 32

            // scratch space for hashing at 0x00..0x3f
            for { } lt(p, end) { p := add(p, 0x20) } {
                let h := mload(p)

                // sort (leaf, h)
                switch lt(leaf, h)
                case 1 {
                    mstore(0x00, leaf)
                    mstore(0x20, h)
                }
                default {
                    mstore(0x00, h)
                    mstore(0x20, leaf)
                }

                leaf := keccak256(0x00, 0x40)
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
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool isValid) {
        assembly {
            let len := proof.length
            if iszero(len) {
                isValid := eq(leaf, root)
                leave
            }

            // start of proof data in calldata
            let offset := proof.offset
            let end := add(offset, shl(5, len))

            for { } lt(offset, end) { offset := add(offset, 0x20) } {
                let h := calldataload(offset)

                // sort (leaf, h)
                switch lt(leaf, h)
                case 1 {
                    mstore(0x00, leaf)
                    mstore(0x20, h)
                }
                default {
                    mstore(0x00, h)
                    mstore(0x20, leaf)
                }

                leaf := keccak256(0x00, 0x40)
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
            let pLen := mload(proof)
            let lLen := mload(leaves)
            let fLen := mload(flags)

            // condition: leaves.length + proof.length == flags.length + 1
            // and there must be at least one node (either leaf or proof)
            if iszero(eq(add(lLen, pLen), add(fLen, 1))) {
                leave
            }

            // if no flags, we just compare single leaf/proof to root
            switch fLen
            case 0 {
                // either one leaf or one proof element
                switch lLen
                case 1 {
                    isValid := eq(mload(add(leaves, 0x20)), root)
                }
                default {
                    switch pLen
                    case 1 {
                        isValid := eq(mload(add(proof, 0x20)), root)
                    }
                }
                leave
            }
            default { }

            // queue for hashes reuses `leaves` memory; we append new hashes after existing leaves.
            let queue := add(leaves, 0x20)
            let qHead := queue
            let qTail := add(queue, shl(5, lLen)) // end after leaves

            // pointers to proof and flags data
            let pPtr := add(proof, 0x20)
            let pEnd := add(pPtr, shl(5, pLen))
            let fPtr := add(flags, 0x20)
            let fEnd := add(fPtr, shl(5, fLen))

            // main loop over flags
            for { } lt(fPtr, fEnd) { fPtr := add(fPtr, 0x20) } {
                // pop first element from queue
                let a := mload(qHead)
                qHead := add(qHead, 0x20)

                // determine second element: from queue or proof
                let useQueue := mload(fPtr)
                let b
                switch useQueue
                case 0 {
                    // from proof
                    if iszero(lt(pPtr, pEnd)) {
                        // invalid: no more proof
                        leave
                    }
                    b := mload(pPtr)
                    pPtr := add(pPtr, 0x20)
                }
                default {
                    // from queue
                    if iszero(lt(qHead, qTail)) {
                        // invalid: queue underflow
                        leave
                    }
                    b := mload(qHead)
                    qHead := add(qHead, 0x20)
                }

                // sort (a, b) and hash
                switch lt(a, b)
                case 1 {
                    mstore(0x00, a)
                    mstore(0x20, b)
                }
                default {
                    mstore(0x00, b)
                    mstore(0x20, a)
                }

                let h := keccak256(0x00, 0x40)
                // push hash to queue
                mstore(qTail, h)
                qTail := add(qTail, 0x20)
            }

            // after processing all flags, there should be exactly one element left in queue
            // and all proof elements must be consumed
            if iszero(and(eq(sub(qTail, qHead), 0x20), eq(pPtr, pEnd))) {
                leave
            }

            isValid := eq(mload(qHead), root)
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
            let pLen := proof.length
            let lLen := leaves.length
            let fLen := flags.length

            // condition: leaves.length + proof.length == flags.length + 1
            if iszero(eq(add(lLen, pLen), add(fLen, 1))) {
                leave
            }

            switch fLen
            case 0 {
                switch lLen
                case 1 {
                    // single leaf
                    let leaf := calldataload(leaves.offset)
                    isValid := eq(leaf, root)
                }
                default {
                    switch pLen
                    case 1 {
                        let pe := calldataload(proof.offset)
                        isValid := eq(pe, root)
                    }
                }
                leave
            }
            default { }

            // allocate memory for queue: lLen + fLen elements at minimum.
            // We'll just use free memory pointer.
            let queue := mload(0x40)
            let qHead := queue
            let qTail := queue

            // copy leaves into queue
            {
                let lOff := leaves.offset
                let lEnd := add(lOff, shl(5, lLen))
                for { } lt(lOff, lEnd) { lOff := add(lOff, 0x20) } {
                    mstore(qTail, calldataload(lOff))
                    qTail := add(qTail, 0x20)
                }
            }

            // pointers to proof and flags in calldata
            let pOff := proof.offset
            let pEnd := add(pOff, shl(5, pLen))
            let fOff := flags.offset
            let fEnd := add(fOff, shl(5, fLen))

            // main loop over flags
            for { } lt(fOff, fEnd) { fOff := add(fOff, 0x20) } {
                // pop first queue element
                if iszero(lt(qHead, qTail)) {
                    leave
                }
                let a := mstore(0x80, mload(qHead)) // also keep a in stack
                a := mload(qHead)
                qHead := add(qHead, 0x20)

                // flag decides source of second element
                let useQueue := calldataload(fOff)
                let b
                switch useQueue
                case 0 {
                    // from proof
                    if iszero(lt(pOff, pEnd)) {
                        leave
                    }
                    b := calldataload(pOff)
                    pOff := add(pOff, 0x20)
                }
                default {
                    if iszero(lt(qHead, qTail)) {
                        leave
                    }
                    b := mload(qHead)
                    qHead := add(qHead, 0x20)
                }

                // sort (a, b) then hash
                switch lt(a, b)
                case 1 {
                    mstore(0x00, a)
                    mstore(0x20, b)
                }
                default {
                    mstore(0x00, b)
                    mstore(0x20, a)
                }

                let h := keccak256(0x00, 0x40)
                mstore(qTail, h)
                qTail := add(qTail, 0x20)
            }

            // ensure exactly one element remains in queue and all proof elements used
            if iszero(and(eq(sub(qTail, qHead), 0x20), eq(pOff, pEnd))) {
                leave
            }

            isValid := eq(mload(qHead), root)
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
            // calldata arrays are slices; create a slice of length 0 at position 0
            proof.length := 0
            proof.offset := 0
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
            leaves.offset := 0
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
            flags.offset := 0
        }
    }
}