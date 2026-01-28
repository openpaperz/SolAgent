```solidity: Utils.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {strings} from "solidity-stringutils/strings.sol";

/**
 * @dev Struct to store contract information.
 */
struct ContractInfo {
    string shortName;
    string fileName;
    string contractPath;
    string license;
    string sourceCodeHash;
    string artifactPath;
}

library Utils {
    using strings for *;

    /// @dev Cheatcode address used for Foundry VM operations
    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    /**
     * @notice Constructs the fully qualified name of a contract by combining its path and short name.
     *
     * @param contractName The name of the contract.
     * @param outDir The directory where the contract artifacts are stored.
     *
     * @return A string representing the fully qualified name of the contract in the format "contractPath:shortName".
     *
     * Steps:
     * 1. Retrieve the contract information (path and short name) using `getContractInfo`.
     * 2. Concatenate the contract path and short name with a colon separator.
     * 3. Return the fully qualified name as a string.
     */
    function getFullyQualifiedName(string memory contractName, string memory outDir) internal view returns (string memory) {
        ContractInfo memory info = getContractInfo(contractName, outDir);
        return string(abi.encodePacked(info.contractPath, ":", info.shortName));
    }

    /**
     * @notice Retrieves contract information from the artifact file, including the contract's short name, file name, path, license, source code hash, and artifact path.
     *
     * @param contractName The name of the contract to retrieve information for.
     * @param outDir The directory where the contract artifacts are stored.
     * @return info A `ContractInfo` struct containing the contract's details.
     *
     * Steps:
     * 1. Initialize a `Vm` instance using the `CHEATCODE_ADDRESS`.
     * 2. Create a `ContractInfo` struct to store the contract's details.
     * 3. Derive the short name and file name from the `contractName`.
     * 4. Construct the artifact file path using the project root, output directory, file name, and short name.
     * 5. Read the artifact JSON file from the constructed path.
     * 6. Check if the AST (Abstract Syntax Tree) exists in the artifact JSON. If not, revert with an error message.
     * 7. Parse the contract's absolute path from the artifact JSON.
     * 8. If a license exists in the artifact JSON, parse and store it.
     * 9. Parse and store the source code hash from the artifact JSON.
     * 10. Store the artifact path in the `ContractInfo` struct.
     * 11. Return the `ContractInfo` struct containing all the parsed details.
     */
    function getContractInfo(string memory contractName, string memory outDir) internal view returns (ContractInfo memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        ContractInfo memory info;

        info.shortName = _toShortName(contractName);
        info.fileName = _toFileName(contractName);

        string memory projectRoot = vm.projectRoot();
        string memory artifactPath = string(abi.encodePacked(
            projectRoot,
            "/",
            outDir,
            "/",
            info.fileName,
            "/",
            info.shortName,
            ".json"
        ));

        string memory artifactJson = vm.readFile(artifactPath);

        bytes memory astKey = bytes(vm.parseJsonKeys(artifactJson, ".ast"));
        require(astKey.length > 0, "AST not found in artifact JSON. Ensure that 'build_info' is set to true in foundry.toml");

        info.contractPath = vm.parseJsonString(artifactJson, ".ast.absolutePath");

        bytes memory licenseKey = bytes(vm.parseJsonKeys(artifactJson, ".ast.license"));
        if (licenseKey.length > 0) {
            info.license = vm.parseJsonString(artifactJson, ".ast.license");
        }

        info.sourceCodeHash = vm.parseJsonString(artifactJson, ".metadata.settings.compilationTarget");
        info.artifactPath = artifactPath;

        return info;
    }

    /**
     * @notice Retrieves the build-info file for a contract based on its source code hash.
     *
     * @param sourceCodeHash The hash of the contract's source code.
     * @param contractName The name of the contract.
     * @param outDir The directory where the build-info files are located.
     * @return The path to the build-info file matching the source code hash.
     *
     * Steps:
     * 1. Prepare a command to search for the build-info file using the source code hash.
     * 2. Execute the command using a bash shell.
     * 3. Retrieve the output of the command.
     * 4. Check if the output ends with ".json" to ensure it is a valid build-info file.
     * 5. If the output is not a valid build-info file, revert with an error message.
     * 6. Return the path to the build-info file.
     */
    function getBuildInfoFile(string memory sourceCodeHash, string memory contractName, string memory outDir) internal returns (string memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory projectRoot = vm.projectRoot();
        string memory buildInfoDir = string(abi.encodePacked(projectRoot, "/", outDir, "/build-info"));

        string[] memory inputs = new string[](5);
        inputs[0] = "grep";
        inputs[1] = "-rl";
        inputs[2] = sourceCodeHash;
        inputs[3] = buildInfoDir;
        inputs[4] = "| head -n 1";

        Vm.FfiResult memory result = runAsBashCommand(inputs);
        string memory buildInfoFile = string(result.stdout);

        strings.slice memory buildInfoSlice = buildInfoFile.toSlice();
        strings.slice memory jsonExtension = ".json".toSlice();

        require(
            buildInfoSlice.endsWith(jsonExtension),
            string(abi.encodePacked("Build info file not found for contract ", contractName))
        );

        return buildInfoFile;
    }

    /**
     * @notice Retrieves the output directory for Foundry, with a fallback to the default directory if not specified.
     *
     * Steps:
     * 1. Initialize a Vm instance using the cheatcode address.
     * 2. Define a default output directory as "out".
     * 3. Attempt to retrieve the output directory from the environment variable "FOUNDRY_OUT".
     * 4. If the environment variable is not set, return the default output directory.
     *
     * @return The output directory path as a string.
     */
    function getOutDir() internal view returns (string memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory defaultOutDir = "out";

        try vm.envString("FOUNDRY_OUT") returns (string memory outDir) {
            return outDir;
        } catch {
            return defaultOutDir;
        }
    }

    /**
     * @notice Splits a string slice into an array of strings based on a delimiter slice.
     *
     * Steps:
     * 1. Calculate the number of parts by counting occurrences of the delimiter in the input slice.
     * 2. Initialize an array of strings with the calculated number of parts.
     * 3. Iterate through the array and split the input slice using the delimiter.
     * 4. Convert each split slice to a string and store it in the array.
     * 5. Return the array of split strings.
     */
    function _split(strings.slice memory inputSlice, strings.slice memory delimSlice) private pure returns (string[] memory) {
        uint256 parts = inputSlice.count(delimSlice) + 1;
        string[] memory result = new string[](parts);

        for (uint256 i = 0; i < parts; i++) {
            result[i] = inputSlice.split(delimSlice).toString();
        }

        return result;
    }

    /**
     * @notice Converts a contract name string into a valid file name format.
     *
     * Steps:
     * 1. Convert the contract name into a slice for manipulation.
     * 2. Check if the contract name ends with ".sol". If so, return it as is.
     * 3. If the contract name contains a single colon ":", split the string at the colon and return the first part.
     * 4. If the contract name ends with ".json":
     *    a. Split the string by "/" to handle paths.
     *    b. If the resulting parts array has more than one element, return the second-to-last part.
     * 5. If none of the above conditions are met, revert with an error message indicating the required format.
     *
     * @param contractName The input contract name string to be converted.
     * @return string The formatted file name.
     * @dev Reverts if the contract name does not match the expected formats.
     */
    function _toFileName(string memory contractName) private pure returns (string memory) {
        strings.slice memory contractSlice = contractName.toSlice();
        strings.slice memory solExtension = ".sol".toSlice();
        strings.slice memory jsonExtension = ".json".toSlice();
        strings.slice memory colon = ":".toSlice();
        strings.slice memory slash = "/".toSlice();

        if (contractSlice.endsWith(solExtension)) {
            return contractName;
        }

        if (contractSlice.count(colon) == 1) {
            string[] memory parts = _split(contractSlice, colon);
            return parts[0];
        }

        if (contractSlice.endsWith(jsonExtension)) {
            string[] memory parts = _split(contractSlice, slash);
            if (parts.length > 1) {
                return parts[parts.length - 2];
            }
        }

        revert("Contract name must be in the format <filename>.sol, <filename>:<contractname>, or <path>/<filename>/<contractname>.json");
    }

    /**
     * @notice Converts a contract name string into a short name by removing file extensions and paths.
     *
     * Steps:
     * 1. Convert the input contract name into a slice for manipulation.
     * 2. If the name ends with ".sol", remove the ".sol" extension and return the remaining string.
     * 3. If the name contains a single ":", split the string at the ":" and return the second part.
     * 4. If the name ends with ".json", split the string at "/" to isolate the file name, then remove the ".json" extension and return the remaining string.
     * 5. If the name does not match any of the expected formats, revert with an error message indicating the required format.
     *
     * @param contractName The full contract name string to be shortened.
     * @return The shortened contract name.
     */
    function _toShortName(string memory contractName) private pure returns (string memory) {
        strings.slice memory contractSlice = contractName.toSlice();
        strings.slice memory solExtension = ".sol".toSlice();
        strings.slice memory jsonExtension = ".json".toSlice();
        strings.slice memory colon = ":".toSlice();
        strings.slice memory slash = "/".toSlice();

        if (contractSlice.endsWith(solExtension)) {
            contractSlice.rsplit(solExtension);
            return contractSlice.toString();
        }

        if (contractSlice.count(colon) == 1) {
            string[] memory parts = _split(contractSlice, colon);
            return parts[1];
        }

        if (contractSlice.endsWith(jsonExtension)) {
            string[] memory parts = _split(contractSlice, slash);
            strings.slice memory lastPart = parts[parts.length - 1].toSlice();
            lastPart.rsplit(jsonExtension);
            return lastPart.toString();
        }

        revert("Contract name must be in the format <filename>.sol, <filename>:<contractname>, or <path>/<filename>/<contractname>.json");
    }

    /**
     * @notice Converts an array of input strings into a Bash command format.
     *
     * @param inputs An array of strings representing the command inputs.
     * @param bashPath The path to the Bash executable.
     *
     * @return result An array of strings formatted as a Bash command:
     * - result[0]: The Bash executable path.
     * - result[1]: The "-c" flag to execute the command.
     * - result[2]: The concatenated command string from the inputs.
     *
     * Steps:
     * 1. Initialize an empty string `commandString`.
     * 2. Iterate through the `inputs` array and concatenate each input into `commandString`, separated by spaces.
     * 3. Create a new string array `result` with a length of 3.
     * 4. Assign the Bash path, "-c" flag, and the concatenated command string to the `result` array.
     * 5. Return the formatted Bash command array.
     */
    function toBashCommand(string[] memory inputs, string memory bashPath) internal pure returns (string[] memory) {
        string memory commandString = "";

        for (uint256 i = 0; i < inputs.length; i++) {
            if (i > 0) {
                commandString = string(abi.encodePacked(commandString, " "));
            }
            commandString = string(abi.encodePacked(commandString, inputs[i]));
        }

        string[] memory result = new string[](3);
        result[0] = bashPath;
        result[1] = "-c";
        result[2] = commandString;

        return result;
    }

    /**
     * @notice Executes a bash command using the provided inputs.
     *
     * Steps:
     * 1. Initialize a Vm instance using the cheatcode address.
     * 2. Retrieve the default bash path or use the one specified in the environment variable OPENZEPPELIN_BASH_PATH.
     * 3. Convert the inputs into a bash command using the retrieved bash path.
     * 4. Attempt to execute the bash command using the Vm instance.
     * 5. If the command fails with a non-zero exit code and no output (stdout or stderr), revert with an error message.
     *    - This is particularly relevant for Windows users using WSL, where the bash executable might not be correctly configured.
     *    - The error message provides guidance on setting the OPENZEPPELIN_BASH_PATH environment variable.
     * 6. If the command executes successfully, return the result.
     */
    function runAsBashCommand(string[] memory inputs) internal returns (Vm.FfiResult memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory bashPath = "/bin/bash";

        try vm.envString("OPENZEPPELIN_BASH_PATH") returns (string memory customBashPath) {
            bashPath = customBashPath;
        } catch {
            // Use default bash path
        }

        string[] memory command = toBashCommand(inputs, bashPath);
        Vm.FfiResult memory result = vm.tryFfi(command);

        if (result.exitCode != 0 && result.stdout.length == 0 && result.stderr.length == 0) {
            revert(
                "Failed to run bash command. If you are using Windows, set the OPENZEPPELIN_BASH_PATH environment variable to the full path of your bash executable, or ensure bash is available in your PATH."
            );
        }

        return result;
    }
}
```