// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for memory-safe dynamic array operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DynamicArrayLib.sol)
library DynamicArrayLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev A struct to hold a dynamic array with capacity tracking.
    struct DynamicArray {
        uint256[] data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      MEMORY OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Allocates a new array of length `n` in memory.
    function malloc(uint256 n) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, n)
            mstore(0x40, add(add(result, 0x20), shl(5, n)))
        }
    }

    /// @dev Zeroes out the array `a` in memory.
    function zeroize(uint256[] memory a) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            codecopy(add(result, 0x20), codesize(), shl(5, mload(result)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      GETTERS (UINT256[])                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the element at index `i` of `a`.
    function get(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a`.
    function getUint256(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a` as an address.
    function getAddress(uint256[] memory a, uint256 i) internal pure returns (address result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a` as a bool.
    function getBool(uint256[] memory a, uint256 i) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a` as bytes32.
    function getBytes32(uint256[] memory a, uint256 i) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      SETTERS (UINT256[])                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(uint256[] memory a, uint256 i, uint256 data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(uint256[] memory a, uint256 i, address data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(uint256[] memory a, uint256 i, bool data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(uint256[] memory a, uint256 i, bytes32 data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONVERSIONS (UINT256[])                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Converts `a` to an address array.
    function asAddressArray(uint256[] memory a) internal pure returns (address[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    /// @dev Converts `a` to a bool array.
    function asBoolArray(uint256[] memory a) internal pure returns (bool[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    /// @dev Converts `a` to a bytes32 array.
    function asBytes32Array(uint256[] memory a) internal pure returns (bytes32[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    /// @dev Converts `a` to a uint256 array.
    function toUint256Array(address[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    /// @dev Converts `a` to a uint256 array.
    function toUint256Array(bool[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    /// @dev Converts `a` to a uint256 array.
    function toUint256Array(bytes32[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  ARRAY OPERATIONS (UINT256[])              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Truncates `a` to length `n`.
    function truncate(uint256[] memory a, uint256 n)
        internal
        pure
        returns (uint256[] memory result)
    {
        assembly ("memory-safe") {
            result := a
            if lt(n, mload(a)) { mstore(result, n) }
        }
    }

    /// @dev Frees the memory of `a` by setting its length to 0.
    function free(uint256[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
            mstore(result, 0)
        }
    }

    /// @dev Returns the keccak256 hash of `a`.
    function hash(uint256[] memory a) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            result := keccak256(add(a, 0x20), shl(5, mload(a)))
        }
    }

    /// @dev Returns a slice of `a` from index `start` to `end` (exclusive).
    function slice(uint256[] memory a, uint256 start, uint256 end)
        internal
        pure
        returns (uint256[] memory result)
    {
        assembly ("memory-safe") {
            let n := mload(a)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, n), lt(n, start)))
            if lt(start, end) {
                let resultLen := sub(end, start)
                result := mload(0x40)
                mstore(result, resultLen)
                a := add(add(a, 0x20), shl(5, start))
                let w := not(0x1f)
                for { let i := resultLen } i {} {
                    i := sub(i, 1)
                    mstore(add(add(result, 0x20), shl(5, i)), mload(add(a, shl(5, i))))
                }
                mstore(0x40, and(add(add(result, 0x20), shl(5, resultLen)), w))
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    SEARCH OPERATIONS (UINT256[])           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns whether `a` contains `needle`.
    function contains(uint256[] memory a, uint256 needle) internal pure returns (bool) {
        return ~indexOf(a, needle, 0) != 0;
    }

    /// @dev Returns the first index of `needle` in `a`, starting from `from`.
    /// Returns `not(0)` if not found.
    function indexOf(uint256[] memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        assembly ("memory-safe") {
            result := not(0)
            let n := mload(a)
            if lt(from, n) {
                let o := add(add(a, 0x20), shl(5, from))
                let cache := mload(add(a, shl(5, n)))
                mstore(add(a, shl(5, n)), needle)
                for {} 1 {} {
                    if eq(mload(o), needle) { break }
                    o := add(o, 0x20)
                }
                mstore(add(a, shl(5, n)), cache)
                if lt(shr(5, sub(o, add(a, 0x20))), n) {
                    result := shr(5, sub(o, add(a, 0x20)))
                }
            }
        }
    }

    /// @dev Returns the first index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function indexOf(uint256[] memory a, uint256 needle) internal pure returns (uint256 result) {
        result = indexOf(a, needle, 0);
    }

    /// @dev Returns the last index of `needle` in `a`, starting from `from` backwards.
    /// Returns `not(0)` if not found.
    function lastIndexOf(uint256[] memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        assembly ("memory-safe") {
            result := not(0)
            let n := mload(a)
            if n {
                from := xor(from, mul(xor(from, sub(n, 1)), lt(sub(n, 1), from)))
                let o := add(add(a, 0x20), shl(5, from))
                let cache := mload(a)
                mstore(a, needle)
                for {} 1 {} {
                    if eq(mload(o), needle) { break }
                    o := sub(o, 0x20)
                }
                mstore(a, cache)
                if iszero(lt(o, add(a, 0x20))) { result := shr(5, sub(o, add(a, 0x20))) }
            }
        }
    }

    /// @dev Returns the last index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function lastIndexOf(uint256[] memory a, uint256 needle)
        internal
        pure
        returns (uint256 result)
    {
        result = lastIndexOf(a, needle, type(uint256).max);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      RETURN OPERATIONS (UINT256[])         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Directly returns `a` without copying.
    function directReturn(uint256[] memory a) internal pure {
        assembly ("memory-safe") {
            let o := sub(a, 0x20)
            mstore(o, 0x20)
            return(o, add(0x40, shl(5, mload(a))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   DYNAMIC ARRAY OPERATIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the length of `a`.
    function length(DynamicArray memory a) internal pure returns (uint256) {
        return a.data.length;
    }

    /// @dev Wraps `a` into a `DynamicArray`.
    function wrap(uint256[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            mstore(result, a)
        }
    }

    /// @dev Wraps `a` into a `DynamicArray`.
    function wrap(address[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            mstore(result, a)
        }
    }

    /// @dev Wraps `a` into a `DynamicArray`.
    function wrap(bool[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            mstore(result, a)
        }
    }

    /// @dev Wraps `a` into a `DynamicArray`.
    function wrap(bytes32[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            mstore(result, a)
        }
    }

    /// @dev Clears `a` by setting its length to 0.
    function clear(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(a)
            mstore(o, 0)
        }
    }

    /// @dev Frees `a` by setting its length to 0.
    function free(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(a)
            mstore(o, 0)
        }
    }

    /// @dev Resizes `a` to length `n`.
    function resize(DynamicArray memory a, uint256 n)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        result = reserve(result, n);
        assembly ("memory-safe") {
            let o := mload(result)
            let m := mload(o)
            if gt(n, m) { codecopy(add(add(o, 0x20), shl(5, m)), codesize(), shl(5, sub(n, m))) }
            mstore(o, n)
        }
    }

    /// @dev Expands `a` to at least length `n`.
    function expand(DynamicArray memory a, uint256 n)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        if (n >= a.data.length) result = reserve(result, n);
        assembly ("memory-safe") {
            mstore(mload(result), n)
        }
    }

    /// @dev Truncates `a` to length `n`.
    function truncate(DynamicArray memory a, uint256 n)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(result)
            if lt(n, mload(o)) { mstore(o, n) }
        }
    }

    /// @dev Reserves at least `minimum` capacity for `a`.
    function reserve(DynamicArray memory a, uint256 minimum)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let p := 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f
            if iszero(lt(minimum, 0xffffffff)) { invalid() }
            let o := mload(result)
            if iszero(o) {
                let c := add(shl(1, minimum), 1)
                o := mload(0x40)
                mstore(o, mul(c, p))
                mstore(result, add(o, 0x20))
                mstore(add(o, 0x20), 0)
                mstore(0x40, add(add(o, 0x40), shl(5, c)))
                break
            }
            let b := sub(o, 0x20)
            let c := div(mload(b), p)
            if iszero(c) { invalid() }
            c := shr(1, sub(c, 1))
            let r := add(shl(1, minimum), 1)
            if iszero(lt(c, r)) { break }
            if eq(mload(0x40), add(add(o, 0x20), shl(5, c))) {
                mstore(b, mul(r, p))
                mstore(0x40, add(add(o, 0x20), shl(5, r)))
                break
            }
            let n := mload(o)
            let newO := mload(0x40)
            mstore(newO, mul(r, p))
            let newData := add(newO, 0x20)
            mstore(result, newData)
            let w := not(0x1f)
            let i := 0
            for {} lt(i, n) { i := add(i, 1) } {
                mstore(add(add(newData, 0x20), shl(5, i)), mload(add(add(o, 0x20), shl(5, i))))
            }
            mstore(newData, n)
            mstore(0x40, and(add(add(newData, 0x20), shl(5, r)), w))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    PUSH OPERATIONS (DYNAMIC ARRAY)         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, uint256 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let p := 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f
            let o := mload(result)
            let newLen := add(mload(o), 1)
            let newByteLen := shl(5, newLen)
            if iszero(o) {
                o := mload(0x40)
                mstore(o, mul(p, 3))
                mstore(result, add(o, 0x20))
                mstore(add(o, 0x20), 0)
                mstore(0x40, add(add(o, 0x40), 0x40))
            }
            let b := sub(o, 0x20)
            let c := div(mload(b), p)
            if iszero(c) { invalid() }
            c := shr(1, sub(c, 1))
            if iszero(lt(c, newLen)) {
                if eq(mload(0x40), add(add(o, 0x20), shl(5, c))) {
                    mstore(0x40, add(mload(0x40), 0x20))
                }
            }
            if lt(c, newLen) {
                let r := add(shl(1, newLen), 1)
                if eq(mload(0x40), add(add(o, 0x20), shl(5, c))) {
                    mstore(b, mul(r, p))
                    mstore(0x40, add(add(o, 0x20), shl(5, r)))
                }
                if iszero(eq(mload(0x40), add(add(o, 0x20), shl(5, c)))) {
                    let n := mload(o)
                    let newO := mload(0x40)
                    mstore(newO, mul(r, p))
                    let newData := add(newO, 0x20)
                    mstore(result, newData)
                    let w := not(0x1f)
                    let i := 0
                    for {} lt(i, n) { i := add(i, 1) } {
                        mstore(add(add(newData, 0x20), shl(5, i)), mload(add(add(o, 0x20), shl(5, i))))
                    }
                    mstore(newData, n)
                    mstore(0x40, and(add(add(newData, 0x20), shl(5, r)), w))
                    o := newData
                }
            }
            mstore(add(add(o, 0x20), shl(5, mload(o))), data)
            mstore(o, newLen)
        }
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, address data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result = p(a, uint256(uint160(data)));
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, bool data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result = p(a, _toUint(data));
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, bytes32 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result = p(a, uint256(data));
    }

    /// @dev Returns a new empty `DynamicArray`.
    function p() internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            let p := 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f
            let o := mload(0x40)
            mstore(o, mul(p, 3))
            mstore(result, add(o, 0x20))
            mstore(add(o, 0x20), 0)
            mstore(0x40, add(add(o, 0x40), 0x40))
        }
    }

    /// @dev Returns a new `DynamicArray` with `data`.
    function p(uint256 data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    /// @dev Returns a new `DynamicArray` with `data`.
    function p(address data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    /// @dev Returns a new `DynamicArray` with `data`.
    function p(bool data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    /// @dev Returns a new `DynamicArray` with `data`.
    function p(bytes32 data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    POP OPERATIONS (DYNAMIC ARRAY)          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Pops and returns the last element from `a`.
    function pop(DynamicArray memory a) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(add(o, 0x20), shl(5, sub(n, 1))))
            mstore(o, sub(n, gt(n, 0)))
        }
    }

    /// @dev Pops and returns the last element from `a`.
    function popUint256(DynamicArray memory a) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(add(o, 0x20), shl(5, sub(n, 1))))
            mstore(o, sub(n, gt(n, 0)))
        }
    }

    /// @dev Pops and returns the last element from `a`.
    function popAddress(DynamicArray memory a) internal pure returns (address result) {
        assembly ("memory-safe") {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(add(o, 0x20), shl(5, sub(n, 1))))
            mstore(o, sub(n, gt(n, 0)))
        }
    }

    /// @dev Pops and returns the last element from `a`.
    function popBool(DynamicArray memory a) internal pure returns (bool result) {
        assembly ("memory-safe") {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(add(o, 0x20), shl(5, sub(n, 1))))
            mstore(o, sub(n, gt(n, 0)))
        }
    }

    /// @dev Pops and returns the last element from `a`.
    function popBytes32(DynamicArray memory a) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(add(o, 0x20), shl(5, sub(n, 1))))
            mstore(o, sub(n, gt(n, 0)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   GETTERS (DYNAMIC ARRAY)                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the element at index `i` of `a`.
    function get(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            let o := mload(a)
            result := mload(add(add(o, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a`.
    function getUint256(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            let o := mload(a)
            result := mload(add(add(o, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a` as an address.
    function getAddress(DynamicArray memory a, uint256 i) internal pure returns (address result) {
        assembly ("memory-safe") {
            let o := mload(a)
            result := mload(add(add(o, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a` as a bool.
    function getBool(DynamicArray memory a, uint256 i) internal pure returns (bool result) {
        assembly ("memory-safe") {
            let o := mload(a)
            result := mload(add(add(o, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at index `i` of `a` as bytes32.
    function getBytes32(DynamicArray memory a, uint256 i) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let o := mload(a)
            result := mload(add(add(o, 0x20), shl(5, i)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   SETTERS (DYNAMIC ARRAY)                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(DynamicArray memory a, uint256 i, uint256 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(result)
            mstore(add(add(o, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(DynamicArray memory a, uint256 i, address data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(result)
            mstore(add(add(o, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(DynamicArray memory a, uint256 i, bool data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(result)
            mstore(add(add(o, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets the element at index `i` of `a` to `data`.
    function set(DynamicArray memory a, uint256 i, bytes32 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        assembly ("memory-safe") {
            let o := mload(result)
            mstore(add(add(o, 0x20), shl(5, i)), data)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONVERSIONS (DYNAMIC ARRAY)               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Converts `a` to a uint256 array.
    function asUint256Array(DynamicArray memory a)
        internal
        pure
        returns (uint256[] memory result)
    {
        assembly ("memory-safe") {
            result := mload(a)
        }
    }

    /// @dev Converts `a` to an address array.
    function asAddressArray(DynamicArray memory a) internal pure returns (address[] memory result) {
        assembly ("memory-safe") {
            result := mload(a)
        }
    }

    /// @dev Converts `a` to a bool array.
    function asBoolArray(DynamicArray memory a) internal pure returns (bool[] memory result) {
        assembly ("memory-safe") {
            result := mload(a)
        }
    }

    /// @dev Converts `a` to a bytes32 array.
    function asBytes32Array(DynamicArray memory a) internal pure returns (bytes32[] memory result) {
        assembly ("memory-safe") {
            result := mload(a)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               ARRAY OPERATIONS (DYNAMIC ARRAY)             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a slice of `a` from index `start` to `end` (exclusive).
    function slice(DynamicArray memory a, uint256 start, uint256 end)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result = wrap(slice(a.data, start, end));
    }

    /// @dev Returns a slice of `a` from index `start` to the end.
    function slice(DynamicArray memory a, uint256 start)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result = wrap(slice(a.data, start, type(uint256).max));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              SEARCH OPERATIONS (DYNAMIC ARRAY)             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns whether `a` contains `needle`.
    function contains(DynamicArray memory a, uint256 needle) internal pure returns (bool) {
        return contains(a.data, needle);
    }

    /// @dev Returns whether `a` contains `needle`.
    function contains(DynamicArray memory a, address needle) internal pure returns (bool) {
        return contains(a.data, uint256(uint160(needle)));
    }

    /// @dev Returns whether `a` contains `needle`.
    function contains(DynamicArray memory a, bytes32 needle) internal pure returns (bool) {
        return contains(a.data, uint256(needle));
    }

    /// @dev Returns the first index of `needle` in `a`, starting from `from`.
    /// Returns `not(0)` if not found.
    function indexOf(DynamicArray memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return indexOf(a.data, needle, from);
    }

    /// @dev Returns the first index of `needle` in `a`, starting from `from`.
    /// Returns `not(0)` if not found.
    function indexOf(DynamicArray memory a, address needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return indexOf(a.data, uint256(uint160(needle)), from);
    }

    /// @dev Returns the first index of `needle` in `a`, starting from `from`.
    /// Returns `not(0)` if not found.
    function indexOf(DynamicArray memory a, bytes32 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return indexOf(a.data, uint256(needle), from);
    }

    /// @dev Returns the first index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function indexOf(DynamicArray memory a, uint256 needle) internal pure returns (uint256) {
        return indexOf(a.data, needle, 0);
    }

    /// @dev Returns the first index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function indexOf(DynamicArray memory a, address needle) internal pure returns (uint256) {
        return indexOf(a.data, uint256(uint160(needle)), 0);
    }

    /// @dev Returns the first index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function indexOf(DynamicArray memory a, bytes32 needle) internal pure returns (uint256) {
        return indexOf(a.data, uint256(needle), 0);
    }

    /// @dev Returns the last index of `needle` in `a`, starting from `from` backwards.
    /// Returns `not(0)` if not found.
    function lastIndexOf(DynamicArray memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(a.data, needle, from);
    }

    /// @dev Returns the last index of `needle` in `a`, starting from `from` backwards.
    /// Returns `not(0)` if not found.
    function lastIndexOf(DynamicArray memory a, address needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(a.data, uint256(uint160(needle)), from);
    }

    /// @dev Returns the last index of `needle` in `a`, starting from `from` backwards.
    /// Returns `not(0)` if not found.
    function lastIndexOf(DynamicArray memory a, bytes32 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(a.data, uint256(needle), from);
    }

    /// @dev Returns the last index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function lastIndexOf(DynamicArray memory a, uint256 needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, needle, type(uint256).max);
    }

    /// @dev Returns the last index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function lastIndexOf(DynamicArray memory a, address needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(uint160(needle)), type(uint256).max);
    }

    /// @dev Returns the last index of `needle` in `a`.
    /// Returns `not(0)` if not found.
    function lastIndexOf(DynamicArray memory a, bytes32 needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(needle), type(uint256).max);
    }

    /// @dev Returns the keccak256 hash of `a`.
    function hash(DynamicArray memory a) internal pure returns (bytes32 result) {
        return hash(a.data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                RETURN OPERATIONS (DYNAMIC ARRAY)           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Directly returns `a` without copying.
    function directReturn(DynamicArray memory a) internal pure {
        directReturn(a.data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Helper to deallocate the memory of `result`.
    function _deallocate(DynamicArray memory result) private pure {
        assembly ("memory-safe") {
            mstore(result, 0)
        }
    }

    /// @dev Converts a bool to a uint256 without branching.
    function _toUint(bool b) private pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := iszero(iszero(b))
        }
    }
}
