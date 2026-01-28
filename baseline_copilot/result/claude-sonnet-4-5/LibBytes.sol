// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for bytes related operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBytes.sol)
library LibBytes {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev A struct representing a storage container for bytes data.
    struct BytesStorage {
        bytes32 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     BYTES STORAGE OPERATIONS               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the bytes data in the storage slot.
    function set(BytesStorage storage $, bytes memory s) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            let packed := or(0xff, shl(8, n))
            let i := 0x1f
            for {} 1 {} {
                if iszero(gt(n, i)) {
                    packed := or(mload(add(s, 0x20)), shl(mul(8, i), n))
                    break
                }
                let o := add(s, 0x20)
                mstore(0x00, $._spacer.slot)
                let p := keccak256(0x00, 0x20)
                for {} 1 {} {
                    sstore(add(p, shr(5, i)), mload(add(o, i)))
                    i := add(i, 0x20)
                    if iszero(lt(i, n)) { break }
                }
                break
            }
            sstore($._spacer.slot, packed)
        }
    }

    /// @dev Sets the calldata for a BytesStorage struct.
    function setCalldata(BytesStorage storage $, bytes calldata s) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let n := s.length
            let packed := or(0xff, shl(8, n))
            let i := 0x1f
            for {} 1 {} {
                if iszero(gt(n, i)) {
                    packed := or(shl(mul(8, i), n), shr(mul(8, sub(0x20, i)), calldataload(s.offset)))
                    break
                }
                mstore(0x00, $._spacer.slot)
                let p := keccak256(0x00, 0x20)
                for {} 1 {} {
                    sstore(add(p, shr(5, i)), calldataload(add(s.offset, i)))
                    i := add(i, 0x20)
                    if iszero(lt(i, n)) { break }
                }
                break
            }
            sstore($._spacer.slot, packed)
        }
    }

    /// @dev Clears the storage of the BytesStorage struct.
    function clear(BytesStorage storage $) internal {
        /// @solidity memory-safe-assembly
        assembly {
            sstore($._spacer.slot, 0)
        }
    }

    /// @dev Checks if the BytesStorage is empty.
    function isEmpty(BytesStorage storage $) internal view returns (bool) {
        /// @solidity memory-safe-assembly
        assembly {
            return iszero(byte(0, sload($._spacer.slot)))
        }
    }

    /// @dev Retrieves the length of the BytesStorage data structure.
    function length(BytesStorage storage $) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let packed := sload($._spacer.slot)
            result := byte(0, packed)
            if eq(result, 0xff) {
                result := shr(8, packed)
            }
        }
    }

    /// @dev Retrieves the bytes stored in the BytesStorage struct.
    function get(BytesStorage storage $) internal view returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let packed := sload($._spacer.slot)
            let n := byte(0, packed)
            let i := 0x1f
            for {} 1 {} {
                if eq(n, 0xff) {
                    n := shr(8, packed)
                    mstore(0x00, $._spacer.slot)
                    let p := keccak256(0x00, 0x20)
                    for { i := 0x00 } 1 {} {
                        mstore(add(result, add(0x20, i)), sload(add(p, shr(5, i))))
                        i := add(i, 0x20)
                        if iszero(lt(i, n)) { break }
                    }
                    break
                }
                mstore(add(result, 0x20), packed)
                break
            }
            mstore(result, n)
            mstore(add(add(result, 0x20), n), 0)
            mstore(0x40, add(add(result, 0x40), n))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     BYTES OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Replaces occurrences of `needle` in `subject` with `replacement`.
    function replace(bytes memory subject, bytes memory needle, bytes memory replacement)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let needleLen := mload(needle)
            let replacementLen := mload(replacement)
            let d := sub(result, subject)
            let i := add(subject, 0x20)
            let end := add(i, mload(subject))
            for {} 1 {} {
                if iszero(lt(needleLen, mload(subject))) {
                    let searchEnd := add(sub(end, needleLen), 1)
                    let h := 0
                    if iszero(lt(needleLen, 0x20)) {
                        h := keccak256(add(needle, 0x20), needleLen)
                    }
                    let w := mload(add(needle, 0x20))
                    for {} 1 {} {
                        if iszero(lt(i, searchEnd)) { break }
                        if iszero(shr(128, xor(mload(i), w))) {
                            if iszero(or(lt(needleLen, 0x20), eq(keccak256(i, needleLen), h))) {
                                let o := add(i, d)
                                let r := add(replacement, 0x20)
                                let rEnd := add(r, replacementLen)
                                for {} 1 {} {
                                    mstore(o, mload(r))
                                    r := add(r, 0x20)
                                    o := add(o, 0x20)
                                    if iszero(lt(r, rEnd)) { break }
                                }
                                d := sub(add(d, replacementLen), needleLen)
                                i := add(i, needleLen)
                                if iszero(lt(i, searchEnd)) { break }
                                continue
                            }
                        }
                        mstore(add(i, d), mload(i))
                        i := add(i, 1)
                    }
                }
                break
            }
            let o := add(i, d)
            for {} 1 {} {
                mstore(o, mload(i))
                i := add(i, 0x20)
                o := add(o, 0x20)
                if iszero(lt(i, end)) { break }
            }
            let n := sub(o, add(result, 0x20))
            mstore(o, 0)
            mstore(0x40, add(o, 0x20))
            mstore(result, n)
        }
    }

    /// @dev Finds the index of `needle` in `subject`, starting from `from`.
    function indexOf(bytes memory subject, bytes memory needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := not(0)
            let needleLen := mload(needle)
            if iszero(needleLen) {
                result := from
                if iszero(lt(from, mload(subject))) {
                    result := mload(subject)
                }
                leave
            }
            let i := add(subject, 0x20)
            let subjectLen := mload(subject)
            if iszero(gt(needleLen, subjectLen)) {
                i := add(i, from)
                let end := add(sub(add(subject, 0x20), needleLen), subjectLen)
                let h := 0
                if iszero(lt(needleLen, 0x20)) {
                    h := keccak256(add(needle, 0x20), needleLen)
                }
                let w := mload(add(needle, 0x20))
                for {} 1 {} {
                    if iszero(lt(i, end)) { break }
                    if iszero(shr(128, xor(mload(i), w))) {
                        if iszero(or(lt(needleLen, 0x20), eq(keccak256(i, needleLen), h))) {
                            result := sub(i, add(subject, 0x20))
                            break
                        }
                    }
                    i := add(i, 1)
                }
            }
        }
    }

    /// @dev Finds the index of `needle` in `subject`.
    function indexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return indexOf(subject, needle, 0);
    }

    /// @dev Finds the last index of `needle` in `subject`, starting from `from`.
    function lastIndexOf(bytes memory subject, bytes memory needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := not(0)
            let needleLen := mload(needle)
            let subjectLen := mload(subject)
            if iszero(gt(needleLen, subjectLen)) {
                let i := add(subject, 0x20)
                let end := add(i, subjectLen)
                i := add(i, from)
                if iszero(gt(i, end)) {
                    i := end
                }
                let h := 0
                if iszero(lt(needleLen, 0x20)) {
                    h := keccak256(add(needle, 0x20), needleLen)
                }
                let w := mload(add(needle, 0x20))
                for {} 1 {} {
                    if lt(i, add(add(subject, 0x20), needleLen)) { break }
                    i := sub(i, 1)
                    if iszero(shr(128, xor(mload(i), w))) {
                        if iszero(or(lt(needleLen, 0x20), eq(keccak256(i, needleLen), h))) {
                            result := sub(i, add(subject, 0x20))
                            break
                        }
                    }
                }
            }
        }
    }

    /// @dev Finds the last index of `needle` in `subject`.
    function lastIndexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return lastIndexOf(subject, needle, type(uint256).max);
    }

    /// @dev Returns true if `needle` is in `subject`.
    function contains(bytes memory subject, bytes memory needle) internal pure returns (bool) {
        return indexOf(subject, needle) != type(uint256).max;
    }

    /// @dev Returns true if `subject` starts with `needle`.
    function startsWith(bytes memory subject, bytes memory needle) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(needle)
            result := and(
                iszero(gt(n, mload(subject))),
                eq(keccak256(add(subject, 0x20), n), keccak256(add(needle, 0x20), n))
            )
        }
    }

    /// @dev Returns true if `subject` ends with `needle`.
    function endsWith(bytes memory subject, bytes memory needle) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(needle)
            let subjectLen := mload(subject)
            result := and(
                iszero(gt(n, subjectLen)),
                eq(
                    keccak256(add(add(subject, 0x20), sub(subjectLen, n)), n),
                    keccak256(add(needle, 0x20), n)
                )
            )
        }
    }

    /// @dev Repeats `subject` `times` number of times.
    function repeat(bytes memory subject, uint256 times) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLen := mload(subject)
            if iszero(or(iszero(times), iszero(subjectLen))) {
                result := mload(0x40)
                subject := add(subject, 0x20)
                let o := add(result, 0x20)
                for {} 1 {} {
                    let i := 0
                    for {} 1 {} {
                        mstore(add(o, i), mload(add(subject, i)))
                        i := add(i, 0x20)
                        if iszero(lt(i, subjectLen)) { break }
                    }
                    o := add(o, subjectLen)
                    times := sub(times, 1)
                    if iszero(times) { break }
                }
                mstore(o, 0)
                let n := sub(o, add(result, 0x20))
                mstore(0x40, add(o, 0x20))
                mstore(result, n)
            }
        }
    }

    /// @dev Slices `subject` from `start` to `end`.
    function slice(bytes memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLen := mload(subject)
            if iszero(gt(end, subjectLen)) {
                end := subjectLen
            }
            if iszero(gt(start, subjectLen)) {
                start := subjectLen
            }
            if lt(start, end) {
                result := mload(0x40)
                let n := sub(end, start)
                let i := add(subject, add(0x20, start))
                let o := add(result, 0x20)
                for {} 1 {} {
                    mstore(o, mload(i))
                    i := add(i, 0x20)
                    o := add(o, 0x20)
                    if iszero(lt(o, add(add(result, 0x20), n))) { break }
                }
                mstore(add(o, sub(n, sub(o, add(result, 0x20)))), 0)
                mstore(0x40, add(result, add(n, 0x40)))
                mstore(result, n)
            }
        }
    }

    /// @dev Slices `subject` from `start` to the end.
    function slice(bytes memory subject, uint256 start) internal pure returns (bytes memory result) {
        result = slice(subject, start, type(uint256).max);
    }

    /// @dev Slices calldata `subject` from `start` to `end`.
    function sliceCalldata(bytes calldata subject, uint256 start, uint256 end)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLen := subject.length
            if iszero(gt(end, subjectLen)) {
                end := subjectLen
            }
            if iszero(gt(start, subjectLen)) {
                start := subjectLen
            }
            result.offset := add(subject.offset, start)
            result.length := mul(lt(start, end), sub(end, start))
        }
    }

    /// @dev Slices calldata `subject` from `start` to the end.
    function sliceCalldata(bytes calldata subject, uint256 start)
        internal
        pure
        returns (bytes calldata result)
    {
        result = sliceCalldata(subject, start, type(uint256).max);
    }

    /// @dev Truncates `subject` to `n` bytes.
    function truncate(bytes memory subject, uint256 n) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := subject
            if lt(n, mload(result)) {
                mstore(result, n)
            }
        }
    }

    /// @dev Truncates calldata `subject` to `n` bytes.
    function truncatedCalldata(bytes calldata subject, uint256 n)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result.offset := subject.offset
            result.length := xor(n, mul(xor(n, subject.length), lt(subject.length, n)))
        }
    }

    /// @dev Finds the indices of all occurrences of `needle` in `subject`.
    function indicesOf(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let needleLen := mload(needle)
            let subjectLen := mload(subject)
            if iszero(gt(needleLen, subjectLen)) {
                result := mload(0x40)
                let i := add(subject, 0x20)
                let o := add(result, 0x20)
                let end := add(sub(add(subject, 0x20), needleLen), subjectLen)
                let h := 0
                if iszero(lt(needleLen, 0x20)) {
                    h := keccak256(add(needle, 0x20), needleLen)
                }
                let w := mload(add(needle, 0x20))
                for {} 1 {} {
                    if iszero(lt(i, end)) { break }
                    if iszero(shr(128, xor(mload(i), w))) {
                        if iszero(or(lt(needleLen, 0x20), eq(keccak256(i, needleLen), h))) {
                            mstore(o, sub(i, add(subject, 0x20)))
                            o := add(o, 0x20)
                            i := add(i, needleLen)
                            if iszero(lt(i, end)) { break }
                            continue
                        }
                    }
                    i := add(i, 1)
                }
                mstore(result, shr(5, sub(o, add(result, 0x20))))
                mstore(0x40, o)
            }
        }
    }

    /// @dev Splits `subject` by `delimiter`.
    function split(bytes memory subject, bytes memory delimiter)
        internal
        pure
        returns (bytes[] memory result)
    {
        uint256[] memory indices = indicesOf(subject, delimiter);
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(0x1f)
            let indexLen := mload(indices)
            let subjectLen := mload(subject)
            let delimiterLen := mload(delimiter)
            result := mload(0x40)
            let r := add(result, 0x20)
            let s := add(subject, 0x20)
            let p := s
            let o := add(r, shl(5, add(indexLen, 1)))
            if iszero(delimiterLen) {
                for { let i := 0 } 1 {} {
                    mstore(r, o)
                    let n := 1
                    mstore(o, n)
                    mcopy(add(o, 0x20), add(s, i), n)
                    o := and(add(add(o, 0x40), n), w)
                    r := add(r, 0x20)
                    i := add(i, 1)
                    if iszero(lt(i, subjectLen)) { break }
                }
                mstore(result, sub(shr(5, sub(r, add(result, 0x20))), 1))
                mstore(0x40, o)
                leave
            }
            for { let i := 0 } 1 {} {
                let q := add(s, mload(add(add(indices, 0x20), shl(5, i))))
                mstore(r, o)
                let n := sub(q, p)
                mstore(o, n)
                mcopy(add(o, 0x20), p, n)
                o := and(add(add(o, 0x40), n), w)
                r := add(r, 0x20)
                p := add(q, delimiterLen)
                i := add(i, 1)
                if iszero(lt(i, indexLen)) { break }
            }
            mstore(r, o)
            let n := sub(add(s, subjectLen), p)
            mstore(o, n)
            mcopy(add(o, 0x20), p, n)
            o := and(add(add(o, 0x40), n), w)
            mstore(result, add(indexLen, 1))
            mstore(0x40, o)
        }
    }

    /// @dev Concatenates `a` and `b`.
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let aLen := mload(a)
            let o := add(result, 0x20)
            let i := add(a, 0x20)
            for {} 1 {} {
                mstore(o, mload(i))
                i := add(i, 0x20)
                o := add(o, 0x20)
                if iszero(lt(i, add(add(a, 0x20), aLen))) { break }
            }
            let bLen := mload(b)
            i := add(b, 0x20)
            for {} 1 {} {
                mstore(o, mload(i))
                i := add(i, 0x20)
                o := add(o, 0x20)
                if iszero(lt(i, add(add(b, 0x20), bLen))) { break }
            }
            let n := add(aLen, bLen)
            mstore(add(result, add(0x20, n)), 0)
            mstore(result, n)
            mstore(0x40, add(result, add(n, 0x40)))
        }
    }

    /// @dev Returns true if `a` equals `b`.
    function eq(bytes memory a, bytes memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Returns true if `a` equals `b`.
    function eqs(bytes memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := not(shr(shl(3, mload(a)), not(0)))
            let x := xor(mload(add(a, 0x20)), b)
            result := iszero(or(iszero(lt(mload(a), 0x21)), and(x, m)))
        }
    }

    /// @dev Compares `a` and `b`.
    function cmp(bytes memory a, bytes memory b) internal pure returns (int256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLen := mload(a)
            let bLen := mload(b)
            let n := add(and(aLen, not(0x1f)), 0x20)
            let i := 0x20
            for {} 1 {} {
                if iszero(lt(i, n)) { break }
                let aWord := mload(add(a, i))
                let bWord := mload(add(b, i))
                if xor(aWord, bWord) {
                    result := or(shl(1, gt(aWord, bWord)), 1)
                    if iszero(gt(aWord, bWord)) {
                        result := not(0)
                    }
                    leave
                }
                i := add(i, 0x20)
            }
            let m := not(shr(shl(3, and(aLen, 0x1f)), not(0)))
            let aWord := and(mload(add(a, n)), m)
            let bWord := and(mload(add(b, n)), m)
            if xor(aWord, bWord) {
                result := or(shl(1, gt(aWord, bWord)), 1)
                if iszero(gt(aWord, bWord)) {
                    result := not(0)
                }
                leave
            }
            result := sub(gt(aLen, bLen), lt(aLen, bLen))
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(bytes memory a) internal pure {
        assembly {
            let returnOffset := sub(a, 0x20)
            let returnSize := add(mload(a), 0x40)
            mstore(add(returnSize, returnOffset), 0)
            mstore(returnOffset, 0x20)
            return(returnOffset, and(add(returnSize, 0x1f), not(0x1f)))
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(bytes[] memory a) internal pure {
        assembly {
            let returnOffset := sub(a, 0x20)
            let returnSize := add(mload(a), 0x40)
            mstore(add(returnSize, returnOffset), 0)
            mstore(returnOffset, 0x20)
            return(returnOffset, and(add(returnSize, 0x1f), not(0x1f)))
        }
    }

    /// @dev Loads a bytes32 from `a` at `offset`.
    function load(bytes memory a, uint256 offset) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), offset))
        }
    }

    /// @dev Loads a bytes32 from calldata `a` at `offset`.
    function loadCalldata(bytes calldata a, uint256 offset) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := calldataload(add(a.offset, offset))
        }
    }

    /// @dev Returns an empty calldata bytes.
    function emptyCalldata() internal pure returns (bytes calldata result) {
        /// @solidity memory-safe-assembly
        assembly {
            result.length := 0
        }
    }
}