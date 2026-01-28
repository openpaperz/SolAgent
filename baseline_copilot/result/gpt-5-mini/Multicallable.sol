// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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
        if (msg.value != 0) revert("Multicallable: msg.value not supported");
        bytes32 results = _multicall(data);
        // Return directly to avoid copying/decoding overhead in Solidity.
        _multicallDirectReturn(results);
        // The above line will return via assembly. This is unreachable but keeps the compiler happy.
        revert("unreachable");
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
        // Prepare an in-memory array to hold each call's return data.
        bytes[] memory ret = new bytes[](data.length);

        for (uint256 i = 0; i < data.length; ++i) {
            (bool ok, bytes memory out) = address(this).delegatecall(data[i]);
            if (!ok) {
                // Bubble up revert reason.
                assembly {
                    let ptr := add(out, 32)
                    let len := mload(out)
                    revert(ptr, len)
                }
            }
            ret[i] = out;
        }

        // Return the memory pointer to `ret` as bytes32 so the caller can reconstruct it.
        assembly {
            results := ret
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
        // The `results` parameter is expected to be a memory pointer to a `bytes[]`.
        assembly {
            decoded := results
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
        // Reconstruct the bytes[] from the pointer and ABI-encode it, then return the encoded data directly.
        bytes[] memory decoded = _multicallResultsToBytesArray(results);
        bytes memory encoded = abi.encode(decoded);
        assembly {
            let dataPtr := add(encoded, 32)
            let dataLen := mload(encoded)
            return(dataPtr, dataLen)
        }
    }
}