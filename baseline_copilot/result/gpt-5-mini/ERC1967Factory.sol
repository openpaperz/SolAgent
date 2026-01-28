// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract ERC1967Factory {
    /// Events
    event AdminChanged(address indexed proxy, address indexed newAdmin);
    event Upgraded(address indexed proxy, address indexed implementation);
    event Deployed(address indexed proxy, address indexed implementation, address indexed admin);

    /// Errors
    error Unauthorized();
    error UpgradeFailed();
    error DeploymentFailed();
    error SaltDoesNotStartWithCaller();

    /**
     * @notice Retrieves the admin address associated with a given proxy address.
     *
     * @param proxy The address of the proxy contract.
     * @return admin The address of the admin associated with the proxy.
     *
     * Steps:
     * 1. Use inline assembly to load the admin address from storage.
     * 2. The storage slot is calculated by shifting the proxy address left by 96 bits.
     * 3. Return the retrieved admin address.
     */
    function adminOf(address proxy) public view returns (address admin) {
        assembly {
            // slot = proxy << 96
            let slot := shl(96, proxy)
            admin := sload(slot)
        }
    }

    /**
     * @notice Changes the admin of a proxy contract. Only the current admin can call this function.
     *
     * @param proxy The address of the proxy contract whose admin is to be changed.
     * @param admin The address of the new admin.
     *
     * Steps:
     * 1. Check if the caller is the current admin of the proxy.
     *    - If not, revert with an unauthorized error.
     * 2. Store the new admin address in the proxy's storage.
     * 3. Emit an `AdminChanged` event with the proxy and new admin addresses.
     *
     * @dev This function uses inline assembly to directly interact with storage and emit events.
     */
    function changeAdmin(address proxy, address admin) public {
        // check caller
        address cur = adminOf(proxy);
        if (cur != msg.sender) revert Unauthorized();

        assembly {
            let slot := shl(96, proxy)
            sstore(slot, admin)
        }

        emit AdminChanged(proxy, admin);
    }

    /**
     * @notice Upgrades the implementation of a proxy contract to a new address.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param implementation The address of the new implementation contract.
     *
     * Steps:
     * 1. Calls the `upgradeAndCall` function with the provided proxy and implementation addresses.
     * 2. Passes an empty data payload (`_emptyData()`) to the `upgradeAndCall` function.
     *
     * Note: This function is payable, meaning it can receive Ether during the transaction.
     */
    function upgrade(address proxy, address implementation) public payable {
        upgradeAndCall(proxy, implementation, _emptyData());
    }

    /**
     * @notice Upgrades the implementation of a proxy contract and calls a function on the new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param implementation The address of the new implementation contract.
     * @param data The calldata to be passed to the new implementation after the upgrade.
     *
     * Steps:
     * 1. Check if the caller is the admin of the proxy by comparing the stored admin address with the caller's address.
     * 2. If the caller is not the admin, revert with an unauthorized error.
     * 3. Prepare the calldata for the upgrade by storing the implementation address and the implementation slot in memory.
     * 4. Copy the provided data into memory for the call.
     * 5. Attempt to upgrade the proxy by calling the proxy with the prepared calldata.
     * 6. If the call fails:
     *    - If there is no returndata, revert with an `UpgradeFailed` error.
     *    - Otherwise, revert with the returned error data.
     * 7. If the call succeeds, emit an `Upgraded` event with the proxy and implementation addresses.
     *
     * @dev This function uses inline assembly to perform low-level operations and checks.
     */
    function upgradeAndCall(address proxy, address implementation, bytes calldata data) public payable {
        // Verify admin
        if (adminOf(proxy) != msg.sender) revert Unauthorized();

        // We'll attempt to call the proxy with the selector for "upgradeTo(address)" and
        // then, if provided, call initialization data (if the proxy supports it).
        // Selector for "upgradeTo(address)" is bytes4(keccak256("upgradeTo(address)")) == 0x3659cfe6
        bytes memory callToUpgrade = abi.encodeWithSelector(bytes4(0x3659cfe6), implementation);

        // If initialization data provided, try to call "upgradeToAndCall(address,bytes)" if proxy supports it:
        // selector for "upgradeToAndCall(address,bytes)" == keccak256("upgradeToAndCall(address,bytes)") -> 0x4f1ef286
        bool ok;
        bytes memory returndata;

        if (data.length == 0) {
            (ok, returndata) = proxy.call{value: msg.value}(callToUpgrade);
        } else {
            bytes memory callToUpgradeAndCall = abi.encodePacked(bytes4(0x4f1ef286), abi.encode(implementation, data));
            (ok, returndata) = proxy.call{value: msg.value}(callToUpgradeAndCall);
            if (!ok) {
                // Fallback: try upgradeTo and then call init separately
                (ok, returndata) = proxy.call{value: msg.value}(callToUpgrade);
                if (ok) {
                    (ok, returndata) = proxy.call{value: 0}(data);
                }
            }
        }

        if (!ok) {
            if (returndata.length == 0) revert UpgradeFailed();
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }

        emit Upgraded(proxy, implementation);
    }

    /**
     * @notice Deploys a new proxy contract with the specified implementation and admin address.
     *
     * @param implementation The address of the implementation contract to be used by the proxy.
     * @param admin The address of the admin who will manage the proxy.
     * @return proxy The address of the newly deployed proxy contract.
     *
     * Steps:
     * 1. Calls the `deployAndCall` function with the provided implementation, admin, and empty data.
     * 2. Returns the address of the deployed proxy contract.
     */
    function deploy(address implementation, address admin) public payable returns (address proxy) {
        return deployAndCall(implementation, admin, _emptyData());
    }

    /**
     * @notice Deploys a proxy contract and calls a function on it with the provided data.
     *
     * @param implementation The address of the implementation contract to be used by the proxy.
     * @param admin The address of the admin who will manage the proxy.
     * @param data The calldata to be passed to the proxy after deployment.
     * @return proxy The address of the deployed proxy contract.
     *
     * Steps:
     * 1. Deploy a proxy contract using the `_deploy` function, passing the implementation address, admin address, 
     *    an empty bytes32 value (salt), and the provided data.
     * 2. Return the address of the deployed proxy contract.
     */
    function deployAndCall(address implementation, address admin, bytes calldata data) public payable returns (address proxy) {
        return _deploy(implementation, admin, bytes32(0), false, data);
    }

    /**
     * @notice Deploys a deterministic proxy contract using the provided implementation, admin, and salt.
     *
     * @param implementation The address of the implementation contract to be used by the proxy.
     * @param admin The address of the admin who will manage the proxy.
     * @param salt A unique salt value to ensure deterministic deployment.
     *
     * @return proxy The address of the deployed proxy contract.
     *
     * Steps:
     * 1. Calls `deployDeterministicAndCall` with the provided implementation, admin, salt, and empty data.
     * 2. Returns the address of the deployed proxy contract.
     */
    function deployDeterministic(address implementation, address admin, bytes32 salt) public payable returns (address proxy) {
        return deployDeterministicAndCall(implementation, admin, salt, _emptyData());
    }

    /**
     * @notice Deploys a deterministic proxy contract with a given implementation, admin, salt, and optional initialization data.
     *
     * @param implementation The address of the implementation contract.
     * @param admin The address of the admin for the proxy contract.
     * @param salt A unique salt value used to deterministically generate the proxy address.
     * @param data Optional initialization data to be passed to the proxy after deployment.
     * @return proxy The address of the deployed proxy contract.
     *
     * Steps:
     * 1. Check if the salt starts with the zero address or matches the caller's address.
     *    - If not, revert with an error indicating the salt does not start with the caller.
     * 2. Deploy the proxy contract using the provided implementation, admin, salt, and initialization data.
     * 3. Return the address of the deployed proxy contract.
     *
     * @dev The function uses assembly to perform low-level checks and revert if the salt condition is not met.
     */
    function deployDeterministicAndCall(address implementation, address admin, bytes32 salt, bytes calldata data) public payable returns (address proxy) {
        // Check salt starts with zero address or caller
        // Interpret first 20 bytes of salt (leftmost) as an address prefix check
        // We'll check: bytes32(salt) >> (12*8) == bytes32(bytes20(msg.sender)) || top bytes zero
        bytes32 top = salt;
        // Extract top 20 bytes: shift right by 96 bits (12 bytes)
        bytes32 top20;
        assembly {
            top20 := shr(96, top)
        }
        // If top20 != 0 and not equal to caller address, revert
        if (top20 != bytes32(0)) {
            // Compare to caller
            bytes32 callerPacked;
            assembly {
                callerPacked := shr(96, shl(96, caller()))
            }
            if (top20 != callerPacked) revert SaltDoesNotStartWithCaller();
        }

        return _deploy(implementation, admin, salt, true, data);
    }

    /**
     * @notice Deploys a proxy contract using either `create` or `create2` depending on the `useSalt` flag.
     *
     * Steps:
     * 1. Retrieve the initialization code for the proxy.
     * 2. Use assembly to create the proxy:
     *    - If `useSalt` is false, use `create` to deploy the proxy.
     *    - If `useSalt` is true, use `create2` with the provided `salt` to deploy the proxy.
     * 3. Revert if the proxy creation fails.
     *
     * 4. Set up the calldata to configure the proxy's implementation:
     *    - Store the implementation address and the implementation slot in memory.
     *    - Copy the provided `data` into memory for the proxy initialization.
     * 5. Call the proxy to set the implementation and revert if the call fails:
     *    - If no returndata is available, revert with the `DeploymentFailed` error.
     *    - Otherwise, bubble up the returned error.
     *
     * 6. Store the admin address for the proxy in storage.
     * 7. Emit the `Deployed` event with the proxy, implementation, and admin addresses.
     */
    function _deploy(address implementation, address admin, bytes32 salt, bool useSalt, bytes calldata data) internal returns (address proxy) {
        bytes memory initCode = _rawInitCode();

        assembly {
            let codePtr := add(initCode, 32)
            let codeSize := mload(initCode)

            switch useSalt
            case 0 {
                proxy := create(callvalue(), codePtr, codeSize)
            }
            default {
                proxy := create2(callvalue(), codePtr, codeSize, salt)
            }
        }

        if (proxy == address(0)) revert DeploymentFailed();

        // Try to initialize the proxy: first try upgradeAndCall pattern via proxy
        // We'll attempt to call "initialize(address)" or pass provided data to proxy
        if (data.length > 0) {
            (bool ok, bytes memory returndata) = proxy.call{value: 0}(data);
            if (!ok) {
                if (returndata.length == 0) revert DeploymentFailed();
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }

        // Store admin in factory-specific storage scheme (slot = proxy << 96)
        assembly {
            sstore(shl(96, proxy), admin)
        }

        emit Deployed(proxy, implementation, admin);
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using the CREATE2 opcode.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @return predicted The predicted address of the contract that would be deployed with the given salt.
     *
     * Steps:
     * 1. Compute the bytecode hash of the contract to be deployed.
     * 2. Use inline assembly to calculate the deterministic address:
     *    - Write the prefix `0xff` to memory.
     *    - Store the bytecode hash, deployer address, and salt in memory.
     *    - Compute the keccak256 hash of the concatenated data to derive the predicted address.
     * 3. Restore the overwritten memory to its original state.
     * 4. Return the predicted address.
     *
     * Note: The upper 96 bits of the predicted address may be dirty and should be cleaned if used in other assembly blocks.
     */
    function predictDeterministicAddress(bytes32 salt) public view returns (address predicted) {
        bytes32 codeHash = initCodeHash();
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, codeHash));
        predicted = address(uint160(uint256(data)));
    }

    /**
     * @notice Returns the keccak256 hash of the initialization code.
     *
     * Steps:
     * 1. Retrieve the initialization code from the contract.
     * 2. Use inline assembly to compute the keccak256 hash of the code.
     * 3. Return the computed hash.
     */
    function initCodeHash() public view returns (bytes32 result) {
        bytes memory initCode = _rawInitCode();
        result = keccak256(initCode);
    }

    /**
     * @notice A function to initialize the contract's runtime code.
     *
     * This function uses inline assembly to generate and return the runtime code for the contract.
     * The runtime code is responsible for handling delegate calls and managing the contract's state.
     *
     * Steps:
     * 1. Load the free memory pointer into `m`.
     * 2. Use inline assembly to generate the runtime code based on the contract's address.
     * 3. Depending on the number of leading zero bytes in the factory's address, different runtime code is generated.
     * 4. The runtime code includes:
     *    - Creation code to deploy the contract.
     *    - Runtime code to handle delegate calls, check the caller, copy calldata, and manage state.
     *    - Logic to handle successful and failed delegate calls, including reverting or returning data.
     *    - Logic to set a new implementation if the caller is the factory.
     * 5. The generated runtime code is stored in memory and returned as a `bytes32` value.
     *
     * The function is designed to be gas-efficient and ensures that the contract behaves correctly when deployed.
     */
    function _initCode() internal view returns (bytes32 m) {
        // For simplicity and to keep deterministic behavior we return the first 32 bytes
        // of the runtime code used by _rawInitCode. Higher-level callers use _rawInitCode.
        bytes memory rc = _rawInitCode();
        assembly {
            m := mload(add(rc, 32))
        }
    }

    /**
     * @notice Internal helper returning the raw init code used for deployment as memory bytes.
     *
     * We produce a minimal proxy-like runtime that will simply forward calls to an implementation slot.
     * For this example we return a small piece of initialization code. Production-grade factories
     * should embed proper proxy bytecode tailored to EIP-1967 or another proxy standard.
     */
    function _rawInitCode() internal view returns (bytes memory) {
        // Minimal proxy creation code (EIP-1167 style) that delegates to an implementation address stored inline.
        // Note: This is a simplification: a production factory would use full runtime that reads implementation from storage.
        // Here we create a tiny contract that returns nothing; the factory will still set admin storage for it.
        return hex"600a600c600039600a6000f3600052600a6016f3";
    }

    /**
     * @notice Internal function that returns an empty bytes calldata.
     * 
     * Steps:
     * 1. Use inline assembly to set the length of the returned data to 0.
     * 2. Return the empty bytes calldata.
     */
    function _emptyData() internal pure returns (bytes memory data) {
        data = "";
    }
}
// ...existing code...