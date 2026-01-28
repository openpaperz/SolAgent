// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DynamicArrayLib {
    struct DynamicArray {
        uint256[] data;
    }

    // --- Basic uint256[] utilities ---

    function malloc(uint256 n) internal pure returns (uint256[] memory result) {
        result = new uint256[](n);
    }

    function zeroize(uint256[] memory a) internal pure returns (uint256[] memory result) {
        result = new uint256[](a.length);
        // new array is zeroed by default
    }

    function get(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        require(i < a.length, "Index OOB");
        result = a[i];
    }

    function getUint256(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        return get(a, i);
    }

    function getAddress(uint256[] memory a, uint256 i) internal pure returns (address result) {
        require(i < a.length, "Index OOB");
        result = address(uint160(a[i]));
    }

    function getBool(uint256[] memory a, uint256 i) internal pure returns (bool result) {
        require(i < a.length, "Index OOB");
        result = a[i] != 0;
    }

    function getBytes32(uint256[] memory a, uint256 i) internal pure returns (bytes32 result) {
        require(i < a.length, "Index OOB");
        result = bytes32(a[i]);
    }

    function set(uint256[] memory a, uint256 i, uint256 data) internal pure returns (uint256[] memory result) {
        require(i < a.length, "Index OOB");
        result = a;
        result[i] = data;
    }

    function set(uint256[] memory a, uint256 i, address data) internal pure returns (uint256[] memory result) {
        return set(a, i, uint256(uint160(data)));
    }

    function set(uint256[] memory a, uint256 i, bool data) internal pure returns (uint256[] memory result) {
        return set(a, i, data ? 1 : 0);
    }

    function set(uint256[] memory a, uint256 i, bytes32 data) internal pure returns (uint256[] memory result) {
        return set(a, i, uint256(data));
    }

    function asAddressArray(uint256[] memory a) internal pure returns (address[] memory result) {
        result = new address[](a.length);
        for (uint256 i = 0; i < a.length; i++) result[i] = address(uint160(a[i]));
    }

    function asBoolArray(uint256[] memory a) internal pure returns (bool[] memory result) {
        result = new bool[](a.length);
        for (uint256 i = 0; i < a.length; i++) result[i] = a[i] != 0;
    }

    function asBytes32Array(uint256[] memory a) internal pure returns (bytes32[] memory result) {
        result = new bytes32[](a.length);
        for (uint256 i = 0; i < a.length; i++) result[i] = bytes32(a[i]);
    }

    function toUint256Array(address[] memory a) internal pure returns (uint256[] memory result) {
        result = new uint256[](a.length);
        for (uint256 i = 0; i < a.length; i++) result[i] = uint256(uint160(a[i]));
    }

    function toUint256Array(bool[] memory a) internal pure returns (uint256[] memory result) {
        result = new uint256[](a.length);
        for (uint256 i = 0; i < a.length; i++) result[i] = a[i] ? 1 : 0;
    }

    function toUint256Array(bytes32[] memory a) internal pure returns (uint256[] memory result) {
        result = new uint256[](a.length);
        for (uint256 i = 0; i < a.length; i++) result[i] = uint256(a[i]);
    }

    function truncate(uint256[] memory a, uint256 n) internal pure returns (uint256[] memory result) {
        if (n >= a.length) return a;
        result = new uint256[](n);
        for (uint256 i = 0; i < n; i++) result[i] = a[i];
    }

    function free(uint256[] memory /* a */) internal pure returns (uint256[] memory result) {
        result = new uint256[](0);
    }

    function hash(uint256[] memory a) internal pure returns (bytes32 result) {
        result = keccak256(abi.encode(a));
    }

    function slice(uint256[] memory a, uint256 start, uint256 end) internal pure returns (uint256[] memory result) {
        uint256 len = a.length;
        if (start > len) start = len;
        if (end > len) end = len;
        if (start >= end) return new uint256[](0);
        uint256 resultLen = end - start;
        result = new uint256[](resultLen);
        for (uint256 i = 0; i < resultLen; i++) result[i] = a[start + i];
    }

    function contains(uint256[] memory a, uint256 needle) internal pure returns (bool) {
        return indexOf(a, needle) != type(uint256).max;
    }

    function indexOf(uint256[] memory a, uint256 needle, uint256 from) internal pure returns (uint256 result) {
        uint256 n = a.length;
        if (from >= n) return type(uint256).max;
        for (uint256 i = from; i < n; i++) {
            if (a[i] == needle) return i;
        }
        return type(uint256).max;
    }

    function indexOf(uint256[] memory a, uint256 needle) internal pure returns (uint256 result) {
        return indexOf(a, needle, 0);
    }

    function lastIndexOf(uint256[] memory a, uint256 needle, uint256 from) internal pure returns (uint256 result) {
        uint256 n = a.length;
        if (n == 0) return type(uint256).max;
        if (from >= n) from = n - 1;
        for (uint256 i = from + 1; i > 0; i--) {
            uint256 idx = i - 1;
            if (a[idx] == needle) return idx;
            if (i == 1) break;
        }
        return type(uint256).max;
    }

    function lastIndexOf(uint256[] memory a, uint256 needle) internal pure returns (uint256 result) {
        if (a.length == 0) return type(uint256).max;
        return lastIndexOf(a, needle, a.length - 1);
    }

    function directReturn(uint256[] memory a) internal pure {
        assembly {
            let len := mload(a)
            let size := add(mul(len, 0x20), 0x20)
            return(a, size)
        }
    }

    // --- DynamicArray wrappers and utilities ---

    function length(DynamicArray memory a) internal pure returns (uint256) {
        return a.data.length;
    }

    function wrap(uint256[] memory a) internal pure returns (DynamicArray memory result) {
        result.data = a;
    }

    function wrap(address[] memory a) internal pure returns (DynamicArray memory result) {
        result.data = toUint256Array(a);
    }

    function wrap(bool[] memory a) internal pure returns (DynamicArray memory result) {
        result.data = toUint256Array(a);
    }

    function wrap(bytes32[] memory a) internal pure returns (DynamicArray memory result) {
        result.data = toUint256Array(a);
    }

    function clear(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        result = a;
        result.data = new uint256[](0);
    }

    function free(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        result = a;
        result.data = new uint256[](0);
    }

    function resize(DynamicArray memory a, uint256 n) internal pure returns (DynamicArray memory result) {
        result = a;
        uint256 oldLen = a.data.length;
        if (n == oldLen) return result;
        uint256[] memory newData = new uint256[](n);
        uint256 minLen = oldLen < n ? oldLen : n;
        for (uint256 i = 0; i < minLen; i++) newData[i] = a.data[i];
        result.data = newData;
    }

    function expand(DynamicArray memory a, uint256 n) internal pure returns (DynamicArray memory result) {
        result = a;
        if (result.data.length >= n) return result;
        result = resize(result, n);
    }

    function truncate(DynamicArray memory a, uint256 n) internal pure returns (DynamicArray memory result) {
        result = a;
        if (n >= a.data.length) return result;
        uint256[] memory newData = new uint256[](n);
        for (uint256 i = 0; i < n; i++) newData[i] = a.data[i];
        result.data = newData;
    }

    function reserve(DynamicArray memory a, uint256 /* minimum */) internal pure returns (DynamicArray memory result) {
        // Memory-only implementation: no capacity metadata tracked; no-op.
        result = a;
    }

    function p(DynamicArray memory a, uint256 data) internal pure returns (DynamicArray memory result) {
        result = a;
        uint256 oldLen = a.data.length;
        uint256[] memory newData = new uint256[](oldLen + 1);
        for (uint256 i = 0; i < oldLen; i++) newData[i] = a.data[i];
        newData[oldLen] = data;
        result.data = newData;
    }

    function p(DynamicArray memory a, address data) internal pure returns (DynamicArray memory result) {
        return p(a, uint256(uint160(data)));
    }

    function p(DynamicArray memory a, bool data) internal pure returns (DynamicArray memory result) {
        return p(a, data ? 1 : 0);
    }

    function p(DynamicArray memory a, bytes32 data) internal pure returns (DynamicArray memory result) {
        return p(a, uint256(data));
    }

    function p() internal pure returns (DynamicArray memory result) {
        result.data = new uint256[](0);
    }

    function p(uint256 data) internal pure returns (DynamicArray memory result) {
        result.data = new uint256[](1);
        result.data[0] = data;
    }

    function p(address data) internal pure returns (DynamicArray memory result) {
        return p(uint256(uint160(data)));
    }

    function p(bool data) internal pure returns (DynamicArray memory result) {
        return p(data ? 1 : 0);
    }

    function p(bytes32 data) internal pure returns (DynamicArray memory result) {
        return p(uint256(data));
    }

    function pop(DynamicArray memory a) internal pure returns (uint256 result) {
        return popUint256(a);
    }

    function popUint256(DynamicArray memory a) internal pure returns (uint256 result) {
        uint256 n = a.data.length;
        require(n > 0, "Empty");
        result = a.data[n - 1];
        uint256[] memory newData = new uint256[](n - 1);
        for (uint256 i = 0; i < n - 1; i++) newData[i] = a.data[i];
        a.data = newData;
    }

    function popAddress(DynamicArray memory a) internal pure returns (address result) {
        uint256 v = popUint256(a);
        result = address(uint160(v));
    }

    function popBool(DynamicArray memory a) internal pure returns (bool result) {
        uint256 v = popUint256(a);
        result = v != 0;
    }

    function popBytes32(DynamicArray memory a) internal pure returns (bytes32 result) {
        uint256 v = popUint256(a);
        result = bytes32(v);
    }

    function get(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        return get(a.data, i);
    }

    function getUint256(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        return get(a.data, i);
    }

    function getAddress(DynamicArray memory a, uint256 i) internal pure returns (address result) {
        return getAddress(a.data, i);
    }

    function getBool(DynamicArray memory a, uint256 i) internal pure returns (bool result) {
        return getBool(a.data, i);
    }

    function getBytes32(DynamicArray memory a, uint256 i) internal pure returns (bytes32 result) {
        return getBytes32(a.data, i);
    }

    function set(DynamicArray memory a, uint256 i, uint256 data) internal pure returns (DynamicArray memory result) {
        result = a;
        result.data = set(a.data, i, data);
    }

    function set(DynamicArray memory a, uint256 i, address data) internal pure returns (DynamicArray memory result) {
        return set(a, i, uint256(uint160(data)));
    }

    function set(DynamicArray memory a, uint256 i, bool data) internal pure returns (DynamicArray memory result) {
        return set(a, i, data ? 1 : 0);
    }

    function set(DynamicArray memory a, uint256 i, bytes32 data) internal pure returns (DynamicArray memory result) {
        return set(a, i, uint256(data));
    }

    function asUint256Array(DynamicArray memory a) internal pure returns (uint256[] memory result) {
        return a.data;
    }

    function asAddressArray(DynamicArray memory a) internal pure returns (address[] memory result) {
        return asAddressArray(a.data);
    }

    function asBoolArray(DynamicArray memory a) internal pure returns (bool[] memory result) {
        return asBoolArray(a.data);
    }

    function asBytes32Array(DynamicArray memory a) internal pure returns (bytes32[] memory result) {
        return asBytes32Array(a.data);
    }

    function slice(DynamicArray memory a, uint256 start, uint256 end) internal pure returns (DynamicArray memory result) {
        result.data = slice(a.data, start, end);
    }

    function slice(DynamicArray memory a, uint256 start) internal pure returns (DynamicArray memory result) {
        result.data = slice(a.data, start, a.data.length);
    }

    function contains(DynamicArray memory a, uint256 needle) internal pure returns (bool) {
        return contains(a.data, needle);
    }

    function contains(DynamicArray memory a, address needle) internal pure returns (bool) {
        return contains(a.data, uint256(uint160(needle)));
    }

    function contains(DynamicArray memory a, bytes32 needle) internal pure returns (bool) {
        return contains(a.data, uint256(needle));
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
        return hash(a.data);
    }

    function directReturn(DynamicArray memory a) internal pure {
        directReturn(a.data);
    }

    function _deallocate(DynamicArray memory /* result */) private pure {
        // No-op in memory-safe high-level implementation.
    }

    function _toUint(bool b) private pure returns (uint256 result) {
        return b ? 1 : 0;
    }
}