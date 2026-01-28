// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Masks {
    /// @notice A Mask is a 32-byte bitset used to represent up to 256 groups.
    type Mask is bytes32;

    /**
     * @notice Converts a single uint8 group into a Mask with that bit set.
     *
     * @param group The group index (0..255) to convert into a Mask.
     * @return A Mask with only the bit for `group` set.
     */
    function toMask(uint8 group) internal pure returns (Mask) {
        return Mask.wrap(bytes32(uint256(1) << uint256(group)));
    }

    /**
     * @notice Converts an array of uint8 values into a combined Mask.
     *
     * @param groups An array of uint8 values representing individual masks.
     * @return A Mask that is the union of all individual masks in the `groups` array.
     */
    function toMask(uint8[] memory groups) internal pure returns (Mask) {
        Mask set = Mask.wrap(bytes32(0));
        for (uint256 i = 0; i < groups.length; ++i) {
            set = union(set, toMask(groups[i]));
        }
        return set;
    }

    /**
     * @notice Checks if a specific group is enabled in the given Mask.
     *
     * @param self The Mask to check against.
     * @param group The group to check within the Mask.
     * @return bool Returns `true` if the group is enabled in the Mask, otherwise `false`.
     */
    function get(Mask self, uint8 group) internal pure returns (bool) {
        Mask g = toMask(group);
        return (Mask.unwrap(self) & Mask.unwrap(g)) != bytes32(0);
    }

    /**
     * @notice Checks if a given Mask is empty.
     *
     * @param self The Mask to check.
     * @return bool Returns `true` if the Mask is empty (i.e., its underlying bytes32 value is 0), otherwise `false`.
     */
    function isEmpty(Mask self) internal pure returns (bool) {
        return Mask.unwrap(self) == bytes32(0);
    }

    /**
     * @notice Computes the complement of a given mask.
     *
     * @param m1 The mask to compute the complement of.
     * @return A new mask representing the complement of the input mask.
     */
    function complement(Mask m1) internal pure returns (Mask) {
        return Mask.wrap(~Mask.unwrap(m1));
    }

    /**
     * @notice Combines two `Mask` instances using a bitwise OR operation and returns the resulting `Mask`.
     *
     * @param m1 The first `Mask` instance to be combined.
     * @param m2 The second `Mask` instance to be combined.
     * @return A new `Mask` instance representing the union of `m1` and `m2`.
     */
    function union(Mask m1, Mask m2) internal pure returns (Mask) {
        return Mask.wrap(Mask.unwrap(m1) | Mask.unwrap(m2));
    }

    /**
     * @notice Computes the intersection of two masks.
     *
     * @param m1 The first mask to intersect.
     * @param m2 The second mask to intersect.
     * @return A new mask representing the intersection of `m1` and `m2`.
     */
    function intersection(Mask m1, Mask m2) internal pure returns (Mask) {
        return Mask.wrap(Mask.unwrap(m1) & Mask.unwrap(m2));
    }

    /**
     * @notice Computes the difference between two masks.
     *
     * @param m1 The first mask.
     * @param m2 The second mask.
     * @return The resulting mask after computing the difference between `m1` and `m2`.
     */
    function difference(Mask m1, Mask m2) internal pure returns (Mask) {
        return intersection(m1, complement(m2));
    }

    /**
     * @notice Computes the symmetric difference between two masks.
     *
     * The symmetric difference of two sets (masks) is the set of elements which are in either of the sets
     * but not in their intersection.
     *
     * @param m1 The first mask.
     * @param m2 The second mask.
     * @return A new mask representing the symmetric difference between `m1` and `m2`.
     */
    function symmetricDifference(Mask m1, Mask m2) internal pure returns (Mask) {
        // XOR is the symmetric difference for bitsets.
        return Mask.wrap(Mask.unwrap(m1) ^ Mask.unwrap(m2));
    }
}
// ...existing code...