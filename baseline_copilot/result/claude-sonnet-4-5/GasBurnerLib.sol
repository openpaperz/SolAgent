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
            mstore(0x10, or(1, x))
            let n := mul(gt(x, 120), div(x, 91))
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                mstore(0x10, keccak256(0x10, 0x20))
            }
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
            let n := mul(gt(x, 3500), div(x, 3200))
            let m := mload(0x40)
            mstore(0x00, or(shl(160, x), address()))
            mstore(0x00, keccak256(0x00, 0x20))
            mstore(0x20, or(shl(160, x), address()))
            mstore(0x40, or(shl(160, x), address()))
            mstore(0x60, or(shl(160, x), address()))
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                pop(staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20))
            }
            if iszero(mload(0x10)) {
                invalid()
            }
            mstore(0x60, 0)
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
     *
     * Note: This function uses low-level assembly and is highly optimized for specific use cases. It may not be immediately clear without additional context.
     */
    function burn(uint256 x) internal {
        assembly {
            let m := mload(0x40)
            let n := mul(gt(x, 18000), div(x, 17700))
            mstore(m, or(or(shl(160, address()), shl(80, origin())), timestamp()))
            codecopy(add(m, 0x20), keccak256(m, 0x20), 2080)
            for { let i := 0 } 1 { i := add(i, 1) } {
                let h := keccak256(m, 2080)
                mstore(m, h)
                codecopy(add(m, and(h, 0x7ff)), h, 32)
                mstore(add(m, 2048), not(h))
                if eq(i, n) {
                    n := add(gt(mod(x, 17700), 0x30), mod(x, 17700))
                    mstore(add(m, n), h)
                    log0(m, add(n, 0x20))
                    break
                }
                log0(m, 2080)
            }
        }
    }
}
