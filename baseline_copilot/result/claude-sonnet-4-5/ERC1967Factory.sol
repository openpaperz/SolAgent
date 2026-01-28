// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice ERC1967 proxy factory for deploying and managing upgradeable proxy contracts.
contract ERC1967Factory {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to perform the operation.
    error Unauthorized();

    /// @dev The proxy deployment has failed.
    error DeploymentFailed();

    /// @dev The proxy upgrade has failed.
    error UpgradeFailed();

    /// @dev The salt does not start with the caller.
    error SaltDoesNotStartWithCaller();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when a proxy contract is deployed.
    event Deployed(address indexed proxy, address indexed implementation, address indexed admin);

    /// @dev Emitted when a proxy contract is upgraded.
    event Upgraded(address indexed proxy, address indexed implementation);

    /// @dev Emitted when the admin of a proxy is changed.
    event AdminChanged(address indexed proxy, address indexed admin);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONSTANTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ERC-1967 implementation slot.
    /// `uint256(keccak256("eip1967.proxy.implementation")) - 1`.
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ADMIN OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
            mstore(0x00, shl(96, proxy))
            admin := sload(keccak256(0x00, 0x14))
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
        assembly {
            mstore(0x00, shl(96, proxy))
            let adminSlot := keccak256(0x00, 0x14)
            if iszero(eq(caller(), sload(adminSlot))) {
                mstore(0x00, 0x82b42900) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
            sstore(adminSlot, admin)
            log3(0x00, 0x00, _ADMIN_CHANGED_EVENT_SIGNATURE, proxy, admin)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UPGRADE OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
    function upgradeAndCall(address proxy, address implementation, bytes calldata data)
        public
        payable
    {
        assembly {
            mstore(0x00, shl(96, proxy))
            if iszero(eq(caller(), sload(keccak256(0x00, 0x14)))) {
                mstore(0x00, 0x82b42900) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, implementation)
            mstore(0x20, _IMPLEMENTATION_SLOT)
            calldatacopy(0x40, data.offset, data.length)
            if iszero(call(gas(), proxy, callvalue(), 0x00, add(0x40, data.length), 0x00, 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, 0x4c9c8ce3) // `UpgradeFailed()`.
                    revert(0x1c, 0x04)
                }
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            log3(0x00, 0x00, _UPGRADED_EVENT_SIGNATURE, proxy, implementation)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DEPLOY OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
    function deploy(address implementation, address admin)
        public
        payable
        returns (address proxy)
    {
        proxy = deployAndCall(implementation, admin, _emptyData());
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
    function deployAndCall(address implementation, address admin, bytes calldata data)
        public
        payable
        returns (address proxy)
    {
        proxy = _deploy(implementation, admin, bytes32(0), false, data);
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
    function deployDeterministic(address implementation, address admin, bytes32 salt)
        public
        payable
        returns (address proxy)
    {
        proxy = deployDeterministicAndCall(implementation, admin, salt, _emptyData());
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
    function deployDeterministicAndCall(
        address implementation,
        address admin,
        bytes32 salt,
        bytes calldata data
    ) public payable returns (address proxy) {
        assembly {
            let m := mload(0x40)
            let spillSalt := shr(96, salt)
            if iszero(or(iszero(spillSalt), eq(spillSalt, caller()))) {
                mstore(0x00, 0x2f634836) // `SaltDoesNotStartWithCaller()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m)
        }
        proxy = _deploy(implementation, admin, salt, true, data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
    function _deploy(
        address implementation,
        address admin,
        bytes32 salt,
        bool useSalt,
        bytes calldata data
    ) internal returns (address proxy) {
        bytes32 m = _initCode();
        assembly {
            let n := mload(m)
            if iszero(useSalt) { proxy := create(0, add(m, 0x20), n) }
            if useSalt { proxy := create2(0, add(m, 0x20), n, salt) }
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, implementation)
            mstore(0x20, _IMPLEMENTATION_SLOT)
            calldatacopy(0x40, data.offset, data.length)
            if iszero(call(gas(), proxy, callvalue(), 0x00, add(0x40, data.length), 0x00, 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                    revert(0x1c, 0x04)
                }
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            mstore(0x00, shl(96, proxy))
            sstore(keccak256(0x00, 0x14), admin)
            log4(0x00, 0x00, _DEPLOYED_EVENT_SIGNATURE, proxy, implementation, admin)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ADDRESS PREDICTION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        bytes32 hash = initCodeHash();
        assembly {
            let m := mload(0x40)
            mstore(0x00, address())
            mstore8(0x0b, 0xff)
            mstore(0x20, salt)
            mstore(0x40, hash)
            predicted := keccak256(0x0b, 0x55)
            mstore(0x40, m)
        }
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
        bytes32 m = _initCode();
        assembly {
            result := keccak256(add(m, 0x20), mload(m))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INIT CODE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        assembly {
            m := mload(0x40)
            let n := 0x1e
            switch shr(88, address())
            case 0 {
                mstore(m, 0xfe60806040526000803760406000803e60403d3d393d3d3d363d3d37363d73)
                mstore(add(m, 0x1e), shl(0x58, address()))
                mstore(add(m, 0x33), 0x5af43d3d93803e606057fd5bf300000000000000000000000000000000000000)
                n := 0x3b
            }
            default {
                mstore(m, 0xfe60806040526000803760406000803e60403d3d393d3d3d363d3d37363d6c)
                mstore(add(m, 0x1e), shl(0x70, address()))
                mstore(add(m, 0x2e), 0x5af43d3d93803e602d57fd5bf300000000000000000000000000000000000000)
                n := 0x36
            }
            mstore(m, n)
            mstore(0x40, add(m, add(0x20, n)))
        }
    }

    /**
     * @notice Internal function that returns an empty bytes calldata.
     * 
     * Steps:
     * 1. Use inline assembly to set the length of the returned data to 0.
     * 2. Return the empty bytes calldata.
     */
    function _emptyData() internal pure returns (bytes calldata data) {
        assembly {
            data.length := 0
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EVENT SIGNATURES                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev `keccak256(bytes("Deployed(address,address,address)"))`.
    uint256 private constant _DEPLOYED_EVENT_SIGNATURE =
        0x09e48df7857bd0c1e0d31bb8a85d42cf1874817895f171c917f6ee2cea73ec20;

    /// @dev `keccak256(bytes("Upgraded(address,address)"))`.
    uint256 private constant _UPGRADED_EVENT_SIGNATURE =
        0x5d611f318680d00598bb735d61bacf0c514c6b50e1e5ad30040a4df2b12791c7;

    /// @dev `keccak256(bytes("AdminChanged(address,address)"))`.
    uint256 private constant _ADMIN_CHANGED_EVENT_SIGNATURE =
        0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f;
}
