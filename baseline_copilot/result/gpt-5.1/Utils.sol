// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Vm.sol";
import "solidity-stringutils/strings.sol";

library Utils {
    using strings for *;

    struct ContractInfo {
        string shortName;
        string fileName;
        string contractPath;
        string license;
        string sourceCodeHash;
        string artifactPath;
    }

    address internal constant CHEATCODE_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

    /// @notice Constructs the fully qualified name of a contract by combining its path and short name.
    ///
    /// @param contractName The name of the contract.
    /// @param outDir The directory where the contract artifacts are stored.
    ///
    /// @return A string representing the fully qualified name of the contract in the format "contractPath:shortName".
    ///
    /// Steps:
    /// 1. Retrieve the contract information (path and short name) using `getContractInfo`.
    /// 2. Concatenate the contract path and short name with a colon separator.
    /// 3. Return the fully qualified name as a string.
    function getFullyQualifiedName(string memory contractName, string memory outDir) internal view returns (string memory) {
        ContractInfo memory info = getContractInfo(contractName, outDir);
        return string(abi.encodePacked(info.contractPath, ":", info.shortName));
    }

    /// @notice Retrieves contract information from the artifact file, including the contract's short name, file name, path, license, source code hash, and artifact path.
    ///
    /// @param contractName The name of the contract to retrieve information for.
    /// @param outDir The directory where the contract artifacts are stored.
    /// @return info A `ContractInfo` struct containing the contract's details.
    ///
    /// Steps:
    /// 1. Initialize a `Vm` instance using the `CHEATCODE_ADDRESS`.
    /// 2. Create a `ContractInfo` struct to store the contract's details.
    /// 3. Derive the short name and file name from the `contractName`.
    /// 4. Construct the artifact file path using the project root, output directory, file name, and short name.
    /// 5. Read the artifact JSON file from the constructed path.
    /// 6. Check if the AST (Abstract Syntax Tree) exists in the artifact JSON. If not, revert with an error message.
    /// 7. Parse the contract's absolute path from the artifact JSON.
    /// 8. If a license exists in the artifact JSON, parse and store it.
    /// 9. Parse and store the source code hash from the artifact JSON.
    /// 10. Store the artifact path in the `ContractInfo` struct.
    /// 11. Return the `ContractInfo` struct containing all the parsed details.
    function getContractInfo(string memory contractName, string memory outDir) internal view returns (ContractInfo memory info) {
        Vm vm = Vm(CHEATCODE_ADDRESS);

        string memory shortName = _toShortName(contractName);
        string memory fileName = _toFileName(contractName);

        // project root from FOUNDRY_PROJECT_ROOT, defaults to current dir "."
        string memory projectRoot = vm.envOr("FOUNDRY_PROJECT_ROOT", string("."));
        string memory artifactPath = string(
            abi.encodePacked(
                projectRoot,
                "/",
                outDir,
                "/",
                fileName,
                "/",
                shortName,
                ".json"
            )
        );

        string memory json = vm.readFile(artifactPath);

        // Ensure AST exists
        bool hasAst = vm.keyExists(json, ".ast");
        if (!hasAst) {
            revert(string(abi.encodePacked("Artifact for ", contractName, " has no AST at ", artifactPath)));
        }

        // Parse contract absolute path
        string memory contractPath = vm.parseJsonString(json, ".ast.absolutePath");

        // Optional license
        string memory license = "";
        if (vm.keyExists(json, ".ast.license")) {
            license = vm.parseJsonString(json, ".ast.license");
        }

        // Source code hash
        string memory sourceCodeHash = vm.parseJsonString(json, ".ast.srcHash");

        info = ContractInfo({
            shortName: shortName,
            fileName: fileName,
            contractPath: contractPath,
            license: license,
            sourceCodeHash: sourceCodeHash,
            artifactPath: artifactPath
        });
    }

    /// @notice Retrieves the build-info file for a contract based on its source code hash.
    ///
    /// @param sourceCodeHash The hash of the contract's source code.
    /// @param contractName The name of the contract.
    /// @param outDir The directory where the build-info files are located.
    /// @return The path to the build-info file matching the source code hash.
    ///
    /// Steps:
    /// 1. Prepare a command to search for the build-info file using the source code hash.
    /// 2. Execute the command using a bash shell.
    /// 3. Retrieve the output of the command.
    /// 4. Check if the output ends with ".json" to ensure it is a valid build-info file.
    /// 5. If the output is not a valid build-info file, revert with an error message.
    /// 6. Return the path to the build-info file.
    function getBuildInfoFile(string memory sourceCodeHash, string memory contractName, string memory outDir) internal returns (string memory) {
        string[] memory cmd = new string[](7);
        cmd[0] = "bash";
        cmd[1] = "-lc";
        // find <outDir>-build-info -name '*.json' -print0 | xargs -0 grep -l <hash>
        cmd[2] = string(
            abi.encodePacked(
                "set -e; ",
                "DIR=\"",
                outDir,
                "-build-info\"; ",
                "if [ ! -d \"$DIR\" ]; then exit 1; fi; ",
                "find \"$DIR\" -name '*.json' -print0 | xargs -0 grep -l ",
                sourceCodeHash
            )
        );
        // trailing elements unused but keep array sized as declared
        cmd[3] = "";
        cmd[4] = "";
        cmd[5] = "";
        cmd[6] = "";

        Vm.FfiResult memory res = runAsBashCommand(cmd);

        string memory path = string(res.stdout);

        // trim whitespace/newlines
        path = _trim(path);

        bytes memory b = bytes(path);
        if (b.length < 5) {
            revert(string(abi.encodePacked("No build-info file found for ", contractName)));
        }
        bytes memory suffix = bytes(".json");
        for (uint256 i = 0; i < 5; i++) {
            if (b[b.length - 5 + i] != suffix[i]) {
                revert(string(abi.encodePacked("Invalid build-info file for ", contractName, ": ", path)));
            }
        }

        return path;
    }

    /// @notice Retrieves the output directory for Foundry, with a fallback to the default directory if not specified.
    ///
    /// Steps:
    /// 1. Initialize a Vm instance using the cheatcode address.
    /// 2. Define a default output directory as "out".
    /// 3. Attempt to retrieve the output directory from the environment variable "FOUNDRY_OUT".
    /// 4. If the environment variable is not set, return the default output directory.
    ///
    /// @return The output directory path as a string.
    function getOutDir() internal view returns (string memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory defaultOut = "out";
        return vm.envOr("FOUNDRY_OUT", defaultOut);
    }

    /// @notice Splits a string slice into an array of strings based on a delimiter slice.
    ///
    /// Steps:
    /// 1. Calculate the number of parts by counting occurrences of the delimiter in the input slice.
    /// 2. Initialize an array of strings with the calculated number of parts.
    /// 3. Iterate through the array and split the input slice using the delimiter.
    /// 4. Convert each split slice to a string and store it in the array.
    /// 5. Return the array of split strings.
    function _split(strings.slice memory inputSlice, strings.slice memory delimSlice) private pure returns (string[] memory) {
        uint256 partsCount = inputSlice.count(delimSlice) + 1;
        string[] memory parts = new string[](partsCount);

        for (uint256 i = 0; i < partsCount; i++) {
            parts[i] = inputSlice.split(delimSlice).toString();
        }

        return parts;
    }

    /// @notice Converts a contract name string into a valid file name format.
    ///
    /// Steps:
    /// 1. Convert the contract name into a slice for manipulation.
    /// 2. Check if the contract name ends with ".sol". If so, return it as is.
    /// 3. If the contract name contains a single colon ":", split the string at the colon and return the first part.
    /// 4. If the contract name ends with ".json":
    ///    a. Split the string by "/" to handle paths.
    ///    b. If the resulting parts array has more than one element, return the second-to-last part.
    /// 5. If none of the above conditions are met, revert with an error message indicating the required format.
    ///
    /// @param contractName The input contract name string to be converted.
    /// @return string The formatted file name.
    /// @dev Reverts if the contract name does not match the expected formats.
    function _toFileName(string memory contractName) private pure returns (string memory) {
        strings.slice memory s = contractName.toSlice();

        if (s.endsWith(".sol".toSlice())) {
            return contractName;
        }

        // "path/File.sol:Contract"
        if (s.count(":".toSlice()) == 1) {
            strings.slice memory beforeColon = s.copy();
            beforeColon.beyond(":".toSlice()); // move internal pointer after colon for copy usage
            // To get part before colon, re-init slice
            strings.slice memory full = contractName.toSlice();
            strings.slice memory left = full.split(":".toSlice());
            return left.toString();
        }

        if (s.endsWith(".json".toSlice())) {
            string[] memory parts = _split(s, "/".toSlice());
            if (parts.length > 1) {
                // second-to-last element
                return parts[parts.length - 2];
            }
        }

        revert("Contract name must end with .sol, be of form file.sol:Contract, or path/to/build-info.json");
    }

    /// @notice Converts a contract name string into a short name by removing file extensions and paths.
    ///
    /// Steps:
    /// 1. Convert the input contract name into a slice for manipulation.
    /// 2. If the name ends with ".sol", remove the ".sol" extension and return the remaining string.
    /// 3. If the name contains a single ":", split the string at the ":" and return the second part.
    /// 4. If the name ends with ".json", split the string at "/" to isolate the file name, then remove the ".json" extension and return the remaining string.
    /// 5. If the name does not match any of the expected formats, revert with an error message indicating the required format.
    ///
    /// @param contractName The full contract name string to be shortened.
    /// @return The shortened contract name.
    function _toShortName(string memory contractName) private pure returns (string memory) {
        strings.slice memory s = contractName.toSlice();

        if (s.endsWith(".sol".toSlice())) {
            strings.slice memory withoutExt = contractName.toSlice();
            // length of ".sol" is 4
            withoutExt._len -= 4;
            return withoutExt.toString();
        }

        if (s.count(":".toSlice()) == 1) {
            strings.slice memory full = contractName.toSlice();
            full.split(":".toSlice()); // discard before colon
            strings.slice memory after = full;
            return after.toString();
        }

        if (s.endsWith(".json".toSlice())) {
            string[] memory pathParts = _split(s, "/".toSlice());
            string memory fileName = pathParts[pathParts.length - 1];
            strings.slice memory fileSlice = fileName.toSlice();
            // remove .json
            fileSlice._len -= 5;
            return fileSlice.toString();
        }

        revert("Contract name must end with .sol, be of form file.sol:Contract, or path/to/build-info.json");
    }

    /// @notice Converts an array of input strings into a Bash command format.
    ///
    /// @param inputs An array of strings representing the command inputs.
    /// @param bashPath The path to the Bash executable.
    ///
    /// @return result An array of strings formatted as a Bash command:
    /// - result[0]: The Bash executable path.
    /// - result[1]: The "-c" flag to execute the command.
    /// - result[2]: The concatenated command string from the inputs.
    ///
    /// Steps:
    /// 1. Initialize an empty string `commandString`.
    /// 2. Iterate through the `inputs` array and concatenate each input into `commandString`, separated by spaces.
    /// 3. Create a new string array `result` with a length of 3.
    /// 4. Assign the Bash path, "-c" flag, and the concatenated command string to the `result` array.
    /// 5. Return the formatted Bash command array.
    function toBashCommand(string[] memory inputs, string memory bashPath) internal pure returns (string[] memory) {
        string memory commandString = "";
        for (uint256 i = 0; i < inputs.length; i++) {
            if (i == 0) {
                commandString = inputs[i];
            } else {
                commandString = string(abi.encodePacked(commandString, " ", inputs[i]));
            }
        }

        string[] memory result = new string[](3);
        result[0] = bashPath;
        result[1] = "-c";
        result[2] = commandString;
        return result;
    }

    /// @notice Executes a bash command using the provided inputs.
    ///
    /// Steps:
    /// 1. Initialize a Vm instance using the cheatcode address.
    /// 2. Retrieve the default bash path or use the one specified in the environment variable OPENZEPPELIN_BASH_PATH.
    /// 3. Convert the inputs into a bash command using the retrieved bash path.
    /// 4. Attempt to execute the bash command using the Vm instance.
    /// 5. If the command fails with a non-zero exit code and no output (stdout or stderr), revert with an error message.
    ///    - This is particularly relevant for Windows users using WSL, where the bash executable might not be correctly configured.
    ///    - The error message provides guidance on setting the OPENZEPPELIN_BASH_PATH environment variable.
    /// 6. If the command executes successfully, return the result.
    function runAsBashCommand(string[] memory inputs) internal returns (Vm.FfiResult memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);

        string memory defaultBash = "bash";
        string memory bashPath = vm.envOr("OPENZEPPELIN_BASH_PATH", defaultBash);

        string[] memory cmd = toBashCommand(inputs, bashPath);

        Vm.FfiResult memory result = vm.tryFfi(cmd);

        if (result.exitCode != 0 && result.stdout.length == 0 && result.stderr.length == 0) {
            revert(
                string(
                    abi.encodePacked(
                        "Failed to execute bash command. ",
                        "If you are on Windows using WSL, ensure that the OPENZEPPELIN_BASH_PATH environment variable ",
                        "is set to the path of your bash executable."
                    )
                )
            );
        }

        return result;
    }

    function _trim(string memory s) private pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length == 0) return s;

        uint256 start = 0;
        uint256 end = b.length - 1;

        while (start < b.length && _isWhitespace(b[start])) {
            start++;
        }
        while (end > start && _isWhitespace(b[end])) {
            end--;
        }

        if (start == 0 && end == b.length - 1) {
            return s;
        }

        bytes memory out = new bytes(end - start + 1);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = b[start + i];
        }
        return string(out);
    }

    function _isWhitespace(bytes1 c) private pure returns (bool) {
        return c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;
    }
}