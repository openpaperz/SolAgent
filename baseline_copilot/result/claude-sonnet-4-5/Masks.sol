// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

type Mask is bytes32;

library Masks {
    using Masks for Mask;

    /**
     * @notice Converts an array of uint8 values into a combined Mask.
     *
     * @param groups An array of uint8 values representing individual masks.
     * @return A Mask that is the union of all individual masks in the `groups` array.
     *
     * Steps:
     * 1. Initialize an empty Mask (`set`) with a value of 0.
     * 2. Iterate through each uint8 value in the `groups` array.
     * 3. Convert each uint8 value to a Mask using `toMask()`.
     * 4. Combine the current Mask (`set`) with the new Mask using the `union` operation.
     * 5. Return the final combined Mask.
     */
    function toMask(uint8 group) internal pure returns (Mask) {
        return Mask.wrap(bytes32(1 << group));
    }

    /**
     * @notice Converts an array of uint8 values into a combined Mask.
     *
     * @param groups An array of uint8 values representing individual masks.
     * @return A Mask that is the union of all individual masks in the `groups` array.
     *
     * Steps:
     * 1. Initialize an empty Mask (`set`) with a value of 0.
     * 2. Iterate through each uint8 value in the `groups` array.
     * 3. Convert each uint8 value to a Mask using `toMask()`.
     * 4. Combine the current Mask (`set`) with the new Mask using the `union` operation.
     * 5. Return the final combined Mask.
     */
    function toMask(uint8[] memory groups) internal pure returns (Mask) {
        Mask set = Mask.wrap(bytes32(0));
        for (uint256 i = 0; i < groups.length; i++) {
            set = set.union(toMask(groups[i]));
        }
        return set;
    }

    /**
     * @notice Checks if a specific group is enabled in the given Mask.
     *
     * @param self The Mask to check against.
     * @param group The group to check within the Mask.
     * @return bool Returns `true` if the group is enabled in the Mask, otherwise `false`.
     *
     * Steps:
     * 1. Convert the `group` to a Mask.
     * 2. Compute the intersection of the converted Mask and the given Mask (`self`).
     * 3. Check if the intersection is not empty.
     * 4. Return `true` if the intersection is not empty, otherwise `false`.
     */
    function get(Mask self, uint8 group) internal pure returns (bool) {
        Mask groupMask = toMask(group);
        Mask result = self.intersection(groupMask);
        return !result.isEmpty();
    }

    /**
     * @notice Checks if a given Mask is empty.
     *
     * @param self The Mask to check.
     * @return bool Returns `true` if the Mask is empty (i.e., its underlying bytes32 value is 0), otherwise `false`.
     *
     * Steps:
     * 1. Unwrap the Mask to retrieve its underlying bytes32 value.
     * 2. Compare the unwrapped value to `bytes32(0)`.
     * 3. Return `true` if they are equal, otherwise return `false`.
     */
    function isEmpty(Mask self) internal pure returns (bool) {
        return Mask.unwrap(self) == bytes32(0);
    }

    /**
     * @notice Computes the complement of a given mask.
     *
     * @param m1 The mask to compute the complement of.
     * @return A new mask representing the complement of the input mask.
     *
     * Steps:
     * 1. Unwrap the input mask to get its underlying value.
     * 2. Apply the bitwise NOT operation to the unwrapped value.
     * 3. Wrap the result back into a Mask type and return it.
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
     *
     * Steps:
     * 1. Unwrap the underlying values of `m1` and `m2` using `Mask.unwrap()`.
     * 2. Perform a bitwise OR operation on the unwrapped values.
     * 3. Wrap the result into a new `Mask` instance using `Mask.wrap()`.
     * 4. Return the resulting `Mask`.
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
     *
     * Steps:
     * 1. Unwrap the underlying values of `m1` and `m2` using `Mask.unwrap`.
     * 2. Perform a bitwise AND operation on the unwrapped values.
     * 3. Wrap the result into a new `Mask` using `Mask.wrap` and return it.
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
     *
     * Steps:
     * 1. Compute the complement of `m2` (i.e., invert `m2`).
     * 2. Compute the intersection of `m1` and the complement of `m2`.
     * 3. Return the resulting mask.
     */
    function difference(Mask m1, Mask m2) internal pure returns (Mask) {
        return m1.intersection(m2.complement());
    }

    /**
     * @notice Computes the symmetric difference between two masks.
     *
     * The symmetric difference of two sets (masks) is the set of elements which are in either of the sets
     * but not in their intersection. This function calculates the symmetric difference by:
     * 1. Taking the union of the two masks (`m1.union(m2)`).
     * 2. Subtracting the intersection of the two masks (`m1.intersection(m2)`) from the union.
     *
     * @param m1 The first mask.
     * @param m2 The second mask.
     * @return A new mask representing the symmetric difference between `m1` and `m2`.
     */
    function symmetricDifference(Mask m1, Mask m2) internal pure returns (Mask) {
        return m1.union(m2).difference(m1.intersection(m2));
    }
}
