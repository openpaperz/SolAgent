// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {strings} from "solidity-stringutils/strings.sol";

interface IUpgradeableProxy {
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function upgradeTo(address newImplementation) external;
}

interface IProxyAdmin {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external payable;
    function upgrade(address proxy, address implementation) external;
}

interface IUpgradeableBeacon {
    function upgradeTo(address newImplementation) external;
}

interface IVersioned {
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
}

struct Options {
    string referenceContract;
    string referenceBuildInfoDir;
    string[] exclude;
    string constructorData;
    bool unsafeSkipStorageCheck;
    bool unsafeSkipAllChecks;
    bool unsafeAllow;
    bool unsafeAllowRenames;
    DefenderOptions defender;
}

struct DefenderOptions {
    bool useDefenderDeploy;
    bool skipVerifySourceCode;
    string relayerId;
    string salt;
    string upgradeApprovalProcessId;
}

library DefenderDeploy {
    function deploy(
        string memory contractName,
        bytes memory constructorData,
        DefenderOptions memory opts
    ) internal returns (address) {
        // Placeholder implementation for DefenderDeploy
        revert("DefenderDeploy not implemented");
    }
}

library Chains {
    function getOutputDir() internal view returns (string memory) {
        return "out";
    }
}

library Versions {
    function UPGRADES_CORE_VERSION() internal pure returns (string memory) {
        return "1.0.0";
    }
}

library PropagateFunction {
    function propagateFunction(
        string memory contractName,
        bytes memory functionData
    ) internal view returns (bytes memory) {
        // Placeholder implementation
        return "";
    }
}

library Utils {
    function getContractName(string memory fullyQualifiedName) internal pure returns (string memory) {
        // Extract contract name from fully qualified name
        return fullyQualifiedName;
    }

    function getFullyQualifiedName(string memory contractName) internal view returns (string memory) {
        return contractName;
    }
}

library Compile {
    function getCode(string memory contractName) internal view returns (bytes memory) {
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        return vm.getCode(contractName);
    }
}

