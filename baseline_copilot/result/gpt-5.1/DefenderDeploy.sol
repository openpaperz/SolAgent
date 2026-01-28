// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Vm.sol";

library DefenderDeploy {
  using stdJson for string;

  struct ContractInfo {
    string name;
    string path;
    string license;
    string sourceName;
    string shortName;
    string sourceHash;
  }

  struct TxOverrides {
    uint256 gasLimit;
    uint256 gasPrice;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
  }

  struct DefenderOptions {
    string licenseType;
    bool skipVerifySourceCode;
    bool skipLicenseType;
    string relayerId;
    string salt;
    string metadata;
    TxOverrides txOverrides;
  }

  struct Options {
    string approvalProcessId;
  }

  struct ProposeUpgradeResponse {
    string proposalId;
    string proposalUrl;
  }

  struct ApprovalProcessResponse {
    string approvalProcessId;
    address via;
    string viaType;
  }

  Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  /// @notice Deploys a contract using the provided contract name, constructor data, and deployment options.
  ///
  /// @param contractName The name of the contract to be deployed.
  /// @param constructorData The encoded constructor arguments for the contract.
  /// @param defenderOpts The deployment options, including any specific configurations for the Defender service.
  ///
  /// @return The address of the deployed contract.
  ///
  /// Steps:
  /// 1. Retrieve the output directory where the contract artifacts are stored.
  /// 2. Fetch the contract information (e.g., source code hash, short name) using the contract name and output directory.
  /// 3. Construct the build info file path using the contract's source code hash, short name, and output directory.
  ///
  /// 4. Build the deployment command using the contract information, build info file, constructor data, and deployment options.
  /// 5. Execute the deployment command as a bash command using FFI (Foreign Function Interface).
  ///
  /// 6. Check the exit code of the deployment command:
  ///    - If the exit code is not 0, revert with an error message indicating the deployment failure.
  ///    - If the exit code is 0, parse the deployed contract address from the command's standard output.
  ///
  /// 7. Return the parsed deployed contract address.
  function deploy(
    string memory contractName,
    bytes memory constructorData,
    DefenderOptions memory defenderOpts
  ) internal returns (address) {
    string memory outDir = vm.envOr("FOUNDRY_OUT_DIR", string("out"));
    ContractInfo memory contractInfo = _getContractInfo(contractName, outDir);

    string memory buildInfoFile = string(
      abi.encodePacked(
        outDir,
        "/",
        contractInfo.sourceHash,
        "/",
        contractInfo.shortName,
        ".json"
      )
    );

    string[] memory inputs = buildDeployCommand(contractInfo, buildInfoFile, constructorData, defenderOpts);
    (int256 exitCode, bytes memory stdoutBytes, bytes memory stderrBytes) = vm.ffiWithReturnStdoutStderr(inputs);

    if (exitCode != 0) {
      revert(string(abi.encodePacked("Defender deploy failed: ", string(stderrBytes))));
    }

    string memory stdout = string(stdoutBytes);
    string memory addrLine = _parseLine("Deployed to: ", stdout, true);
    bytes memory addrBytes = bytes(addrLine);
    require(addrBytes.length >= 42, "Invalid deployed address");
    return _toAddress(addrLine);
  }

  /// @notice Constructs a deploy command for deploying a contract using OpenZeppelin Defender.
  ///
  /// @param contractInfo Contains details about the contract, such as its name, path, and license.
  /// @param buildInfoFile The file containing build information for the contract.
  /// @param constructorData Bytecode for the contract's constructor, if any.
  /// @param defenderOpts Configuration options for the Defender deployment, including license type, relayer ID, and transaction overrides.
  ///
  /// Steps:
  /// 1. Initialize a Vm instance for cheatcode operations.
  /// 2. Validate the `licenseType` option against `skipVerifySourceCode` and `skipLicenseType` options, reverting if invalid.
  /// 3. Initialize an array to store the command inputs.
  /// 4. Populate the command inputs with the following:
  ///    - Base command (`npx` and OpenZeppelin Defender CLI).
  ///    - Contract name and path.
  ///    - Chain ID and build info file.
  ///    - Constructor bytecode, if provided.
  ///    - License type, if applicable.
  ///    - Relayer ID, if provided.
  ///    - Salt, if provided.
  ///    - Gas limit, gas price, max fee per gas, and max priority fee per gas, if provided.
  ///    - Metadata, if provided.
  /// 5. Create a correctly sized copy of the inputs array to avoid empty slots.
  /// 6. Return the constructed command inputs.
  ///
  /// @return inputs The array of strings representing the deploy command.
  function buildDeployCommand(
    ContractInfo memory contractInfo,
    string memory buildInfoFile,
    bytes memory constructorData,
    DefenderOptions memory defenderOpts
  ) internal view returns (string[] memory) {
    if (bytes(defenderOpts.licenseType).length != 0) {
      if (defenderOpts.skipVerifySourceCode || defenderOpts.skipLicenseType) {
        revert("Invalid license options combination");
      }
    }

    string[] memory inputBuilder = new string[](255);
    uint256 idx = 0;

    inputBuilder[idx++] = "npx";
    inputBuilder[idx++] = "@openzeppelin/defender-deploy-client@latest";
    inputBuilder[idx++] = "deploy";
    inputBuilder[idx++] = "--network";
    inputBuilder[idx++] = _toString(block.chainid);
    inputBuilder[idx++] = "--contract";
    inputBuilder[idx++] = contractInfo.name;
    inputBuilder[idx++] = "--artifact";
    inputBuilder[idx++] = buildInfoFile;
    inputBuilder[idx++] = "--contract-path";
    inputBuilder[idx++] = contractInfo.path;

    if (constructorData.length > 0) {
      inputBuilder[idx++] = "--constructor-args";
      inputBuilder[idx++] = _toHex(constructorData);
    }

    if (!defenderOpts.skipVerifySourceCode) {
      inputBuilder[idx++] = "--verify-source-code";
      string memory licenseType = bytes(defenderOpts.licenseType).length == 0
        ? _toLicenseType(contractInfo)
        : defenderOpts.licenseType;
      if (!defenderOpts.skipLicenseType) {
        inputBuilder[idx++] = "--license-type";
        inputBuilder[idx++] = licenseType;
      }
    }

    if (bytes(defenderOpts.relayerId).length != 0) {
      inputBuilder[idx++] = "--relayer-id";
      inputBuilder[idx++] = defenderOpts.relayerId;
    }

    if (bytes(defenderOpts.salt).length != 0) {
      inputBuilder[idx++] = "--salt";
      inputBuilder[idx++] = defenderOpts.salt;
    }

    if (defenderOpts.txOverrides.gasLimit != 0) {
      inputBuilder[idx++] = "--gas-limit";
      inputBuilder[idx++] = _toString(defenderOpts.txOverrides.gasLimit);
    }
    if (defenderOpts.txOverrides.gasPrice != 0) {
      inputBuilder[idx++] = "--gas-price";
      inputBuilder[idx++] = _toString(defenderOpts.txOverrides.gasPrice);
    }
    if (defenderOpts.txOverrides.maxFeePerGas != 0) {
      inputBuilder[idx++] = "--max-fee-per-gas";
      inputBuilder[idx++] = _toString(defenderOpts.txOverrides.maxFeePerGas);
    }
    if (defenderOpts.txOverrides.maxPriorityFeePerGas != 0) {
      inputBuilder[idx++] = "--max-priority-fee-per-gas";
      inputBuilder[idx++] = _toString(defenderOpts.txOverrides.maxPriorityFeePerGas);
    }

    if (bytes(defenderOpts.metadata).length != 0) {
      inputBuilder[idx++] = "--metadata";
      inputBuilder[idx++] = defenderOpts.metadata;
    }

    string[] memory inputs = new string[](idx);
    for (uint256 i = 0; i < idx; i++) {
      inputs[i] = inputBuilder[i];
    }
    return inputs;
  }

  /// @notice Converts a given SPDX license identifier into a standardized license type.
  ///
  /// @param contractInfo A struct containing the license identifier and contract path.
  /// @return string memory The standardized license type corresponding to the SPDX identifier.
  ///
  /// Steps:
  /// 1. Convert the license identifier into a slice for comparison.
  /// 2. Compare the license identifier against known SPDX identifiers.
  /// 3. Return the corresponding standardized license type.
  /// 4. If the license identifier is not recognized, revert with an error message indicating the unsupported license.
  function _toLicenseType(ContractInfo memory contractInfo) private pure returns (string memory) {
    bytes memory id = bytes(contractInfo.license);

    if (_eq(id, "MIT")) return "MIT";
    if (_eq(id, "GPL-3.0") || _eq(id, "GPL-3.0-only")) return "GPL-3.0";
    if (_eq(id, "GPL-3.0-or-later")) return "GPL-3.0-or-later";
    if (_eq(id, "GPL-2.0") || _eq(id, "GPL-2.0-only")) return "GPL-2.0";
    if (_eq(id, "GPL-2.0-or-later")) return "GPL-2.0-or-later";
    if (_eq(id, "AGPL-3.0") || _eq(id, "AGPL-3.0-only")) return "AGPL-3.0";
    if (_eq(id, "AGPL-3.0-or-later")) return "AGPL-3.0-or-later";
    if (_eq(id, "LGPL-3.0") || _eq(id, "LGPL-3.0-only")) return "LGPL-3.0";
    if (_eq(id, "LGPL-3.0-or-later")) return "LGPL-3.0-or-later";
    if (_eq(id, "Unlicense")) return "UNLICENSED";
    if (_eq(id, "Apache-2.0")) return "Apache-2.0";
    if (_eq(id, "BSD-3-Clause")) return "BSD-3-Clause";

    revert(
      string(
        abi.encodePacked(
          "Unsupported SPDX license '",
          contractInfo.license,
          "' for contract at ",
          contractInfo.path
        )
      )
    );
  }

  /// @notice Proposes an upgrade for a proxy contract by deploying a new implementation and submitting the upgrade proposal.
  ///
  /// @param proxyAddress The address of the proxy contract to be upgraded.
  /// @param proxyAdminAddress The address of the proxy admin contract that manages the proxy.
  /// @param newImplementationAddress The address of the new implementation contract.
  /// @param newImplementationContractName The name of the new implementation contract.
  /// @param opts Additional options for the upgrade proposal.
  ///
  /// @return ProposeUpgradeResponse A struct containing the response from the upgrade proposal process.
  ///
  /// Steps:
  /// 1. Initialize the Vm (cheatcode) instance for interacting with the environment.
  /// 2. Retrieve the output directory and contract information for the new implementation contract.
  /// 3. Build the command to propose the upgrade using the provided parameters and contract info.
  /// 4. Execute the command as a bash command using the Vm's FFI (Foreign Function Interface).
  /// 5. Check the exit code of the command:
  ///    - If the exit code is not 0, revert with an error message indicating the failure.
  ///    - If successful, parse the stdout into a `ProposeUpgradeResponse` struct and return it.
  ///
  /// Reverts:
  /// - If the command execution fails (exit code != 0), the function reverts with an error message.
  function proposeUpgrade(
    address proxyAddress,
    address proxyAdminAddress,
    address newImplementationAddress,
    string memory newImplementationContractName,
    Options memory opts
  ) internal returns (ProposeUpgradeResponse memory) {
    string memory outDir = vm.envOr("FOUNDRY_OUT_DIR", string("out"));
    ContractInfo memory contractInfo = _getContractInfo(newImplementationContractName, outDir);

    string[] memory inputs = buildProposeUpgradeCommand(
      proxyAddress,
      proxyAdminAddress,
      newImplementationAddress,
      contractInfo,
      opts
    );

    (int256 exitCode, bytes memory stdoutBytes, bytes memory stderrBytes) = vm.ffiWithReturnStdoutStderr(inputs);
    if (exitCode != 0) {
      revert(string(abi.encodePacked("Defender propose-upgrade failed: ", string(stderrBytes))));
    }

    return parseProposeUpgradeResponse(string(stdoutBytes));
  }

  /// @notice Parses the response from a propose upgrade command and extracts the proposal ID and URL.
  ///
  /// @param stdout The raw string output from the propose upgrade command.
  /// @return response A `ProposeUpgradeResponse` struct containing the parsed proposal ID and URL.
  ///
  /// Steps:
  /// 1. Initialize an empty `ProposeUpgradeResponse` struct.
  /// 2. Extract the proposal ID by parsing the line starting with "Proposal ID: " from the stdout.
  /// 3. Extract the proposal URL by parsing the line starting with "Proposal URL: " from the stdout.
  /// 4. Return the populated `ProposeUpgradeResponse` struct.
  function parseProposeUpgradeResponse(
    string memory stdout
  ) internal pure returns (ProposeUpgradeResponse memory response) {
    response.proposalId = _parseLine("Proposal ID: ", stdout, true);
    response.proposalUrl = _parseLine("Proposal URL: ", stdout, true);
  }

  /// @notice Parses a line from a given string output based on an expected prefix.
  ///
  /// Steps:
  /// 1. Convert the expected prefix into a slice for comparison.
  /// 2. Check if the output string contains the expected prefix.
  /// 3. If the prefix is found:
  ///    - Extract the substring beyond the prefix.
  ///    - Remove any following lines by splitting at the newline character.
  ///    - Return the extracted substring.
  /// 4. If the prefix is not found and the line is required:
  ///    - Revert with an error message indicating the prefix was not found.
  /// 5. If the prefix is not found and the line is not required:
  ///    - Return an empty string.
  ///
  /// @param expectedPrefix The prefix to search for in the output string.
  /// @param stdout The output string to parse.
  /// @param required Whether the line with the prefix is mandatory.
  /// @return The parsed line or an empty string if not required.
  function _parseLine(
    string memory expectedPrefix,
    string memory stdout,
    bool required
  ) private pure returns (string memory) {
    bytes memory out = bytes(stdout);
    bytes memory prefix = bytes(expectedPrefix);

    int256 idx = _indexOf(out, prefix);
    if (idx < 0) {
      if (required) {
        revert(string(abi.encodePacked("Expected prefix not found: ", expectedPrefix)));
      }
      return "";
    }

    uint256 start = uint256(idx) + prefix.length;
    uint256 i = start;
    while (i < out.length && out[i] != "\n") {
      i++;
    }

    bytes memory line = new bytes(i - start);
    for (uint256 j = 0; j < line.length; j++) {
      line[j] = out[start + j];
    }
    return string(line);
  }

  /// @notice Builds a command to propose an upgrade for a proxy contract using OpenZeppelin Defender.
  ///
  /// @param proxyAddress The address of the proxy contract to be upgraded.
  /// @param proxyAdminAddress The address of the proxy admin contract (optional, can be zero address).
  /// @param newImplementationAddress The address of the new implementation contract.
  /// @param contractInfo Contains the path to the contract artifact file.
  /// @param opts Contains additional options, such as the upgrade approval process ID.
  ///
  /// Steps:
  /// 1. Initialize a Vm instance for cheatcode operations.
  /// 2. Create an array to hold the command inputs, with a maximum length of 255.
  /// 3. Populate the array with the necessary command components:
  ///    - Command to run the OpenZeppelin Defender CLI.
  ///    - Proxy address and new implementation address.
  ///    - Chain ID of the current blockchain.
  ///    - Path to the contract artifact file.
  ///    - Proxy admin address (if provided).
  ///    - Upgrade approval process ID (if provided).
  /// 4. Create a correctly sized array to hold the command inputs.
  /// 5. Copy the populated inputs into the correctly sized array.
  /// 6. Return the array of command inputs.
  ///
  /// @return inputs The array of strings representing the command to propose the upgrade.
  function buildProposeUpgradeCommand(
    address proxyAddress,
    address proxyAdminAddress,
    address newImplementationAddress,
    ContractInfo memory contractInfo,
    Options memory opts
  ) internal view returns (string[] memory) {
    string[] memory inputBuilder = new string[](255);
    uint256 idx = 0;

    inputBuilder[idx++] = "npx";
    inputBuilder[idx++] = "@openzeppelin/defender-deploy-client@latest";
    inputBuilder[idx++] = "propose-upgrade";
    inputBuilder[idx++] = "--network";
    inputBuilder[idx++] = _toString(block.chainid);
    inputBuilder[idx++] = "--proxy-address";
    inputBuilder[idx++] = _toHex(abi.encodePacked(proxyAddress));
    inputBuilder[idx++] = "--new-implementation-address";
    inputBuilder[idx++] = _toHex(abi.encodePacked(newImplementationAddress));
    inputBuilder[idx++] = "--artifact";
    inputBuilder[idx++] = contractInfo.path;

    if (proxyAdminAddress != address(0)) {
      inputBuilder[idx++] = "--proxy-admin";
      inputBuilder[idx++] = _toHex(abi.encodePacked(proxyAdminAddress));
    }

    if (bytes(opts.approvalProcessId).length != 0) {
      inputBuilder[idx++] = "--approval-process-id";
      inputBuilder[idx++] = opts.approvalProcessId;
    }

    string[] memory inputs = new string[](idx);
    for (uint256 i = 0; i < idx; i++) {
      inputs[i] = inputBuilder[i];
    }
    return inputs;
  }

  /// @notice Retrieves the approval process for a given command by executing a bash command and parsing the output.
  ///
  /// Steps:
  /// 1. Build the command inputs required to fetch the approval process.
  /// 2. Execute the command as a bash command using the `Utils.runAsBashCommand` function.
  /// 3. Retrieve the standard output from the command execution.
  ///
  /// 4. Check if the command execution was successful by verifying the exit code.
  /// 5. If the exit code is non-zero, revert with an error message containing the standard error output.
  ///
  /// 6. Parse the standard output to create an `ApprovalProcessResponse` object.
  /// 7. Return the parsed `ApprovalProcessResponse`.
  function getApprovalProcess(string memory command) internal returns (ApprovalProcessResponse memory) {
    string[] memory inputs = buildGetApprovalProcessCommand(command);
    (int256 exitCode, bytes memory stdoutBytes, bytes memory stderrBytes) = vm.ffiWithReturnStdoutStderr(inputs);

    if (exitCode != 0) {
      revert(string(abi.encodePacked("Defender approval-process command failed: ", string(stderrBytes))));
    }

    return parseApprovalProcessResponse(string(stdoutBytes));
  }

  /// @notice Parses the approval process response from a given stdout string and returns an `ApprovalProcessResponse` struct.
  ///
  /// @param stdout The string containing the output from which the approval process response is to be parsed.
  /// @return response An `ApprovalProcessResponse` struct containing the parsed data.
  ///
  /// Steps:
  /// 1. Initialize a `Vm` instance using the cheatcode address.
  /// 2. Create an empty `ApprovalProcessResponse` struct.
  /// 3. Parse the "Approval process ID" from the stdout string and assign it to the response.
  /// 4. Parse the "Via" field from the stdout string. If it exists, convert it to an address and assign it to the response.
  /// 5. Parse the "Via type" from the stdout string and assign it to the response.
  /// 6. Return the populated `ApprovalProcessResponse` struct.
  function parseApprovalProcessResponse(
    string memory stdout
  ) internal pure returns (ApprovalProcessResponse memory response) {
    response.approvalProcessId = _parseLine("Approval process ID: ", stdout, true);

    string memory viaStr = _parseLine("Via: ", stdout, false);
    if (bytes(viaStr).length != 0) {
      response.via = _toAddress(viaStr);
    }

    response.viaType = _parseLine("Via type: ", stdout, false);
  }

  /// @notice Constructs a command for the OpenZeppelin Defender Deploy Client CLI to get approval process details.
  ///
  /// @param command The base command to be executed (e.g., "approval-process:get").
  /// @return inputs An array of strings representing the full CLI command with arguments.
  ///
  /// Steps:
  /// 1. Initialize a string array `inputBuilder` with a size of 255 to temporarily store command components.
  /// 2. Add the base command components:
  ///    - "npx" (Node Package Executor).
  ///    - The OpenZeppelin Defender Deploy Client CLI package with its version.
  ///    - The provided `command` (e.g., "approval-process:get").
  ///    - The `--chainId` flag followed by the current blockchain's chain ID.
  /// 3. Create a new string array `inputs` with the correct length (number of components added).
  /// 4. Copy the components from `inputBuilder` to `inputs` to avoid empty slots.
  /// 5. Return the `inputs` array as the final command.
  function buildGetApprovalProcessCommand(
    string memory command
  ) internal view returns (string[] memory) {
    string[] memory inputBuilder = new string[](255);
    uint256 idx = 0;

    inputBuilder[idx++] = "npx";
    inputBuilder[idx++] = "@openzeppelin/defender-deploy-client@latest";
    inputBuilder[idx++] = command;
    inputBuilder[idx++] = "--chainId";
    inputBuilder[idx++] = _toString(block.chainid);

    string[] memory inputs = new string[](idx);
    for (uint256 i = 0; i < idx; i++) {
      inputs[i] = inputBuilder[i];
    }
    return inputs;
  }

  // --------- internal helpers ---------

  function _getContractInfo(
    string memory contractName,
    string memory outDir
  ) private view returns (ContractInfo memory info) {
    // Assume standard Foundry artifact layout: out/<ContractName>.sol/<ContractName>.json
    string memory artifactPath = string(
      abi.encodePacked(outDir, "/", contractName, ".sol/", contractName, ".json")
    );

    string memory json = vm.readFile(artifactPath);
    string memory metadata = json.parseRaw(".metadata");
    string memory sources = metadata.parseRaw(".sources");
    string[] memory sourceNames = sources.parseKeys();
    require(sourceNames.length > 0, "No sources in artifact");

    string memory firstSource = sourceNames[0];
    string memory sourceMetaPath = string(abi.encodePacked(".sources.", firstSource));
    string memory license = metadata.readString(string(abi.encodePacked(sourceMetaPath, ".license")));

    info.name = contractName;
    info.path = artifactPath;
    info.license = license;
    info.sourceName = firstSource;
    info.shortName = contractName;
    info.sourceHash = metadata.readString(".output.sourcesFingerprints[0]");
  }

  function _indexOf(bytes memory data, bytes memory needle) private pure returns (int256) {
    if (needle.length == 0 || needle.length > data.length) return -1;
    for (uint256 i = 0; i <= data.length - needle.length; i++) {
      bool match_ = true;
      for (uint256 j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) {
          match_ = false;
          break;
        }
      }
      if (match_) return int256(i);
    }
    return -1;
  }

  function _eq(bytes memory a, string memory b) private pure returns (bool) {
    bytes memory bb = bytes(b);
    if (a.length != bb.length) return false;
    for (uint256 i = 0; i < a.length; i++) {
      if (a[i] != bb[i]) return false;
    }
    return true;
  }

  function _toString(uint256 v) private pure returns (string memory) {
    if (v == 0) return "0";
    uint256 j = v;
    uint256 length;
    while (j != 0) {
      length++;
      j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    j = v;
    while (j != 0) {
      k = k - 1;
      bstr[k] = bytes1(uint8(48 + uint256(j % 10)));
      j /= 10;
    }
    return string(bstr);
  }

  function _toHex(bytes memory data) private pure returns (string memory) {
    bytes16 hexChars = "0123456789abcdef";
    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = "0";
    str[1] = "x";
    for (uint256 i = 0; i < data.length; i++) {
      str[2 + i * 2] = hexChars[uint8(data[i] >> 4)];
      str[3 + i * 2] = hexChars[uint8(data[i] & 0x0f)];
    }
    return string(str);
  }

  function _toAddress(string memory s) private pure returns (address) {
    bytes memory b = bytes(s);
    require(b.length >= 42, "Address string too short");
    uint256 start = b[1] == "x" || b[1] == "X" ? 2 : 0;
    uint160 result = 0;
    for (uint256 i = start; i < start + 40 && i < b.length; i++) {
      uint8 c = uint8(b[i]);
      uint8 value;
      if (c >= 48 && c <= 57) value = c - 48;
      else if (c >= 65 && c <= 70) value = c - 55;
      else if (c >= 97 && c <= 102) value = c - 87;
      else revert("Invalid hex char");
      result = (result << 4) | uint160(value);
    }
    return address(result);
  }
}