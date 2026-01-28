// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract providing batched delegatecall-based multicall functionality.
contract Multicallable {
    /**
     * @notice Executes multiple function calls in a single transaction.
     *
     * @dev This function is designed to handle multiple calls in a single transaction,
     * but it reverts if `msg.value` is non-zero to prevent potential double-spending issues.
     * If you need to send Ether with the calls, you must override this function and
     * implement the necessary checks.
     *
     * @param data An array of encoded function calls to be executed.
     * @return An array of bytes containing the return data from each function call.
     *
     * Steps:
     * 1. Revert if `msg.value` is non-zero to prevent double-spending.
     * 2. Call the internal `_multicall` function to execute the provided data.
     * 3. Return the results directly using `_multicallDirectReturn`.
     */
    function multicall(bytes[] calldata data) public virtual payable returns (bytes[] memory) {
        if (msg.value != 0) revert("Multicallable: value not allowed");
        bytes32 packed = _multicall(data);
        return _multicallResultsToBytesArray(packed);
    }

    /**
     * @notice Executes multiple function calls in a single transaction using delegatecall.
     * @dev This function is marked as internal and virtual, allowing it to be overridden by derived contracts.
     *
     * Steps:
     * 1. Allocate memory for the results and store the length of the data array.
     * 2. Copy the calldata into memory for processing.
     * 3. Iterate over each function call in the data array:
     *    a. Load the function call data from calldata.
     *    b. Execute the function call using delegatecall.
     *    c. If the delegatecall fails, revert with the returned data.
     *    d. Store the return data and its size in memory.
     *    e. Advance the memory pointer to prepare for the next function call.
     * 4. Allocate memory for the final results and pack the length of the results into the return value.
     *
     * @param data An array of encoded function calls to be executed.
     * @return results The packed results of the function calls, including their lengths.
     */
    function _multicall(bytes[] calldata data) internal virtual returns (bytes32 results) {
        assembly {
            // Pointer to free memory.
            let m := mload(0x40)

            // Number of calls.
            let len := data.length

            // We will build the ABI-encoded `bytes[]` in memory starting at `m`.
            // Layout:
            // m[0x00]: length (len)
            // m[0x20..]: offsets and data.

            // Store the length of the outer array.
            mstore(m, len)

            // Pointer to where the element heads (offsets) start.
            let heads := add(m, 0x20)
            // Pointer to where the element data will start (right after all heads).
            let dataPtr := add(heads, shl(5, len)) // len * 0x20

            // Calldata array layout:
            // data.offset = data.offset
            // data.length = len
            // Each element is at:
            //   element.offset = calldataload(add(data.offset, mul(i, 0x20)))
            //   element.length = calldataload(element.offset)
            //   element.data = element.offset + 0x20

            let dataOffset := data.offset

            // Loop over each call.
            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 1)
            } {
                // Load the offset of data[i] (relative to calldata start of `data` array).
                let elementOffset := calldataload(add(dataOffset, shl(5, i)))
                elementOffset := add(dataOffset, elementOffset)

                // Load the length of data[i].
                let elementLen := calldataload(elementOffset)
                // Pointer to the actual call data in calldata.
                let elementData := add(elementOffset, 0x20)

                // Perform delegatecall.
                let success := delegatecall(gas(), address(), elementData, elementLen, 0, 0)
                let retSize := returndatasize()

                // If delegatecall failed, bubble up the revert.
                if iszero(success) {
                    // Copy returndata and revert with it.
                    returndatacopy(0, 0, retSize)
                    revert(0, retSize)
                }

                // Store the offset for this element's data relative to the start of the bytes[].
                // Current offset: dataPtr - m
                mstore(add(heads, shl(5, i)), sub(dataPtr, m))

                // Store the length of the return data.
                mstore(dataPtr, retSize)
                // Copy the return data right after the length.
                let dest := add(dataPtr, 0x20)
                returndatacopy(dest, 0, retSize)

                // Advance dataPtr past this element (length word + data).
                dataPtr := add(dest, retSize)
            }

            // Total size of the encoded bytes[] in memory.
            let totalSize := sub(dataPtr, m)

            // Update free memory pointer.
            mstore(0x40, dataPtr)

            // Pack the pointer and length into a bytes32:
            // High 192 bits: memory pointer to encoded array.
            // Low 64 bits: total size in bytes.
            // This is an internal encoding solely for use with `_multicallResultsToBytesArray`
            // and `_multicallDirectReturn`.
            results := or(shl(64, m), totalSize)
        }
    }

    /**
     * @notice Converts a `bytes32` result from a multicall into a `bytes[]` array.
     *
     * Steps:
     * 1. Allocate memory for the decoded array.
     * 2. Extract the offset from the `results` parameter.
     * 3. Store the length of the decoded array.
     * 4. Calculate the start and end pointers for the decoded array.
     * 5. Allocate memory for the decoded array elements.
     * 6. Calculate the start pointer for the `results` elements.
     * 7. Compute the difference between the input and output pointers.
     * 8. Loop through the elements, copying them from `results` to the decoded array.
     *
     * @param results The `bytes32` input containing the multicall results.
     * @return decoded The decoded `bytes[]` array.
     */
    function _multicallResultsToBytesArray(bytes32 results) internal virtual pure returns (bytes[] memory decoded) {
        assembly {
            // Extract the pointer and total size from `results`.
            let size := and(results, 0xFFFFFFFFFFFFFFFF)
            let ptr := shr(64, results)

            // `ptr` points to an ABI-encoded `bytes[]` in memory.
            decoded := ptr

            // We assume the memory layout produced by `_multicall`:
            // [0x00]: length
            // [0x20..]: heads and data.
            // The Solidity ABI decoder is already satisfied with this layout.
        }
    }

    /**
     * @notice Internal function to handle multicall with direct return values.
     *
     * Steps:
     * 1. Uses inline assembly to perform low-level operations.
     * 2. Extracts the lower 64 bits of the `results` parameter and returns them.
     * 3. Shifts the `results` parameter right by 64 bits and returns the upper 64 bits.
     *
     * @param results A bytes32 value containing the data to be split and returned.
     */
    function _multicallDirectReturn(bytes32 results) internal virtual pure {
        assembly {
            // Extract lower 64 bits (size) and higher bits (pointer).
            let size := and(results, 0xFFFFFFFFFFFFFFFF)
            let ptr := shr(64, results)
            // Return the encoded bytes[] directly.
            return(ptr, size)
        }
    }
}