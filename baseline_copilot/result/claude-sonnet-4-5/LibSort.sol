// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for efficient array sorting and manipulation operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibSort.sol)
library LibSort {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INSERTION SORT                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Performs an insertion sort on an array of unsigned integers in-place.
    /// @dev This function uses low-level assembly for optimization and memory safety.
    /// The array is sorted in ascending order.
    function insertionSort(uint256[] memory a) internal pure {
        assembly ("memory-safe") {
            let n := mload(a)
            mstore(a, 0)
            let h := add(a, shl(5, n))
            let w := not(0)
            for { let i := add(a, 0x20) } 1 {} {
                i := add(i, 0x20)
                if gt(i, h) { break }
                let k := mload(i)
                let j := i
                let v := mload(sub(j, 0x20))
                if iszero(gt(v, k)) { continue }
                for {} 1 {} {
                    mstore(j, v)
                    j := sub(j, 0x20)
                    v := mload(sub(j, 0x20))
                    if iszero(gt(v, k)) { break }
                }
                mstore(j, k)
            }
            mstore(a, n)
        }
    }

    /// @notice Performs an insertion sort on an array of signed integers in-place.
    /// @dev This function uses low-level assembly for optimization and memory safety.
    /// The array is sorted in ascending order.
    function insertionSort(int256[] memory a) internal pure {
        _flipSign(a);
        insertionSort(_toUints(a));
        _flipSign(a);
    }

    /// @notice Performs an insertion sort on an array of addresses in-place.
    /// @dev This function uses low-level assembly for optimization and memory safety.
    /// The array is sorted in ascending order.
    function insertionSort(address[] memory a) internal pure {
        insertionSort(_toUints(a));
    }

    /// @notice Performs an insertion sort on an array of bytes32 in-place.
    /// @dev This function uses low-level assembly for optimization and memory safety.
    /// The array is sorted in ascending order.
    function insertionSort(bytes32[] memory a) internal pure {
        insertionSort(_toUints(a));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         SORT                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Sorts an array of unsigned integers in ascending order using a combination of insertion sort and quicksort.
    /// @dev The function uses inline assembly for optimized performance and memory safety.
    /// @param a The array of unsigned integers to be sorted.
    function sort(uint256[] memory a) internal pure {
        assembly ("memory-safe") {
            let n := mload(a)
            if iszero(lt(n, 2)) {
                let w := not(0)
                let s := 0x20
                let u := mul(s, lt(0xffffffffffffffff, n))
                mstore(a, u)

                let h := add(a, shl(5, n))

                for { let e := h } iszero(u) {} {
                    let p := a
                    e := add(e, w)
                    for { let k := add(a, s) } 1 {} {
                        if iszero(lt(k, e)) { break }
                        let t := add(k, s)
                        let c := mload(k)
                        let j := k
                        for {} 1 {} {
                            let v := mload(j)
                            let g := gt(v, c)
                            if iszero(g) { break }
                            mstore(add(j, s), v)
                            j := add(j, w)
                            if iszero(gt(j, p)) { break }
                        }
                        mstore(add(j, s), c)
                        k := t
                    }
                    break
                }

                for {} iszero(u) {} {
                    let z := add(a, s)
                    let y := add(a, shl(5, n))
                    let x := add(z, shl(4, n))
                    let j := z
                    let k := y
                    for {} 1 {} {
                        if iszero(lt(j, x)) {
                            let t := k
                            k := j
                            j := t
                            x := y
                        }
                        let p := mload(j)
                        let t := add(j, s)
                        for {} lt(t, x) {} {
                            let q := mload(t)
                            let g := gt(q, p)
                            let l := xor(t, mul(xor(t, j), g))
                            j := l
                            p := xor(p, mul(xor(p, q), g))
                            t := add(t, s)
                        }
                        mstore(k, p)
                        k := add(k, s)
                        if iszero(lt(k, y)) { break }
                    }
                    break
                }

                for { let l := 0 } 1 {} {
                    mstore(a, n)

                    let c := shl(1, iszero(iszero(n)))
                    let f := 0
                    let o := h
                    for {} 1 {} {
                        o := sub(o, s)
                        let b := mload(o)
                        let d := mload(a)
                        f := or(f, xor(b, d))
                        if iszero(gt(o, a)) { break }
                        c := add(c, lt(d, b))
                    }

                    if iszero(and(iszero(c), f)) {
                        if iszero(or(c, u)) {
                            let i := a
                            let j := h
                            for {} 1 {} {
                                let t := mload(i)
                                mstore(i, mload(j))
                                mstore(j, t)
                                i := add(i, s)
                                j := sub(j, s)
                                if iszero(lt(i, j)) { break }
                            }
                        }
                        break
                    }
                    mstore(a, 0)

                    function swap(a_, b_) -> _a, _b {
                        _a := b_
                        _b := a_
                    }

                    function mswap(i_, j_, s_) {
                        let t := mload(i_)
                        mstore(i_, mload(j_))
                        mstore(j_, t)
                    }

                    function sortInner(l_, r_) {
                        for {} lt(add(l_, 0x20), r_) {} {
                            if iszero(lt(add(l_, 0xa0), r_)) {
                                let e := r_
                                for { let k := add(l_, 0x20) } 1 {} {
                                    if iszero(lt(k, e)) { break }
                                    let j := k
                                    let v := mload(j)
                                    let u := mload(add(j, w))
                                    if iszero(gt(u, v)) { continue }
                                    for {} 1 {} {
                                        mstore(j, u)
                                        j := add(j, w)
                                        u := mload(add(j, w))
                                        if iszero(gt(u, v)) { break }
                                    }
                                    mstore(j, v)
                                    k := add(k, 0x20)
                                }
                                break
                            }

                            let m := shr(1, add(l_, r_))
                            m := and(m, w)

                            let i := l_
                            let j := r_

                            let p := mload(m)
                            p := xor(p, mul(xor(p, mload(l_)), gt(mload(l_), p)))
                            p := xor(p, mul(xor(p, mload(r_)), gt(p, mload(r_))))

                            for {} 1 {} {
                                for {} lt(mload(i), p) {} {
                                    i := add(i, s)
                                }
                                for {} gt(mload(j), p) {} {
                                    j := add(j, w)
                                }
                                if iszero(lt(i, j)) { break }
                                mswap(i, j, s)
                                i, j := swap(add(i, s), add(j, w))
                            }

                            if iszero(lt(l_, j)) {
                                let d := eq(l_, j)
                                j := add(j, mul(s, d))
                                l_ := add(l_, mul(s, d))
                            }
                            sortInner(l_, j)
                            l_ := i
                        }
                    }
                    sortInner(a, h)
                    break
                }
            }
        }
    }

    /// @notice Sorts an array of signed integers in ascending order using a combination of insertion sort and quicksort.
    /// @dev The function uses inline assembly for optimized performance and memory safety.
    /// @param a The array of signed integers to be sorted.
    function sort(int256[] memory a) internal pure {
        _flipSign(a);
        sort(_toUints(a));
        _flipSign(a);
    }

    /// @notice Sorts an array of addresses in ascending order using a combination of insertion sort and quicksort.
    /// @dev The function uses inline assembly for optimized performance and memory safety.
    /// @param a The array of addresses to be sorted.
    function sort(address[] memory a) internal pure {
        sort(_toUints(a));
    }

    /// @notice Sorts an array of bytes32 in ascending order using a combination of insertion sort and quicksort.
    /// @dev The function uses inline assembly for optimized performance and memory safety.
    /// @param a The array of bytes32 to be sorted.
    function sort(bytes32[] memory a) internal pure {
        sort(_toUints(a));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UNIQUIFY SORTED                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Removes duplicate elements from a sorted array in-place.
    /// @dev This function assumes that the input array `a` is already sorted.
    /// It uses low-level assembly to optimize memory operations and ensure gas efficiency.
    /// @param a The sorted array of uint256 values to be uniquified.
    function uniquifySorted(uint256[] memory a) internal pure {
        assembly ("memory-safe") {
            let n := mload(a)
            if gt(n, 1) {
                let x := add(a, 0x20)
                let y := add(a, 0x40)
                let e := add(a, shl(5, n))
                for {} 1 {} {
                    if eq(mload(x), mload(y)) {
                        y := add(y, 0x20)
                        if eq(y, e) { break }
                        continue
                    }
                    x := add(x, 0x20)
                    mstore(x, mload(y))
                    y := add(y, 0x20)
                    if eq(y, e) { break }
                }
                mstore(a, shr(5, sub(x, a)))
            }
        }
    }

    /// @notice Removes duplicate elements from a sorted array in-place.
    /// @dev This function assumes that the input array `a` is already sorted.
    /// @param a The sorted array of int256 values to be uniquified.
    function uniquifySorted(int256[] memory a) internal pure {
        uniquifySorted(_toUints(a));
    }

    /// @notice Removes duplicate elements from a sorted array in-place.
    /// @dev This function assumes that the input array `a` is already sorted.
    /// @param a The sorted array of address values to be uniquified.
    function uniquifySorted(address[] memory a) internal pure {
        uniquifySorted(_toUints(a));
    }

    /// @notice Removes duplicate elements from a sorted array in-place.
    /// @dev This function assumes that the input array `a` is already sorted.
    /// @param a The sorted array of bytes32 values to be uniquified.
    function uniquifySorted(bytes32[] memory a) internal pure {
        uniquifySorted(_toUints(a));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     SEARCH SORTED                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Searches for a specific value (`needle`) in a sorted array (`a`) and returns whether it was found and its index.
    /// @param a The sorted array of uint256 values to search within.
    /// @param needle The uint256 value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    /// @return index The index of the found value in the array. If not found, this will be the position where the value could be inserted to maintain the sorted order.
    function searchSorted(uint256[] memory a, uint256 needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        return _searchSorted(a, needle, 0);
    }

    /// @notice Searches for a specific value (`needle`) in a sorted array (`a`) and returns whether it was found and its index.
    /// @param a The sorted array of int256 values to search within.
    /// @param needle The int256 value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    /// @return index The index of the found value in the array.
    function searchSorted(int256[] memory a, int256 needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        return _searchSorted(_toUints(a), uint256(needle), 1 << 255);
    }

    /// @notice Searches for a specific value (`needle`) in a sorted array (`a`) and returns whether it was found and its index.
    /// @param a The sorted array of address values to search within.
    /// @param needle The address value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    /// @return index The index of the found value in the array.
    function searchSorted(address[] memory a, address needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        return _searchSorted(_toUints(a), uint256(uint160(needle)), 0);
    }

    /// @notice Searches for a specific value (`needle`) in a sorted array (`a`) and returns whether it was found and its index.
    /// @param a The sorted array of bytes32 values to search within.
    /// @param needle The bytes32 value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    /// @return index The index of the found value in the array.
    function searchSorted(bytes32[] memory a, bytes32 needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        return _searchSorted(_toUints(a), uint256(needle), 0);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       IN SORTED                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Checks if a given value (`needle`) exists in a sorted array (`a`).
    /// @param a The sorted array of uint256 values to search within.
    /// @param needle The uint256 value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    function inSorted(uint256[] memory a, uint256 needle) internal pure returns (bool found) {
        (found,) = searchSorted(a, needle);
    }

    /// @notice Checks if a given value (`needle`) exists in a sorted array (`a`).
    /// @param a The sorted array of int256 values to search within.
    /// @param needle The int256 value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    function inSorted(int256[] memory a, int256 needle) internal pure returns (bool found) {
        (found,) = searchSorted(a, needle);
    }

    /// @notice Checks if a given value (`needle`) exists in a sorted array (`a`).
    /// @param a The sorted array of address values to search within.
    /// @param needle The address value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    function inSorted(address[] memory a, address needle) internal pure returns (bool found) {
        (found,) = searchSorted(a, needle);
    }

    /// @notice Checks if a given value (`needle`) exists in a sorted array (`a`).
    /// @param a The sorted array of bytes32 values to search within.
    /// @param needle The bytes32 value to search for in the array.
    /// @return found A boolean indicating whether the value was found in the array.
    function inSorted(bytes32[] memory a, bytes32 needle) internal pure returns (bool found) {
        (found,) = searchSorted(a, needle);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         REVERSE                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Reverses the order of elements in a given array in-place.
    /// @dev This function uses low-level assembly to efficiently reverse the array.
    /// @param a The array of uint256 values to be reversed.
    function reverse(uint256[] memory a) internal pure {
        assembly ("memory-safe") {
            if iszero(lt(mload(a), 2)) {
                let s := 0x20
                let w := not(0)
                let h := add(a, shl(5, mload(a)))
                for { a := add(a, s) } 1 {} {
                    let t := mload(a)
                    mstore(a, mload(h))
                    mstore(h, t)
                    h := add(h, w)
                    a := add(a, s)
                    if iszero(lt(a, h)) { break }
                }
            }
        }
    }

    /// @notice Reverses the order of elements in a given array in-place.
    /// @dev This function uses low-level assembly to efficiently reverse the array.
    /// @param a The array of int256 values to be reversed.
    function reverse(int256[] memory a) internal pure {
        reverse(_toUints(a));
    }

    /// @notice Reverses the order of elements in a given array in-place.
    /// @dev This function uses low-level assembly to efficiently reverse the array.
    /// @param a The array of address values to be reversed.
    function reverse(address[] memory a) internal pure {
        reverse(_toUints(a));
    }

    /// @notice Reverses the order of elements in a given array in-place.
    /// @dev This function uses low-level assembly to efficiently reverse the array.
    /// @param a The array of bytes32 values to be reversed.
    function reverse(bytes32[] memory a) internal pure {
        reverse(_toUints(a));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          COPY                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Copies an array of uint256 values in memory using low-level assembly for efficiency.
    /// @param a The input array of uint256 values to be copied.
    /// @return result A new array containing the copied values.
    function copy(uint256[] memory a) internal pure returns (uint256[] memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            let n := add(shl(5, mload(a)), 0x20)
            let o := add(result, n)
            mstore(0x40, o)
            for { let i := a } 1 {} {
                mstore(result, mload(i))
                result := add(result, 0x20)
                i := add(i, 0x20)
                if eq(result, o) { break }
            }
            result := mload(0x40)
            mstore(0x40, o)
        }
    }

    /// @notice Copies an array of int256 values in memory using low-level assembly for efficiency.
    /// @param a The input array of int256 values to be copied.
    /// @return result A new array containing the copied values.
    function copy(int256[] memory a) internal pure returns (int256[] memory result) {
        result = _toInts(copy(_toUints(a)));
    }

    /// @notice Copies an array of address values in memory using low-level assembly for efficiency.
    /// @param a The input array of address values to be copied.
    /// @return result A new array containing the copied values.
    function copy(address[] memory a) internal pure returns (address[] memory result) {
        result = _toAddresses(copy(_toUints(a)));
    }

    /// @notice Copies an array of bytes32 values in memory using low-level assembly for efficiency.
    /// @param a The input array of bytes32 values to be copied.
    /// @return result A new array containing the copied values.
    function copy(bytes32[] memory a) internal pure returns (bytes32[] memory result) {
        result = _toBytes32s(copy(_toUints(a)));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       IS SORTED                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Checks if an array of unsigned integers is sorted in ascending order.
    /// @dev This function uses low-level assembly to optimize the sorting check.
    /// @param a The array of unsigned integers to check.
    /// @return result A boolean indicating whether the array is sorted (true) or not (false).
    function isSorted(uint256[] memory a) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let e := add(a, shl(5, mload(a)))
                let u := mload(add(a, 0x20))
                for { let i := add(a, 0x40) } 1 {} {
                    let t := mload(i)
                    result := iszero(gt(u, t))
                    u := t
                    i := add(i, 0x20)
                    if or(iszero(result), eq(i, e)) { break }
                }
            }
        }
    }

    /// @notice Checks if an array of signed integers is sorted in ascending order.
    /// @dev This function uses low-level assembly to optimize the sorting check.
    /// @param a The array of signed integers to check.
    /// @return result A boolean indicating whether the array is sorted (true) or not (false).
    function isSorted(int256[] memory a) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let e := add(a, shl(5, mload(a)))
                let u := mload(add(a, 0x20))
                u := add(u, shl(255, 1))
                for { let i := add(a, 0x40) } 1 {} {
                    let t := add(mload(i), shl(255, 1))
                    result := iszero(gt(u, t))
                    u := t
                    i := add(i, 0x20)
                    if or(iszero(result), eq(i, e)) { break }
                }
            }
        }
    }

    /// @notice Checks if an array of addresses is sorted in ascending order.
    /// @dev This function uses low-level assembly to optimize the sorting check.
    /// @param a The array of addresses to check.
    /// @return result A boolean indicating whether the array is sorted (true) or not (false).
    function isSorted(address[] memory a) internal pure returns (bool result) {
        result = isSorted(_toUints(a));
    }

    /// @notice Checks if an array of bytes32 is sorted in ascending order.
    /// @dev This function uses low-level assembly to optimize the sorting check.
    /// @param a The array of bytes32 to check.
    /// @return result A boolean indicating whether the array is sorted (true) or not (false).
    function isSorted(bytes32[] memory a) internal pure returns (bool result) {
        result = isSorted(_toUints(a));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 IS SORTED AND UNIQUIFIED                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Checks if a given array of uint256 is sorted in ascending order and contains no duplicate elements.
    /// @param a The array of uint256 values to be checked.
    /// @return result A boolean indicating whether the array is sorted and uniquified (true) or not (false).
    function isSortedAndUniquified(uint256[] memory a) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let e := add(a, shl(5, mload(a)))
                let u := mload(add(a, 0x20))
                for { let i := add(a, 0x40) } 1 {} {
                    let t := mload(i)
                    result := lt(u, t)
                    u := t
                    i := add(i, 0x20)
                    if or(iszero(result), eq(i, e)) { break }
                }
            }
        }
    }

    /// @notice Checks if a given array of int256 is sorted in ascending order and contains no duplicate elements.
    /// @param a The array of int256 values to be checked.
    /// @return result A boolean indicating whether the array is sorted and uniquified (true) or not (false).
    function isSortedAndUniquified(int256[] memory a) internal pure returns (bool result) {
        assembly ("memory-safe") {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let e := add(a, shl(5, mload(a)))
                let u := mload(add(a, 0x20))
                u := add(u, shl(255, 1))
                for { let i := add(a, 0x40) } 1 {} {
                    let t := add(mload(i), shl(255, 1))
                    result := lt(u, t)
                    u := t
                    i := add(i, 0x20)
                    if or(iszero(result), eq(i, e)) { break }
                }
            }
        }
    }

    /// @notice Checks if a given array of address is sorted in ascending order and contains no duplicate elements.
    /// @param a The array of address values to be checked.
    /// @return result A boolean indicating whether the array is sorted and uniquified (true) or not (false).
    function isSortedAndUniquified(address[] memory a) internal pure returns (bool result) {
        result = isSortedAndUniquified(_toUints(a));
    }

    /// @notice Checks if a given array of bytes32 is sorted in ascending order and contains no duplicate elements.
    /// @param a The array of bytes32 values to be checked.
    /// @return result A boolean indicating whether the array is sorted and uniquified (true) or not (false).
    function isSortedAndUniquified(bytes32[] memory a) internal pure returns (bool result) {
        result = isSortedAndUniquified(_toUints(a));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       DIFFERENCE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Computes the difference between two arrays of unsigned integers.
    /// @param a The first array of unsigned integers.
    /// @param b The second array of unsigned integers.
    /// @return c An array containing the elements that are in `a` but not in `b`.
    function difference(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        c = _difference(a, b, 0);
    }

    /// @notice Computes the difference between two arrays of signed integers.
    /// @param a The first array of signed integers.
    /// @param b The second array of signed integers.
    /// @return c An array containing the elements that are in `a` but not in `b`.
    function difference(int256[] memory a, int256[] memory b)
        internal
        pure
        returns (int256[] memory c)
    {
        c = _toInts(_difference(_toUints(a), _toUints(b), 1 << 255));
    }

    /// @notice Computes the difference between two arrays of addresses.
    /// @param a The first array of addresses.
    /// @param b The second array of addresses.
    /// @return c An array containing the elements that are in `a` but not in `b`.
    function difference(address[] memory a, address[] memory b)
        internal
        pure
        returns (address[] memory c)
    {
        c = _toAddresses(_difference(_toUints(a), _toUints(b), 0));
    }

    /// @notice Computes the difference between two arrays of bytes32.
    /// @param a The first array of bytes32.
    /// @param b The second array of bytes32.
    /// @return c An array containing the elements that are in `a` but not in `b`.
    function difference(bytes32[] memory a, bytes32[] memory b)
        internal
        pure
        returns (bytes32[] memory c)
    {
        c = _toBytes32s(_difference(_toUints(a), _toUints(b), 0));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INTERSECTION                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Computes the intersection of two arrays of unsigned integers.
    /// @param a The first array of unsigned integers.
    /// @param b The second array of unsigned integers.
    /// @return c An array containing the common elements between `a` and `b`.
    function intersection(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        c = _intersection(a, b, 0);
    }

    /// @notice Computes the intersection of two arrays of signed integers.
    /// @param a The first array of signed integers.
    /// @param b The second array of signed integers.
    /// @return c An array containing the common elements between `a` and `b`.
    function intersection(int256[] memory a, int256[] memory b)
        internal
        pure
        returns (int256[] memory c)
    {
        c = _toInts(_intersection(_toUints(a), _toUints(b), 1 << 255));
    }

    /// @notice Computes the intersection of two arrays of addresses.
    /// @param a The first array of addresses.
    /// @param b The second array of addresses.
    /// @return c An array containing the common elements between `a` and `b`.
    function intersection(address[] memory a, address[] memory b)
        internal
        pure
        returns (address[] memory c)
    {
        c = _toAddresses(_intersection(_toUints(a), _toUints(b), 0));
    }

    /// @notice Computes the intersection of two arrays of bytes32.
    /// @param a The first array of bytes32.
    /// @param b The second array of bytes32.
    /// @return c An array containing the common elements between `a` and `b`.
    function intersection(bytes32[] memory a, bytes32[] memory b)
        internal
        pure
        returns (bytes32[] memory c)
    {
        c = _toBytes32s(_intersection(_toUints(a), _toUints(b), 0));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          UNION                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Computes the union of two arrays of unsigned integers.
    /// @param a The first array of unsigned integers.
    /// @param b The second array of unsigned integers.
    /// @return c The resulting array containing the union of `a` and `b`.
    function union(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        c = _union(a, b, 0);
    }

    /// @notice Computes the union of two arrays of signed integers.
    /// @param a The first array of signed integers.
    /// @param b The second array of signed integers.
    /// @return c The resulting array containing the union of `a` and `b`.
    function union(int256[] memory a, int256[] memory b)
        internal
        pure
        returns (int256[] memory c)
    {
        c = _toInts(_union(_toUints(a), _toUints(b), 1 << 255));
    }

    /// @notice Computes the union of two arrays of addresses.
    /// @param a The first array of addresses.
    /// @param b The second array of addresses.
    /// @return c The resulting array containing the union of `a` and `b`.
    function union(address[] memory a, address[] memory b)
        internal
        pure
        returns (address[] memory c)
    {
        c = _toAddresses(_union(_toUints(a), _toUints(b), 0));
    }

    /// @notice Computes the union of two arrays of bytes32.
    /// @param a The first array of bytes32.
    /// @param b The second array of bytes32.
    /// @return c The resulting array containing the union of `a` and `b`.
    function union(bytes32[] memory a, bytes32[] memory b)
        internal
        pure
        returns (bytes32[] memory c)
    {
        c = _toBytes32s(_union(_toUints(a), _toUints(b), 0));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CLEAN                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Cleans an array of addresses by masking out non-address bits.
    /// @param a An array of addresses to be cleaned.
    function clean(address[] memory a) internal pure {
        assembly ("memory-safe") {
            let m := shr(96, not(0))
            let e := add(a, shl(5, mload(a)))
            for {} iszero(eq(a, e)) {} {
                a := add(a, 0x20)
                mstore(a, and(m, mload(a)))
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PRIVATE HELPERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Converts an array of `int256` to an array of `uint256`.
    /// @param a The input array of `int256` values.
    /// @return casted The resulting array of `uint256` values.
    function _toUints(int256[] memory a) private pure returns (uint256[] memory casted) {
        assembly ("memory-safe") {
            casted := a
        }
    }

    /// @notice Converts an array of `address` to an array of `uint256`.
    /// @param a The input array of `address` values.
    /// @return casted The resulting array of `uint256` values.
    function _toUints(address[] memory a) private pure returns (uint256[] memory casted) {
        assembly ("memory-safe") {
            casted := a
        }
    }

    /// @notice Converts an array of `bytes32` to an array of `uint256`.
    /// @param a The input array of `bytes32` values.
    /// @return casted The resulting array of `uint256` values.
    function _toUints(bytes32[] memory a) private pure returns (uint256[] memory casted) {
        assembly ("memory-safe") {
            casted := a
        }
    }

    /// @notice Converts an array of `uint256` to an array of `int256` using low-level assembly.
    /// @param a The input array of `uint256` values.
    /// @return casted The resulting array of `int256` values.
    function _toInts(uint256[] memory a) private pure returns (int256[] memory casted) {
        assembly ("memory-safe") {
            casted := a
        }
    }

    /// @notice Converts an array of uint256 values to an array of addresses.
    /// @dev This function uses inline assembly to perform the conversion.
    /// @param a The input array of uint256 values.
    /// @return casted The resulting array of addresses.
    function _toAddresses(uint256[] memory a) private pure returns (address[] memory casted) {
        assembly ("memory-safe") {
            casted := a
        }
    }

    /// @notice Converts an array of uint256 values to an array of bytes32 values.
    /// @dev This function uses inline assembly to perform the conversion efficiently.
    /// @param a The input array of uint256 values.
    /// @return casted The resulting array of bytes32 values.
    function _toBytes32s(uint256[] memory a) private pure returns (bytes32[] memory casted) {
        assembly ("memory-safe") {
            casted := a
        }
    }

    /// @notice Private helper function that flips the sign of all integers in the given array.
    /// @param a The array of int256 values to flip signs.
    function _flipSign(int256[] memory a) private pure {
        assembly ("memory-safe") {
            let w := shl(255, 1)
            let e := add(a, shl(5, mload(a)))
            for {} iszero(eq(a, e)) {} {
                a := add(a, 0x20)
                mstore(a, add(mload(a), w))
            }
        }
    }

    /// @notice Performs a binary search on a sorted array to find a specific value.
    /// @param a The sorted array to search in.
    /// @param needle The value to search for.
    /// @param signed A signed offset to apply during comparison.
    /// @return found Boolean indicating whether the value was found.
    /// @return index The index of the found value, or 0 if not found.
    function _searchSorted(uint256[] memory a, uint256 needle, uint256 signed)
        private
        pure
        returns (bool found, uint256 index)
    {
        assembly ("memory-safe") {
            let l := 0
            let r := mload(a)
            needle := add(needle, signed)
            for {} 1 {} {
                index := shr(1, add(l, r))
                if iszero(lt(l, r)) { break }
                let t := add(mload(add(a, shl(5, index))), signed)
                let c := lt(t, needle)
                r := add(mul(index, iszero(c)), mul(r, c))
                l := add(mul(index, c), mul(l, iszero(c)))
                l := add(l, c)
            }
            found := eq(add(mload(add(a, shl(5, index))), signed), needle)
            found := and(found, lt(index, mload(a)))
        }
    }

    /// @notice Computes the difference between two arrays of unsigned integers (`a` and `b`) based on a signed flag.
    /// @param a The first array of unsigned integers.
    /// @param b The second array of unsigned integers.
    /// @param signed A flag to determine the comparison logic (e.g., signed or unsigned comparison).
    /// @return c A new array containing the difference between `a` and `b`.
    function _difference(uint256[] memory a, uint256[] memory b, uint256 signed)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly ("memory-safe") {
            let s := 0x20
            let na := mload(a)
            let nb := mload(b)
            c := mload(0x40)
            let o := add(c, s)
            a := add(a, s)
            b := add(b, s)
            let t := 0
            let u := signed
            for { let ea := add(a, shl(5, na)) } iszero(eq(a, ea)) {} {
                let av := add(mload(a), u)
                for { let eb := add(add(b, t), shl(5, nb)) } iszero(eq(add(b, t), eb)) {} {
                    let bv := add(mload(add(b, t)), u)
                    if iszero(lt(bv, av)) { break }
                    t := add(t, s)
                }
                let d := iszero(eq(av, add(mload(add(b, t)), u)))
                d := or(d, eq(t, shl(5, nb)))
                mstore(o, mload(a))
                o := add(o, mul(s, d))
                a := add(a, s)
            }
            mstore(c, shr(5, sub(sub(o, c), s)))
            mstore(0x40, o)
        }
    }

    /// @notice Computes the intersection of two sorted arrays `a` and `b` with an optional signed offset.
    /// @param a The first sorted array of uint256 values.
    /// @param b The second sorted array of uint256 values.
    /// @param signed An optional signed offset to adjust the comparison logic.
    /// @return c A new array containing the intersection of `a` and `b`.
    function _intersection(uint256[] memory a, uint256[] memory b, uint256 signed)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly ("memory-safe") {
            let s := 0x20
            let na := mload(a)
            let nb := mload(b)
            c := mload(0x40)
            let o := add(c, s)
            a := add(a, s)
            b := add(b, s)
            let t := 0
            let u := signed
            for { let ea := add(a, shl(5, na)) } iszero(eq(a, ea)) {} {
                let av := add(mload(a), u)
                for { let eb := add(add(b, t), shl(5, nb)) } iszero(eq(add(b, t), eb)) {} {
                    let bv := add(mload(add(b, t)), u)
                    if iszero(lt(bv, av)) { break }
                    t := add(t, s)
                }
                let d := iszero(eq(av, add(mload(add(b, t)), u)))
                d := or(d, eq(t, shl(5, nb)))
                mstore(o, mload(a))
                o := add(o, mul(s, iszero(d)))
                a := add(a, s)
            }
            mstore(c, shr(5, sub(sub(o, c), s)))
            mstore(0x40, o)
        }
    }

    /// @notice Computes the union of two sorted arrays `a` and `b` with optional signed comparison.
    /// @param a The first sorted array of uint256 values.
    /// @param b The second sorted array of uint256 values.
    /// @param signed A flag to determine if signed comparison should be used (0 for unsigned, non-zero for signed).
    /// @return c A new array containing the union of `a` and `b`.
    function _union(uint256[] memory a, uint256[] memory b, uint256 signed)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly ("memory-safe") {
            let s := 0x20
            let na := mload(a)
            let nb := mload(b)
            c := mload(0x40)
            let o := add(c, s)
            a := add(a, s)
            b := add(b, s)
            let ea := add(a, shl(5, na))
            let eb := add(b, shl(5, nb))
            let u := signed
            for {} iszero(or(eq(a, ea), eq(b, eb))) {} {
                let av := add(mload(a), u)
                let bv := add(mload(b), u)
                if iszero(lt(bv, av)) {
                    mstore(o, mload(a))
                    a := add(a, s)
                    o := add(o, s)
                    if eq(av, bv) {
                        b := add(b, s)
                    }
                    continue
                }
                mstore(o, mload(b))
                b := add(b, s)
                o := add(o, s)
            }
            for {} iszero(eq(a, ea)) {} {
                mstore(o, mload(a))
                a := add(a, s)
                o := add(o, s)
            }
            for {} iszero(eq(b, eb)) {} {
                mstore(o, mload(b))
                b := add(b, s)
                o := add(o, s)
            }
            mstore(c, shr(5, sub(sub(o, c), s)))
            mstore(0x40, o)
        }
    }
}