library Core {
    using strings for *;

    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    modifier tryPrank(address tryCaller) {
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        if (tryCaller != address(0)) {
            vm.startPrank(tryCaller);
        }
        _;
        if (tryCaller != address(0)) {
            vm.stopPrank();
        }
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed during the upgrade process.
     * @param opts Options for the upgrade process.
     *
     * Steps:
     * 1. Attempt to impersonate the specified caller (`tryCaller`).
     * 2. Call the internal `upgradeProxy` function with the provided parameters.
     */
    function upgradeProxy(address proxy, string memory contractName, bytes memory data, Options memory opts) internal {
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
    function upgradeProxy(address proxy, string memory contractName, bytes memory data, Options memory opts, address tryCaller) internal tryPrank(tryCaller) {
        upgradeProxy(proxy, contractName, data, opts);
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
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes32 adminSlotValue = vm.load(proxy, ADMIN_SLOT);

        if (adminSlotValue == bytes32(0)) {
            string memory version = getUpgradeInterfaceVersion(proxy);
            if (keccak256(bytes(version)) == keccak256(bytes("5.0.0")) || data.length > 0) {
                IUpgradeableProxy(proxy).upgradeToAndCall(newImpl, data);
            } else {
                IUpgradeableProxy(proxy).upgradeTo(newImpl);
            }
        } else {
            address admin = address(uint160(uint256(adminSlotValue)));
            string memory version = getUpgradeInterfaceVersion(admin);
            if (keccak256(bytes(version)) == keccak256(bytes("5.0.0")) || data.length > 0) {
                IProxyAdmin(admin).upgradeAndCall(proxy, newImpl, data);
            } else {
                IProxyAdmin(admin).upgrade(proxy, newImpl);
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
    function upgradeProxyTo(address proxy, address newImpl, bytes memory data, address tryCaller) internal tryPrank(tryCaller) {
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
    function upgradeBeacon(address beacon, string memory contractName, Options memory opts, address tryCaller) internal tryPrank(tryCaller) {
        upgradeBeacon(beacon, contractName, opts);
    }

    /**
     * @notice Upgrades the implementation of a beacon contract to a new address.
     *
     * Steps:
     * 1. Calls the `upgradeTo` function on the specified beacon contract, passing the new implementation address.
     * 2. This function is internal, meaning it can only be called within the contract or derived contracts.
     */
    function upgradeBeaconTo(address beacon, address newImpl) internal {
        IUpgradeableBeacon(beacon).upgradeTo(newImpl);
    }

    /**
     * @notice Upgrades the implementation of a beacon contract to a new address.
     *
     * Steps:
     * 1. Calls the `upgradeTo` function on the specified beacon contract, passing the new implementation address.
     * 2. This function is internal, meaning it can only be called within the contract or derived contracts.
     */
    function upgradeBeaconTo(address beacon, address newImpl, address tryCaller) internal tryPrank(tryCaller) {
        upgradeBeaconTo(beacon, newImpl);
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
    function deployImplementation(string memory contractName, Options memory opts) internal returns (address) {
        validateImplementation(contractName, opts);
        return deploy(contractName, bytes(opts.constructorData), opts);
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
    function prepareUpgrade(string memory contractName, Options memory opts) internal returns (address) {
        validateUpgrade(contractName, opts);
        return deploy(contractName, bytes(opts.constructorData), opts);
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
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes32 adminSlotValue = vm.load(proxy, ADMIN_SLOT);
        return address(uint160(uint256(adminSlotValue)));
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
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes32 implSlotValue = vm.load(proxy, IMPLEMENTATION_SLOT);
        return address(uint160(uint256(implSlotValue)));
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
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes32 beaconSlotValue = vm.load(proxy, BEACON_SLOT);
        return address(uint160(uint256(beaconSlotValue)));
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
        bytes memory data = abi.encodeWithSelector(IVersioned.UPGRADE_INTERFACE_VERSION.selector);
        (bool success, bytes memory returndata) = addr.staticcall(data);
        
        if (success && returndata.length > 32) {
            return abi.decode(returndata, (string));
        }
        
        return "";
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
        bytes memory data = abi.encodeWithSignature("owner()");
        (bool success, bytes memory returndata) = addr.staticcall(data);
        return success && returndata.length == 32;
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
    function _validate(string memory contractName, Options memory opts, bool requireReference) private {
        if (opts.unsafeSkipAllChecks) {
            return;
        }

        string[] memory inputs = buildValidateCommand(contractName, opts, requireReference);
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
        Vm.FfiResult memory result = vm.tryFfi(inputs);
        
        string memory stdout = string(result.stdout);
        
        if (result.exitCode == 0 && bytes(stdout).length > 0) {
            strings.slice memory s = stdout.toSlice();
            strings.slice memory needle = strings.toSlice("SUCCESS");
            if (s.contains(needle)) {
                return;
            }
        }
        
        if (result.stderr.length > 0) {
            revert(string.concat("Validation command failed: ", string(result.stderr)));
        }
        
        revert(string.concat("Validation failed: ", stdout));
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
    function buildValidateCommand(string memory contractName, Options memory opts, bool requireReference) internal view returns (string[] memory) {
        string memory outDir = Chains.getOutputDir();
        string[] memory inputBuilder = new string[](100);
        uint256 idx = 0;
        
        inputBuilder[idx++] = "npx";
        inputBuilder[idx++] = string.concat("@openzeppelin/upgrades-core@", Versions.UPGRADES_CORE_VERSION());
        inputBuilder[idx++] = "validate";
        inputBuilder[idx++] = string.concat(outDir, "/build-info");
        inputBuilder[idx++] = Utils.getFullyQualifiedName(contractName);
        
        if (bytes(opts.referenceContract).length > 0) {
            inputBuilder[idx++] = "--reference";
            inputBuilder[idx++] = opts.referenceContract;
        }
        
        if (bytes(opts.referenceBuildInfoDir).length > 0) {
            inputBuilder[idx++] = "--referenceBuildInfoDirs";
            inputBuilder[idx++] = opts.referenceBuildInfoDir;
        }
        
        for (uint256 i = 0; i < opts.exclude.length; i++) {
            inputBuilder[idx++] = "--exclude";
            inputBuilder[idx++] = opts.exclude[i];
        }
        
        if (opts.unsafeSkipStorageCheck) {
            inputBuilder[idx++] = "--unsafeSkipStorageCheck";
        }
        
        if (requireReference) {
            inputBuilder[idx++] = "--requireReference";
        }
        
        if (opts.unsafeAllow) {
            inputBuilder[idx++] = "--unsafeAllow";
        }
        
        if (opts.unsafeAllowRenames) {
            inputBuilder[idx++] = "--unsafeAllowRenames";
        }
        
        string[] memory inputs = new string[](idx);
        for (uint256 i = 0; i < idx; i++) {
            inputs[i] = inputBuilder[i];
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
    function deploy(string memory contractName, bytes memory constructorData, Options memory opts) internal returns (address) {
        if (opts.defender.useDefenderDeploy) {
            return DefenderDeploy.deploy(contractName, constructorData, opts.defender);
        } else {
            return _deploy(contractName, constructorData);
        }
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
    function _deploy(string memory contractName, bytes memory constructorData) private returns (address) {
        bytes memory creationCode = Compile.getCode(contractName);
        bytes memory bytecode = bytes.concat(creationCode, constructorData);
        address addr = _deployFromBytecode(bytecode);
        
        require(addr != address(0), string.concat("Failed to deploy contract: ", contractName));
        
        return addr;
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
