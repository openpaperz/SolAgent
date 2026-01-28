// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {strings} from "solidity-stringutils/strings.sol";

/**
 * @dev Options for deployment via Defender.
 */
struct DefenderOptions {
    bool skipVerifySourceCode;
    bool skipLicenseType;
    string licenseType;
    string relayerId;
    bytes32 salt;
    uint256 gasLimit;
    uint256 gasPrice;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    string metadata;
}

/**
 * @dev Options for upgrade proposals.
 */
struct Options {
    string upgradeApprovalProcessId;
}

/**
 * @dev Contract information including path and license.
 */
struct ContractInfo {
    string contractName;
    string contractPath;
    string license;
    string sourceCodeHash;
    string shortName;
}

/**
 * @dev Response from a propose upgrade operation.
 */
struct ProposeUpgradeResponse {
    string proposalId;
    string url;
}

/**
 * @dev Response from an approval process query.
 */
struct ApprovalProcessResponse {
    string approvalProcessId;
    address via;
    string viaType;
}

library DefenderDeploy {
    using strings for *;

    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    /**
     * @notice Deploys a contract using the provided contract name, constructor data, and deployment options.
     *
     * @param contractName The name of the contract to be deployed.
     * @param constructorData The encoded constructor arguments for the contract.
     * @param defenderOpts The deployment options, including any specific configurations for the Defender service.
     *
     * @return The address of the deployed contract.
     *
     * Steps:
     * 1. Retrieve the output directory where the contract artifacts are stored.
     * 2. Fetch the contract information (e.g., source code hash, short name) using the contract name and output directory.
     * 3. Construct the build info file path using the contract's source code hash, short name, and output directory.
     *
     * 4. Build the deployment command using the contract information, build info file, constructor data, and deployment options.
     * 5. Execute the deployment command as a bash command using FFI (Foreign Function Interface).
     *
     * 6. Check the exit code of the deployment command:
     *    - If the exit code is not 0, revert with an error message indicating the deployment failure.
     *    - If the exit code is 0, parse the deployed contract address from the command's standard output.
     *
     * 7. Return the parsed deployed contract address.
     */
    function deploy(string memory contractName, bytes memory constructorData, DefenderOptions memory defenderOpts) internal returns (address) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        
        // 1. Retrieve the output directory
        string memory outputDir = _getOutputDirectory(vm);
        
        // 2. Fetch the contract information
        ContractInfo memory contractInfo = _getContractInfo(vm, contractName, outputDir);
        
        // 3. Construct the build info file path
        string memory buildInfoFile = string.concat(
            outputDir,
            "/build-info/",
            contractInfo.sourceCodeHash,
            ".json"
        );
        
        // 4. Build the deployment command
        string[] memory inputs = buildDeployCommand(contractInfo, buildInfoFile, constructorData, defenderOpts);
        
        // 5. Execute the deployment command
        Vm.FfiResult memory result = vm.tryFfi(inputs);
        
        // 6. Check the exit code
        if (result.exitCode != 0) {
            revert(string.concat(
                "Failed to deploy contract using Defender: ",
                string(result.stderr)
            ));
        }
        
        // Parse the deployed contract address from stdout
        address deployedAddress = _parseDeployedAddress(string(result.stdout));
        
        // 7. Return the deployed contract address
        return deployedAddress;
    }

    /**
     * @notice Constructs a deploy command for deploying a contract using OpenZeppelin Defender.
     *
     * @param contractInfo Contains details about the contract, such as its name, path, and license.
     * @param buildInfoFile The file containing build information for the contract.
     * @param constructorData Bytecode for the contract's constructor, if any.
     * @param defenderOpts Configuration options for the Defender deployment, including license type, relayer ID, and transaction overrides.
     *
     * Steps:
     * 1. Initialize a Vm instance for cheatcode operations.
     * 2. Validate the `licenseType` option against `skipVerifySourceCode` and `skipLicenseType` options, reverting if invalid.
     * 3. Initialize an array to store the command inputs.
     * 4. Populate the command inputs with the following:
     *    - Base command (`npx` and OpenZeppelin Defender CLI).
     *    - Contract name and path.
     *    - Chain ID and build info file.
     *    - Constructor bytecode, if provided.
     *    - License type, if applicable.
     *    - Relayer ID, if provided.
     *    - Salt, if provided.
     *    - Gas limit, gas price, max fee per gas, and max priority fee per gas, if provided.
     *    - Metadata, if provided.
     * 5. Create a correctly sized copy of the inputs array to avoid empty slots.
     * 6. Return the constructed command inputs.
     *
     * @return inputs The array of strings representing the deploy command.
     */
    function buildDeployCommand(ContractInfo memory contractInfo, string memory buildInfoFile, bytes memory constructorData, DefenderOptions memory defenderOpts) internal view returns (string[] memory) {
        // 1. Initialize a Vm instance
        Vm vm = Vm(CHEATCODE_ADDRESS);
        
        // 2. Validate the licenseType option
        if (bytes(defenderOpts.licenseType).length > 0 && defenderOpts.skipVerifySourceCode) {
            revert("Cannot specify licenseType when skipVerifySourceCode is true");
        }
        
        // 3. Initialize an array to store the command inputs
        string[] memory inputBuilder = new string[](255);
        uint256 i = 0;
        
        // 4. Populate the command inputs
        // Base command
        inputBuilder[i++] = "npx";
        inputBuilder[i++] = "@openzeppelin/defender-deploy-client-cli@0.2.11";
        inputBuilder[i++] = "deploy";
        
        // Contract name and path
        inputBuilder[i++] = "--contractName";
        inputBuilder[i++] = contractInfo.contractName;
        inputBuilder[i++] = "--contractPath";
        inputBuilder[i++] = contractInfo.contractPath;
        
        // Chain ID
        inputBuilder[i++] = "--chainId";
        inputBuilder[i++] = Strings.toString(block.chainid);
        
        // Build info file
        inputBuilder[i++] = "--buildInfoFile";
        inputBuilder[i++] = buildInfoFile;
        
        // Constructor bytecode, if provided
        if (constructorData.length > 0) {
            inputBuilder[i++] = "--constructorBytecode";
            inputBuilder[i++] = _bytesToHexString(constructorData);
        }
        
        // License type, if applicable
        if (!defenderOpts.skipVerifySourceCode && !defenderOpts.skipLicenseType) {
            string memory licenseType = bytes(defenderOpts.licenseType).length > 0 
                ? defenderOpts.licenseType 
                : _toLicenseType(contractInfo);
            inputBuilder[i++] = "--licenseType";
            inputBuilder[i++] = licenseType;
        }
        
        // Relayer ID, if provided
        if (bytes(defenderOpts.relayerId).length > 0) {
            inputBuilder[i++] = "--relayerId";
            inputBuilder[i++] = defenderOpts.relayerId;
        }
        
        // Salt, if provided
        if (defenderOpts.salt != bytes32(0)) {
            inputBuilder[i++] = "--salt";
            inputBuilder[i++] = _bytes32ToHexString(defenderOpts.salt);
        }
        
        // Gas limit, if provided
        if (defenderOpts.gasLimit > 0) {
            inputBuilder[i++] = "--gasLimit";
            inputBuilder[i++] = Strings.toString(defenderOpts.gasLimit);
        }
        
        // Gas price, if provided
        if (defenderOpts.gasPrice > 0) {
            inputBuilder[i++] = "--gasPrice";
            inputBuilder[i++] = Strings.toString(defenderOpts.gasPrice);
        }
        
        // Max fee per gas, if provided
        if (defenderOpts.maxFeePerGas > 0) {
            inputBuilder[i++] = "--maxFeePerGas";
            inputBuilder[i++] = Strings.toString(defenderOpts.maxFeePerGas);
        }
        
        // Max priority fee per gas, if provided
        if (defenderOpts.maxPriorityFeePerGas > 0) {
            inputBuilder[i++] = "--maxPriorityFeePerGas";
            inputBuilder[i++] = Strings.toString(defenderOpts.maxPriorityFeePerGas);
        }
        
        // Metadata, if provided
        if (bytes(defenderOpts.metadata).length > 0) {
            inputBuilder[i++] = "--metadata";
            inputBuilder[i++] = defenderOpts.metadata;
        }
        
        // 5. Create a correctly sized copy of the inputs array
        string[] memory inputs = new string[](i);
        for (uint256 j = 0; j < i; j++) {
            inputs[j] = inputBuilder[j];
        }
        
        // 6. Return the constructed command inputs
        return inputs;
    }

    /**
     * @notice Converts a given SPDX license identifier into a standardized license type.
     *
     * @param contractInfo A struct containing the license identifier and contract path.
     * @return string memory The standardized license type corresponding to the SPDX identifier.
     *
     * Steps:
     * 1. Convert the license identifier into a slice for comparison.
     * 2. Compare the license identifier against known SPDX identifiers.
     * 3. Return the corresponding standardized license type.
     * 4. If the license identifier is not recognized, revert with an error message indicating the unsupported license.
     */
    function _toLicenseType(ContractInfo memory contractInfo) private pure returns (string memory) {
        // 1. Convert the license identifier into a slice for comparison
        strings.slice memory licenseSlice = contractInfo.license.toSlice();
        
        // 2. Compare the license identifier against known SPDX identifiers and return the corresponding type
        if (licenseSlice.equals("MIT".toSlice())) {
            return "MIT";
        } else if (licenseSlice.equals("Apache-2.0".toSlice())) {
            return "Apache-2.0";
        } else if (licenseSlice.equals("GPL-3.0".toSlice())) {
            return "GPL-3.0";
        } else if (licenseSlice.equals("GPL-2.0".toSlice())) {
            return "GPL-2.0";
        } else if (licenseSlice.equals("LGPL-3.0".toSlice())) {
            return "LGPL-3.0";
        } else if (licenseSlice.equals("LGPL-2.1".toSlice())) {
            return "LGPL-2.1";
        } else if (licenseSlice.equals("BSD-2-Clause".toSlice())) {
            return "BSD-2-Clause";
        } else if (licenseSlice.equals("BSD-3-Clause".toSlice())) {
            return "BSD-3-Clause";
        } else if (licenseSlice.equals("MPL-2.0".toSlice())) {
            return "MPL-2.0";
        } else if (licenseSlice.equals("ISC".toSlice())) {
            return "ISC";
        } else if (licenseSlice.equals("Unlicense".toSlice())) {
            return "Unlicense";
        } else if (licenseSlice.equals("UNLICENSED".toSlice())) {
            return "None";
        } else {
            // 4. If the license identifier is not recognized, revert
            revert(string.concat(
                "Unsupported license type: ",
                contractInfo.license,
                " in ",
                contractInfo.contractPath
            ));
        }
    }

    /**
     * @notice Proposes an upgrade for a proxy contract by deploying a new implementation and submitting the upgrade proposal.
     *
     * @param proxyAddress The address of the proxy contract to be upgraded.
     * @param proxyAdminAddress The address of the proxy admin contract that manages the proxy.
     * @param newImplementationAddress The address of the new implementation contract.
     * @param newImplementationContractName The name of the new implementation contract.
     * @param opts Additional options for the upgrade proposal.
     *
     * @return ProposeUpgradeResponse A struct containing the response from the upgrade proposal process.
     *
     * Steps:
     * 1. Initialize the Vm (cheatcode) instance for interacting with the environment.
     * 2. Retrieve the output directory and contract information for the new implementation contract.
     * 3. Build the command to propose the upgrade using the provided parameters and contract info.
     * 4. Execute the command as a bash command using the Vm's FFI (Foreign Function Interface).
     * 5. Check the exit code of the command:
     *    - If the exit code is not 0, revert with an error message indicating the failure.
     *    - If successful, parse the stdout into a `ProposeUpgradeResponse` struct and return it.
     *
     * Reverts:
     * - If the command execution fails (exit code != 0), the function reverts with an error message.
     */
    function proposeUpgrade(address proxyAddress, address proxyAdminAddress, address newImplementationAddress, string memory newImplementationContractName, Options memory opts) internal returns (ProposeUpgradeResponse memory) {
        // 1. Initialize the Vm instance
        Vm vm = Vm(CHEATCODE_ADDRESS);
        
        // 2. Retrieve the output directory and contract information
        string memory outputDir = _getOutputDirectory(vm);
        ContractInfo memory contractInfo = _getContractInfo(vm, newImplementationContractName, outputDir);
        
        // 3. Build the command to propose the upgrade
        string[] memory inputs = buildProposeUpgradeCommand(
            proxyAddress,
            proxyAdminAddress,
            newImplementationAddress,
            contractInfo,
            opts
        );
        
        // 4. Execute the command
        Vm.FfiResult memory result = vm.tryFfi(inputs);
        
        // 5. Check the exit code
        if (result.exitCode != 0) {
            revert(string.concat(
                "Failed to propose upgrade: ",
                string(result.stderr)
            ));
        }
        
        // Parse the stdout into a ProposeUpgradeResponse struct
        ProposeUpgradeResponse memory response = parseProposeUpgradeResponse(string(result.stdout));
        
        return response;
    }

    /**
     * @notice Parses the response from a propose upgrade command and extracts the proposal ID and URL.
     *
     * @param stdout The raw string output from the propose upgrade command.
     * @return response A `ProposeUpgradeResponse` struct containing the parsed proposal ID and URL.
     *
     * Steps:
     * 1. Initialize an empty `ProposeUpgradeResponse` struct.
     * 2. Extract the proposal ID by parsing the line starting with "Proposal ID: " from the stdout.
     * 3. Extract the proposal URL by parsing the line starting with "Proposal URL: " from the stdout.
     * 4. Return the populated `ProposeUpgradeResponse` struct.
     */
    function parseProposeUpgradeResponse(string memory stdout) internal pure returns (ProposeUpgradeResponse memory) {
        // 1. Initialize an empty ProposeUpgradeResponse struct
        ProposeUpgradeResponse memory response;
        
        // 2. Extract the proposal ID
        response.proposalId = _parseLine("Proposal ID: ", stdout, true);
        
        // 3. Extract the proposal URL
        response.url = _parseLine("Proposal URL: ", stdout, true);
        
        // 4. Return the populated struct
        return response;
    }

    /**
     * @notice Parses a line from a given string output based on an expected prefix.
     *
     * Steps:
     * 1. Convert the expected prefix into a slice for comparison.
     * 2. Check if the output string contains the expected prefix.
     * 3. If the prefix is found:
     *    - Extract the substring beyond the prefix.
     *    - Remove any following lines by splitting at the newline character.
     *    - Return the extracted substring.
     * 4. If the prefix is not found and the line is required:
     *    - Revert with an error message indicating the prefix was not found.
     * 5. If the prefix is not found and the line is not required:
     *    - Return an empty string.
     *
     * @param expectedPrefix The prefix to search for in the output string.
     * @param stdout The output string to parse.
     * @param required Whether the line with the prefix is mandatory.
     * @return The parsed line or an empty string if not required.
     */
    function _parseLine(string memory expectedPrefix, string memory stdout, bool required) private pure returns (string memory) {
        // 1. Convert the expected prefix into a slice
        strings.slice memory prefixSlice = expectedPrefix.toSlice();
        strings.slice memory stdoutSlice = stdout.toSlice();
        
        // 2. Check if the output string contains the expected prefix
        if (stdoutSlice.contains(prefixSlice)) {
            // 3. Extract the substring beyond the prefix
            strings.slice memory delimiter = expectedPrefix.toSlice();
            stdoutSlice.find(delimiter).beyond(delimiter);
            strings.slice memory remaining = stdoutSlice.find(delimiter).beyond(delimiter);
            
            // Remove any following lines by splitting at the newline character
            strings.slice memory newlineSlice = "\n".toSlice();
            if (remaining.contains(newlineSlice)) {
                return remaining.split(newlineSlice).toString();
            } else {
                return remaining.toString();
            }
        } else {
            // 4. If the prefix is not found and the line is required
            if (required) {
                revert(string.concat(
                    "Expected prefix not found in output: ",
                    expectedPrefix
                ));
            }
            
            // 5. If not required, return an empty string
            return "";
        }
    }

    /**
     * @notice Builds a command to propose an upgrade for a proxy contract using OpenZeppelin Defender.
     *
     * @param proxyAddress The address of the proxy contract to be upgraded.
     * @param proxyAdminAddress The address of the proxy admin contract (optional, can be zero address).
     * @param newImplementationAddress The address of the new implementation contract.
     * @param contractInfo Contains the path to the contract artifact file.
     * @param opts Contains additional options, such as the upgrade approval process ID.
     *
     * Steps:
     * 1. Initialize a Vm instance for cheatcode operations.
     * 2. Create an array to hold the command inputs, with a maximum length of 255.
     * 3. Populate the array with the necessary command components:
     *    - Command to run the OpenZeppelin Defender CLI.
     *    - Proxy address and new implementation address.
     *    - Chain ID of the current blockchain.
     *    - Path to the contract artifact file.
     *    - Proxy admin address (if provided).
     *    - Upgrade approval process ID (if provided).
     * 4. Create a correctly sized array to hold the command inputs.
     * 5. Copy the populated inputs into the correctly sized array.
     * 6. Return the array of command inputs.
     *
     * @return inputs The array of strings representing the command to propose the upgrade.
     */
    function buildProposeUpgradeCommand(address proxyAddress, address proxyAdminAddress, address newImplementationAddress, ContractInfo memory contractInfo, Options memory opts) internal view returns (string[] memory) {
        // 1. Initialize a Vm instance
        Vm vm = Vm(CHEATCODE_ADDRESS);
        
        // 2. Create an array to hold the command inputs
        string[] memory inputBuilder = new string[](255);
        uint256 i = 0;
        
        // 3. Populate the array with the necessary command components
        inputBuilder[i++] = "npx";
        inputBuilder[i++] = "@openzeppelin/defender-deploy-client-cli@0.2.11";
        inputBuilder[i++] = "propose-upgrade";
        
        // Proxy address
        inputBuilder[i++] = "--proxyAddress";
        inputBuilder[i++] = Strings.toHexString(uint160(proxyAddress), 20);
        
        // New implementation address
        inputBuilder[i++] = "--newImplementationAddress";
        inputBuilder[i++] = Strings.toHexString(uint160(newImplementationAddress), 20);
        
        // Chain ID
        inputBuilder[i++] = "--chainId";
        inputBuilder[i++] = Strings.toString(block.chainid);
        
        // Contract artifact path
        inputBuilder[i++] = "--contractArtifactFile";
        inputBuilder[i++] = contractInfo.contractPath;
        
        // Proxy admin address (if provided)
        if (proxyAdminAddress != address(0)) {
            inputBuilder[i++] = "--proxyAdminAddress";
            inputBuilder[i++] = Strings.toHexString(uint160(proxyAdminAddress), 20);
        }
        
        // Upgrade approval process ID (if provided)
        if (bytes(opts.upgradeApprovalProcessId).length > 0) {
            inputBuilder[i++] = "--approvalProcessId";
            inputBuilder[i++] = opts.upgradeApprovalProcessId;
        }
        
        // 4. Create a correctly sized array
        string[] memory inputs = new string[](i);
        
        // 5. Copy the populated inputs
        for (uint256 j = 0; j < i; j++) {
            inputs[j] = inputBuilder[j];
        }
        
        // 6. Return the array of command inputs
        return inputs;
    }

    /**
     * @notice Retrieves the approval process for a given command by executing a bash command and parsing the output.
     *
     * Steps:
     * 1. Build the command inputs required to fetch the approval process.
     * 2. Execute the command as a bash command using the `Utils.runAsBashCommand` function.
     * 3. Retrieve the standard output from the command execution.
     *
     * 4. Check if the command execution was successful by verifying the exit code.
     * 5. If the exit code is non-zero, revert with an error message containing the standard error output.
     *
     * 6. Parse the standard output to create an `ApprovalProcessResponse` object.
     * 7. Return the parsed `ApprovalProcessResponse`.
     */
    function getApprovalProcess(string memory command) internal returns (ApprovalProcessResponse memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        
        // 1. Build the command inputs
        string[] memory inputs = buildGetApprovalProcessCommand(command);
        
        // 2. Execute the command
        Vm.FfiResult memory result = vm.tryFfi(inputs);
        
        // 4. Check if the command execution was successful
        if (result.exitCode != 0) {
            // 5. Revert with an error message
            revert(string.concat(
                "Failed to get approval process: ",
                string(result.stderr)
            ));
        }
        
        // 6. Parse the standard output
        ApprovalProcessResponse memory response = parseApprovalProcessResponse(string(result.stdout));
        
        // 7. Return the parsed response
        return response;
    }

    /**
     * @notice Parses the approval process response from a given stdout string and returns an `ApprovalProcessResponse` struct.
     *
     * @param stdout The string containing the output from which the approval process response is to be parsed.
     * @return response An `ApprovalProcessResponse` struct containing the parsed data.
     *
     * Steps:
     * 1. Initialize a `Vm` instance using the cheatcode address.
     * 2. Create an empty `ApprovalProcessResponse` struct.
     * 3. Parse the "Approval process ID" from the stdout string and assign it to the response.
     * 4. Parse the "Via" field from the stdout string. If it exists, convert it to an address and assign it to the response.
     * 5. Parse the "Via type" from the stdout string and assign it to the response.
     * 6. Return the populated `ApprovalProcessResponse` struct.
     */
    function parseApprovalProcessResponse(string memory stdout) internal pure returns (ApprovalProcessResponse memory) {
        // 1. Initialize a Vm instance (not needed for pure function, but following the spec)
        
        // 2. Create an empty ApprovalProcessResponse struct
        ApprovalProcessResponse memory response;
        
        // 3. Parse the "Approval process ID"
        response.approvalProcessId = _parseLine("Approval process ID: ", stdout, true);
        
        // 4. Parse the "Via" field
        string memory viaStr = _parseLine("Via: ", stdout, false);
        if (bytes(viaStr).length > 0) {
            response.via = _parseAddress(viaStr);
        }
        
        // 5. Parse the "Via type"
        response.viaType = _parseLine("Via type: ", stdout, true);
        
        // 6. Return the populated struct
        return response;
    }

    /**
     * @notice Constructs a command for the OpenZeppelin Defender Deploy Client CLI to get approval process details.
     *
     * @param command The base command to be executed (e.g., "approval-process:get").
     * @return inputs An array of strings representing the full CLI command with arguments.
     *
     * Steps:
     * 1. Initialize a string array `inputBuilder` with a size of 255 to temporarily store command components.
     * 2. Add the base command components:
     *    - "npx" (Node Package Executor).
     *    - The OpenZeppelin Defender Deploy Client CLI package with its version.
     *    - The provided `command` (e.g., "approval-process:get").
     *    - The `--chainId` flag followed by the current blockchain's chain ID.
     * 3. Create a new string array `inputs` with the correct length (number of components added).
     * 4. Copy the components from `inputBuilder` to `inputs` to avoid empty slots.
     * 5. Return the `inputs` array as the final command.
     */
    function buildGetApprovalProcessCommand(string memory command) internal view returns (string[] memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        
        // 1. Initialize a string array inputBuilder
        string[] memory inputBuilder = new string[](255);
        uint256 i = 0;
        
        // 2. Add the base command components
        inputBuilder[i++] = "npx";
        inputBuilder[i++] = "@openzeppelin/defender-deploy-client-cli@0.2.11";
        inputBuilder[i++] = command;
        inputBuilder[i++] = "--chainId";
        inputBuilder[i++] = Strings.toString(block.chainid);
        
        // 3. Create a new string array with the correct length
        string[] memory inputs = new string[](i);
        
        // 4. Copy the components from inputBuilder to inputs
        for (uint256 j = 0; j < i; j++) {
            inputs[j] = inputBuilder[j];
        }
        
        // 5. Return the inputs array
        return inputs;
    }

    // Helper functions
    
    function _getOutputDirectory(Vm vm) private view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/out");
    }
    
    function _getContractInfo(Vm vm, string memory contractName, string memory outputDir) private view returns (ContractInfo memory) {
        // This is a simplified implementation
        // In a real scenario, this would parse the contract artifacts to extract the information
        ContractInfo memory info;
        info.contractName = contractName;
        info.contractPath = string.concat(outputDir, "/", contractName, ".sol/", contractName, ".json");
        info.license = "MIT"; // Default, should be read from the contract
        info.sourceCodeHash = ""; // Should be computed from the contract source
        info.shortName = contractName;
        return info;
    }
    
    function _parseDeployedAddress(string memory stdout) private pure returns (address) {
        // Parse the deployed address from the stdout
        string memory addressStr = _parseLine("Deployed to: ", stdout, true);
        return _parseAddress(addressStr);
    }
    
    function _parseAddress(string memory addressStr) private pure returns (address) {
        // Remove "0x" prefix if present
        strings.slice memory addrSlice = addressStr.toSlice();
        strings.slice memory prefix = "0x".toSlice();
        if (addrSlice.startsWith(prefix)) {
            addrSlice = addrSlice.beyond(prefix);
        }
        
        // Convert hex string to address
        bytes memory addrBytes = bytes(addrSlice.toString());
        require(addrBytes.length == 40, "Invalid address length");
        
        uint160 result = 0;
        for (uint256 i = 0; i < 40; i++) {
            uint8 digit = uint8(addrBytes[i]);
            uint8 value;
            
            if (digit >= 48 && digit <= 57) {
                value = digit - 48;
            } else if (digit >= 65 && digit <= 70) {
                value = digit - 55;
            } else if (digit >= 97 && digit <= 102) {
                value = digit - 87;
            } else {
                revert("Invalid hex character");
            }
            
            result = result * 16 + value;
        }
        
        return address(result);
    }
    
    function _bytesToHexString(bytes memory data) private pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(2 + data.length * 2);
        result[0] = "0";
        result[1] = "x";
        
        for (uint256 i = 0; i < data.length; i++) {
            result[2 + i * 2] = hexChars[uint8(data[i] >> 4)];
            result[2 + i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }
        
        return string(result);
    }
    
    function _bytes32ToHexString(bytes32 data) private pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(66);
        result[0] = "0";
        result[1] = "x";
        
        for (uint256 i = 0; i < 32; i++) {
            result[2 + i * 2] = hexChars[uint8(data[i] >> 4)];
            result[2 + i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }
        
        return string(result);
    }
}
