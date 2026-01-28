// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for managing enumerable sets of different types.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/EnumerableSetLib.sol)
library EnumerableSetLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The value is the zero sentinel.
    error ValueIsZeroSentinel();

    /// @dev The index is out of bounds.
    error IndexOutOfBounds();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev A sentinel value to denote the zero value in a set.
    uint256 private constant _ZERO_SENTINEL = 1;

    /// @dev The storage slot seed for enumerable word sets.
    uint256 private constant _ENUMERABLE_WORD_SET_SLOT_SEED = 0x18fb5864;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev A struct representing a set of addresses.
    struct AddressSet {
        uint256 _spacer;
    }

    /// @dev A struct representing a set of bytes32 values.
    struct Bytes32Set {
        uint256 _spacer;
    }

    /// @dev A struct representing a set of uint256 values.
    struct Uint256Set {
        uint256 _spacer;
    }

    /// @dev A struct representing a set of int256 values.
    struct Int256Set {
        uint256 _spacer;
    }

    /// @dev A struct representing a set of uint8 values.
    struct Uint8Set {
        uint256 data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ADDRESS SET OPERATIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of elements in the set.
    function length(AddressSet storage set) internal view returns (uint256 result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                result := n
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                result := add(result, iszero(iszero(shr(96, sload(s)))))
            }
        }
    }

    /// @dev Returns whether `value` is in the set.
    function contains(AddressSet storage set, address value) internal view returns (bool result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            mstore(0x00, value)
            let v := shl(96, mload(0x00))
            if iszero(v) {
                if eq(value, _ZERO_SENTINEL) {
                    mstore(0x00, 0x5a6c1d0b)
                    revert(0x1c, 0x04)
                }
                v := shl(96, _ZERO_SENTINEL)
            }
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                mstore(0x00, v)
                result := iszero(iszero(sload(keccak256(0x00, 0x24))))
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                if eq(shr(96, shl(96, sload(s))), v) {
                    result := 1
                    break
                }
            }
        }
    }

    /// @dev Adds `value` to the set. Returns whether `value` was not in the set.
    function add(AddressSet storage set, address value) internal returns (bool result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            mstore(0x00, value)
            let v := shl(96, mload(0x00))
            if iszero(v) {
                if eq(value, _ZERO_SENTINEL) {
                    mstore(0x00, 0x5a6c1d0b)
                    revert(0x1c, 0x04)
                }
                v := shl(96, _ZERO_SENTINEL)
            }
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                mstore(0x00, v)
                let p := keccak256(0x00, 0x24)
                if iszero(sload(p)) {
                    sstore(p, or(shl(224, add(n, 1)), rootPacked))
                    sstore(rootSlot, or(shl(224, 4), rootPacked))
                    result := 1
                }
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                let e := sload(s)
                if eq(shr(96, shl(96, e)), v) {
                    break
                }
                if iszero(shr(96, e)) {
                    sstore(s, or(v, e))
                    result := 1
                    break
                }
            }
            if iszero(or(result, n)) {
                sstore(rootSlot, or(v, shl(224, add(n, 1))))
                result := 1
            }
        }
    }

    /// @dev Removes `value` from the set. Returns whether `value` was in the set.
    function remove(AddressSet storage set, address value) internal returns (bool result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            mstore(0x00, value)
            let v := shl(96, mload(0x00))
            if iszero(v) {
                if eq(value, _ZERO_SENTINEL) {
                    mstore(0x00, 0x5a6c1d0b)
                    revert(0x1c, 0x04)
                }
                v := shl(96, _ZERO_SENTINEL)
            }
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                mstore(0x00, v)
                let p := keccak256(0x00, 0x24)
                let e := sload(p)
                if iszero(iszero(e)) {
                    sstore(p, 0)
                    sstore(rootSlot, or(shl(224, sub(n, 1)), rootPacked))
                    result := 1
                }
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                let e := sload(s)
                if eq(shr(96, shl(96, e)), v) {
                    sstore(s, shl(96, shr(96, e)))
                    result := 1
                    break
                }
            }
        }
    }

    /// @dev Returns all elements in the set.
    function values(AddressSet storage set) internal view returns (address[] memory result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            let m := mload(0x40)
            result := m
            let o := add(m, 0x20)
            mstore(m, 0)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    mstore(0x00, shl(96, i))
                    let v := sload(keccak256(0x00, 0x24))
                    if iszero(iszero(v)) {
                        mstore(o, shr(96, v))
                        o := add(o, 0x20)
                        mstore(result, add(mload(result), 1))
                    }
                }
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                let v := shr(96, sload(s))
                if iszero(iszero(v)) {
                    if eq(v, _ZERO_SENTINEL) { v := 0 }
                    mstore(o, v)
                    o := add(o, 0x20)
                    mstore(result, add(mload(result), 1))
                }
            }
            mstore(0x40, o)
        }
    }

    /// @dev Returns the element at index `i` in the set.
    function at(AddressSet storage set, uint256 i) internal view returns (address result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                let c := 0
                for { let j := 0 } lt(j, n) { j := add(j, 1) } {
                    mstore(0x00, shl(96, j))
                    let v := sload(keccak256(0x00, 0x24))
                    if iszero(iszero(v)) {
                        if eq(c, i) {
                            result := shr(96, v)
                            break
                        }
                        c := add(c, 1)
                    }
                }
                if iszero(result) {
                    if iszero(lt(i, c)) {
                        mstore(0x00, 0x4e23d035)
                        revert(0x1c, 0x04)
                    }
                }
                break
            }
            let c := 0
            for { let j := 0 } lt(j, n) { j := add(j, 1) } {
                let s := add(rootSlot, j)
                let v := shr(96, sload(s))
                if iszero(iszero(v)) {
                    if eq(c, i) {
                        result := v
                        if eq(v, _ZERO_SENTINEL) { result := 0 }
                        break
                    }
                    c := add(c, 1)
                }
            }
            if iszero(result) {
                if iszero(lt(i, c)) {
                    mstore(0x00, 0x4e23d035)
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    BYTES32 SET OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of elements in the set.
    function length(Bytes32Set storage set) internal view returns (uint256 result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                result := n
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                result := add(result, iszero(iszero(sload(s))))
            }
        }
    }

    /// @dev Returns whether `value` is in the set.
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let v := value
            if iszero(v) {
                if eq(value, _ZERO_SENTINEL) {
                    mstore(0x00, 0x5a6c1d0b)
                    revert(0x1c, 0x04)
                }
                v := _ZERO_SENTINEL
            }
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                mstore(0x00, v)
                result := iszero(iszero(sload(keccak256(0x00, 0x24))))
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                if eq(sload(s), v) {
                    result := 1
                    break
                }
            }
        }
    }

    /// @dev Adds `value` to the set. Returns whether `value` was not in the set.
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let v := value
            if iszero(v) {
                if eq(value, _ZERO_SENTINEL) {
                    mstore(0x00, 0x5a6c1d0b)
                    revert(0x1c, 0x04)
                }
                v := _ZERO_SENTINEL
            }
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                mstore(0x00, v)
                let p := keccak256(0x00, 0x24)
                if iszero(sload(p)) {
                    sstore(p, or(shl(224, add(n, 1)), rootPacked))
                    sstore(rootSlot, or(shl(224, 4), rootPacked))
                    result := 1
                }
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                let e := sload(s)
                if eq(e, v) {
                    break
                }
                if iszero(e) {
                    sstore(s, v)
                    result := 1
                    break
                }
            }
            if iszero(or(result, n)) {
                sstore(rootSlot, or(v, shl(224, add(n, 1))))
                result := 1
            }
        }
    }

    /// @dev Removes `value` from the set. Returns whether `value` was in the set.
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let v := value
            if iszero(v) {
                if eq(value, _ZERO_SENTINEL) {
                    mstore(0x00, 0x5a6c1d0b)
                    revert(0x1c, 0x04)
                }
                v := _ZERO_SENTINEL
            }
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                mstore(0x00, v)
                let p := keccak256(0x00, 0x24)
                let e := sload(p)
                if iszero(iszero(e)) {
                    sstore(p, 0)
                    sstore(rootSlot, or(shl(224, sub(n, 1)), rootPacked))
                    result := 1
                }
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                if eq(sload(s), v) {
                    sstore(s, 0)
                    result := 1
                    break
                }
            }
        }
    }

    /// @dev Returns all elements in the set.
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            let m := mload(0x40)
            result := m
            let o := add(m, 0x20)
            mstore(m, 0)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    mstore(0x00, i)
                    let v := sload(keccak256(0x00, 0x24))
                    if iszero(iszero(v)) {
                        mstore(o, v)
                        o := add(o, 0x20)
                        mstore(result, add(mload(result), 1))
                    }
                }
                break
            }
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let s := add(rootSlot, i)
                let v := sload(s)
                if iszero(iszero(v)) {
                    if eq(v, _ZERO_SENTINEL) { v := 0 }
                    mstore(o, v)
                    o := add(o, 0x20)
                    mstore(result, add(mload(result), 1))
                }
            }
            mstore(0x40, o)
        }
    }

    /// @dev Returns the element at index `i` in the set.
    function at(Bytes32Set storage set, uint256 i) internal view returns (bytes32 result) {
        bytes32 rootSlot = _rootSlot(set);
        assembly ("memory-safe") {
            let rootPacked := sload(rootSlot)
            let n := shr(224, rootPacked)
            for {} iszero(lt(n, 4)) {} {
                mstore(0x04, rootSlot)
                let c := 0
                for { let j := 0 } lt(j, n) { j := add(j, 1) } {
                    mstore(0x00, j)
                    let v := sload(keccak256(0x00, 0x24))
                    if iszero(iszero(v)) {
                        if eq(c, i) {
                            result := v
                            break
                        }
                        c := add(c, 1)
                    }
                }
                if iszero(result) {
                    if iszero(lt(i, c)) {
                        mstore(0x00, 0x4e23d035)
                        revert(0x1c, 0x04)
                    }
                }
                break
            }
            let c := 0
            for { let j := 0 } lt(j, n) { j := add(j, 1) } {
                let s := add(rootSlot, j)
                let v := sload(s)
                if iszero(iszero(v)) {
                    if eq(c, i) {
                        result := v
                        if eq(v, _ZERO_SENTINEL) { result := 0 }
                        break
                    }
                    c := add(c, 1)
                }
            }
            if iszero(result) {
                if iszero(lt(i, c)) {
                    mstore(0x00, 0x4e23d035)
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   UINT256 SET OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of elements in the set.
    function length(Uint256Set storage set) internal view returns (uint256 result) {
        result = length(_toBytes32Set(set));
    }

    /// @dev Returns whether `value` is in the set.
    function contains(Uint256Set storage set, uint256 value) internal view returns (bool result) {
        result = contains(_toBytes32Set(set), bytes32(value));
    }

    /// @dev Adds `value` to the set. Returns whether `value` was not in the set.
    function add(Uint256Set storage set, uint256 value) internal returns (bool result) {
        result = add(_toBytes32Set(set), bytes32(value));
    }

    /// @dev Removes `value` from the set. Returns whether `value` was in the set.
    function remove(Uint256Set storage set, uint256 value) internal returns (bool result) {
        result = remove(_toBytes32Set(set), bytes32(value));
    }

    /// @dev Returns all elements in the set.
    function values(Uint256Set storage set) internal view returns (uint256[] memory result) {
        result = _toUints(values(_toBytes32Set(set)));
    }

    /// @dev Returns the element at index `i` in the set.
    function at(Uint256Set storage set, uint256 i) internal view returns (uint256 result) {
        result = uint256(at(_toBytes32Set(set), i));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INT256 SET OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of elements in the set.
    function length(Int256Set storage set) internal view returns (uint256 result) {
        result = length(_toBytes32Set(set));
    }

    /// @dev Returns whether `value` is in the set.
    function contains(Int256Set storage set, int256 value) internal view returns (bool result) {
        result = contains(_toBytes32Set(set), bytes32(uint256(value)));
    }

    /// @dev Adds `value` to the set. Returns whether `value` was not in the set.
    function add(Int256Set storage set, int256 value) internal returns (bool result) {
        result = add(_toBytes32Set(set), bytes32(uint256(value)));
    }

    /// @dev Removes `value` from the set. Returns whether `value` was in the set.
    function remove(Int256Set storage set, int256 value) internal returns (bool result) {
        result = remove(_toBytes32Set(set), bytes32(uint256(value)));
    }

    /// @dev Returns all elements in the set.
    function values(Int256Set storage set) internal view returns (int256[] memory result) {
        result = _toInts(values(_toBytes32Set(set)));
    }

    /// @dev Returns the element at index `i` in the set.
    function at(Int256Set storage set, uint256 i) internal view returns (int256 result) {
        result = int256(uint256(at(_toBytes32Set(set), i)));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UINT8 SET OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of elements in the set.
    function length(Uint8Set storage set) internal view returns (uint256 result) {
        assembly ("memory-safe") {
            let data := sload(set.slot)
            for { let i := 0 } lt(i, 256) { i := add(i, 1) } {
                result := add(result, and(shr(i, data), 1))
            }
        }
    }

    /// @dev Returns whether `value` is in the set.
    function contains(Uint8Set storage set, uint8 value) internal view returns (bool result) {
        assembly ("memory-safe") {
            result := and(shr(value, sload(set.slot)), 1)
        }
    }

    /// @dev Adds `value` to the set. Returns whether `value` was not in the set.
    function add(Uint8Set storage set, uint8 value) internal returns (bool result) {
        assembly ("memory-safe") {
            let data := sload(set.slot)
            let mask := shl(value, 1)
            result := iszero(and(data, mask))
            if result {
                sstore(set.slot, or(data, mask))
            }
        }
    }

    /// @dev Removes `value` from the set. Returns whether `value` was in the set.
    function remove(Uint8Set storage set, uint8 value) internal returns (bool result) {
        assembly ("memory-safe") {
            let data := sload(set.slot)
            let mask := shl(value, 1)
            result := iszero(iszero(and(data, mask)))
            if result {
                sstore(set.slot, and(data, not(mask)))
            }
        }
    }

    /// @dev Returns all elements in the set.
    function values(Uint8Set storage set) internal view returns (uint8[] memory result) {
        assembly ("memory-safe") {
            let data := sload(set.slot)
            let m := mload(0x40)
            result := m
            let o := add(m, 0x20)
            mstore(m, 0)
            for { let i := 0 } lt(i, 256) { i := add(i, 1) } {
                if and(shr(i, data), 1) {
                    mstore(o, i)
                    o := add(o, 0x20)
                    mstore(result, add(mload(result), 1))
                }
            }
            mstore(0x40, o)
        }
    }

    /// @dev Returns the element at index `i` in the set.
    function at(Uint8Set storage set, uint256 i) internal view returns (uint8 result) {
        assembly ("memory-safe") {
            let data := sload(set.slot)
            let c := 0
            for { let j := 0 } lt(j, 256) { j := add(j, 1) } {
                if and(shr(j, data), 1) {
                    if eq(c, i) {
                        result := j
                        break
                    }
                    c := add(c, 1)
                }
            }
            if iszero(lt(i, c)) {
                mstore(0x00, 0x4e23d035)
                revert(0x1c, 0x04)
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the root slot for an AddressSet.
    function _rootSlot(AddressSet storage s) private pure returns (bytes32 r) {
        assembly ("memory-safe") {
            mstore(0x04, _ENUMERABLE_WORD_SET_SLOT_SEED)
            mstore(0x00, s.slot)
            r := keccak256(0x00, 0x24)
        }
    }

    /// @dev Returns the root slot for a Bytes32Set.
    function _rootSlot(Bytes32Set storage s) private pure returns (bytes32 r) {
        assembly ("memory-safe") {
            mstore(0x04, _ENUMERABLE_WORD_SET_SLOT_SEED)
            mstore(0x00, s.slot)
            r := keccak256(0x00, 0x24)
        }
    }

    /// @dev Converts a Uint256Set to a Bytes32Set.
    function _toBytes32Set(Uint256Set storage s) private pure returns (Bytes32Set storage c) {
        assembly ("memory-safe") {
            c.slot := s.slot
        }
    }

    /// @dev Converts an Int256Set to a Bytes32Set.
    function _toBytes32Set(Int256Set storage s) private pure returns (Bytes32Set storage c) {
        assembly ("memory-safe") {
            c.slot := s.slot
        }
    }

    /// @dev Converts a bytes32 array to a uint256 array.
    function _toUints(bytes32[] memory a) private pure returns (uint256[] memory c) {
        assembly ("memory-safe") {
            c := a
        }
    }

    /// @dev Converts a bytes32 array to an int256 array.
    function _toInts(bytes32[] memory a) private pure returns (int256[] memory c) {
        assembly ("memory-safe") {
            c := a
        }
    }
}