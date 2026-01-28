```solidity: DeploylessPredeployQueryer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract DeploylessPredeployQueryer {
    /**
     * @notice Constructor that initializes the contract with a target address, target query calldata, factory address, and factory calldata.
     *
     * @param target The address of the target contract to interact with.
     * @param targetQueryCalldata An array of calldata bytes to be used in calls to the target contract.
     * @param factory The address of the factory contract used to deploy the target if it does not exist.
     * @param factoryCalldata The calldata bytes to be used in the call to the factory contract for deploying the target.
     *
     * Steps:
     * 1. Check if the target contract exists by checking its code size.
     * 2. If the target does not exist, deploy it using the factory contract and the provided factory calldata.
     * 3. Verify that the deployed contract's address matches the expected target address.
     * 4. Iterate over the provided target query calldata and execute each call to the target contract.
     * 5. Handle any reverts or errors during the calls and revert the transaction if necessary.
     * 6. Store the results of the calls in memory and return them as a structured output.
     *
     * Assembly Details:
     * - Uses low-level assembly for memory management and contract calls.
     * - Handles memory allocation, calldata execution, and return data storage.
     * - Ensures memory safety and proper error handling during contract interactions.
     */
    constructor(address target, bytes[] memory targetQueryCalldata, address factory, bytes memory factoryCalldata) {
        assembly {
            // Step 1: Check if target contract exists
            let codeSize := extcodesize(target)
            
            // Step 2: If target doesn't exist, deploy it using factory
            if iszero(codeSize) {
                // Load factory calldata from memory
                let factoryCalldataPtr := add(factoryCalldata, 0x20)
                let factoryCalldataSize := mload(factoryCalldata)
                
                // Call factory to deploy target
                let success := call(gas(), factory, 0, factoryCalldataPtr, factoryCalldataSize, 0, 0)
                
                // Revert if factory call failed
                if iszero(success) {
                    revert(0, 0)
                }
                
                // Step 3: Verify deployed contract address matches target
                // Update code size after deployment
                codeSize := extcodesize(target)
                if iszero(codeSize) {
                    revert(0, 0)
                }
            }
            
            // Step 4: Execute queries to target contract
            // Get the number of queries
            let numQueries := mload(targetQueryCalldata)
            
            // Allocate memory for results
            // Result format: [numQueries, [success1, resultLength1, resultData1], [success2, resultLength2, resultData2], ...]
            let resultPtr := mload(0x40)
            let currentResultPtr := add(resultPtr, 0x20)
            
            // Store number of queries
            mstore(resultPtr, numQueries)
            
            // Iterate through each query
            for { let i := 0 } lt(i, numQueries) { i := add(i, 1) } {
                // Get pointer to current query calldata
                let queryDataOffset := mload(add(add(targetQueryCalldata, 0x20), mul(i, 0x20)))
                let queryDataPtr := add(add(targetQueryCalldata, 0x20), queryDataOffset)
                let queryDataLength := mload(queryDataPtr)
                let queryData := add(queryDataPtr, 0x20)
                
                // Execute call to target
                let success := call(gas(), target, 0, queryData, queryDataLength, 0, 0)
                
                // Store success flag
                mstore(currentResultPtr, success)
                currentResultPtr := add(currentResultPtr, 0x20)
                
                // Get return data size
                let returnDataSize := returndatasize()
                
                // Store return data length
                mstore(currentResultPtr, returnDataSize)
                currentResultPtr := add(currentResultPtr, 0x20)
                
                // Copy return data if any
                if gt(returnDataSize, 0) {
                    returndatacopy(currentResultPtr, 0, returnDataSize)
                    currentResultPtr := add(currentResultPtr, returnDataSize)
                }
            }
            
            // Update free memory pointer
            mstore(0x40, currentResultPtr)
            
            // Step 6: Return the results
            let resultSize := sub(currentResultPtr, resultPtr)
            return(resultPtr, resultSize)
        }
    }
}
```
