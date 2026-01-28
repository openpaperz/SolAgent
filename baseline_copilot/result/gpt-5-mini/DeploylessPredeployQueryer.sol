// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract DeploylessPredeployQueryer {
    bytes[] public results;
    event Deployed(address indexed target);

    /**
     * @notice Constructor that initializes the contract with a target address, target query calldata, factory address, and factory calldata.
     *
     * @param target The address of the target contract to interact with.
     * @param targetQueryCalldata An array of calldata bytes to be used in calls to the target contract.
     * @param factory The address of the factory contract used to deploy the target if it does not exist.
     * @param factoryCalldata The calldata bytes to be used in the call to the factory contract for deploying the target.
     *
     * Steps implemented:
     * 1. Check if the target contract exists by checking its code size.
     * 2. If the target does not exist, call the factory with `factoryCalldata` to deploy it.
     * 3. Verify that the deployed contract's address has code.
     * 4. Iterate over the provided target query calldata and execute each call to the target contract.
     * 5. Handle any reverts or errors during the calls and revert the transaction if necessary (bubbling revert reasons when present).
     * 6. Store the results of the calls in storage (`results`) for later retrieval.
     */
    constructor(
        address target,
        bytes[] memory targetQueryCalldata,
        address factory,
        bytes memory factoryCalldata
    ) {
        uint256 size;
        assembly { size := extcodesize(target) }

        if (size == 0) {
            // Deploy via factory
            (bool ok, bytes memory factoryRet) = factory.call(factoryCalldata);
            if (!ok) {
                // Bubble up factory revert reason if present
                if (factoryRet.length > 0) {
                    assembly {
                        revert(add(factoryRet, 0x20), mload(factoryRet))
                    }
                } else {
                    revert("Factory call failed without revert reason");
                }
            }

            // Verify target now has code
            assembly { size := extcodesize(target) }
            if (size == 0) revert("Deployment failed: target has no code");
            emit Deployed(target);
        }

        // Execute provided queries against target and collect results
        for (uint256 i = 0; i < targetQueryCalldata.length; i++) {
            bytes memory callData = targetQueryCalldata[i];
            (bool success, bytes memory ret) = target.call(callData);
            if (!success) {
                // Bubble up revert reason from target call if present
                if (ret.length > 0) {
                    assembly {
                        revert(add(ret, 0x20), mload(ret))
                    }
                } else {
                    revert("Target call reverted without reason");
                }
            }
            results.push(ret);
        }
    }

    /// @notice Returns the number of stored call results.
    function getResultsLength() external view returns (uint256) {
        return results.length;
    }

    /// @notice Returns the stored result at index `i`.
    function resultAt(uint256 i) external view returns (bytes memory) {
        return results[i];
    }
}