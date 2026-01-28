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
        // Step 1: Revert if msg.value is non-zero to prevent double-spending
        assembly {
            if callvalue() {
                mstore(0x00, 0xb398979f) // `ETHValueNotAllowed()`.
                revert(0x1c, 0x04)
            }
        }
        
        // Step 2: Call the internal _multicall function to execute the provided data
        bytes32 results = _multicall(data);
        
        // Step 3: Return the results directly using _multicallDirectReturn
        _multicallDirectReturn(results);
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
            // Step 1: Allocate memory for the results and store the length of the data array
            mstore(0x00, 0x20)
            mstore(0x20, data.length) // Store length of the array
            
            let n := data.length
            let o := 0x40 // Memory offset for storing results
            
            // Step 2: Copy the calldata into memory for processing
            // (Implicit - we work directly with calldata)
            
            // Step 3: Iterate over each function call in the data array
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // Step 3a: Load the function call data from calldata
                let c := add(data.offset, calldataload(add(data.offset, mul(i, 0x20))))
                let l := calldataload(c)
                c := add(c, 0x20)
                
                // Step 3b: Execute the function call using delegatecall
                if iszero(delegatecall(gas(), address(), c, l, 0x00, 0x00)) {
                    // Step 3c: If the delegatecall fails, revert with the returned data
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                
                // Step 3d: Store the return data and its size in memory
                mstore(o, 0x20)
                let r := returndatasize()
                mstore(add(o, 0x20), r)
                returndatacopy(add(o, 0x40), 0x00, r)
                
                // Step 3e: Advance the memory pointer to prepare for the next function call
                o := add(o, and(add(add(r, 0x40), 0x1f), not(0x1f)))
            }
            
            // Step 4: Allocate memory for the final results and pack the length of the results into the return value
            mstore(0x40, o)
            results := or(shl(64, 0x40), 0x20)
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
            // Step 1: Allocate memory for the decoded array
            decoded := mload(0x40)
            
            // Step 2: Extract the offset from the `results` parameter
            let o := shr(64, results)
            
            // Step 3: Store the length of the decoded array
            let n := mload(add(o, and(results, 0xffffffffffffffff)))
            mstore(decoded, n)
            
            // Step 4: Calculate the start and end pointers for the decoded array
            let s := add(decoded, 0x20)
            let e := add(s, mul(n, 0x20))
            
            // Step 5: Allocate memory for the decoded array elements
            mstore(0x40, e)
            
            // Step 6: Calculate the start pointer for the `results` elements
            o := add(o, and(results, 0xffffffffffffffff))
            o := add(o, 0x20)
            
            // Step 7: Compute the difference between the input and output pointers
            let d := sub(e, o)
            
            // Step 8: Loop through the elements, copying them from `results` to the decoded array
            for {} 1 {} {
                mstore(s, d)
                let l := mload(add(o, 0x20))
                let c := add(l, 0x40)
                
                // Copy the element data
                for { let i := 0 } lt(i, c) { i := add(i, 0x20) } {
                    mstore(add(e, i), mload(add(o, i)))
                }
                
                s := add(s, 0x20)
                e := add(e, and(add(c, 0x1f), not(0x1f)))
                o := add(o, and(add(c, 0x1f), not(0x1f)))
                
                if iszero(lt(s, add(decoded, mul(add(n, 1), 0x20)))) { break }
            }
            
            mstore(0x40, e)
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
            // Step 1: Uses inline assembly to perform low-level operations
            // Step 2: Extracts the lower 64 bits of the `results` parameter and returns them
            let o := and(results, 0xffffffffffffffff)
            
            // Step 3: Shifts the `results` parameter right by 64 bits and returns the upper 64 bits
            let s := shr(64, results)
            
            // Return the data from memory
            return(add(s, o), sub(mload(0x40), add(s, o)))
        }
    }
}
