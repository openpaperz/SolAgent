// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for compression and decompression operations.
library LibZip {
    /**
     * @notice Compresses the input data using a custom compression algorithm.
     *
     * The function uses low-level assembly to optimize memory usage and performance.
     * It implements a custom compression algorithm that processes the input data in chunks,
     * identifies repeated patterns, and compresses them using a hash-based approach.
     *
     * Steps:
     * 1. Initialize the result memory pointer and zeroize the hashmap.
     * 2. Copy the input data into memory and set up pointers for processing.
     * 3. Iterate through the input data to identify repeated patterns using a hash function.
     * 4. For each repeated pattern, encode the length and offset of the match.
     * 5. For non-repeated data, encode it as literals.
     * 6. Update the hashmap with the current position to facilitate future pattern matching.
     * 7. After processing, copy the compressed result to a compact memory location.
     * 8. Store the length of the compressed data and allocate memory for the result.
     *
     * @param data The input data to be compressed.
     * @return result The compressed data as a byte array.
     */
    function flzCompress(bytes memory data) internal pure returns (bytes memory result) {
        assembly {
            function ms(d_, o_, l_) -> _o {
                _o := add(o_, l_)
                let s_ := add(d_, 0x20)
                let c_ := add(result, _o)
                for { let e_ := add(s_, l_) } iszero(eq(s_, e_)) { s_ := add(s_, 0x20) } {
                    mstore(c_, mload(s_))
                    c_ := add(c_, 0x20)
                }
            }
            function ms8(o_, v_) -> _o {
                mstore8(add(result, o_), v_)
                _o := add(o_, 1)
            }
            function u24(p_) -> _u {
                _u := mload(p_)
                _u := or(shl(16, byte(0, _u)), or(shl(8, byte(1, _u)), byte(2, _u)))
            }
            function h(d_, l_) -> _h {
                _h := or(shl(16, byte(0, d_)), or(shl(8, byte(1, d_)), byte(2, d_)))
                _h := and(shr(19, mul(197, _h)), 0x1fff)
            }
            result := mload(0x40)
            codecopy(result, codesize(), 0x8000)
            let op := 0x20
            let a := add(data, 0x20)
            let e := add(a, mload(data))
            let r := a
            let s := 0
            let p := 0
            let q := 0
            for {} lt(a, e) {} {
                let o := a
                let l := sub(e, a)
                if iszero(lt(l, 4)) {
                    let t := u24(a)
                    p := mload(add(result, h(t, l)))
                    mstore(add(result, h(t, l)), a)
                    s := xor(t, u24(p))
                    if iszero(or(s, or(lt(sub(a, p), 0x2000), lt(l, 10)))) {
                        if iszero(gt(sub(a, r), 0)) {
                            let z := sub(a, r)
                            if iszero(lt(z, 238)) {
                                op := ms8(op, 17)
                                op := ms8(op, sub(z, 238))
                            }
                            if iszero(gt(z, 0)) { z := 0 }
                            if iszero(lt(z, 4)) {
                                let z_ := sub(z, 3)
                                op := ms8(op, add(224, z_))
                            }
                            if gt(z, 0) {
                                if lt(z, 4) { op := ms8(op, add(shl(5, z), 31)) }
                                op := ms(r, op, z)
                            }
                        }
                        l := 2
                        for {} and(lt(add(l, a), e), eq(byte(0, mload(add(l, a))), byte(0, mload(add(l, p))))) {} {
                            l := add(l, 1)
                        }
                        q := sub(a, p)
                        a := add(a, l)
                        r := a
                        q := sub(q, 1)
                        if lt(l, 9) {
                            op := ms8(op, add(or(shl(5, sub(l, 2)), and(shr(8, q), 31)), 1))
                            op := ms8(op, and(q, 255))
                            continue
                        }
                        op := ms8(op, add(and(shr(8, q), 31), 1))
                        op := ms8(op, and(q, 255))
                        l := sub(l, 9)
                        if iszero(lt(l, 238)) {
                            op := ms8(op, 0)
                            op := ms8(op, sub(l, 238))
                        }
                        if gt(l, 0) { op := ms8(op, l) }
                        continue
                    }
                }
                a := add(a, 1)
            }
            if iszero(gt(sub(e, r), 0)) {
                let z := sub(e, r)
                if iszero(lt(z, 238)) {
                    op := ms8(op, 17)
                    op := ms8(op, sub(z, 238))
                }
                if iszero(gt(z, 0)) { z := 0 }
                if iszero(lt(z, 4)) {
                    let z_ := sub(z, 3)
                    op := ms8(op, add(224, z_))
                }
                if gt(z, 0) {
                    if lt(z, 4) { op := ms8(op, add(shl(5, z), 31)) }
                    op := ms(r, op, z)
                }
            }
            let c := mload(result)
            let m := mload(0x40)
            result := m
            mstore(m, sub(op, 0x20))
            m := add(m, 0x20)
            let d := add(c, 0x20)
            for { let f := add(d, op) } iszero(eq(d, f)) { d := add(d, 0x20) } {
                mstore(m, mload(d))
                m := add(m, 0x20)
            }
            mstore(m, 0)
            mstore(0x40, add(m, 0x20))
        }
    }

    /**
     * @notice Decompresses data using a custom algorithm (likely FLZ decompression).
     *
     * @param data The compressed data to be decompressed.
     * @return result The decompressed data as a bytes array.
     *
     * Steps:
     * 1. Allocate memory for the result and initialize pointers for the output (`op`) and the end of the input data (`end`).
     * 2. Iterate through the compressed data:
     *    - Read the current byte and determine the type of operation based on the first 3 bits.
     *    - If the operation type is 0, copy the next byte(s) directly to the output.
     *    - If the operation type is non-zero, perform a more complex copy operation involving a reference to previously decompressed data.
     * 3. Update the result length and zeroize the memory slot after the decompressed data.
     * 4. Adjust the free memory pointer to allocate memory for the decompressed data.
     *
     * Note: This function uses inline assembly for low-level memory manipulation, which is highly optimized but requires careful handling to avoid memory corruption.
     */
    function flzDecompress(bytes memory data) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            let op := add(result, 0x20)
            let end := add(add(data, 0x20), mload(data))
            for { data := add(data, 0x20) } lt(data, end) {} {
                let w := mload(data)
                let c := byte(0, w)
                let t := shr(5, c)
                if iszero(t) {
                    let l := add(and(c, 31), 1)
                    if eq(l, 1) {
                        l := add(byte(1, w), 238)
                        data := add(data, 1)
                    }
                    if eq(and(c, 31), 31) {
                        let n := byte(1, w)
                        l := add(n, 4)
                        data := add(data, 1)
                    }
                    for { data := add(data, 1) let f := add(data, l) } lt(data, f) { data := add(data, 0x20) } {
                        mstore(op, mload(data))
                        op := add(op, 0x20)
                    }
                    op := sub(op, sub(data, f))
                    data := f
                    continue
                }
                let o := add(shl(8, and(c, 31)), byte(1, w))
                let s := sub(op, add(o, 1))
                let l := add(t, 2)
                data := add(data, 2)
                if lt(t, 7) {
                    for { let f := add(s, l) } lt(s, f) { s := add(s, 1) } {
                        mstore8(op, byte(0, mload(s)))
                        op := add(op, 1)
                    }
                    continue
                }
                l := byte(0, w)
                if iszero(l) {
                    l := add(byte(1, w), 238)
                    data := add(data, 1)
                }
                l := add(l, 9)
                for { let f := add(s, l) } lt(s, f) { s := add(s, 1) } {
                    mstore8(op, byte(0, mload(s)))
                    op := add(op, 1)
                }
            }
            mstore(result, sub(sub(op, result), 0x20))
            mstore(op, 0)
            mstore(0x40, add(op, 0x20))
        }
    }

    /**
     * @notice Compresses the input data using a custom Run-Length Encoding (RLE) algorithm.
     * 
     * @dev This function processes the input data byte by byte, compressing sequences of consecutive 
     *      0x00 or 0xff bytes into a more compact format. The compressed data is stored in the returned 
     *      `result` bytes array.
     *
     * @param data The input data to be compressed.
     * @return result The compressed data as a bytes array.
     *
     * Steps:
     * 1. Initialize the result pointer and allocate memory for the compressed data.
     * 2. Iterate through each byte of the input data:
     *    - If the byte is 0x00, increment the zero counter (`z`).
     *    - If the byte is 0xff, increment the 0xff counter (`y`).
     *    - If a non-zero or non-0xff byte is encountered, write any pending RLE sequences to the result.
     * 3. After processing all bytes, write any remaining RLE sequences to the result.
     * 4. Perform a bitwise negation on the first 4 bytes of the result.
     * 5. Store the length of the compressed data and zeroize the memory slot after the result.
     * 6. Update the free memory pointer to allocate memory for the compressed data.
     */
    function cdCompress(bytes memory data) internal pure returns (bytes memory result) {
        assembly {
            function rle(v_, o_, d_) -> _o, _d {
                mstore(o_, shl(240, or(and(0xff, add(d_, 0x80)), shl(8, v_))))
                _o := add(o_, 2)
            }
            result := mload(0x40)
            let op := add(result, 0x20)
            let z := 0
            let y := 0
            let end := add(data, mload(data))
            for { data := add(data, 0x20) } lt(data, end) { data := add(data, 1) } {
                let c := byte(0, mload(data))
                if iszero(c) {
                    if y {
                        op, y := rle(255, op, y)
                    }
                    z := add(z, 1)
                    continue
                }
                if eq(c, 255) {
                    if z {
                        op, z := rle(0, op, z)
                    }
                    y := add(y, 1)
                    continue
                }
                if y {
                    op, y := rle(255, op, y)
                }
                if z {
                    op, z := rle(0, op, z)
                }
                mstore8(op, c)
                op := add(op, 1)
            }
            if y {
                op, y := rle(255, op, y)
            }
            if z {
                op, z := rle(0, op, z)
            }
            mstore(add(result, 0x20), not(mload(add(result, 0x20))))
            mstore(result, sub(sub(op, result), 0x20))
            mstore(op, 0)
            mstore(0x40, add(op, 0x20))
        }
    }

    /**
     * @notice Decompresses a compressed byte array using a custom algorithm.
     *
     * @dev This function uses inline assembly to perform low-level memory operations for efficiency.
     * It processes the input data byte by byte, handling special cases for zero bytes and compressed sequences.
     *
     * @param data The compressed byte array to be decompressed.
     * @return result The decompressed byte array.
     *
     * Steps:
     * 1. Check if the input data is non-empty.
     * 2. Allocate memory for the result and initialize pointers for the result and input data.
     * 3. Temporarily modify the first 4 bytes of the input data to facilitate decompression.
     * 4. Iterate through the input data:
     *    - If a zero byte is encountered, handle it as a special case for compressed sequences.
     *    - Otherwise, copy the byte directly to the result.
     * 5. Restore the original first 4 bytes of the input data.
     * 6. Store the length of the decompressed data in the result.
     * 7. Zeroize the memory slot after the decompressed data to ensure clean memory state.
     * 8. Update the free memory pointer to allocate memory for the decompressed data.
     */
    function cdDecompress(bytes memory data) internal pure returns (bytes memory result) {
        assembly {
            if mload(data) {
                result := mload(0x40)
                let op := add(result, 0x20)
                let end := add(add(data, 0x20), mload(data))
                let w := mload(add(data, 0x20))
                mstore(add(data, 0x20), not(w))
                for { data := add(data, 0x20) } lt(data, end) {} {
                    data := add(data, 1)
                    let c := byte(0, mload(data))
                    if iszero(c) {
                        data := add(data, 1)
                        let d := byte(0, mload(data))
                        let v := and(d, 0x7f)
                        let l := sub(and(d, 127), 127)
                        if gt(v, 0x7f) {
                            l := and(d, 127)
                        }
                        let f := sub(d, l)
                        codecopy(op, codesize(), l)
                        op := add(op, l)
                        continue
                    }
                    mstore8(op, c)
                    op := add(op, 1)
                }
                mstore(add(data, 1), w)
                mstore(result, sub(sub(op, result), 0x20))
                mstore(op, 0)
                mstore(0x40, add(op, 0x20))
            }
        }
    }

    /**
     * @notice Internal function to handle custom fallback logic using assembly.
     *
     * Steps:
     * 1. Check if there is no calldata. If true, return immediately.
     * 2. Initialize an offset `o` to 0 and a mask `f` to negate the first 4 bytes.
     * 3. Loop through the calldata:
     *    a. Extract a byte from the calldata, XOR it with the mask, and check if it is zero.
     *    b. If zero, extract the next byte and determine if it is greater than 0x7f.
     *    c. Store either 0xff or 0x00 in memory based on the extracted byte.
     *    d. Update the offset `o` accordingly.
     *    e. If the byte is not zero, store it in memory and increment the offset.
     * 4. Perform a delegatecall using the processed calldata.
     * 5. Copy the return data and check if the delegatecall was successful.
     * 6. If successful, return the data. Otherwise, revert with the return data.
     */
    function cdFallback() internal {
        assembly {
            if iszero(calldatasize()) { return(0, 0) }
            let o := 0
            let f := not(0)
            for { let i := 0 } lt(i, calldatasize()) {} {
                let c := byte(0, xor(calldataload(i), f))
                f := 0
                if iszero(c) {
                    i := add(i, 1)
                    let d := byte(0, calldataload(i))
                    c := sub(and(d, 127), 127)
                    if gt(and(d, 128), 0) {
                        c := and(d, 127)
                        codecopy(add(0, o), codesize(), c)
                        o := add(o, c)
                        i := add(i, 1)
                        continue
                    }
                    let m := 0
                    if iszero(gt(and(d, 128), 0)) {
                        m := not(0)
                    }
                    codecopy(add(0, o), codesize(), c)
                    o := add(o, c)
                    i := add(i, 1)
                    continue
                }
                mstore8(add(0, o), c)
                o := add(o, 1)
                i := add(i, 1)
            }
            let success := delegatecall(gas(), address(), 0, o, 0, 0)
            returndatacopy(0, 0, returndatasize())
            if success { return(0, returndatasize()) }
            revert(0, returndatasize())
        }
    }
}
