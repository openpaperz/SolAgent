// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DynamicArrayLib {
    struct DynamicArray {
        uint256[] data;
    }

    function malloc(uint256 n) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, n)
            mstore(0x40, add(result, add(0x20, shl(5, n))))
        }
    }

    function zeroize(uint256[] memory a) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            codecopy(add(result, 0x20), 0, shl(5, mload(result)))
        }
    }

    function get(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    function getUint256(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    function getAddress(uint256[] memory a, uint256 i) internal pure returns (address result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    function getBool(uint256[] memory a, uint256 i) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := iszero(iszero(mload(add(add(a, 0x20), shl(5, i)))))
        }
    }

    function getBytes32(uint256[] memory a, uint256 i) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    function set(uint256[] memory a, uint256 i, uint256 data) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    function set(uint256[] memory a, uint256 i, address data) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    function set(uint256[] memory a, uint256 i, bool data) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), _toUint(data))
        }
    }

    function set(uint256[] memory a, uint256 i, bytes32 data) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    function asAddressArray(uint256[] memory a) internal pure returns (address[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    function asBoolArray(uint256[] memory a) internal pure returns (bool[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    function asBytes32Array(uint256[] memory a) internal pure returns (bytes32[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    function toUint256Array(address[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    function toUint256Array(bool[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    function toUint256Array(bytes32[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := a
        }
    }

    function truncate(uint256[] memory a, uint256 n) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            let len := mload(result)
            if lt(n, len) {
                mstore(result, n)
            }
        }
    }

    function free(uint256[] memory a) internal pure returns (uint256[] memory result) {
        result = a;
        assembly ("memory-safe") {
            mstore(result, 0)
        }
    }

    function hash(uint256[] memory a) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let len := mload(a)
            result := keccak256(add(a, 0x20), shl(5, len))
        }
    }

    function slice(uint256[] memory a, uint256 start, uint256 end) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            let len := mload(a)
            if gt(end, len) { end := len }
            if gt(start, len) { start := len }
            if lt(start, end) {
                let resultLen := sub(end, start)
                result := mload(0x40)
                mstore(result, resultLen)
                let src := add(add(a, 0x20), shl(5, start))
                let dest := add(result, 0x20)
                let o := add(src, shl(5, resultLen))
                for { } gt(o, src) { } {
                    o := sub(o, 0x20)
                    dest := add(dest, 0x20)
                    mstore(dest, mload(o))
                }
                mstore(0x40, add(add(result, 0x20), shl(5, resultLen)))
            }
        }
    }

    function contains(uint256[] memory a, uint256 needle) internal pure returns (bool) {
        return ~indexOf(a, needle) != 0;
    }

    function indexOf(uint256[] memory a, uint256 needle, uint256 from) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := not(0)
            let len := mload(a)
            if lt(from, len) {
                let start := add(add(a, 0x20), shl(5, from))
                let end := add(add(a, 0x20), shl(5, len))
                let lastWord := mload(end)
                mstore(end, needle)
                for { } 1 { } {
                    if eq(mload(start), needle) { break }
                    start := add(start, 0x20)
                }
                mstore(end, lastWord)
                if lt(start, end) {
                    result := shr(5, sub(sub(start, a), 0x20))
                }
            }
        }
    }

    function indexOf(uint256[] memory a, uint256 needle) internal pure returns (uint256 result) {
        result = indexOf(a, needle, 0);
    }

    function lastIndexOf(uint256[] memory a, uint256 needle, uint256 from) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := not(0)
            let len := mload(a)
            if gt(len, 0) {
                if iszero(lt(from, len)) { from := sub(len, 1) }
                let o := add(add(a, 0x20), shl(5, from))
                let savedLen := mload(a)
                mstore(a, needle)
                for { } 1 { } {
                    if eq(mload(o), needle) { break }
                    if iszero(lt(o, add(a, 0x20))) { break }
                    o := sub(o, 0x20)
                }
                mstore(a, savedLen)
                if iszero(eq(mload(o), needle)) { o := 0 }
                if iszero(iszero(o)) {
                    result := shr(5, sub(sub(o, a), 0x20))
                }
            }
        }
    }

    function lastIndexOf(uint256[] memory a, uint256 needle) internal pure returns (uint256 result) {
        result = lastIndexOf(a, needle, type(uint256).max);
    }

    function directReturn(uint256[] memory a) internal pure {
        assembly ("memory-safe") {
            let ptr := sub(a, 0x20)
            let len := mload(a)
            mstore(ptr, add(1, len)) // return array length + data words as a single bytes array
            return(ptr, add(0x40, shl(5, len)))
        }
    }

    function length(DynamicArray memory a) internal pure returns (uint256) {
        return a.data.length;
    }

    function wrap(uint256[] memory a) internal pure returns (DynamicArray memory result) {
        result.data = a;
    }

    function wrap(address[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, a)
            mstore(0x40, add(result, 0x20))
        }
    }

    function wrap(bool[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, a)
            mstore(0x40, add(result, 0x20))
        }
    }

    function wrap(bytes32[] memory a) internal pure returns (DynamicArray memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, a)
            mstore(0x40, add(result, 0x20))
        }
    }

    function clear(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        result = a;
        assembly ("memory-safe") {
            let arr := mload(result)
            if iszero(iszero(arr)) {
                mstore(arr, 0)
            }
        }
    }

    function free(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        result = a;
        assembly ("memory-safe") {
            let arr := mload(result)
            if iszero(iszero(arr)) {
                mstore(arr, 0)
            }
        }
    }

    function resize(DynamicArray memory a, uint256 n) internal pure returns (DynamicArray memory result) {
        result = a;
        uint256[] memory arr = result.data;
        uint256 len = arr.length;
        if (n <= len) {
            assembly ("memory-safe") {
                mstore(arr, n)
            }
            return result;
        }
        assembly ("memory-safe") {
            let newArr := mload(0x40)
            mstore(newArr, n)
            let src := add(arr, 0x20)
            let dest := add(newArr, 0x20)
            let end := add(src, shl(5, len))
            for { } lt(src, end) { } {
                mstore(dest, mload(src))
                src := add(src, 0x20)
                dest := add(dest, 0x20)
            }
            codecopy(dest, 0, shl(5, sub(n, len)))
            mstore(0x40, add(add(newArr, 0x20), shl(5, n)))
            mstore(result, newArr)
        }
    }

    function expand(DynamicArray memory a, uint256 n) internal pure returns (DynamicArray memory result) {
        result = a;
        if (n <= result.data.length) return result;
        return resize(result, n);
    }

    function truncate(DynamicArray memory a, uint256 n) internal pure returns (DynamicArray memory result) {
        result = a;
        assembly ("memory-safe") {
            let arr := mload(result)
            let len := mload(arr)
            if lt(n, len) {
                mstore(arr, n)
            }
        }
    }

    function reserve(DynamicArray memory a, uint256 minimum) internal pure returns (DynamicArray memory result) {
        result = a;
        assembly ("memory-safe") {
            if lt(minimum, 0xffffffff) {
                let arr := mload(result)
                if iszero(arr) {
                    let cap := shl(1, lt(minimum, 2))
                    if gt(minimum, cap) { cap := minimum }
                    let meta := mload(0x40)
                    mstore(meta, mul(cap, 0x10001))
                    let data := add(meta, 0x20)
                    mstore(data, 0)
                    mstore(0x40, add(add(data, 0x20), shl(5, cap)))
                    mstore(result, data)
                } else {
                    let meta := sub(arr, 0x20)
                    let packed := mload(meta)
                    let cap := div(packed, 0x10001)
                    let len := mload(arr)
                    for { } 1 { } {
                        if iszero(lt(cap, minimum)) { break }
                        cap := shl(1, cap)
                        if lt(cap, minimum) { cap := minimum }
                        let freePtr := mload(0x40)
                        let expected := add(add(arr, 0x20), shl(5, mload(arr)))
                        if eq(freePtr, expected) {
                            let newEnd := add(add(arr, 0x20), shl(5, cap))
                            mstore(0x40, newEnd)
                            mstore(meta, mul(cap, 0x10001))
                            break
                        }
                        let newMeta := mload(0x40)
                        let newData := add(newMeta, 0x20)
                        mstore(newMeta, mul(cap, 0x10001))
                        mstore(newData, len)
                        let src := add(arr, 0x20)
                        let dest := add(newData, 0x20)
                        let end := add(src, shl(5, len))
                        for { } lt(src, end) { } {
                            mstore(dest, mload(src))
                            src := add(src, 0x20)
                            dest := add(dest, 0x20)
                        }
                        mstore(0x40, add(add(newData, 0x20), shl(5, cap)))
                        mstore(result, newData)
                        break
                    }
                }
            }
        }
    }

    function p(DynamicArray memory a, uint256 data) internal pure returns (DynamicArray memory result) {
        result = reserve(a, a.data.length + 1);
        uint256[] memory arr = result.data;
        uint256 len = arr.length;
        assembly ("memory-safe") {
            let pos := add(add(arr, 0x20), shl(5, len))
            mstore(pos, data)
            mstore(arr, add(len, 1))
        }
    }

    function p(DynamicArray memory a, address data) internal pure returns (DynamicArray memory result) {
        result = reserve(a, a.data.length + 1);
        uint256[] memory arr = result.data;
        uint256 len = arr.length;
        assembly ("memory-safe") {
            let pos := add(add(arr, 0x20), shl(5, len))
            mstore(pos, data)
            mstore(arr, add(len, 1))
        }
    }

    function p(DynamicArray memory a, bool data) internal pure returns (DynamicArray memory result) {
        result = reserve(a, a.data.length + 1);
        uint256[] memory arr = result.data;
        uint256 len = arr.length;
        assembly ("memory-safe") {
            let pos := add(add(arr, 0x20), shl(5, len))
            mstore(pos, _toUint(data))
            mstore(arr, add(len, 1))
        }
    }

    function p(DynamicArray memory a, bytes32 data) internal pure returns (DynamicArray memory result) {
        result = reserve(a, a.data.length + 1);
        uint256[] memory arr = result.data;
        uint256 len = arr.length;
        assembly ("memory-safe") {
            let pos := add(add(arr, 0x20), shl(5, len))
            mstore(pos, data)
            mstore(arr, add(len, 1))
        }
    }

    function p() internal pure returns (DynamicArray memory result) {
        uint256[] memory arr = malloc(0);
        result.data = arr;
    }

    function p(uint256 data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    function p(address data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    function p(bool data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    function p(bytes32 data) internal pure returns (DynamicArray memory result) {
        result = p();
        result = p(result, data);
    }

    function pop(DynamicArray memory a) internal pure returns (uint256 result) {
        uint256[] memory arr = a.data;
        assembly ("memory-safe") {
            let len := mload(arr)
            if len {
                let newLen := sub(len, 1)
                let pos := add(add(arr, 0x20), shl(5, newLen))
                result := mload(pos)
                mstore(arr, newLen)
            }
        }
    }

    function popUint256(DynamicArray memory a) internal pure returns (uint256 result) {
        result = pop(a);
    }

    function popAddress(DynamicArray memory a) internal pure returns (address result) {
        uint256 v = pop(a);
        result = address(uint160(v));
    }

    function popBool(DynamicArray memory a) internal pure returns (bool result) {
        uint256 v = pop(a);
        result = v != 0;
    }

    function popBytes32(DynamicArray memory a) internal pure returns (bytes32 result) {
        uint256 v = pop(a);
        result = bytes32(v);
    }

    function get(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        result = get(a.data, i);
    }

    function getUint256(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        result = getUint256(a.data, i);
    }

    function getAddress(DynamicArray memory a, uint256 i) internal pure returns (address result) {
        result = getAddress(a.data, i);
    }

    function getBool(DynamicArray memory a, uint256 i) internal pure returns (bool result) {
        result = getBool(a.data, i);
    }

    function getBytes32(DynamicArray memory a, uint256 i) internal pure returns (bytes32 result) {
        result = getBytes32(a.data, i);
    }

    function set(DynamicArray memory a, uint256 i, uint256 data) internal pure returns (DynamicArray memory result) {
        result = a;
        set(result.data, i, data);
    }

    function set(DynamicArray memory a, uint256 i, address data) internal pure returns (DynamicArray memory result) {
        result = a;
        set(result.data, i, data);
    }

    function set(DynamicArray memory a, uint256 i, bool data) internal pure returns (DynamicArray memory result) {
        result = a;
        set(result.data, i, data);
    }

    function set(DynamicArray memory a, uint256 i, bytes32 data) internal pure returns (DynamicArray memory result) {
        result = a;
        set(result.data, i, data);
    }

    function asUint256Array(DynamicArray memory a) internal pure returns (uint256[] memory result) {
        result = a.data;
    }

    function asAddressArray(DynamicArray memory a) internal pure returns (address[] memory result) {
        uint256[] memory arr = a.data;
        assembly ("memory-safe") {
            result := arr
        }
    }

    function asBoolArray(DynamicArray memory a) internal pure returns (bool[] memory result) {
        uint256[] memory arr = a.data;
        assembly ("memory-safe") {
            result := arr
        }
    }

    function asBytes32Array(DynamicArray memory a) internal pure returns (bytes32[] memory result) {
        uint256[] memory arr = a.data;
        assembly ("memory-safe") {
            result := arr
        }
    }

    function slice(DynamicArray memory a, uint256 start, uint256 end) internal pure returns (DynamicArray memory result) {
        uint256[] memory arr = a.data;
        uint256[] memory s = slice(arr, start, end);
        result.data = s;
    }

    function slice(DynamicArray memory a, uint256 start) internal pure returns (DynamicArray memory result) {
        uint256[] memory arr = a.data;
        uint256[] memory s = slice(arr, start, arr.length);
        result.data = s;
    }

    function contains(DynamicArray memory a, uint256 needle) internal pure returns (bool) {
        return contains(a.data, needle);
    }

    function contains(DynamicArray memory a, address needle) internal pure returns (bool) {
        return ~indexOf(a, needle) != 0;
    }

    function contains(DynamicArray memory a, bytes32 needle) internal pure returns (bool) {
        return ~indexOf(a, needle) != 0;
    }

    function indexOf(DynamicArray memory a, uint256 needle, uint256 from) internal pure returns (uint256) {
        return indexOf(a.data, needle, from);
    }

    function indexOf(DynamicArray memory a, address needle, uint256 from) internal pure returns (uint256) {
        return indexOf(a.data, uint256(uint160(needle)), from);
    }

    function indexOf(DynamicArray memory a, bytes32 needle, uint256 from) internal pure returns (uint256) {
        return indexOf(a.data, uint256(needle), from);
    }

    function indexOf(DynamicArray memory a, uint256 needle) internal pure returns (uint256) {
        return indexOf(a.data, needle);
    }

    function indexOf(DynamicArray memory a, address needle) internal pure returns (uint256) {
        return indexOf(a.data, uint256(uint160(needle)));
    }

    function indexOf(DynamicArray memory a, bytes32 needle) internal pure returns (uint256) {
        return indexOf(a.data, uint256(needle));
    }

    function lastIndexOf(DynamicArray memory a, uint256 needle, uint256 from) internal pure returns (uint256) {
        return lastIndexOf(a.data, needle, from);
    }

    function lastIndexOf(DynamicArray memory a, address needle, uint256 from) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(uint160(needle)), from);
    }

    function lastIndexOf(DynamicArray memory a, bytes32 needle, uint256 from) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(needle), from);
    }

    function lastIndexOf(DynamicArray memory a, uint256 needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, needle);
    }

    function lastIndexOf(DynamicArray memory a, address needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(uint160(needle)));
    }

    function lastIndexOf(DynamicArray memory a, bytes32 needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(needle));
    }

    function hash(DynamicArray memory a) internal pure returns (bytes32 result) {
        result = hash(a.data);
    }

    function directReturn(DynamicArray memory a) internal pure {
        directReturn(a.data);
    }

    function _deallocate(DynamicArray memory result) private pure {
        assembly ("memory-safe") {
            mstore(0x40, result)
        }
    }

    function _toUint(bool b) private pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := b
        }
    }
}