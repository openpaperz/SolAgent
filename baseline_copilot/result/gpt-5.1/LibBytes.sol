// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibBytes {
    struct BytesStorage {
        bytes32 _spacer;
    }

    uint256 internal constant NOT_FOUND = type(uint256).max;

    function set(BytesStorage storage $, bytes memory s) internal {
        assembly {
            let n := mload(s)
            let packed := or(shl(8, n), 0xff)
            let slot := $.slot
            switch lt(n, 0xff)
            case 1 {
                let firstWord := mload(add(s, 0x20))
                packed := or(and(firstWord, not(0xff)), packed)
                sstore(slot, packed)
            }
            default {
                mstore(0x00, slot)
                let p := keccak256(0x00, 0x20)
                let o := add(s, 0x20)
                let end := add(o, n)
                for { let i := 0 } lt(add(o, i), end) { i := add(i, 0x20) } {
                    sstore(add(p, shr(5, i)), mload(add(o, i)))
                }
                sstore(slot, packed)
            }
        }
    }

    function setCalldata(BytesStorage storage $, bytes calldata s) internal {
        assembly {
            let n := s.length
            let packed := or(shl(8, n), 0xff)
            let slot := $.slot
            switch lt(n, 0xff)
            case 1 {
                let firstWord := calldataload(s.offset)
                packed := or(and(firstWord, not(0xff)), packed)
                sstore(slot, packed)
            }
            default {
                mstore(0x00, slot)
                let p := keccak256(0x00, 0x20)
                let o := s.offset
                let end := add(o, n)
                for { let i := 0 } lt(add(o, i), end) { i := add(i, 0x20) } {
                    sstore(add(p, shr(5, i)), calldataload(add(o, i)))
                }
                sstore(slot, packed)
            }
        }
    }

    function clear(BytesStorage storage $) internal {
        delete $._spacer;
    }

    function isEmpty(BytesStorage storage $) internal view returns (bool) {
        assembly {
            let v := sload($.slot)
            mstore(0x00, v)
            // Empty if low byte is zero (no length stored) and whole word is zero.
            let last := byte(31, mload(0x00))
            mstore(0x00, iszero(last))
            return(0x00, 0x20)
        }
    }

    function length(BytesStorage storage $) internal view returns (uint256 result) {
        assembly {
            let v := sload($.slot)
            mstore(0x00, v)
            let last := byte(31, mload(0x00))
            switch eq(last, 0xff)
            case 1 {
                result := shr(8, v)
            }
            default {
                result := last
            }
        }
    }

    function get(BytesStorage storage $) internal view returns (bytes memory result) {
        assembly {
            let packed := sload($.slot)
            mstore(0x00, packed)
            let last := byte(31, mload(0x00))
            let n := 0
            switch eq(last, 0xff)
            case 1 {
                n := shr(8, packed)
            }
            default {
                n := last
            }
            result := mload(0x40)
            let rData := add(result, 0x20)
            mstore(result, n)
            switch eq(last, 0xff)
            case 0 {
                // inline, drop length byte
                let word := and(packed, not(0xff))
                mstore(rData, shr(8, word))
            }
            default {
                mstore(0x00, $.slot)
                let p := keccak256(0x00, 0x20)
                let end := add(rData, n)
                for { let i := 0 } lt(add(rData, i), end) { i := add(i, 0x20) } {
                    mstore(add(rData, i), sload(add(p, shr(5, i))))
                }
            }
            let lastSlot := add(rData, n)
            mstore(lastSlot, 0)
            mstore(0x40, add(lastSlot, 0x20))
        }
    }

    function replace(bytes memory subject, bytes memory needle, bytes memory replacement) internal pure returns (bytes memory result) {
        assembly {
            let subjLen := mload(subject)
            let needleLen := mload(needle)
            let replLen := mload(replacement)

            if iszero(needleLen) {
                result := mload(0x40)
                mstore(result, add(subjLen, mul(replLen, add(subjLen, 1))))
                let rPtr := add(result, 0x20)
                let sPtr := add(subject, 0x20)
                for { let i := 0 } lt(i, subjLen) { i := add(i, 1) } {
                    // copy replacement
                    let rEnd := add(rPtr, replLen)
                    for { let j := 0 } lt(add(rPtr, j), rEnd) { j := add(j, 0x20) } {
                        mstore(add(rPtr, j), mload(add(replacement, add(0x20, j))))
                    }
                    rPtr := rEnd
                    mstore8(rPtr, byte(0, mload(add(sPtr, i))))
                    rPtr := add(rPtr, 1)
                }
                let rEnd2 := add(rPtr, replLen)
                for { let j := 0 } lt(add(rPtr, j), rEnd2) { j := add(j, 0x20) } {
                    mstore(add(rPtr, j), mload(add(replacement, add(0x20, j))))
                }
                mstore(0x40, add(rEnd2, 0x20))
                leave
            }

            if or(iszero(subjLen), gt(needleLen, subjLen)) {
                result := subject
                leave
            }

            let sPtr := add(subject, 0x20)
            let sEnd := add(sPtr, subjLen)
            let nPtr := add(needle, 0x20)

            let free := mload(0x40)
            result := free
            let rPtr := add(result, 0x20)

            let searchEnd := sub(add(sPtr, subjLen), needleLen)
            let nFirst := mload(nPtr)
            let nHash := 0
            if iszero(lt(needleLen, 0x20)) {
                nHash := keccak256(nPtr, needleLen)
            }

            for { } lt(sPtr, sEnd) { } {
                if gt(sPtr, searchEnd) {
                    // copy remainder
                    for { } lt(sPtr, sEnd) { sPtr := add(sPtr, 0x20) rPtr := add(rPtr, 0x20) } {
                        mstore(rPtr, mload(sPtr))
                    }
                    break
                }
                if eq(mload(sPtr), nFirst) {
                    let match := 0
                    if lt(needleLen, 0x20) {
                        let mask := not(sub(exp(2, mul(8, sub(0x20, needleLen))), 1))
                        match := eq(and(mload(sPtr), mask), and(nFirst, mask))
                    }
                    if iszero(match) {
                        if iszero(lt(needleLen, 0x20)) {
                            match := eq(keccak256(sPtr, needleLen), nHash)
                        }
                    }
                    if match {
                        // copy replacement
                        let rEnd := add(rPtr, replLen)
                        for { let j := 0 } lt(add(rPtr, j), rEnd) { j := add(j, 0x20) } {
                            mstore(add(rPtr, j), mload(add(replacement, add(0x20, j))))
                        }
                        rPtr := rEnd
                        sPtr := add(sPtr, needleLen)
                        continue
                    }
                }
                mstore8(rPtr, byte(0, mload(sPtr)))
                sPtr := add(sPtr, 1)
                rPtr := add(rPtr, 1)
            }

            let rLen := sub(rPtr, add(result, 0x20))
            mstore(result, rLen)
            let last := add(add(result, 0x20), rLen)
            mstore(last, 0)
            mstore(0x40, add(last, 0x20))
        }
    }

    function indexOf(bytes memory subject, bytes memory needle, uint256 from) internal pure returns (uint256 result) {
        assembly {
            let subjLen := mload(subject)
            let needleLen := mload(needle)
            let sPtr := add(subject, 0x20)

            result := NOT_FOUND

            if iszero(needleLen) {
                if lt(from, subjLen) {
                    result := from
                }
                leave
            }

            if or(gt(needleLen, subjLen), gt(from, subjLen)) {
                leave
            }

            sPtr := add(sPtr, from)
            let end := add(add(subject, 0x20), sub(subjLen, needleLen))
            let nPtr := add(needle, 0x20)
            let nFirst := mload(nPtr)
            let nHash := 0
            if iszero(lt(needleLen, 0x20)) {
                nHash := keccak256(nPtr, needleLen)
            }

            for { } le(sPtr, end) { sPtr := add(sPtr, 1) } {
                if eq(mload(sPtr), nFirst) {
                    let match := 0
                    if lt(needleLen, 0x20) {
                        let mask := not(sub(exp(2, mul(8, sub(0x20, needleLen))), 1))
                        match := eq(and(mload(sPtr), mask), and(nFirst, mask))
                    }
                    if iszero(match) {
                        if iszero(lt(needleLen, 0x20)) {
                            match := eq(keccak256(sPtr, needleLen), nHash)
                        }
                    }
                    if match {
                        result := sub(sub(sPtr, add(subject, 0x20)), 0)
                        break
                    }
                }
            }
        }
    }

    function indexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return indexOf(subject, needle, 0);
    }

    function lastIndexOf(bytes memory subject, bytes memory needle, uint256 from) internal pure returns (uint256 result) {
        assembly {
            let subjLen := mload(subject)
            let needleLen := mload(needle)
            let sBase := add(subject, 0x20)

            result := NOT_FOUND

            if iszero(needleLen) {
                if lt(from, subjLen) {
                    result := from
                }
                leave
            }

            if or(gt(needleLen, subjLen), iszero(subjLen)) {
                leave
            }

            if iszero(lt(from, sub(subjLen, needleLen))) {
                if lt(from, subjLen) {
                    from := sub(subjLen, needleLen)
                } else {
                    from := sub(subjLen, needleLen)
                }
            }

            let nPtr := add(needle, 0x20)
            let nFirst := mload(nPtr)
            let nHash := 0
            if iszero(lt(needleLen, 0x20)) {
                nHash := keccak256(nPtr, needleLen)
            }

            for { let i := add(sBase, from) } iszero(lt(i, sBase)) { i := sub(i, 1) } {
                if lt(sub(add(i, needleLen), sBase), add(subjLen, 1)) {
                    if eq(mload(i), nFirst) {
                        let match := 0
                        if lt(needleLen, 0x20) {
                            let mask := not(sub(exp(2, mul(8, sub(0x20, needleLen))), 1))
                            match := eq(and(mload(i), mask), and(nFirst, mask))
                        }
                        if iszero(match) {
                            if iszero(lt(needleLen, 0x20)) {
                                match := eq(keccak256(i, needleLen), nHash)
                            }
                        }
                        if match {
                            result := sub(sub(i, sBase), 0)
                            break
                        }
                    }
                }
                if eq(i, sBase) { break }
            }
        }
    }

    function lastIndexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return lastIndexOf(subject, needle, type(uint256).max);
    }

    function contains(bytes memory subject, bytes memory needle) internal pure returns (bool) {
        return indexOf(subject, needle, 0) != NOT_FOUND;
    }

    function startsWith(bytes memory subject, bytes memory needle) internal pure returns (bool result) {
        assembly {
            let n := mload(needle)
            if gt(n, mload(subject)) {
                result := 0
            } else {
                let sPtr := add(subject, 0x20)
                let nPtr := add(needle, 0x20)
                result := eq(keccak256(sPtr, n), keccak256(nPtr, n))
            }
        }
    }

    function endsWith(bytes memory subject, bytes memory needle) internal pure returns (bool result) {
        assembly {
            let n := mload(needle)
            let sLen := mload(subject)
            if gt(n, sLen) {
                result := 0
            } else {
                let sPtr := add(add(subject, 0x20), sub(sLen, n))
                let nPtr := add(needle, 0x20)
                result := eq(keccak256(sPtr, n), keccak256(nPtr, n))
            }
        }
    }

    function repeat(bytes memory subject, uint256 times) internal pure returns (bytes memory result) {
        assembly {
            let len := mload(subject)
            if iszero(or(times, len)) {
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x40))
                leave
            }
            let total := mul(len, times)
            result := mload(0x40)
            mstore(result, total)
            let rPtr := add(result, 0x20)
            let sPtr := add(subject, 0x20)
            for { let t := times } t { t := sub(t, 1) } {
                let i := 0
                for { } lt(i, len) { i := add(i, 0x20) } {
                    mstore(add(rPtr, i), mload(add(sPtr, i)))
                }
                rPtr := add(rPtr, len)
            }
            let last := add(add(result, 0x20), total)
            mstore(last, 0)
            mstore(0x40, add(last, 0x20))
        }
    }

    function slice(bytes memory subject, uint256 start, uint256 end) internal pure returns (bytes memory result) {
        assembly {
            let len := mload(subject)
            if gt(end, len) { end := len }
            if gt(start, len) { start := len }
            if lt(end, start) { end := start }
            let n := sub(end, start)
            result := mload(0x40)
            mstore(result, n)
            let rPtr := add(result, 0x20)
            let sPtr := add(add(subject, 0x20), start)
            let i := add(sPtr, n)
            for { } gt(i, sPtr) { } {
                i := sub(i, 0x20)
                let j := sub(add(rPtr, sub(i, sPtr)), 0)
                mstore(j, mload(i))
                if eq(i, sPtr) { break }
            }
            let last := add(rPtr, n)
            mstore(last, 0)
            mstore(0x40, add(last, 0x20))
        }
    }

    function slice(bytes memory subject, uint256 start) internal pure returns (bytes memory result) {
        return slice(subject, start, type(uint256).max);
    }

    function sliceCalldata(bytes calldata subject, uint256 start, uint256 end) internal pure returns (bytes calldata result) {
        assembly {
            let len := subject.length
            if gt(end, len) { end := len }
            if gt(start, len) { start := len }
            if lt(end, start) { end := start }
            result.offset := add(subject.offset, start)
            result.length := sub(end, start)
        }
    }

    function sliceCalldata(bytes calldata subject, uint256 start) internal pure returns (bytes calldata result) {
        return sliceCalldata(subject, start, type(uint256).max);
    }

    function truncate(bytes memory subject, uint256 n) internal pure returns (bytes memory result) {
        result = subject;
        assembly {
            let len := mload(result)
            if lt(n, len) {
                mstore(result, n)
            }
        }
    }

    function truncatedCalldata(bytes calldata subject, uint256 n) internal pure returns (bytes calldata result) {
        assembly {
            result.offset := subject.offset
            let len := subject.length
            if lt(len, n) {
                result.length := len
            } else {
                result.length := n
            }
        }
    }

    function indicesOf(bytes memory subject, bytes memory needle) internal pure returns (uint256[] memory result) {
        assembly {
            let subjLen := mload(subject)
            let needleLen := mload(needle)

            if or(iszero(needleLen), gt(needleLen, subjLen)) {
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x40))
                leave
            }

            let sPtr := add(subject, 0x20)
            let nPtr := add(needle, 0x20)
            let end := add(add(subject, 0x20), sub(subjLen, needleLen))
            let nFirst := mload(nPtr)
            let nHash := 0
            if iszero(lt(needleLen, 0x20)) {
                nHash := keccak256(nPtr, needleLen)
            }

            let free := mload(0x40)
            // temp store indices as plain array without length first
            let tmp := add(free, 0x20)
            let count := 0

            for { let p := sPtr } le(p, end) { p := add(p, 1) } {
                if eq(mload(p), nFirst) {
                    let match := 0
                    if lt(needleLen, 0x20) {
                        let mask := not(sub(exp(2, mul(8, sub(0x20, needleLen))), 1))
                        match := eq(and(mload(p), mask), and(nFirst, mask))
                    }
                    if iszero(match) {
                        if iszero(lt(needleLen, 0x20)) {
                            match := eq(keccak256(p, needleLen), nHash)
                        }
                    }
                    if match {
                        mstore(add(tmp, mul(count, 0x20)), sub(sub(p, sPtr), 0))
                        count := add(count, 1)
                        p := add(p, sub(needleLen, 1))
                    }
                }
            }

            result := free
            mstore(result, count)
            let rData := add(result, 0x20)
            let size := mul(count, 0x20)
            let i := 0
            for { } lt(i, size) { i := add(i, 0x20) } {
                mstore(add(rData, i), mstore(add(tmp, i), mload(add(tmp, i))))
            }
            let last := add(rData, size)
            mstore(last, 0)
            mstore(0x40, add(last, 0x20))
        }
    }

    function split(bytes memory subject, bytes memory delimiter) internal pure returns (bytes[] memory result) {
        assembly {
            let subjLen := mload(subject)
            let delLen := mload(delimiter)

            if iszero(delLen) {
                result := mload(0x40)
                mstore(result, subjLen)
                let rPtr := add(result, 0x20)
                let sPtr := add(subject, 0x20)
                for { let i := 0 } lt(i, subjLen) { i := add(i, 1) } {
                    let arr := mload(0x40)
                    mstore(arr, 1)
                    mstore(add(arr, 0x20), byte(0, mload(add(sPtr, i))))
                    mstore(rPtr, arr)
                    rPtr := add(rPtr, 0x20)
                    mstore(0x40, add(add(arr, 0x40), 0x00))
                }
                mstore(0x40, rPtr)
                leave
            }

            let indices := indicesOf(subject, delimiter)
            let count := add(mload(indices), 1)
            result := mload(0x40)
            mstore(result, count)
            let rPtr := add(result, 0x20)

            let prev := 0
            let sPtr := add(subject, 0x20)

            for { let i := 0 } lt(i, sub(count, 1)) { i := add(i, 1) } {
                let idx := mload(add(add(indices, 0x20), mul(i, 0x20)))
                let segLen := sub(idx, prev)
                let arr := mload(0x40)
                mstore(arr, segLen)
                let aPtr := add(arr, 0x20)
                let src := add(sPtr, prev)
                let end := add(aPtr, segLen)
                for { } lt(aPtr, end) { aPtr := add(aPtr, 0x20) src := add(src, 0x20) } {
                    mstore(aPtr, mload(src))
                }
                mstore(rPtr, arr)
                rPtr := add(rPtr, 0x20)
                mstore(0x40, add(add(arr, 0x20), and(add(segLen, 0x1f), not(0x1f))))
                prev := add(idx, delLen)
            }

            let lastLen := sub(subjLen, prev)
            let arrLast := mload(0x40)
            mstore(arrLast, lastLen)
            let aPtrLast := add(arrLast, 0x20)
            let srcLast := add(sPtr, prev)
            let endLast := add(aPtrLast, lastLen)
            for { } lt(aPtrLast, endLast) { aPtrLast := add(aPtrLast, 0x20) srcLast := add(srcLast, 0x20) } {
                mstore(aPtrLast, mload(srcLast))
            }
            mstore(rPtr, arrLast)
            rPtr := add(rPtr, 0x20)
            mstore(0x40, add(add(arrLast, 0x20), and(add(lastLen, 0x1f), not(0x1f))))
        }
    }

    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        assembly {
            let aLen := mload(a)
            let bLen := mload(b)
            let total := add(aLen, bLen)
            result := mload(0x40)
            mstore(result, total)
            let rPtr := add(result, 0x20)
            let aPtr := add(a, 0x20)
            let bPtr := add(b, 0x20)

            let endA := add(rPtr, aLen)
            for { } lt(rPtr, endA) { rPtr := add(rPtr, 0x20) aPtr := add(aPtr, 0x20) } {
                mstore(rPtr, mload(aPtr))
            }
            let endB := add(rPtr, bLen)
            for { } lt(rPtr, endB) { rPtr := add(rPtr, 0x20) bPtr := add(bPtr, 0x20) } {
                mstore(rPtr, mload(bPtr))
            }
            mstore(rPtr, 0)
            mstore(0x40, add(rPtr, 0x20))
        }
    }

    function eq(bytes memory a, bytes memory b) internal pure returns (bool result) {
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    function eqs(bytes memory a, bytes32 b) internal pure returns (bool result) {
        assembly {
            let len := mload(a)
            let m := not(sub(exp(2, mul(8, sub(0x20, len))), 1))
            let x := and(mload(add(a, 0x20)), m)
            result := and(eq(len, 0x20), eq(x, b))
        }
    }

    function cmp(bytes memory a, bytes memory b) internal pure returns (int256 result) {
        assembly {
            let aLen := mload(a)
            let bLen := mload(b)
            let aPtr := add(a, 0x20)
            let bPtr := add(b, 0x20)
            let n := mul(0x20, lt(aLen, bLen))
            if iszero(n) { n := mul(0x20, lt(bLen, aLen)) }
            if iszero(n) { n := mul(0x20, shr(5, aLen)) } // min rounded down

            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                let aw := mload(add(aPtr, i))
                let bw := mload(add(bPtr, i))
                if iszero(eq(aw, bw)) {
                    result := 1
                    if lt(aw, bw) { result := -1 }
                    leave
                }
            }

            let rem := and(aLen, 0x1f)
            if iszero(rem) { rem := and(bLen, 0x1f) }
            if rem {
                let mask := not(sub(exp(2, mul(8, sub(0x20, rem))), 1))
                let aw := and(mload(add(aPtr, n)), mask)
                let bw := and(mload(add(bPtr, n)), mask)
                if iszero(eq(aw, bw)) {
                    result := 1
                    if lt(aw, bw) { result := -1 }
                    leave
                }
            }

            if gt(aLen, bLen) { result := 1 }
            if lt(aLen, bLen) { result := -1 }
        }
    }

    function directReturn(bytes memory a) internal pure {
        assembly {
            let data := sub(a, 0x20)
            let len := add(mload(a), 0x40)
            let padded := and(add(len, 0x3f), not(0x3f))
            mstore(data, 0x20)
            return(data, padded)
        }
    }

    function directReturn(bytes[] memory a) internal pure {
        assembly {
            let off := 0x20
            let len := mload(a)
            let base := a
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                let elem := mload(add(add(base, 0x20), mul(i, 0x20)))
                mstore(add(add(base, 0x20), mul(i, 0x20)), off)
                let eLen := mload(elem)
                off := add(off, add(0x20, and(add(eLen, 0x1f), not(0x1f))))
            }
            let total := add(off, 0x20)
            let data := sub(a, 0x20)
            mstore(data, 0x20)
            let padded := and(add(total, 0x3f), not(0x3f))
            return(data, padded)
        }
    }

    function load(bytes memory a, uint256 offset) internal pure returns (bytes32 result) {
        assembly {
            result := mload(add(add(a, 0x20), offset))
        }
    }

    function loadCalldata(bytes calldata a, uint256 offset) internal pure returns (bytes32 result) {
        assembly {
            result := calldataload(add(a.offset, offset))
        }
    }

    function emptyCalldata() internal pure returns (bytes calldata result) {
        assembly {
            result.offset := 0
            result.length := 0
        }
    }
}