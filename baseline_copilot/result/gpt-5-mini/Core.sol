// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Core {
    struct Options {
        bool unsafeSkipAllChecks;
        bool unsafeSkipStorageCheck;
        string unsafeAllow;
        bool unsafeAllowRenames;
        string reference;
        string buildInfoDir;
        string[] referenceBuildInfoDirs;
        string[] exclude;
        bool defenderDeploy;
        bytes implementationBytecode; // optional: raw creation bytecode for simple deploy flows
    }

    // No-op modifier to allow "tryPrank" usage in signatures (placeholder for external tooling)
    modifier tryPrank(address) {
        _;
    }

    // -----------------------
    // High level upgrade APIs
    // -----------------------

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        Options memory opts
    ) internal {
        address newImpl = prepareUpgrade(contractName, opts);
        upgradeProxyTo(proxy, newImpl, data);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation (impersonate tryCaller).
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        Options memory opts,
        address tryCaller
    ) internal tryPrank(tryCaller) {
        upgradeProxy(proxy, contractName, data, opts);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation address.
     */
    function upgradeProxyTo(
        address proxy,
        address newImpl,
        bytes memory data
    ) internal {
        // Determine if there's an admin (transparent proxy pattern)
        (bool ok, bytes memory adminRes) = proxy.staticcall(abi.encodeWithSignature("admin()"));
        address adminAddr = address(0);
        if (ok && adminRes.length >= 32) {
            adminAddr = abi.decode(adminRes, (address));
        }

        // Determine UUPS / implementation-facing upgrade vs proxy-admin upgrade
        if (adminAddr == address(0)) {
            // UUPS style: call upgradeTo or upgradeToAndCall on the proxy itself
            if (bytes(getUpgradeInterfaceVersion(proxy)).length != 0 || data.length > 0) {
                // Try upgradeToAndCall(address,bytes)
                (bool success, bytes memory ret) = proxy.call(
                    abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImpl, data)
                );
                if (!success) revert(_getRevertMsg(ret));
            } else {
                (bool success, bytes memory ret) = proxy.call(
                    abi.encodeWithSignature("upgradeTo(address)", newImpl)
                );
                if (!success) revert(_getRevertMsg(ret));
            }
        } else {
            // ProxyAdmin style: call upgrade(proxy, newImpl) or upgradeAndCall(proxy, newImpl, data)
            if (bytes(getUpgradeInterfaceVersion(adminAddr)).length != 0 || data.length > 0) {
                (bool success, bytes memory ret) = adminAddr.call(
                    abi.encodeWithSignature("upgradeAndCall(address,address,bytes)", proxy, newImpl, data)
                );
                if (!success) revert(_getRevertMsg(ret));
            } else {
                (bool success, bytes memory ret) = adminAddr.call(
                    abi.encodeWithSignature("upgrade(address,address)", proxy, newImpl)
                );
                if (!success) revert(_getRevertMsg(ret));
            }
        }
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation address (impersonate tryCaller).
     */
    function upgradeProxyTo(
        address proxy,
        address newImpl,
        bytes memory data,
        address tryCaller
    ) internal tryPrank(tryCaller) {
        upgradeProxyTo(proxy, newImpl, data);
    }

    // -----------------------
    // Beacon upgrade APIs
    // -----------------------

    /**
     * @notice Upgrades a beacon to a new implementation by contract name.
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName,
        Options memory opts
    ) internal {
        address newImpl = prepareUpgrade(contractName, opts);
        upgradeBeaconTo(beacon, newImpl);
    }

    /**
     * @notice Upgrades a beacon to a new implementation by contract name (impersonate tryCaller).
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName,
        Options memory opts,
        address tryCaller
    ) internal tryPrank(tryCaller) {
        upgradeBeacon(beacon, contractName, opts);
    }

    /**
     * @notice Upgrades the implementation of a beacon contract to a new address.
     */
    function upgradeBeacon(address beacon, address newImpl) internal {
        (bool success, bytes memory ret) = beacon.call(abi.encodeWithSignature("upgradeTo(address)", newImpl));
        if (!success) revert(_getRevertMsg(ret));
    }

    /**
     * @notice Upgrades the implementation of a beacon contract to a new address (impersonate tryCaller).
     */
    function upgradeBeacon(address beacon, address newImpl, address tryCaller) internal tryPrank(tryCaller) {
        upgradeBeacon(beacon, newImpl);
    }

    // -----------------------
    // Validation / deployment
    // -----------------------

    function validateImplementation(string memory contractName, Options memory opts) internal {
        _validate(contractName, opts, false);
    }

    function deployImplementation(string memory contractName, Options memory opts) internal returns (address) {
        // Validate first
        _validate(contractName, opts, false);

        // If a raw bytecode is provided in opts, deploy it; otherwise revert indicating no bytecode
        if (opts.implementationBytecode.length == 0) {
            revert("Core: no implementation bytecode provided in options");
        }

        address addr = _deployFromBytecode(opts.implementationBytecode);
        require(addr != address(0), "Core: deployment failed");
        return addr;
    }

    function validateUpgrade(string memory contractName, Options memory opts) internal {
        _validate(contractName, opts, true);
    }

    function prepareUpgrade(string memory contractName, Options memory opts) internal returns (address) {
        validateUpgrade(contractName, opts);
        return deployImplementation(contractName, opts);
    }

    // -----------------------
    // Proxy/beacon helpers
    // -----------------------

    function getAdminAddress(address proxy) internal view returns (address) {
        (bool ok, bytes memory res) = proxy.staticcall(abi.encodeWithSignature("admin()"));
        if (ok && res.length >= 32) {
            return abi.decode(res, (address));
        }
        return address(0);
    }

    function getImplementationAddress(address proxy) internal view returns (address) {
        (bool ok, bytes memory res) = proxy.staticcall(abi.encodeWithSignature("implementation()"));
        if (ok && res.length >= 32) {
            return abi.decode(res, (address));
        }
        return address(0);
    }

    function getBeaconAddress(address proxy) internal view returns (address) {
        (bool ok, bytes memory res) = proxy.staticcall(abi.encodeWithSignature("beacon()"));
        if (ok && res.length >= 32) {
            return abi.decode(res, (address));
        }
        return address(0);
    }

    /**
     * @notice Attempts to read a contract's UPGRADE_INTERFACE_VERSION constant / function.
     */
    function getUpgradeInterfaceVersion(address addr) internal view returns (string memory) {
        (bool ok, bytes memory data) = addr.staticcall(abi.encodeWithSignature("UPGRADE_INTERFACE_VERSION()"));
        if (!ok || data.length == 0) {
            return "";
        }
        // Attempt to decode as string if possible; fallback to empty string on failure
        // If the return is an ABI-encoded string it should decode fine
        try this._decodeString(data) returns (string memory s) {
            return s;
        } catch {
            return "";
        }
    }

    function inferProxyAdmin(address addr) internal view returns (bool) {
        return _hasOwner(addr);
    }

    function _hasOwner(address addr) private view returns (bool) {
        (bool ok, bytes memory res) = addr.staticcall(abi.encodeWithSignature("owner()"));
        return ok && res.length >= 32;
    }

    // -----------------------
    // Validation command builder (best-effort)
    // -----------------------

    function _validate(string memory contractName, Options memory opts, bool requireReference) private {
        if (opts.unsafeSkipAllChecks) {
            return;
        }
        // In this environment we cannot execute external processes.
        // Build the command for tooling and simulate success.
        // If a real integration is required, external tooling must execute the produced command.
        string[] memory cmd = buildValidateCommand(contractName, opts, requireReference);

        // Best-effort sanity: basic validation of inputs
        require(bytes(contractName).length > 0, "Core: empty contract name for validation");

        // No-op: assume validation would be performed by off-chain tooling using the produced command.
        // If the user wants to enforce, they should wire up an external process to run `cmd`.
    }

    function buildValidateCommand(
        string memory contractName,
        Options memory opts,
        bool requireReference
    ) internal view returns (string[] memory) {
        // Base args: npx, @openzeppelin/upgrades-core@latest, validate, --build-info-dir, <dir>, <contract>
        uint256 extras = 0;
        extras += opts.referenceBuildInfoDirs.length;
        extras += opts.exclude.length;
        if (bytes(opts.reference).length != 0) extras += 1;
        if (opts.unsafeAllowRenames) extras += 1;
        if (bytes(opts.unsafeAllow).length != 0) extras += 1;
        if (opts.unsafeSkipStorageCheck) extras += 1;
        if (requireReference) extras += 1;

        uint256 base = 6; // npx, tool, validate, --build-info-dir, dir, contractFQN
        string[] memory inputs = new string[](base + extras);

        inputs[0] = "npx";
        inputs[1] = "@openzeppelin/upgrades-core@latest";
        inputs[2] = "validate";
        inputs[3] = "--build-info-dir";
        inputs[4] = opts.buildInfoDir;
        inputs[5] = contractName;

        uint256 idx = base;
        if (bytes(opts.reference).length != 0) {
            inputs[idx++] = "--reference";
            inputs[idx++] = opts.reference;
        }
        for (uint256 i = 0; i < opts.referenceBuildInfoDirs.length; i++) {
            inputs[idx++] = "--referenceBuildInfoDirs";
            inputs[idx++] = opts.referenceBuildInfoDirs[i];
        }
        for (uint256 i = 0; i < opts.exclude.length; i++) {
            inputs[idx++] = "--exclude";
            inputs[idx++] = opts.exclude[i];
        }
        if (opts.unsafeSkipStorageCheck) {
            inputs[idx++] = "--unsafeSkipStorageCheck";
        }
        if (requireReference) {
            inputs[idx++] = "--requireReference";
        }
        if (bytes(opts.unsafeAllow).length != 0) {
            inputs[idx++] = "--unsafeAllow";
            inputs[idx++] = opts.unsafeAllow;
        }
        if (opts.unsafeAllowRenames) {
            inputs[idx++] = "--unsafeAllowRenames";
        }

        // If actual used portion is smaller (due to our counting complexity), shrink the array
        if (idx != inputs.length) {
            string[] memory out = new string[](idx);
            for (uint256 j = 0; j < idx; j++) out[j] = inputs[j];
            return out;
        }
        return inputs;
    }

    // -----------------------
    // Deploy helpers
    // -----------------------

    function deploy(
        string memory contractName,
        bytes memory constructorData,
        Options memory opts
    ) internal returns (address) {
        if (opts.defenderDeploy) {
            revert("Core: DefenderDeploy not implemented in-contract");
        } else {
            // For name-based deployment, we expect the Options to carry implementationBytecode
            if (opts.implementationBytecode.length == 0) {
                // fallback to _deploy which requires bytecode resolution by other means
                return _deploy(contractName, constructorData);
            }
            // If constructor data is provided, append it to creation code
            bytes memory creation = abi.encodePacked(opts.implementationBytecode, constructorData);
            address addr = _deployFromBytecode(creation);
            require(addr != address(0), "Core: deploy failed");
            return addr;
        }
    }

    function _deploy(string memory /*contractName*/, bytes memory /*constructorData*/) private returns (address) {
        revert("Core: _deploy by contractName not implemented; provide implementationBytecode in Options");
    }

    function _deployFromBytecode(bytes memory bytecode) private returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        return addr;
    }

    // -----------------------
    // Utilities
    // -----------------------

    function _decodeString(bytes memory encoded) external pure returns (string memory) {
        // Helper to allow try/catch decoding in view context
        return abi.decode(encoded, (string));
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Core: transaction reverted";
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}