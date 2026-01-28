// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library GasBurnerLib {
    /**
     * @notice Internal pure function to perform a burn operation using low-level assembly.
     *
     * @param x The input value used in the burn operation.
     *
     * Steps:
     * 1. Store the value `or(1, x)` at memory location `0x10`.
     * 2. Calculate `n` as the result of `mul(gt(x, 120), div(x, 91))`. This determines the number of iterations.
     * 3. Iterate `n` times, updating the value at memory location `0x10` using the `keccak256` hash function.
     * 4. If the final value at memory location `0x10` is zero, trigger an invalid operation (revert).
     */
    function burnPure(uint256 x) internal pure {
        assembly {
            // Store or(1, x) at memory location 0x10
            mstore(0x10, or(1, x))

            // n = mul(gt(x, 120), div(x, 91))
            let n := mul(gt(x, 120), div(x, 91))

            // iterate n times and update memory at 0x10 with keccak256 of 0x10..0x30
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                mstore(0x10, keccak256(0x10, 0x20))
            }

            // if the final value at 0x10 is zero, trigger invalid opcode
            if iszero(mload(0x10)) {
                invalid()
            }
        }
    }

    /**
     * @notice A view function that performs a series of low-level assembly operations.
     *
     * Steps:
     * 1. Calculate `n` based on the input `x`. If `x` is greater than 3500, `n` is set to `x / 3200`; otherwise, `n` is 0.
     * 2. Store the current free memory pointer in `m`.
     * 3. Perform a series of memory operations:
     *    - Store a computed value at memory location 0x00.
     *    - Compute the keccak256 hash of the first 32 bytes of memory and store it back at 0x00.
     *    - Store predefined values at memory locations 0x20, 0x40, and 0x60.
     * 4. Execute a loop `n` times, performing a static call to address 1 (Ethereum precompile) with the data in memory.
     * 5. If the value at memory location 0x10 is zero, trigger an invalid opcode to revert the transaction.
     * 6. Restore the zero slot and free memory pointer to their original values.
     *
     * @param x The input value used to determine the number of loop iterations.
     */
    function burnView(uint256 x) internal view {
        assembly {
            // n = (x > 3500) ? x / 3200 : 0
            let n := mul(gt(x, 3500), div(x, 3200))

            // save free memory pointer
            let m := mload(0x40)

            // Prepare memory region for the staticcall
            // store a computed value at 0x00
            mstore(0x00, add(x, 1))
            // compute keccak256 of first 32 bytes and store it back at 0x00
            mstore(0x00, keccak256(0x00, 0x20))
            // store predefined values at 0x20, 0x40, 0x60
            mstore(0x20, 0x100)
            mstore(0x40, 0x200)
            mstore(0x60, 0x300)

            // initialize a guard value at 0x10 used for verification later
            mstore(0x10, 1)

            // Loop n times performing staticcall to address 1 (precompile)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // staticcall(gas, to, in_ptr, in_size, out_ptr, out_size)
                // use memory 0x00..0x80 as input
                let success := staticcall(gas(), 0x01, 0x00, 0x80, 0x00, 0x20)
                // if call returned data, overwrite guard with returned word
                if and(success, gt(returndatasize(), 0)) {
                    // copy returned data to 0x10
                    returndatacopy(0x10, 0x00, 0x20)
                }
            }

            // If the guard at 0x10 is zero, revert with invalid opcode
            if iszero(mload(0x10)) {
                // restore zero slot and free memory pointer before invalid
                mstore(0x00, 0)
                mstore(0x40, m)
                invalid()
            }

            // restore zero slot and free memory pointer
            mstore(0x00, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Internal function to perform a custom burn operation using low-level assembly.
     *
     * Steps:
     * 1. Load the free memory pointer (`mload(0x40)`) into `m`.
     * 2. Calculate `n` based on the input `x`. If `x` is greater than 18000, `n` is set to `x / 17700`; otherwise, it is 0.
     * 3. Store a combination of the contract's address, transaction origin, and current timestamp in memory at `m`.
     * 4. Copy a portion of the contract's code (2080 bytes) into memory starting at `m + 0x20`, using a keccak256 hash as a selector.
     * 5. Enter a loop that continues indefinitely:
     *    a. Calculate a new hash `h` based on the current memory content.
     *    b. Store `h` in memory at `m`.
     *    c. Copy a portion of the contract's code into memory at `m + (h & 0x7ff)`, using `h` as a selector.
     *    d. Store the bitwise negation of `h` in memory at `m + 2048`.
     *    e. If the loop counter `i` equals `n`:
     *       i. Adjust `n` based on `x % 17700` and ensure it is greater than 0x30.
     *       ii. Store `h` in memory at `m + n`.
     *       iii. Emit a log0 event with the memory content from `m` to `m + n + 0x20`.
     *       iv. Break the loop.
     *    f. Emit a log0 event with the memory content from `m` to `m + 2080`.
     */
    function burn(uint256 x) internal {
        assembly {
            // m := free memory pointer
            let m := mload(0x40)

            // n := (x > 18000) ? x / 17700 : 0
            let n := mul(gt(x, 18000), div(x, 17700))

            // store a combination of address(this), tx.origin, and timestamp at m
            // pack values by xoring shifted forms to avoid collisions; exact packing isn't critical
            let addrPart := shl(96, address())
            let originPart := shl(160, origin())
            let timePart := timestamp()
            mstore(m, xor(addrPart, xor(originPart, timePart)))

            // compute a selector hash based on current memory and copy contract code into memory at m + 0x20
            let sel := keccak256(m, 0x20)
            // ensure offset within code size
            let codesz := codesize()
            let off := mod(sel, codesz)
            // copy up to 2080 bytes of the contract's own code to m + 0x20
            // guard size by codesz - off
            let maxCopy := codesz
            // if codesz < 2080, adjust copy size; else use 2080
            let copySize := 2080
            if lt(maxCopy, copySize) {
                copySize := maxCopy
            }
            codecopy(add(m, 0x20), off, copySize)

            // loop indefinitely, will break internally
            for { let i := 0 } 1 { i := add(i, 1) } {
                // compute a new hash based on current memory (m .. m+0x200)
                let h := keccak256(m, 0x200)
                // store h at m
                mstore(m, h)
                // compute a destination offset within m using h & 0x7ff
                let destOffset := and(h, 0x7ff)
                // compute codecopy offset using h mod codesz
                let codeOff := mod(h, codesz)
                // copy up to 512 bytes from code into memory at m + destOffset
                // ensure we don't exceed available code size
                let smallCopy := 512
                if lt(codesz, smallCopy) {
                    smallCopy := codesz
                }
                codecopy(add(m, destOffset), codeOff, smallCopy)

                // store bitwise negation of h at m + 2048 (0x800)
                mstore(add(m, 0x800), not(h))

                // if i == n then perform final emission and break
                if eq(i, n) {
                    // adjust n based on x % 17700 and ensure > 0x30
                    let nn := add(mod(x, 17700), 0x31)
                    if lt(nn, 0x31) { nn := 0x31 }
                    // store h at m + nn
                    mstore(add(m, nn), h)
                    // emit log0 with memory region m .. m + nn + 0x20
                    log0(m, add(nn, 0x20))
                    break
                }

                // otherwise emit a larger chunk
                log0(m, 2080)
            }

            // restore free memory pointer (set to m + 4096 to avoid clobbering)
            let newFree := add(m, 0x1000)
            mstore(0x40, newFree)
        }
    }
}