// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Lightweight, generic enumerable sets for several primitive types.
/// @dev This implementation stores set contents in storage using a root slot
/// computed from the user's struct slot and an internal seed. Uint8Set is a
/// compact bitset implementation.
library EnumerableSetLib {
    // Errors
    error ValueIsZeroSentinel();
    error IndexOutOfBounds();

    // seeds
    bytes32 private constant _ENUMERABLE_WORD_SET_SLOT_SEED =
        keccak256("solady.enumerable_word_set.slot_seed");

    // Struct definitions as requested by the plan (placeholders / roots).
    struct AddressSet {
        uint256 _spacer;
    }

    struct Bytes32Set {
        uint256 _spacer;
    }

    struct Uint256Set {
        uint256 _spacer;
    }

    struct Int256Set {
        uint256 _spacer;
    }

    /// @notice Uint8Set stores a bitmask in a single uint256. Valid values are 0..255.
    struct Uint8Set {
        uint256 data;
    }

    /* -------------------------------------------------------------------------
       Internal helpers: root slot computation and conversions
       ------------------------------------------------------------------------- */

    /// @dev Compute the root slot for an arbitrary set (based on the struct slot).
    function _rootSlot(Bytes32Set storage s) private pure returns (bytes32 r) {
        bytes32 slot;
        assembly {
            slot := s
        }
        r = keccak256(abi.encodePacked(slot, _ENUMERABLE_WORD_SET_SLOT_SEED));
    }

    /// @dev For AddressSet / Uint256Set / Int256Set convert a storage pointer to a Bytes32Set pointer
    /// so the core storage layout and routines are shared.
    function _toBytes32Set(Uint256Set storage s)
        private
        pure
        returns (Bytes32Set storage c)
    {
        assembly {
            c := s
        }
    }

    function _toBytes32Set(Int256Set storage s)
        private
        pure
        returns (Bytes32Set storage c)
    {
        assembly {
            c := s
        }
    }

    function _toBytes32Set(AddressSet storage s)
        private
        pure
        returns (Bytes32Set storage c)
    {
        assembly {
            c := s
        }
    }

    /// @dev Reinterpret a memory bytes32[] as a uint256[] (no copy).
    function _toUints(bytes32[] memory a)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly {
            c := a
        }
    }

    /// @dev Reinterpret a memory bytes32[] as an int256[] (no copy).
    function _toInts(bytes32[] memory a)
        private
        pure
        returns (int256[] memory c)
    {
        assembly {
            c := a
        }
    }

    /* -------------------------------------------------------------------------
       Core Bytes32Set implementations (backed by dynamic storage)
       Storage layout:
         - len stored at slot `root` (uint256)
         - elements stored at consecutive slots starting from keccak256(root)
       ------------------------------------------------------------------------- */

    function length(Bytes32Set storage set) internal view returns (uint256 result) {
        bytes32 root = _rootSlot(set);
        uint256 rslot = uint256(root);
        assembly {
            result := sload(rslot)
        }
    }

    function contains(Bytes32Set storage set, bytes32 value)
        internal
        view
        returns (bool result)
    {
        if (value == bytes32(0)) revert ValueIsZeroSentinel();

        bytes32 root = _rootSlot(set);
        uint256 rslot = uint256(root);

        uint256 len;
        assembly {
            len := sload(rslot)
        }
        if (len == 0) return false;

        bytes32 dataStart = keccak256(abi.encodePacked(root));
        uint256 start = uint256(dataStart);

        for (uint256 i = 0; i < len; ++i) {
            bytes32 v;
            uint256 slot = start + i;
            assembly {
                v := sload(slot)
            }
            if (v == value) return true;
        }
        return false;
    }

    function add(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool result)
    {
        if (value == bytes32(0)) revert ValueIsZeroSentinel();

        bytes32 root = _rootSlot(set);
        uint256 rslot = uint256(root);

        uint256 len;
        assembly {
            len := sload(rslot)
        }

        bytes32 dataStart = keccak256(abi.encodePacked(root));
        uint256 start = uint256(dataStart);

        // check existence
        for (uint256 i = 0; i < len; ++i) {
            bytes32 v;
            uint256 slot = start + i;
            assembly {
                v := sload(slot)
            }
            if (v == value) return false;
        }

        // append
        uint256 appendSlot = start + len;
        assembly {
            sstore(appendSlot, value)
            sstore(rslot, add(len, 1))
        }
        return true;
    }

    function remove(Bytes32Set storage set, bytes32 value)
        internal
        returns (bool result)
    {
        if (value == bytes32(0)) revert ValueIsZeroSentinel();

        bytes32 root = _rootSlot(set);
        uint256 rslot = uint256(root);

        uint256 len;
        assembly {
            len := sload(rslot)
        }
        if (len == 0) return false;

        bytes32 dataStart = keccak256(abi.encodePacked(root));
        uint256 start = uint256(dataStart);

        // find index
        uint256 idx = type(uint256).max;
        for (uint256 i = 0; i < len; ++i) {
            bytes32 v;
            uint256 slot = start + i;
            assembly {
                v := sload(slot)
            }
            if (v == value) {
                idx = i;
                break;
            }
        }
        if (idx == type(uint256).max) return false;

        uint256 lastIndex = len - 1;
        uint256 lastSlot = start + lastIndex;
        bytes32 lastVal;
        assembly {
            lastVal := sload(lastSlot)
        }

        if (idx != lastIndex) {
            uint256 targetSlot = start + idx;
            assembly {
                sstore(targetSlot, lastVal)
            }
        }

        // clear last and decrement len
        assembly {
            sstore(lastSlot, 0)
            sstore(rslot, sub(len, 1))
        }
        return true;
    }

    function values(Bytes32Set storage set)
        internal
        view
        returns (bytes32[] memory result)
    {
        bytes32 root = _rootSlot(set);
        uint256 rslot = uint256(root);
        uint256 len;
        assembly {
            len := sload(rslot)
        }

        result = new bytes32[](len);
        if (len == 0) return result;

        bytes32 dataStart = keccak256(abi.encodePacked(root));
        uint256 start = uint256(dataStart);
        for (uint256 i = 0; i < len; ++i) {
            uint256 slot = start + i;
            bytes32 v;
            assembly {
                v := sload(slot)
            }
            result[i] = v;
        }
    }

    function at(Bytes32Set storage set, uint256 i)
        internal
        view
        returns (bytes32 result)
    {
        bytes32 root = _rootSlot(set);
        uint256 rslot = uint256(root);
        uint256 len;
        assembly {
            len := sload(rslot)
        }
        if (i >= len) revert IndexOutOfBounds();

        bytes32 dataStart = keccak256(abi.encodePacked(root));
        uint256 slot = uint256(dataStart) + i;
        assembly {
            result := sload(slot)
        }
    }

    /* -------------------------------------------------------------------------
       AddressSet wrapper (converts addresses to bytes32)
       ------------------------------------------------------------------------- */

    function length(AddressSet storage set) internal view returns (uint256 result) {
        return length(_toBytes32Set(set));
    }

    function contains(AddressSet storage set, address value)
        internal
        view
        returns (bool result)
    {
        if (value == address(0)) revert ValueIsZeroSentinel();
        return contains(_toBytes32Set(set), bytes32(uint256(uint160(value))));
    }

    function add(AddressSet storage set, address value) internal returns (bool result) {
        if (value == address(0)) revert ValueIsZeroSentinel();
        return add(_toBytes32Set(set), bytes32(uint256(uint160(value))));
    }

    function remove(AddressSet storage set, address value) internal returns (bool result) {
        if (value == address(0)) revert ValueIsZeroSentinel();
        return remove(_toBytes32Set(set), bytes32(uint256(uint160(value))));
    }

    function values(AddressSet storage set) internal view returns (address[] memory result) {
        bytes32[] memory tmp = values(_toBytes32Set(set));
        result = new address[](tmp.length);
        for (uint256 i = 0; i < tmp.length; ++i) {
            result[i] = address(uint160(uint256(tmp[i])));
        }
    }

    function at(AddressSet storage set, uint256 i) internal view returns (address result) {
        bytes32 v = at(_toBytes32Set(set), i);
        return address(uint160(uint256(v)));
    }

    /* -------------------------------------------------------------------------
       Uint256Set wrapper
       ------------------------------------------------------------------------- */

    function length(Uint256Set storage set) internal view returns (uint256 result) {
        return length(_toBytes32Set(set));
    }

    function contains(Uint256Set storage set, uint256 value)
        internal
        view
        returns (bool result)
    {
        return contains(_toBytes32Set(set), bytes32(value));
    }

    function add(Uint256Set storage set, uint256 value) internal returns (bool result) {
        return add(_toBytes32Set(set), bytes32(value));
    }

    function remove(Uint256Set storage set, uint256 value) internal returns (bool result) {
        return remove(_toBytes32Set(set), bytes32(value));
    }

    function values(Uint256Set storage set) internal view returns (uint256[] memory result) {
        bytes32[] memory tmp = values(_toBytes32Set(set));
        return _toUints(tmp);
    }

    function at(Uint256Set storage set, uint256 i) internal view returns (uint256 result) {
        bytes32 v = at(_toBytes32Set(set), i);
        return uint256(v);
    }

    /* -------------------------------------------------------------------------
       Int256Set wrapper
       ------------------------------------------------------------------------- */

    function length(Int256Set storage set) internal view returns (uint256 result) {
        return length(_toBytes32Set(set));
    }

    function contains(Int256Set storage set, int256 value)
        internal
        view
        returns (bool result)
    {
        return contains(_toBytes32Set(set), bytes32(uint256(value)));
    }

    function add(Int256Set storage set, int256 value) internal returns (bool result) {
        return add(_toBytes32Set(set), bytes32(uint256(value)));
    }

    function remove(Int256Set storage set, int256 value) internal returns (bool result) {
        return remove(_toBytes32Set(set), bytes32(uint256(value)));
    }

    function values(Int256Set storage set) internal view returns (int256[] memory result) {
        bytes32[] memory tmp = values(_toBytes32Set(set));
        return _toInts(tmp);
    }

    function at(Int256Set storage set, uint256 i) internal view returns (int256 result) {
        bytes32 v = at(_toBytes32Set(set), i);
        return int256(uint256(v));
    }

    /* -------------------------------------------------------------------------
       Uint8Set: bitmask-based 0..255 set
       ------------------------------------------------------------------------- */

    function length(Uint8Set storage set) internal view returns (uint256 result) {
        // population count of 256-bit word
        uint256 x = set.data;
        // builtin popcount not available; use Kernighan's algo (gas ok for 256 bits)
        while (x != 0) {
            result++;
            x &= x - 1;
        }
    }

    function contains(Uint8Set storage set, uint8 value) internal view returns (bool result) {
        uint256 mask = uint256(1) << value;
        return (set.data & mask) != 0;
    }

    function add(Uint8Set storage set, uint8 value) internal returns (bool result) {
        uint256 mask = uint256(1) << value;
        if ((set.data & mask) != 0) return false;
        set.data |= mask;
        return true;
    }

    function remove(Uint8Set storage set, uint8 value) internal returns (bool result) {
        uint256 mask = uint256(1) << value;
        if ((set.data & mask) == 0) return false;
        set.data &= ~mask;
        return true;
    }

    function values(Uint8Set storage set) internal view returns (uint8[] memory result) {
        uint256 cnt = length(set);
        result = new uint8[](cnt);
        uint256 idx;
        uint256 x = set.data;
        uint8 pos = 0;
        while (x != 0) {
            if ((x & 1) == 1) {
                result[idx++] = pos;
            }
            x >>= 1;
            pos++;
        }
    }

    function at(Uint8Set storage set, uint256 i) internal view returns (uint8 result) {
        uint256 cnt = length(set);
        if (i >= cnt) revert IndexOutOfBounds();
        uint256 idx;
        uint256 x = set.data;
        uint8 pos = 0;
        while (x != 0) {
            if ((x & 1) == 1) {
                if (idx == i) return pos;
                idx++;
            }
            x >>= 1;
            pos++;
        }
        revert IndexOutOfBounds();
    }
}
// ...existing code...