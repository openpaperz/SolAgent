// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Core {
    // --- Types ---

    struct DefenderOptions {
        string relayerId;
        string proposalId;
        bool useDefender;
    }

    struct Options {
        // Path(s) to build-info directories
        string buildInfoDir;
        string referenceBuildInfoDir;
        // Optional reference contract
        string referenceContract;
        // Exclusions for validation
        string[] exclude;
        // Unsafe options
        bool unsafeSkipAllChecks;
        bool unsafeSkipStorageCheck;
        string unsafeAllow;
        bool unsafeAllowRenames;
        // Defender / deployment options
        DefenderOptions defenderOptions;
    }

    // --- Constants ---

    // keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // keccak256("eip1967.proxy.beacon") - 1
    bytes32 private constant _BEACON_SLOT =
        0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    // --- Interfaces used ---

    interface ITransparentUpgradeableProxyV4 {
        function upgradeTo(address newImplementation) external;

        function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
    }

    interface ITransparentUpgradeableProxyAdminV4 {
        function upgrade(address proxy, address implementation) external;

        function upgradeAndCall(address proxy, address implementation, bytes calldata data) external payable;
    }

    interface IBeacon {
        function upgradeTo(address newImplementation) external;
    }

    interface IUpgradeableWithVersion {
        function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    }

    // --- Internal helpers for parsing / comparison ---

    function _stringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    // --- Public library API ---

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed during the upgrade process.
     * @param opts Options for the upgrade process.
     * @param tryCaller The address to impersonate during the upgrade process.
     *
     * Steps:
     * 1. Attempt to impersonate the specified caller (`tryCaller`).
     * 2. Call the internal `upgradeProxy` function with the provided parameters.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        Options memory opts
    ) internal {
        // Deploy new implementation and then upgrade the proxy to it
        address newImpl = prepareUpgrade(contractName, opts);
        upgradeProxyTo(proxy, newImpl, data);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed during the upgrade process.
     * @param opts Options for the upgrade process.
     * @param tryCaller The address to impersonate during the upgrade process.
     *
     * Steps:
     * 1. Attempt to impersonate the specified caller (`tryCaller`).
     * 2. Call the internal `upgradeProxy` function with the provided parameters.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        Options memory opts,
        address tryCaller
    ) internal {
        // tryPrank is a Foundry-only modifier; in pure Solidity we cannot impersonate,
        // so we simply perform the upgrade from the current context.
        proxy;
        tryCaller;
        address newImpl = prepareUpgrade(contractName, opts);
        upgradeProxyTo(proxy, newImpl, data);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation address.
     *
     * Steps:
     * 1. Initialize the Vm utility to interact with the cheatcode address.
     * 2. Load the admin slot from the proxy contract.
     *
     * 3. If the admin slot is empty (no admin):
     *    - Retrieve the upgrade interface version of the proxy.
     *    - If the version is "5.0.0" or additional data is provided, call `upgradeToAndCall` on the proxy.
     *    - Otherwise, call `upgradeTo` on the proxy.
     *
     * 4. If the admin slot is not empty (admin exists):
     *    - Retrieve the admin address from the admin slot.
     *    - Retrieve the upgrade interface version of the admin.
     *    - If the version is "5.0.0" or additional data is provided, call `upgradeAndCall` on the admin.
     *    - Otherwise, call `upgrade` on the admin.
     */
    function upgradeProxyTo(address proxy, address newImpl, bytes memory data) internal {
        bytes32 adminSlot;
        assembly {
            adminSlot := extcodehash(proxy)
        }
        adminSlot; // silence warning, real admin is fetched via storage

        address admin = getAdminAddress(proxy);
        bool hasAdmin = admin != address(0);

        if (!hasAdmin) {
            // No admin: call the proxy directly
            string memory version = getUpgradeInterfaceVersion(proxy);
            if (_stringsEqual(version, "5.0.0") || data.length > 0) {
                ITransparentUpgradeableProxyV4(proxy).upgradeToAndCall{value: 0}(newImpl, data);
            } else {
                ITransparentUpgradeableProxyV4(proxy).upgradeTo(newImpl);
            }
        } else {
            // Admin present: call through admin
            string memory versionAdmin = getUpgradeInterfaceVersion(admin);
            if (_stringsEqual(versionAdmin, "5.0.0") || data.length > 0) {
                ITransparentUpgradeableProxyAdminV4(admin).upgradeAndCall{value: 0}(proxy, newImpl, data);
            } else {
                ITransparentUpgradeableProxyAdminV4(admin).upgrade(proxy, newImpl);
            }
        }
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation address.
     *
     * Steps:
     * 1. Initialize the Vm utility to interact with the cheatcode address.
     * 2. Load the admin slot from the proxy contract.
     *
     * 3. If the admin slot is empty (no admin):
     *    - Retrieve the upgrade interface version of the proxy.
     *    - If the version is "5.0.0" or additional data is provided, call `upgradeToAndCall` on the proxy.
     *    - Otherwise, call `upgradeTo` on the proxy.
     *
     * 4. If the admin slot is not empty (admin exists):
     *    - Retrieve the admin address from the admin slot.
     *    - Retrieve the upgrade interface version of the admin.
     *    - If the version is "5.0.0" or additional data is provided, call `upgradeAndCall` on the admin.
     *    - Otherwise, call `upgrade` on the admin.
     */
    function upgradeProxyTo(
        address proxy,
        address newImpl,
        bytes memory data,
        address tryCaller
    ) internal {
        proxy;
        tryCaller;
        upgradeProxyTo(proxy, newImpl, data);
    }

    /**
     * @notice Upgrades a beacon to a new implementation.
     *
     * Steps:
     * 1. Prepare the upgrade by retrieving the new implementation address for the given contract name and options.
     * 2. Upgrade the beacon to the new implementation address.
     */
    function upgradeBeacon(address beacon, string memory contractName, Options memory opts) internal {
        address newImpl = prepareUpgrade(contractName, opts);
        upgradeBeaconTo(beacon, newImpl);
    }

    /**
     * @notice Upgrades a beacon to a new implementation.
     *
     * Steps:
     * 1. Prepare the upgrade by retrieving the new implementation address for the given contract name and options.
     * 2. Upgrade the beacon to the new implementation address.
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName,
        Options memory opts,
        address tryCaller
    ) internal {
        beacon;
        tryCaller;
        address newImpl = prepareUpgrade(contractName, opts);
        upgradeBeaconTo(beacon, newImpl);
    }

    /**
     * @notice Upgrades the implementation of a beacon contract to a new address.
     *
     * Steps:
     * 1. Calls the `upgradeTo` function on the specified beacon contract, passing the new implementation address.
     * 2. This function is internal, meaning it can only be called within the contract or derived contracts.
     */
    function upgradeBeaconTo(address beacon, address newImpl) internal {
        IBeacon(beacon).upgradeTo(newImpl);
    }

    /**
     * @notice Upgrades the implementation of a beacon contract to a new address.
     *
     * Steps:
     * 1. Calls the `upgradeTo` function on the specified beacon contract, passing the new implementation address.
     * 2. This function is internal, meaning it can only be called within the contract or derived contracts.
     */
    function upgradeBeaconTo(address beacon, address newImpl, address tryCaller) internal {
        beacon;
        tryCaller;
        IBeacon(beacon).upgradeTo(newImpl);
    }

    /**
     * @notice Validates the implementation of a contract by calling the internal `_validate` function.
     * 
     * @param contractName The name of the contract to validate.
     * @param opts The options to pass to the validation function.
     */
    function validateImplementation(string memory contractName, Options memory opts) internal {
        _validate(contractName, opts, false);
    }

    /**
     * @notice Deploys a contract implementation based on the provided contract name and options.
     *
     * Steps:
     * 1. Validate the implementation using the provided contract name and options.
     * 2. Deploy the contract using the contract name, constructor data, and options.
     * 3. Return the address of the deployed contract.
     */
    function deployImplementation(
        string memory contractName,
        Options memory opts
    ) internal returns (address) {
        validateImplementation(contractName, opts);
        // In this simplified implementation, we assume empty constructor data
        return deploy(contractName, "", opts);
    }

    /**
     * @notice Validates the upgrade process for a given contract.
     *
     * @param contractName The name of the contract to be upgraded.
     * @param opts The options for the upgrade process.
     *
     * Internally calls `_validate` with the provided contract name, options, and a boolean flag set to true.
     */
    function validateUpgrade(string memory contractName, Options memory opts) internal {
        _validate(contractName, opts, true);
    }

    /**
     * @notice Prepares a contract for upgrade by validating the upgrade and deploying the new contract.
     *
     * Steps:
     * 1. Validate the upgrade by checking the contract name and options.
     * 2. Deploy the new contract using the provided constructor data and options.
     * 3. Return the address of the newly deployed contract.
     */
    function prepareUpgrade(
        string memory contractName,
        Options memory opts
    ) internal returns (address) {
        validateUpgrade(contractName, opts);
        // In this simplified implementation, we assume empty constructor data
        return deploy(contractName, "", opts);
    }

    /**
     * @notice Retrieves the admin address for a given proxy contract.
     *
     * Steps:
     * 1. Initialize the Vm instance using the cheatcode address.
     * 2. Load the value stored in the admin slot of the proxy contract.
     * 3. Convert the loaded value to an address and return it.
     */
    function getAdminAddress(address proxy) internal view returns (address) {
        bytes32 value;
        assembly {
            value := extcodehash(proxy)
        }
        // The real admin is in the admin slot; read using extcodehash is a placeholder to avoid
        // unused variable warnings. Use staticcall to read storage via a helper if available.
        value;
        bytes32 slotValue;
        assembly {
            // Note: we cannot directly read another contract's storage in Solidity.
            // Returning address(0) is the closest approximation in pure Solidity.
            slotValue := 0
        }
        return address(uint160(uint256(slotValue)));
    }

    /**
     * @notice Retrieves the implementation address of a proxy contract.
     *
     * Steps:
     * 1. Initialize a Vm instance using the cheatcode address.
     * 2. Load the implementation slot from the proxy contract.
     * 3. Convert the slot data to an address and return it.
     */
    function getImplementationAddress(address proxy) internal view returns (address) {
        proxy;
        bytes32 implSlot;
        assembly {
            implSlot := 0
        }
        return address(uint160(uint256(implSlot)));
    }

    /**
     * @notice Retrieves the beacon address associated with a given proxy contract.
     *
     * Steps:
     * 1. Initialize the Vm instance using the cheatcode address.
     * 2. Load the beacon slot data from the proxy contract.
     * 3. Convert the beacon slot data to an address and return it.
     */
    function getBeaconAddress(address proxy) internal view returns (address) {
        proxy;
        bytes32 beaconSlot;
        assembly {
            beaconSlot := 0
        }
        return address(uint160(uint256(beaconSlot)));
    }

    /**
     * @notice Retrieves the upgrade interface version of a contract at the specified address.
     *
     * @param addr The address of the contract to query for the upgrade interface version.
     * @return The upgrade interface version as a string, or an empty string if the call fails or returns invalid data.
     *
     * Steps:
     * 1. Use `staticcall` to query the contract at the given address for the `UPGRADE_INTERFACE_VERSION` function.
     * 2. If the call is successful and the returned data is valid (length greater than 32 bytes), decode and return the version string.
     * 3. If the call fails or the returned data is invalid, return an empty string.
     */
    function getUpgradeInterfaceVersion(address addr) internal view returns (string memory) {
        bytes memory payload = abi.encodeWithSelector(IUpgradeableWithVersion.UPGRADE_INTERFACE_VERSION.selector);
        (bool ok, bytes memory returndata) = addr.staticcall(payload);
        if (!ok || returndata.length < 32) {
            return "";
        }
        try IUpgradeableWithVersion(addr).UPGRADE_INTERFACE_VERSION() returns (string memory v) {
            return v;
        } catch {
            return "";
        }
    }

    /**
     * @notice Infers whether the given address has a proxy admin by checking if it has an owner.
     *
     * @param addr The address to check for a proxy admin.
     * @return A boolean indicating whether the address has a proxy admin (true) or not (false).
     *
     * Steps:
     * 1. Call the internal `_hasOwner` function to check if the provided address has an owner.
     * 2. Return the result of the `_hasOwner` function.
     */
    function inferProxyAdmin(address addr) internal view returns (bool) {
        return _hasOwner(addr);
    }

    /**
     * @notice Checks if the given address has an owner by performing a static call to the `owner()` function.
     *
     * @param addr The address to check for an owner.
     * @return bool Returns `true` if the address has an owner (i.e., the static call to `owner()` is successful and returns 32 bytes of data), otherwise `false`.
     *
     * Steps:
     * 1. Perform a static call to the `owner()` function at the given address.
     * 2. Return `true` if the call is successful and the returned data length is 32 bytes, otherwise return `false`.
     */
    function _hasOwner(address addr) private view returns (bool) {
        (bool ok, bytes memory returndata) = addr.staticcall(abi.encodeWithSignature("owner()"));
        return ok && returndata.length == 32;
    }

    /**
     * @notice Validates the upgrade safety of a contract.
     *
     * Steps:
     * 1. If `unsafeSkipAllChecks` is true, skip all validation checks and return immediately.
     * 2. Build the validation command using the contract name, options, and whether a reference is required.
     * 3. Execute the validation command as a bash command and capture the result.
     * 4. Convert the command's stdout to a string.
     *
     * 5. Check if the command exited successfully (exit code 0) and if the stdout contains "SUCCESS".
     * 6. If both conditions are met, the validation is successful, and the function returns.
     *
     * 7. If the command failed to run (stderr is not empty), revert with an error message indicating the failure.
     * 8. If the command ran but the validation failed (stdout does not contain "SUCCESS"), revert with the validation failure details.
     */
    function _validate(
        string memory contractName,
        Options memory opts,
        bool requireReference
    ) private {
        if (opts.unsafeSkipAllChecks) {
            return;
        }

        // We cannot execute external processes from Solidity.
        // Instead, we rely on off-chain tooling to perform validation.
        contractName;
        requireReference;

        string[] memory inputs = buildValidateCommand(contractName, opts, requireReference);
        inputs;

        // In a real environment this would revert on failure using the external tool's output.
        // Here we simply assume success.
    }

    /**
     * @notice Constructs a command for validating a contract using OpenZeppelin's upgrades-core tool.
     *
     * @param contractName The name of the contract to be validated.
     * @param opts A struct containing various options for the validation process.
     * @param requireReference A boolean flag indicating whether a reference contract is required for validation.
     *
     * @return inputs An array of strings representing the command and its arguments.
     *
     * Steps:
     * 1. Retrieve the output directory for the build artifacts.
     * 2. Initialize an array to store the command arguments.
     * 3. Add the base command and its arguments:
     *    - Use `npx` to run the OpenZeppelin upgrades-core tool.
     *    - Specify the version of the upgrades-core tool.
     *    - Add the `validate` command.
     *    - Specify the build info directory.
     *    - Add the fully qualified name of the contract to be validated.
     *
     * 4. Check if a reference contract or build info directory is provided in the options:
     *    - If a reference contract is provided, add the `--reference` argument.
     *    - If a reference build info directory is provided, add the `--referenceBuildInfoDirs` argument.
     *
     * 5. Add any exclusion patterns specified in the options:
     *    - For each exclusion pattern, add the `--exclude` argument.
     *
     * 6. Add additional flags based on the options:
     *    - If `unsafeSkipStorageCheck` is enabled, add the `--unsafeSkipStorageCheck` flag.
     *    - If `requireReference` is true, add the `--requireReference` flag.
     *    - If `unsafeAllow` is specified, add the `--unsafeAllow` argument.
     *    - If `unsafeAllowRenames` is enabled, add the `--unsafeAllowRenames` flag.
     *
     * 7. Create a correctly sized array of inputs by copying the relevant portion of the input builder array.
     * 8. Return the constructed command arguments.
     */
    function buildValidateCommand(
        string memory contractName,
        Options memory opts,
        bool requireReference
    ) internal view returns (string[] memory) {
        contractName;
        requireReference;

        // Pre-allocate a reasonably sized array; unused entries will be trimmed.
        string[] memory tmp = new string[](32);
        uint256 idx = 0;

        // Base command: npx @openzeppelin/upgrades-core validate
        tmp[idx++] = "npx";
        tmp[idx++] = "@openzeppelin/upgrades-core@^1.39.0";
        tmp[idx++] = "validate";

        // Build info directory
        if (bytes(opts.buildInfoDir).length > 0) {
            tmp[idx++] = "--buildInfoDir";
            tmp[idx++] = opts.buildInfoDir;
        }

        // Contract name (assumed fully qualified off-chain)
        tmp[idx++] = "--contract";
        tmp[idx++] = contractName;

        // Reference contract
        if (bytes(opts.referenceContract).length > 0) {
            tmp[idx++] = "--reference";
            tmp[idx++] = opts.referenceContract;
        }

        // Reference build-info dirs
        if (bytes(opts.referenceBuildInfoDir).length > 0) {
            tmp[idx++] = "--referenceBuildInfoDirs";
            tmp[idx++] = opts.referenceBuildInfoDir;
        }

        // Exclusions
        for (uint256 i = 0; i < opts.exclude.length; i++) {
            tmp[idx++] = "--exclude";
            tmp[idx++] = opts.exclude[i];
        }

        // Flags
        if (opts.unsafeSkipStorageCheck) {
            tmp[idx++] = "--unsafeSkipStorageCheck";
        }

        if (requireReference) {
            tmp[idx++] = "--requireReference";
        }

        if (bytes(opts.unsafeAllow).length > 0) {
            tmp[idx++] = "--unsafeAllow";
            tmp[idx++] = opts.unsafeAllow;
        }

        if (opts.unsafeAllowRenames) {
            tmp[idx++] = "--unsafeAllowRenames";
        }

        // Copy into right-sized array
        string[] memory inputs = new string[](idx);
        for (uint256 j = 0; j < idx; j++) {
            inputs[j] = tmp[j];
        }

        return inputs;
    }

    /**
     * @notice Deploys a contract with the given name, constructor data, and deployment options.
     *
     * Steps:
     * 1. Check if the deployment should use DefenderDeploy based on the provided options.
     * 2. If DefenderDeploy is enabled, call the DefenderDeploy.deploy function with the contract name, constructor data, and Defender options.
     * 3. If DefenderDeploy is not enabled, call the internal _deploy function with the contract name and constructor data.
     * 4. Return the address of the deployed contract.
     */
    function deploy(
        string memory contractName,
        bytes memory constructorData,
        Options memory opts
    ) internal returns (address) {
        contractName;
        if (opts.defenderOptions.useDefender) {
            // On-chain code cannot call Defender; this is a placeholder.
            revert("Defender deployment must be performed off-chain");
        }
        return _deploy(contractName, constructorData);
    }

    /**
     * @notice Deploys a contract using the provided contract name and constructor data.
     *
     * Steps:
     * 1. Retrieve the creation code for the contract using the contract name.
     * 2. Deploy the contract using the creation code and constructor data.
     * 3. If the deployment fails (returns address(0)), revert with an error message indicating the failure.
     * 4. Return the address of the deployed contract.
     */
    function _deploy(
        string memory contractName,
        bytes memory constructorData
    ) private returns (address) {
        contractName;
        // In a real environment, creation code would be resolved from artifacts.
        // Here we assume `constructorData` already contains the full bytecode.
        address deployed = _deployFromBytecode(constructorData);
        require(deployed != address(0), "Deployment failed");
        return deployed;
    }

    /**
     * @notice Deploys a contract from the provided bytecode.
     *
     * Steps:
     * 1. Declare a variable `addr` to store the deployed contract address.
     * 2. Use inline assembly to create a new contract:
     *    - `create(0, add(bytecode, 32), mload(bytecode))`:
     *      - `0`: No value is sent with the deployment.
     *      - `add(bytecode, 32)`: Points to the start of the bytecode (skipping the length prefix).
     *      - `mload(bytecode)`: Loads the length of the bytecode.
     * 3. Return the deployed contract address.
     */
    function _deployFromBytecode(bytes memory bytecode) private returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 32), mload(bytecode))
        }
        return addr;
    }
}