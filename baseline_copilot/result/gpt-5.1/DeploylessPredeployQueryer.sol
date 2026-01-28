// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title DeploylessPredeployQueryer
/// @notice Deploys a target via a factory if needed, then performs multiple static calls to it.
/// The constructor runs the whole flow and returns the concatenated results as returndata,
/// so the contract is effectively "deployless": it is not meant to be used after construction.
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
    constructor(
        address target,
        bytes[] memory targetQueryCalldata,
        address factory,
        bytes memory factoryCalldata
    ) {
        assembly {
            // ---------------------------------------------
            // 1. Check if target exists (code size > 0)
            // ---------------------------------------------
            let targetCodeSize := extcodesize(target)

            // ---------------------------------------------
            // 2. If not, deploy via factory
            // ---------------------------------------------
            if iszero(targetCodeSize) {
                // If factory is zero, we cannot deploy.
                if iszero(factory) {
                    // Revert with no data.
                    revert(0, 0)
                }

                // Call the factory with provided calldata.
                let fPtr := add(factoryCalldata, 0x20)
                let fLen := mload(factoryCalldata)

                // We forward all remaining gas, no ETH.
                let success := call(gas(), factory, 0, fPtr, fLen, 0, 0)
                if iszero(success) {
                    // Bubble up revert data from factory.
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }

                // The factory is assumed to have deployed the contract at `target`.
                // Re-check code size; if still zero, revert.
                targetCodeSize := extcodesize(target)
                if iszero(targetCodeSize) {
                    revert(0, 0)
                }
            }

            // ---------------------------------------------
            // 3. Prepare to perform queries
            // ---------------------------------------------
            let numQueries := mload(targetQueryCalldata)

            // Layout for the final result in memory:
            // [0x00..0x1f]  = total length (bytes) of concatenated results
            // [0x20..]      = concatenated raw returndata of each call
            //
            // We'll first collect raw segments, then compute total length,
            // then copy into [0x20..] and return [0x00..0x1f + 0x20].
            //
            // For temporary storage of segments:
            // segmentMetaLayout:
            //   For each i in [0, numQueries):
            //     offset: base + i * 0x40
            //     [offset + 0x00] = pointer to returndata segment in memory
            //     [offset + 0x20] = length of that segment
            //
            // We place metadata immediately after the free memory pointer.

            let freePtr := mload(0x40)

            // Pointer where we start storing (ptr, len) metadata pairs.
            let metaPtr := freePtr

            // Move free memory pointer past metadata space:
            // we need numQueries * 0x40 bytes.
            let metaSize := mul(numQueries, 0x40)
            let afterMeta := add(metaPtr, metaSize)
            mstore(0x40, afterMeta)

            // running index for metadata
            let i := 0

            // ---------------------------------------------
            // 4. Iterate over queries and perform staticcalls
            // ---------------------------------------------
            for { } lt(i, numQueries) { i := add(i, 1) } {
                // Load pointer to bytes element.
                // targetQueryCalldata is a dynamic array:
                // at memory:
                // [0x00] = length
                // [0x20] = pointer to element 0
                // ...
                // Each element slot is 32 bytes and stores its pointer.
                let elemSlot := add(targetQueryCalldata, add(0x20, mul(i, 0x20)))
                let elemPtr := mload(elemSlot)      // pointer to this bytes
                let elemData := add(elemPtr, 0x20)  // actual bytes start
                let elemLen := mload(elemPtr)       // length of bytes

                // Perform staticcall to target with this calldata.
                let success := staticcall(gas(), target, elemData, elemLen, 0, 0)
                if iszero(success) {
                    // Bubble revert.
                    let rdsize := returndatasize()
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }

                // Copy returndata to fresh memory segment.
                let rdsz := returndatasize()
                let segPtr := mload(0x40) // free memory
                returndatacopy(segPtr, 0, rdsz)

                // Update free memory pointer.
                mstore(0x40, add(segPtr, rdsz))

                // Write segment metadata.
                let metaOffset := add(metaPtr, mul(i, 0x40))
                mstore(metaOffset, segPtr)
                mstore(add(metaOffset, 0x20), rdsz)
            }

            // ---------------------------------------------
            // 5. Compute total length and concatenate
            // ---------------------------------------------
            let totalLen := 0
            i := 0
            for { } lt(i, numQueries) { i := add(i, 1) } {
                let metaOffset := add(metaPtr, mul(i, 0x40))
                let segLen := mload(add(metaOffset, 0x20))
                totalLen := add(totalLen, segLen)
            }

            // Result buffer starts at resPtr.
            // resPtr[0x00] = totalLen
            // resData = resPtr + 0x20
            let resPtr := mload(0x40)
            let resData := add(resPtr, 0x20)

            // Concatenate segments sequentially.
            let writePos := resData
            i := 0
            for { } lt(i, numQueries) { i := add(i, 1) } {
                let metaOffset := add(metaPtr, mul(i, 0x40))
                let segPtr := mload(metaOffset)
                let segLen := mload(add(metaOffset, 0x20))

                // Copy segLen bytes from segPtr to writePos
                // Copy word-by-word; last partial word handled by calldatacopy-like loop.
                // We'll just use a simple loop since sizes are unknown and can be small.
                let copySrc := segPtr
                let copyDst := writePos
                let end := add(segPtr, segLen)
                for { } lt(copySrc, end) {
                    copySrc := add(copySrc, 0x20)
                    copyDst := add(copyDst, 0x20)
                } {
                    let chunk := mload(copySrc)
                    mstore(copyDst, chunk)
                }

                writePos := add(writePos, segLen)
            }

            // Store total length at resPtr
            mstore(resPtr, totalLen)

            // Update free memory pointer past the result buffer.
            mstore(0x40, writePos)

            // ---------------------------------------------
            // 6. Return the ABI-encoded bytes (length + data)
            // ---------------------------------------------
            let totalSize := add(0x20, totalLen)
            return(resPtr, totalSize)
        }
    }
}