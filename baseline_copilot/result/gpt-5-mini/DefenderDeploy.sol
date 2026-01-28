// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Minimal Vm interface for Foundry FFI usage.
interface Vm {
    function ffi(string[] calldata) external returns (bytes memory);
}

/// @title DefenderDeploy
/// @notice Utilities to deploy and propose upgrades via OpenZeppelin Defender CLI using Foundry's vm.ffi cheatcode.
/// Note: This library relies on a Foundry Vm FFI cheatcode available at a pseudo-deterministic address derivation.
library DefenderDeploy {
    // Structs used by the library
    struct DefenderOptions {
        string licenseType;
        string relayerId;
        uint256 salt;
        uint256 gasLimit;
        uint256 gasPrice;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        string metadata;
        bool skipVerifySourceCode;
        bool skipLicenseType;
    }

    struct ContractInfo {
        string name;
        string path;
        string license;
        string sourceHash;
        string shortName;
    }

    struct Options {
        string approvalProcessId;
    }

    struct ProposeUpgradeResponse {
        string proposalId;
        string proposalUrl;
    }

    struct ApprovalProcessResponse {
        string id;
        address via;
        string viaType;
    }

    /// @dev derive a Vm instance using a runtime-keccak derivation compatible with Foundry HEVM address patterns
    function _vm() private pure returns (Vm) {
        // Use a derived address for the vm cheatcode.
        // This is a commonly used pattern in Foundry-based Solidity libraries.
        address vmAddr = address(uint160(uint256(keccak256(abi.encodePacked("hevm cheat code")))));
        return Vm(vmAddr);
    }

    /**
     * @notice Deploys a contract using the provided contract name, constructor data, and deployment options.
     */
    function deploy(
        string memory contractName,
        bytes memory constructorData,
        DefenderOptions memory defenderOpts
    ) internal returns (address) {
        // For simplicity we expect contractInfo and buildInfo resolution to be done external to this helper.
        // Here we construct a deploy command and run it via vm.ffi, then parse the resulting address.
        // Minimal placeholders for demonstration:
        ContractInfo memory contractInfo = ContractInfo({
            name: contractName,
            path: string(abi.encodePacked("out/", contractName, ".json")),
            license: "",
            sourceHash: "",
            shortName: contractName
        });

        string memory buildInfoFile = string(abi.encodePacked("out/", contractName, ".buildinfo.json"));

        string[] memory cmd = buildDeployCommand(contractInfo, buildInfoFile, constructorData, defenderOpts);
        bytes memory raw = _vm().ffi(cmd);
        string memory stdout = string(raw);

        // attempt to parse address from stdout
        string memory addrStr = _parseLine("Deployed to: ", stdout, true);
        return _parseAddress(addrStr);
    }

    /**
     * @notice Constructs a deploy command for deploying a contract using OpenZeppelin Defender.
     */
    function buildDeployCommand(
        ContractInfo memory contractInfo,
        string memory buildInfoFile,
        bytes memory constructorData,
        DefenderOptions memory defenderOpts
    ) internal view returns (string[] memory) {
        string[] memory inputBuilder = new string[](255);
        uint256 idx = 0;

        inputBuilder[idx++] = "npx";
        inputBuilder[idx++] = "@openzeppelin/defender-relay-client@latest";
        inputBuilder[idx++] = "deploy";
        inputBuilder[idx++] = "--contract";
        inputBuilder[idx++] = contractInfo.path;
        inputBuilder[idx++] = "--name";
        inputBuilder[idx++] = contractInfo.name;
        inputBuilder[idx++] = "--chainId";
        inputBuilder[idx++] = _toString(block.chainid);
        inputBuilder[idx++] = "--build-info";
        inputBuilder[idx++] = buildInfoFile;

        if (constructorData.length > 0) {
            inputBuilder[idx++] = "--constructor";
            inputBuilder[idx++] = _toHex(constructorData);
        }

        // license handling
        if (!defenderOpts.skipLicenseType && bytes(defenderOpts.licenseType).length > 0) {
            inputBuilder[idx++] = "--license-type";
            inputBuilder[idx++] = defenderOpts.licenseType;
        }

        if (bytes(defenderOpts.relayerId).length > 0) {
            inputBuilder[idx++] = "--relayer";
            inputBuilder[idx++] = defenderOpts.relayerId;
        }

        if (defenderOpts.salt != 0) {
            inputBuilder[idx++] = "--salt";
            inputBuilder[idx++] = _toString(defenderOpts.salt);
        }

        if (defenderOpts.gasLimit != 0) {
            inputBuilder[idx++] = "--gas";
            inputBuilder[idx++] = _toString(defenderOpts.gasLimit);
        }

        if (defenderOpts.gasPrice != 0) {
            inputBuilder[idx++] = "--gasPrice";
            inputBuilder[idx++] = _toString(defenderOpts.gasPrice);
        }

        if (defenderOpts.maxFeePerGas != 0) {
            inputBuilder[idx++] = "--maxFeePerGas";
            inputBuilder[idx++] = _toString(defenderOpts.maxFeePerGas);
        }

        if (defenderOpts.maxPriorityFeePerGas != 0) {
            inputBuilder[idx++] = "--maxPriorityFeePerGas";
            inputBuilder[idx++] = _toString(defenderOpts.maxPriorityFeePerGas);
        }

        if (bytes(defenderOpts.metadata).length > 0) {
            inputBuilder[idx++] = "--metadata";
            inputBuilder[idx++] = defenderOpts.metadata;
        }

        // copy to correctly sized array
        string[] memory inputs = new string[](idx);
        for (uint256 i = 0; i < idx; i++) {
            inputs[i] = inputBuilder[i];
        }
        return inputs;
    }

    /**
     * @notice Converts a given SPDX license identifier into a standardized license type.
     */
    function _toLicenseType(ContractInfo memory contractInfo) private pure returns (string memory) {
        bytes memory lic = bytes(contractInfo.license);
        if (lic.length == 0) {
            revert("unsupported license: empty");
        }
        // map common SPDX identifiers to CLI license args
        if (_equals(lic, "MIT")) return "MIT";
        if (_equals(lic, "Apache-2.0")) return "APACHE";
        if (_equals(lic, "GPL-3.0")) return "GPL3";
        revert(string(abi.encodePacked("unsupported license: ", contractInfo.license)));
    }

    /**
     * @notice Proposes an upgrade for a proxy contract by deploying a new implementation and submitting the upgrade proposal.
     */
    function proposeUpgrade(
        address proxyAddress,
        address proxyAdminAddress,
        address newImplementationAddress,
        string memory newImplementationContractName,
        Options memory opts
    ) internal returns (ProposeUpgradeResponse memory) {
        ContractInfo memory contractInfo = ContractInfo({
            name: newImplementationContractName,
            path: string(abi.encodePacked("out/", newImplementationContractName, ".json")),
            license: "",
            sourceHash: "",
            shortName: newImplementationContractName
        });

        string[] memory cmd = buildProposeUpgradeCommand(proxyAddress, proxyAdminAddress, newImplementationAddress, contractInfo, opts);
        bytes memory raw = _vm().ffi(cmd);
        string memory stdout = string(raw);

        return parseProposeUpgradeResponse(stdout);
    }

    /**
     * @notice Parses the response from a propose upgrade command and extracts the proposal ID and URL.
     */
    function parseProposeUpgradeResponse(string memory stdout) internal pure returns (ProposeUpgradeResponse memory) {
        ProposeUpgradeResponse memory resp;
        resp.proposalId = _parseLine("Proposal ID: ", stdout, true);
        resp.proposalUrl = _parseLine("Proposal URL: ", stdout, false);
        return resp;
    }

    /**
     * @notice Parses a line from a given string output based on an expected prefix.
     */
    function _parseLine(string memory expectedPrefix, string memory stdout, bool required) private pure returns (string memory) {
        bytes memory s = bytes(stdout);
        bytes memory p = bytes(expectedPrefix);
        if (s.length < p.length) {
            if (required) revert(string(abi.encodePacked("missing prefix: ", expectedPrefix)));
            return "";
        }

        // find prefix in stdout
        for (uint256 i = 0; i + p.length <= s.length; i++) {
            bool matchPrefix = true;
            for (uint256 j = 0; j < p.length; j++) {
                if (s[i + j] != p[j]) {
                    matchPrefix = false;
                    break;
                }
            }
            if (matchPrefix) {
                // extract until newline or end
                uint256 start = i + p.length;
                uint256 end = start;
                while (end < s.length && s[end] != 0x0a && s[end] != 0x0d) {
                    end++;
                }
                bytes memory out = new bytes(end - start);
                for (uint256 k = start; k < end; k++) out[k - start] = s[k];
                return string(out);
            }
        }

        if (required) revert(string(abi.encodePacked("prefix not found: ", expectedPrefix)));
        return "";
    }

    /**
     * @notice Builds a command to propose an upgrade for a proxy contract using OpenZeppelin Defender.
     */
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
        inputBuilder[idx++] = "@openzeppelin/defender-relay-client@latest";
        inputBuilder[idx++] = "propose-upgrade";
        inputBuilder[idx++] = "--proxy";
        inputBuilder[idx++] = _toHexAddress(proxyAddress);
        inputBuilder[idx++] = "--implementation";
        inputBuilder[idx++] = _toHexAddress(newImplementationAddress);
        inputBuilder[idx++] = "--chainId";
        inputBuilder[idx++] = _toString(block.chainid);
        inputBuilder[idx++] = "--artifact";
        inputBuilder[idx++] = contractInfo.path;

        if (proxyAdminAddress != address(0)) {
            inputBuilder[idx++] = "--admin";
            inputBuilder[idx++] = _toHexAddress(proxyAdminAddress);
        }

        if (bytes(opts.approvalProcessId).length > 0) {
            inputBuilder[idx++] = "--approval";
            inputBuilder[idx++] = opts.approvalProcessId;
        }

        string[] memory inputs = new string[](idx);
        for (uint256 i = 0; i < idx; i++) inputs[i] = inputBuilder[i];
        return inputs;
    }

    /**
     * @notice Retrieves the approval process for a given command by executing a bash command and parsing the output.
     */
    function getApprovalProcess(string memory command) internal returns (ApprovalProcessResponse memory) {
        string[] memory cmd = buildGetApprovalProcessCommand(command);
        bytes memory raw = _vm().ffi(cmd);
        string memory stdout = string(raw);

        return parseApprovalProcessResponse(stdout);
    }

    /**
     * @notice Parses the approval process response from a given stdout string and returns an `ApprovalProcessResponse` struct.
     */
    function parseApprovalProcessResponse(string memory stdout) internal pure returns (ApprovalProcessResponse memory) {
        ApprovalProcessResponse memory resp;
        resp.id = _parseLine("Approval process ID: ", stdout, true);
        string memory viaStr = _parseLine("Via: ", stdout, false);
        if (bytes(viaStr).length > 0) {
            resp.via = _parseAddress(viaStr);
        }
        resp.viaType = _parseLine("Via type: ", stdout, false);
        return resp;
    }

    /**
     * @notice Constructs a command for the OpenZeppelin Defender Deploy Client CLI to get approval process details.
     */
    function buildGetApprovalProcessCommand(string memory command) internal view returns (string[] memory) {
        string[] memory inputBuilder = new string[](255);
        uint256 idx = 0;
        inputBuilder[idx++] = "npx";
        inputBuilder[idx++] = "@openzeppelin/defender-relay-client@latest";
        inputBuilder[idx++] = command;
        inputBuilder[idx++] = "--chainId";
        inputBuilder[idx++] = _toString(block.chainid);

        string[] memory inputs = new string[](idx);
        for (uint256 i = 0; i < idx; i++) inputs[i] = inputBuilder[i];
        return inputs;
    }

    // -------------------------
    // Helper utilities
    // -------------------------
    function _equals(bytes memory a, string memory b) private pure returns (bool) {
        return keccak256(a) == keccak256(bytes(b));
    }

    function _toString(uint256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        uint256 temp = v;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = v;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }

    function _toHex(bytes memory data) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }

    function _toHexAddress(address a) private pure returns (string memory) {
        return _toHex(abi.encodePacked(a));
    }

    function _parseAddress(string memory s) private pure returns (address) {
        bytes memory str = bytes(s);
        uint256 start = 0;
        if (str.length >= 2 && str[0] == "0" && str[1] == "x") start = 2;
        uint256 end = str.length;
        // parse last 40 hex chars if full string is longer
        if (end - start > 40) start = end - 40;
        uint160 result = 0;
        for (uint256 i = start; i < end; i++) {
            uint8 c = uint8(str[i]);
            uint8 value;
            if (c >= 48 && c <= 57) value = c - 48;
            else if (c >= 97 && c <= 102) value = 10 + c - 97;
            else if (c >= 65 && c <= 70) value = 10 + c - 65;
            else value = 0;
            result = result * 16 + value;
        }
        return address(result);
    }
}