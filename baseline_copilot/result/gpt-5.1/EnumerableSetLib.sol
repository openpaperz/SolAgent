// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library EnumerableSetLib {
    /// @dev Error thrown when trying to use the reserved zero sentinel value.
    error ValueIsZeroSentinel();

    /// @dev Error thrown when an index is out of bounds.
    error IndexOutOfBounds();

    /// @notice Seed for computing the root slot of a set.
    uint256 private constant _ENUMERABLE_WORD_SET_SLOT_SEED =
        0x8b1f4f4c3e6d5c2a1b9e8d7c6b5a4938271f0e0d0c0b0a0908070605040302;

    /**
     * @notice A struct named `AddressSet` with a single field `_spacer` of type `uint256`.
     *
     * This struct is likely used as a placeholder or for alignment purposes, as it only contains a single field named `_spacer`.
     */
    struct AddressSet {
        uint256 _spacer;
    }

    /**
     * @notice A struct representing a set of bytes32 values.
     *
     * @dev This struct is a placeholder or spacer, potentially used for alignment or future expansion.
     * It currently contains a single `_spacer` field of type `uint256`.
     */
    struct Bytes32Set {
        uint256 _spacer;
    }

    /**
     * @notice A struct representing a set of uint256 values.
     *
     * @dev This struct is currently a placeholder with a single uint256 field (`_spacer`).
     * It can be extended to include additional functionality for managing sets of uint256 values.
     */
    struct Uint256Set {
        uint256 _spacer;
    }

    /**
     * @notice A struct representing a set of int256 values.
     *
     * @dev This struct is currently a placeholder with a single `_spacer` field, which is a uint256.
     * It may be intended for future use or extension to store and manage a set of int256 values.
     */
    struct Int256Set {
        uint256 _spacer;
    }

    /**
     * @notice Defines a struct `Uint8Set` that holds a single `uint256` value named `data`.
     *
     * This struct can be used to store a set of `uint8` values in a compact manner,
     * where each bit in the `uint256` represents a `uint8` value (0 or 1).
     * This is useful for managing sets of small integers efficiently.
     */
    struct Uint8Set {
        uint256 data;
    }

    /**
     * @notice Returns the length of the AddressSet, which represents the number of unique addresses stored in the set.
     */
    function length(AddressSet storage set) internal view returns (uint256 result) {
        result = length(_toBytes32Set(set));
    }

    /**
     * @notice Returns the length of the Bytes32Set, which represents the number of unique values stored in the set.
     */
    function length(Bytes32Set storage set) internal view returns (uint256 result) {
        bytes32 root = _rootSlot(set);
        assembly {
            let packed := sload(root)
            result := shr(224, packed)
        }
    }

    /**
     * @notice Returns the length of the Uint256Set, which represents the number of unique values stored in the set.
     */
    function length(Uint256Set storage set) internal view returns (uint256 result) {
        result = length(_toBytes32Set(set));
    }

    /**
     * @notice Returns the length of the Int256Set, which represents the number of unique values stored in the set.
     */
    function length(Int256Set storage set) internal view returns (uint256 result) {
        result = length(_toBytes32Set(set));
    }

    /**
     * @notice Returns the length of the Uint8Set, which represents the number of unique values stored in the set.
     */
    function length(Uint8Set storage set) internal view returns (uint256 result) {
        uint256 data = set.data;
        while (data != 0) {
            result += data & 1;
            data >>= 1;
        }
    }

    /**
     * @notice Checks if a given address exists in the AddressSet.
     */
    function contains(AddressSet storage set, address value) internal view returns (bool result) {
        bytes32 v = bytes32(uint256(uint160(value)));
        result = contains(_toBytes32Set(set), v);
    }

    /**
     * @notice Checks if a given value exists in the Bytes32Set.
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool result) {
        if (value == bytes32(0)) revert ValueIsZeroSentinel();
        bytes32 root = _rootSlot(set);
        assembly {
            let packed := sload(root)
            let n := shr(224, packed)
            if iszero(n) {
                result := 0
            }
            {
                let slot := add(root, 1)
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    if eq(sload(slot), value) {
                        result := 1
                        break
                    }
                    slot := add(slot, 1)
                }
            }
        }
    }

    /**
     * @notice Checks if a given value exists in the Uint256Set.
     */
    function contains(Uint256Set storage set, uint256 value) internal view returns (bool result) {
        result = contains(_toBytes32Set(set), bytes32(value));
    }

    /**
     * @notice Checks if a given value exists in the Int256Set.
     */
    function contains(Int256Set storage set, int256 value) internal view returns (bool result) {
        result = contains(_toBytes32Set(set), bytes32(uint256(value)));
    }

    /**
     * @notice Checks if a given value exists in the Uint8Set.
     */
    function contains(Uint8Set storage set, uint8 value) internal view returns (bool result) {
        if (value >= 256) return false;
        uint256 mask = 1 << value;
        result = (set.data & mask) != 0;
    }

    /**
     * @notice Adds an address to the AddressSet if it is not already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool result) {
        bytes32 v = bytes32(uint256(uint160(value)));
        result = add(_toBytes32Set(set), v);
    }

    /**
     * @notice Adds a value to the Bytes32Set if it is not already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool result) {
        if (value == bytes32(0)) revert ValueIsZeroSentinel();
        bytes32 root = _rootSlot(set);
        assembly {
            let packed := sload(root)
            let n := shr(224, packed)
            let slot := add(root, 1)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                if eq(sload(slot), value) {
                    result := 0
                    leave
                }
                slot := add(slot, 1)
            }
            sstore(slot, value)
            packed := or(and(packed, 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff), shl(224, add(n, 1)))
            sstore(root, packed)
            result := 1
        }
    }

    /**
     * @notice Adds a value to the Uint256Set if it is not already present.
     */
    function add(Uint256Set storage set, uint256 value) internal returns (bool result) {
        result = add(_toBytes32Set(set), bytes32(value));
    }

    /**
     * @notice Adds a value to the Int256Set if it is not already present.
     */
    function add(Int256Set storage set, int256 value) internal returns (bool result) {
        result = add(_toBytes32Set(set), bytes32(uint256(value)));
    }

    /**
     * @notice Adds a value to the Uint8Set if it is not already present.
     */
    function add(Uint8Set storage set, uint8 value) internal returns (bool result) {
        if (value >= 256) return false;
        uint256 mask = 1 << value;
        if ((set.data & mask) != 0) {
            return false;
        }
        set.data |= mask;
        return true;
    }

    /**
     * @notice Removes a specific address from an AddressSet storage structure.
     */
    function remove(AddressSet storage set, address value) internal returns (bool result) {
        bytes32 v = bytes32(uint256(uint160(value)));
        result = remove(_toBytes32Set(set), v);
    }

    /**
     * @notice Removes a specific value from a Bytes32Set storage structure.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool result) {
        if (value == bytes32(0)) revert ValueIsZeroSentinel();
        bytes32 root = _rootSlot(set);
        assembly {
            let packed := sload(root)
            let n := shr(224, packed)
            let slot := add(root, 1)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                if eq(sload(slot), value) {
                    result := 1
                    let lastSlot := add(root, n)
                    if lt(slot, lastSlot) {
                        sstore(slot, sload(lastSlot))
                    }
                    sstore(lastSlot, 0)
                    packed := or(and(packed, 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff), shl(224, sub(n, 1)))
                    sstore(root, packed)
                    leave
                }
                slot := add(slot, 1)
            }
        }
    }

    /**
     * @notice Removes a specific value from a Uint256Set storage structure.
     */
    function remove(Uint256Set storage set, uint256 value) internal returns (bool result) {
        result = remove(_toBytes32Set(set), bytes32(value));
    }

    /**
     * @notice Removes a specific value from an Int256Set storage structure.
     */
    function remove(Int256Set storage set, int256 value) internal returns (bool result) {
        result = remove(_toBytes32Set(set), bytes32(uint256(value)));
    }

    /**
     * @notice Removes a specific value from a Uint8Set storage structure.
     */
    function remove(Uint8Set storage set, uint8 value) internal returns (bool result) {
        if (value >= 256) return false;
        uint256 mask = 1 << value;
        if ((set.data & mask) == 0) return false;
        set.data &= ~mask;
        return true;
    }

    /**
     * @notice Retrieves the list of addresses stored in the AddressSet.
     */
    function values(AddressSet storage set) internal view returns (address[] memory result) {
        bytes32[] memory raw = values(_toBytes32Set(set));
        uint256 len = raw.length;
        result = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = address(uint160(uint256(raw[i])));
        }
    }

    /**
     * @notice Retrieves the list of values stored in the Bytes32Set.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory result) {
        bytes32 root = _rootSlot(set);
        uint256 n;
        assembly {
            let packed := sload(root)
            n := shr(224, packed)
        }
        result = new bytes32[](n);
        assembly {
            let slot := add(root, 1)
            let ptr := add(result, 0x20)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                mstore(ptr, sload(slot))
                ptr := add(ptr, 0x20)
                slot := add(slot, 1)
            }
        }
    }

    /**
     * @notice Retrieves the list of values stored in the Uint256Set.
     */
    function values(Uint256Set storage set) internal view returns (uint256[] memory result) {
        bytes32[] memory raw = values(_toBytes32Set(set));
        result = _toUints(raw);
    }

    /**
     * @notice Retrieves the list of values stored in the Int256Set.
     */
    function values(Int256Set storage set) internal view returns (int256[] memory result) {
        bytes32[] memory raw = values(_toBytes32Set(set));
        result = _toInts(raw);
    }

    /**
     * @notice Retrieves the list of values stored in the Uint8Set.
     */
    function values(Uint8Set storage set) internal view returns (uint8[] memory result) {
        uint256 count = length(set);
        result = new uint8[](count);
        uint256 data = set.data;
        uint256 idx;
        for (uint8 i = 0; i < 256 && idx < count; i++) {
            if ((data & (1 << i)) != 0) {
                result[idx] = i;
                idx++;
            }
        }
    }

    /**
     * @notice Retrieves the address at a specific index in an AddressSet.
     */
    function at(AddressSet storage set, uint256 i) internal view returns (address result) {
        bytes32 v = at(_toBytes32Set(set), i);
        result = address(uint160(uint256(v)));
    }

    /**
     * @notice Retrieves the value at a specific index in a Bytes32Set.
     */
    function at(Bytes32Set storage set, uint256 i) internal view returns (bytes32 result) {
        bytes32 root = _rootSlot(set);
        uint256 n;
        assembly {
            let packed := sload(root)
            n := shr(224, packed)
        }
        if (i >= n) revert IndexOutOfBounds();
        assembly {
            let slot := add(add(root, 1), i)
            result := sload(slot)
        }
    }

    /**
     * @notice Retrieves the value at a specific index in a Uint256Set.
     */
    function at(Uint256Set storage set, uint256 i) internal view returns (uint256 result) {
        result = uint256(at(_toBytes32Set(set), i));
    }

    /**
     * @notice Retrieves the value at a specific index in an Int256Set.
     */
    function at(Int256Set storage set, uint256 i) internal view returns (int256 result) {
        result = int256(uint256(at(_toBytes32Set(set), i)));
    }

    /**
     * @notice Retrieves the value at a specific index in a Uint8Set.
     */
    function at(Uint8Set storage set, uint256 i) internal view returns (uint8 result) {
        uint8[] memory vals = values(set);
        if (i >= vals.length) revert IndexOutOfBounds();
        result = vals[i];
    }

    /**
     * @notice Computes the root slot for a given AddressSet storage.
     */
    function _rootSlot(AddressSet storage s) private pure returns (bytes32 r) {
        assembly {
            mstore(0x00, s.slot)
            mstore(0x20, _ENUMERABLE_WORD_SET_SLOT_SEED)
            r := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Computes the root slot for a given Bytes32Set storage.
     */
    function _rootSlot(Bytes32Set storage s) private pure returns (bytes32 r) {
        assembly {
            mstore(0x00, s.slot)
            mstore(0x20, _ENUMERABLE_WORD_SET_SLOT_SEED)
            r := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Converts an AddressSet storage reference to a Bytes32Set storage reference.
     */
    function _toBytes32Set(AddressSet storage s) private pure returns (Bytes32Set storage c) {
        assembly {
            c.slot := s.slot
        }
    }

    /**
     * @notice Converts a Uint256Set storage reference to a Bytes32Set storage reference.
     */
    function _toBytes32Set(Uint256Set storage s) private pure returns (Bytes32Set storage c) {
        assembly {
            c.slot := s.slot
        }
    }

    /**
     * @notice Converts an Int256Set storage reference to a Bytes32Set storage reference.
     */
    function _toBytes32Set(Int256Set storage s) private pure returns (Bytes32Set storage c) {
        assembly {
            c.slot := s.slot
        }
    }

    /**
     * @notice Converts an array of `bytes32` to an array of `uint256`.
     */
    function _toUints(bytes32[] memory a) private pure returns (uint256[] memory c) {
        assembly {
            c := a
        }
    }

    /**
     * @notice Converts an array of `bytes32` to an array of `int256` using low-level assembly.
     */
    function _toInts(bytes32[] memory a) private pure returns (int256[] memory c) {
        assembly {
            c := a
        }
    }
}