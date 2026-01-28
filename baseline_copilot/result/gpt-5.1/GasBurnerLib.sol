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
     *
     * Notes:
     * - The function uses inline assembly for low-level memory manipulation.
     * - The `keccak256` hash function is used instead of the `blake2f` precompile for better compatibility.
     */
    function burnPure(uint256 x) internal pure {
        assembly {
            // 1. Store or(1, x) at memory location 0x10.
            mstore(0x10, or(1, x))

            // 2. n = mul(gt(x, 120), div(x, 91))
            let n := mul(gt(x, 120), div(x, 91))

            // 3. Iterate n times, hashing the value at 0x10.
            for { } n { n := sub(n, 1) } {
                mstore(0x10, keccak256(0x10, 0x20))
            }

            // 4. If final value at 0x10 is zero, trigger invalid.
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
     *
     * @dev This function uses inline assembly and is marked as `view`, meaning it does not modify the state.
     */
    function burnView(uint256 x) internal view {
        assembly {
            // 1. n = (x > 3500) ? x / 3200 : 0
            let n := mul(gt(x, 3500), div(x, 3200))

            // 2. Store current free memory pointer in m
            let m := mload(0x40)

            // Save original zero slot and free memory pointer to restore later
            let oldZero := mload(0x00)
            let oldFree := m

            // 3a. Store a computed value at 0x00
            mstore(0x00, xor(x, timestamp()))

            // 3b. Hash first 32 bytes and store back at 0x00
            mstore(0x00, keccak256(0x00, 0x20))

            // 3c. Store predefined values at 0x20, 0x40, 0x60
            mstore(0x20, number())
            mstore(0x40, gas())
            mstore(0x60, caller())

            // Also put a non‑zero sentinel at 0x10 to be modified via staticcalls
            mstore(0x10, or(1, x))

            // 4. Loop n times, staticcall to address 1 with memory data.
            // We'll use memory region [0x00, 0x80) as input/output scratch.
            for { } n { n := sub(n, 1) } {
                // staticcall(gas, to=1, in=0x00, insize=0x80, out=0x10, outsize=0x20)
                // Result will overwrite word at 0x10.
                pop(staticcall(gas(), 1, 0x00, 0x80, 0x10, 0x20))
            }

            // 5. If value at 0x10 is zero, trigger invalid.
            if iszero(mload(0x10)) {
                invalid()
            }

            // 6. Restore zero slot and free memory pointer.
            mstore(0x00, oldZero)
            mstore(0x40, oldFree)
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
     *
     * Note: This function uses low-level assembly and is highly optimized for specific use cases. It may not be immediately clear without additional context.
     */
    function burn(uint256 x) internal {
        assembly {
            // 1. Load free memory pointer into m.
            let m := mload(0x40)

            // 2. n = (x > 18000) ? x / 17700 : 0
            let n := mul(gt(x, 18000), div(x, 17700))

            // 3. Store combination of contract address, tx.origin, and timestamp at m.
            mstore(
                m,
                xor(
                    xor(shl(96, address()), shl(96, origin())),
                    timestamp()
                )
            )

            // 4. Copy 2080 bytes of contract code into memory at m + 0x20.
            {
                // Use keccak256 hash as a selector for the code offset.
                // For simplicity and determinism, clamp offset within code size.
                let codeSize := codesize()
                let selector := keccak256(m, 0x20)
                // Reduce selector to valid offset (word-aligned).
                let offset := mul(and(div(selector, 0x20), sub(div(codeSize, 0x20), 1)), 0x20)
                // Ensure we don't go out of bounds for 2080 bytes.
                if lt(codeSize, add(offset, 2080)) {
                    offset := 0
                }
                codecopy(add(m, 0x20), offset, 2080)
            }

            // Prepare for loop
            let i := 0

            // 5. Infinite loop; we'll break internally.
            for { } 1 { } {
                // 5a. Compute new hash h from [m, m+2080)
                let h := keccak256(m, 2080)

                // 5b. Store h at m.
                mstore(m, h)

                // 5c. Copy a portion of contract code into m + (h & 0x7ff)
                {
                    let codeSize := codesize()
                    let baseOffset := and(h, 0x7ff) // 0..2047
                    // Use h as selector for code offset.
                    let sel := keccak256(add(m, 0x20), 0x40)
                    let offset := mul(and(div(sel, 0x20), sub(div(codeSize, 0x20), 1)), 0x20)
                    // Ensure we don't run out of code for 256 bytes copy.
                    let copySize := 256
                    if lt(codeSize, add(offset, copySize)) {
                        offset := 0
                    }
                    codecopy(add(m, baseOffset), offset, copySize)
                }

                // 5d. Store bitwise negation of h at m + 2048
                mstore(add(m, 2048), not(h))

                // 5e. If i == n, do the special log and break.
                if eq(i, n) {
                    // i. Adjust n using x % 17700; ensure > 0x30.
                    let rem := mod(x, 17700)
                    n := add(0x31, mod(rem, 2048)) // between 0x31 and 0x31+2047

                    // ii. Store h at m + n
                    mstore(add(m, n), h)

                    // iii. log0(m, n + 0x20)
                    log0(m, add(n, 0x20))

                    // iv. Break loop
                    break
                }

                // 5f. Emit log0 event with memory [m, m + 2080)
                log0(m, 2080)

                // Increment loop counter
                i := add(i, 1)
            }

            // Advance free memory pointer past the scratch region.
            // We used up to m + 2080 + 0x20.
            mstore(0x40, add(m, 0x820))
        }
    }
}