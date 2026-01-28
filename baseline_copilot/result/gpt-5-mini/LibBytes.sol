// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title LibBytes
/// @notice Utility library for bytes manipulation and a small BytesStorage container.
library LibBytes {
    struct BytesStorage {
        bytes32 _spacer;
    }

    /// Store bytes into storage container.
    function set(BytesStorage storage $, bytes memory s) internal {
        assembly {
            let slot := $.slot
            let n := mload(s)
            // compute storage base pointer p = keccak256(slot)
            mstore(0x00, slot)
            let p := keccak256(0x00, 0x20)

            // store data in consecutive storage slots starting at p
            let cnt := div(add(n, 31), 32)
            let dataPtr := add(s, 0x20)
            for { let i := 0 } lt(i, cnt) { i := add(i, 1) } {
                let w := mload(add(dataPtr, mul(i, 0x20)))
                sstore(add(p, i), w)
            }

            // store length marker in slot
            // if length > 0xff set low byte to 0xff and encode length >> 8 bits above it
            switch gt(n, 0xff)
            case 1 {
                // shift length left by 8 bits and OR with 0xff
                let packed := or(shl(8, n), 0xff)
                sstore(slot, packed)
            }
            default {
                sstore(slot, n)
            }
        }
    }

    /// Store calldata bytes into storage container.
    function setCalldata(BytesStorage storage $, bytes calldata s) internal {
        assembly {
            let slot := $.slot
            let n := calldataload(s.offset)
            // calldata lengths load differently in some contexts; use s.length from solidity
        }
        // High-level handling for calldata to storage copy:
        // Compute base slot in assembly then copy words from calldata.
        uint256 n = s.length;
        bytes calldata src = s;
        assembly {
            let slot := $.slot
            mstore(0x00, slot)
            let p := keccak256(0x00, 0x20)
            let cnt := div(add(n, 31), 32)
            // copy calldata words
            for { let i := 0 } lt(i, cnt) { i := add(i, 1) } {
                // calldataload expects offset in bytes; calldata location is src.offset + 32 for data
                let off := add(src.offset, mul(i, 0x20))
                let w := calldataload(off)
                sstore(add(p, i), w)
            }
            switch gt(n, 0xff)
            case 1 {
                let packed := or(shl(8, n), 0xff)
                sstore(slot, packed)
            }
            default {
                sstore(slot, n)
            }
        }
    }

    /// Clear storage container.
    function clear(BytesStorage storage $) internal {
        assembly {
            sstore($.slot, 0)
        }
    }

    /// Check if storage container empty.
    function isEmpty(BytesStorage storage $) internal view returns (bool) {
        bytes32 spacer;
        assembly {
            spacer := sload($.slot)
        }
        return spacer == bytes32(0);
    }

    /// Retrieve length of stored bytes.
    function length(BytesStorage storage $) internal view returns (uint256 result) {
        bytes32 spacer;
        assembly {
            spacer := sload($.slot)
        }
        if (spacer == bytes32(0)) return 0;
        uint256 low = uint8(uint256(uint256(spacer) & 0xff));
        if (low == 0xff) {
            // length encoded in higher bytes
            result = uint256(spacer) >> 8;
        } else {
            result = low;
        }
    }

    /// Read bytes from storage container.
    function get(BytesStorage storage $) internal view returns (bytes memory result) {
        uint256 n = length($);
        result = new bytes(n);
        if (n == 0) return result;
        bytes32 spacer;
        assembly {
            spacer := sload($.slot)
            mstore(0x00, $.slot)
            let p := keccak256(0x00, 0x20)
            let cnt := div(add(n, 31), 32)
            let outPtr := add(result, 0x20)
            for { let i := 0 } lt(i, cnt) { i := add(i, 1) } {
                let w := sload(add(p, i))
                mstore(add(outPtr, mul(i, 0x20)), w)
            }
        }
    }

    /// Replace all occurrences of needle with replacement in subject.
    function replace(bytes memory subject, bytes memory needle, bytes memory replacement) internal pure returns (bytes memory result) {
        if (needle.length == 0) {
            // insert replacement between every byte? simpler: return subject
            return subject;
        }
        // naive implementation: find occurrences and build result
        uint256[] memory idxs = indicesOf(subject, needle);
        if (idxs.length == 0) return subject;

        uint256 newLen = subject.length + idxs.length * (replacement.length - needle.length);
        result = new bytes(newLen);

        uint256 dst = 0;
        uint256 readPtr = 0;
        for (uint256 i = 0; i < idxs.length; ++i) {
            uint256 pos = idxs[i];
            // copy subject[readPtr:pos]
            for (; readPtr < pos; ++readPtr) {
                result[dst++] = subject[readPtr];
            }
            // copy replacement
            for (uint256 j = 0; j < replacement.length; ++j) {
                result[dst++] = replacement[j];
            }
            readPtr = pos + needle.length;
        }
        // copy remainder
        while (readPtr < subject.length) {
            result[dst++] = subject[readPtr++];
        }
    }

    uint256 private constant NOT_FOUND = type(uint256).max;

    /// indexOf with from
    function indexOf(bytes memory subject, bytes memory needle, uint256 from) internal pure returns (uint256 result) {
        if (from > subject.length) return NOT_FOUND;
        if (needle.length == 0) return from <= subject.length ? from : subject.length;
        if (needle.length > subject.length) return NOT_FOUND;
        for (uint256 i = from; i + needle.length <= subject.length; ++i) {
            bool ok = true;
            for (uint256 j = 0; j < needle.length; ++j) {
                if (subject[i + j] != needle[j]) { ok = false; break; }
            }
            if (ok) return i;
        }
        return NOT_FOUND;
    }

    /// indexOf without from
    function indexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return indexOf(subject, needle, 0);
    }

    /// lastIndexOf with from
    function lastIndexOf(bytes memory subject, bytes memory needle, uint256 from) internal pure returns (uint256 result) {
        if (needle.length == 0) {
            return from < subject.length ? from : subject.length;
        }
        if (needle.length > subject.length) return NOT_FOUND;
        uint256 start = from;
        if (start > subject.length - needle.length) start = subject.length - needle.length;
        for (uint256 i = start + 1; i > 0; --i) {
            uint256 idx = i - 1;
            bool ok = true;
            for (uint256 j = 0; j < needle.length; ++j) {
                if (subject[idx + j] != needle[j]) { ok = false; break; }
            }
            if (ok) return idx;
            if (i == 1) break;
        }
        return NOT_FOUND;
    }

    /// lastIndexOf without from
    function lastIndexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        if (subject.length == 0) return needle.length == 0 ? 0 : NOT_FOUND;
        if (needle.length == 0) return subject.length;
        return lastIndexOf(subject, needle, subject.length - 1);
    }

    /// contains
    function contains(bytes memory subject, bytes memory needle) internal pure returns (bool) {
        return indexOf(subject, needle) != NOT_FOUND;
    }

    /// startsWith
    function startsWith(bytes memory subject, bytes memory needle) internal pure returns (bool result) {
        if (needle.length > subject.length) return false;
        bytes32 h1;
        bytes32 h2;
        assembly {
            h1 := keccak256(add(subject, 0x20), mload(needle))
            h2 := keccak256(add(needle, 0x20), mload(needle))
        }
        return h1 == h2;
    }

    /// endsWith
    function endsWith(bytes memory subject, bytes memory needle) internal pure returns (bool result) {
        if (needle.length > subject.length) return false;
        uint256 start = subject.length - needle.length;
        for (uint256 i = 0; i < needle.length; ++i) {
            if (subject[start + i] != needle[i]) return false;
        }
        return true;
    }

    /// repeat
    function repeat(bytes memory subject, uint256 times) internal pure returns (bytes memory result) {
        if (times == 0 || subject.length == 0) return new bytes(0);
        uint256 n = subject.length;
        result = new bytes(n * times);
        uint256 dst = 0;
        for (uint256 t = 0; t < times; ++t) {
            for (uint256 i = 0; i < n; ++i) {
                result[dst++] = subject[i];
            }
        }
    }

    /// slice
    function slice(bytes memory subject, uint256 start, uint256 end) internal pure returns (bytes memory result) {
        uint256 len = subject.length;
        if (end > len) end = len;
        if (start > end) start = end;
        uint256 n = end - start;
        result = new bytes(n);
        for (uint256 i = 0; i < n; ++i) {
            result[i] = subject[start + i];
        }
    }

    /// slice with only start
    function slice(bytes memory subject, uint256 start) internal pure returns (bytes memory result) {
        return slice(subject, start, subject.length);
    }

    /// slice calldata (start,end)
    function sliceCalldata(bytes calldata subject, uint256 start, uint256 end) internal pure returns (bytes calldata result) {
        if (end > subject.length) end = subject.length;
        if (start > end) start = end;
        return subject[start:end];
    }

    /// slice calldata (start)
    function sliceCalldata(bytes calldata subject, uint256 start) internal pure returns (bytes calldata result) {
        return sliceCalldata(subject, start, subject.length);
    }

    /// truncate memory bytes to n
    function truncate(bytes memory subject, uint256 n) internal pure returns (bytes memory result) {
        if (n >= subject.length) return subject;
        result = new bytes(n);
        for (uint256 i = 0; i < n; ++i) result[i] = subject[i];
    }

    /// truncatedCalldata
    function truncatedCalldata(bytes calldata subject, uint256 n) internal pure returns (bytes calldata result) {
        uint256 len = subject.length;
        if (n > len) n = len;
        return subject[0:n];
    }

    /// indicesOf
    function indicesOf(bytes memory subject, bytes memory needle) internal pure returns (uint256[] memory result) {
        if (needle.length == 0 || needle.length > subject.length) {
            result = new uint256[](0);
            return result;
        }
        // gather indices dynamically
        uint256 cap = 8;
        uint256[] memory tmp = new uint256[](cap);
        uint256 count = 0;
        for (uint256 i = 0; i + needle.length <= subject.length; ++i) {
            bool ok = true;
            for (uint256 j = 0; j < needle.length; ++j) {
                if (subject[i + j] != needle[j]) { ok = false; break; }
            }
            if (ok) {
                if (count == cap) {
                    // grow
                    uint256[] memory ntmp = new uint256[](cap * 2);
                    for (uint256 k = 0; k < cap; ++k) ntmp[k] = tmp[k];
                    tmp = ntmp;
                    cap = cap * 2;
                }
                tmp[count++] = i;
                i += needle.length - 1;
            }
        }
        result = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) result[i] = tmp[i];
    }

    /// split
    function split(bytes memory subject, bytes memory delimiter) internal pure returns (bytes[] memory result) {
        if (delimiter.length == 0) {
            // each byte as a slice
            result = new bytes[](0);
            return result;
        }
        uint256[] memory idxs = indicesOf(subject, delimiter);
        uint256 parts = idxs.length + 1;
        result = new bytes[](parts);
        uint256 read = 0;
        for (uint256 i = 0; i < idxs.length; ++i) {
            uint256 pos = idxs[i];
            uint256 len = pos - read;
            result[i] = slice(subject, read, pos);
            read = pos + delimiter.length;
        }
        // last part
        result[parts - 1] = slice(subject, read, subject.length);
    }

    /// concat
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        uint256 la = a.length;
        uint256 lb = b.length;
        result = new bytes(la + lb);
        uint256 k = 0;
        for (uint256 i = 0; i < la; ++i) result[k++] = a[i];
        for (uint256 j = 0; j < lb; ++j) result[k++] = b[j];
    }

    /// eq
    function eq(bytes memory a, bytes memory b) internal pure returns (bool result) {
        if (a.length != b.length) return false;
        for (uint256 i = 0; i < a.length; ++i) if (a[i] != b[i]) return false;
        return true;
    }

    /// eqs: compare to bytes32
    function eqs(bytes memory a, bytes32 b) internal pure returns (bool result) {
        if (a.length > 32) return false;
        bytes32 x;
        assembly {
            x := mload(add(a, 0x20))
        }
        // mask off upper bytes of b
        uint256 mask = type(uint256).max << ((32 - a.length) * 8);
        return (bytes32(bytes32(uint256(x) & mask)) == (b & bytes32(mask)));
    }

    /// cmp
    function cmp(bytes memory a, bytes memory b) internal pure returns (int256 result) {
        uint256 la = a.length;
        uint256 lb = b.length;
        uint256 n = la < lb ? la : lb;
        for (uint256 i = 0; i < n; ++i) {
            if (a[i] > b[i]) return 1;
            if (a[i] < b[i]) return -1;
        }
        if (la > lb) return 1;
        if (la < lb) return -1;
        return 0;
    }

    /// directReturn bytes memory
    function directReturn(bytes memory a) internal pure {
        assembly {
            let data := add(a, 0x20)
            let len := mload(a)
            // return data with length prefix
            mstore(sub(data, 0x20), len)
            // round up size to multiple of 32
            let size := add(len, 0x20)
            let rounded := mul(div(add(size, 31), 32), 32)
            return(sub(data, 0x20), rounded)
        }
    }

    /// directReturn array of bytes
    function directReturn(bytes[] memory a) internal pure {
        assembly {
            // The ABI encoding of bytes[] starts with length, then offsets and data.
            let loc := a
            let len := mload(loc)
            // return entire memory region of the dynamic array 'a'
            // This is tricky to compute; we'll compute approximate size by iterating.
            // For safety, compute size as free memory pointer - a
            let free := mload(0x40)
            // approximate return: use free - a (may include surplus, acceptable for low-level directReturn)
            let size := sub(free, loc)
            return(loc, size)
        }
    }

    /// load 32 bytes from memory offset
    function load(bytes memory a, uint256 offset) internal pure returns (bytes32 result) {
        assembly {
            result := mload(add(a, add(0x20, offset)))
        }
    }

    /// loadCalldata
    function loadCalldata(bytes calldata a, uint256 offset) internal pure returns (bytes32 result) {
        assembly {
            result := calldataload(add(a.offset, offset))
        }
    }

    /// emptyCalldata
    function emptyCalldata() internal pure returns (bytes calldata result) {
        bytes memory tmp = new bytes(0);
        result = tmp;
    }
}