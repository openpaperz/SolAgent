// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Utility library for Merkle proof verification (single and multi-proof).
library MerkleProofLib {
    /// @notice Verifies a Merkle proof by computing the root hash from the provided proof and leaf.
    ///
    /// @param proof An array of bytes32 values representing the Merkle proof.
    /// @param root The expected root hash of the Merkle tree.
    /// @param leaf The leaf node to verify against the Merkle proof.
    /// @return isValid A boolean indicating whether the computed root matches the provided root.
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; ++i) {
            computed = _hashPair(computed, proof[i]);
        }
        return computed == root;
    }

    /// @notice Verifies a Merkle proof by reconstructing the root hash from the provided proof and leaf (calldata version).
    ///
    /// @param proof An array of bytes32 representing the Merkle proof.
    /// @param root The expected root hash of the Merkle tree.
    /// @param leaf The leaf node to be verified against the root.
    /// @return isValid A boolean indicating whether the reconstructed root matches the provided root.
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; ++i) {
            computed = _hashPair(computed, proof[i]);
        }
        return computed == root;
    }

    /// @notice Verifies a multi-proof for a Merkle tree using a given set of leaves, proof, and flags.
    ///
    /// @param proof An array of proof elements used to verify the Merkle tree.
    /// @param root The root of the Merkle tree to verify against.
    /// @param leaves An array of leaves to be verified.
    /// @param flags An array of boolean flags indicating whether to pop from the queue or the proof.
    /// @return isValid A boolean indicating whether the multi-proof is valid.
    function verifyMultiProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32[] memory leaves,
        bool[] memory flags
    ) internal pure returns (bool isValid) {
        // Verify expected relationship: leaves.length + proof.length == flags.length + 1
        require(leaves.length + proof.length - 1 == flags.length, "MerkleProofLib: invalid multiproof");
        bytes32 computed = _processMultiProof(proof, leaves, flags);
        return computed == root;
    }

    /// @notice Verifies a Merkle multi-proof using calldata for efficiency.
    ///
    /// @param proof An array of Merkle proof elements.
    /// @param root The Merkle root to verify against.
    /// @param leaves An array of leaf nodes to verify.
    /// @param flags An array of boolean flags indicating whether to pop from the queue or the proof.
    /// @return isValid A boolean indicating whether the proof is valid.
    function verifyMultiProofCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32[] calldata leaves,
        bool[] calldata flags
    ) internal pure returns (bool isValid) {
        require(leaves.length + proof.length - 1 == flags.length, "MerkleProofLib: invalid multiproof");
        bytes32 computed = _processMultiProofCalldata(proof, leaves, flags);
        return computed == root;
    }

    /// @notice Returns an empty proof array.
    function emptyProof() internal pure returns (bytes32[] calldata proof) {
        assembly {
            // Allocate a single word for the array header (length = 0)
            let ptr := mload(0x40)
            mstore(ptr, 0)
            // Return the pointer as calldata array pointer
            proof := ptr
        }
    }

    /// @notice Returns an empty array of `bytes32` leaves.
    function emptyLeaves() internal pure returns (bytes32[] calldata leaves) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0)
            leaves := ptr
        }
    }

    /// @notice Returns an empty array of boolean flags.
    function emptyFlags() internal pure returns (bool[] calldata flags) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0)
            flags := ptr
        }
    }

    /* ---------------------------------------------------------------------
       Internal helpers
       --------------------------------------------------------------------- */

    /// @dev Hashes a pair of bytes32 values in sorted order (lowest value first).
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32 result) {
        // Sort
        if (a < b) {
            assembly {
                // load free memory pointer
                let ptr := mload(0x40)
                mstore(ptr, a)
                mstore(add(ptr, 0x20), b)
                result := keccak256(ptr, 0x40)
            }
        } else {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, b)
                mstore(add(ptr, 0x20), a)
                result := keccak256(ptr, 0x40)
            }
        }
    }

    /// @dev Process multiproof (memory inputs) similar to OpenZeppelin's implementation.
    function _processMultiProof(
        bytes32[] memory proof,
        bytes32[] memory leaves,
        bool[] memory flags
    ) private pure returns (bytes32 merkleRoot) {
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = flags.length;

        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;

        for (uint256 i = 0; i < totalHashes; ++i) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b;
            if (flags[i]) {
                b = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            } else {
                b = proof[proofPos++];
            }
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            merkleRoot = hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            merkleRoot = leaves[0];
        } else {
            merkleRoot = proof[0];
        }
    }

    /// @dev Process multiproof (calldata inputs) similar to OpenZeppelin's implementation.
    function _processMultiProofCalldata(
        bytes32[] calldata proof,
        bytes32[] calldata leaves,
        bool[] calldata flags
    ) private pure returns (bytes32 merkleRoot) {
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = flags.length;

        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;

        for (uint256 i = 0; i < totalHashes; ++i) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b;
            if (flags[i]) {
                b = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            } else {
                b = proof[proofPos++];
            }
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            merkleRoot = hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            merkleRoot = leaves[0];
        } else {
            merkleRoot = proof[0];
        }
    }
}