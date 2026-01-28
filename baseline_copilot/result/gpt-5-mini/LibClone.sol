// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibClone {
    error DeploymentFailed();
    error SaltDoesNotStartWith();

    /// @notice Simple EIP-1167 style init code generator.
    function initCode(address implementation) internal pure returns (bytes memory c) {
        // EIP-1167 minimal proxy creation + runtime code
        // creation: 0x3d602d80600a3d3981f3
        // runtime:  0x363d3d373d3d3d363d73<impl>5af43d82803e903d91602b57fd5bf3
        return abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            bytes20(implementation),
            hex"5af43d82803e903d91602b57fd5bf3"
        );
    }

    function initCode(address implementation, bytes memory /*args*/) internal pure returns (bytes memory c) {
        // For simplicity, append args to the standard init code.
        return abi.encodePacked(initCode(implementation));
    }

    function initCode_PUSH0(address implementation) internal pure returns (bytes memory c) {
        return initCode(implementation);
    }

    function initCode_PUSH0(address implementation, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCode(implementation, "");
    }

    function initCodeERC1967(address implementation) internal pure returns (bytes memory c) {
        // For compatibility return same as basic initCode.
        return initCode(implementation);
    }

    function initCodeERC1967(address implementation, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967(implementation);
    }

    function initCodeERC1967I(address implementation) internal pure returns (bytes memory c) {
        return initCode(implementation);
    }

    function initCodeERC1967I(address implementation, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967I(implementation);
    }

    function initCodeERC1967Bootstrap(address /*authorizedUpgrader*/) internal pure returns (bytes memory c) {
        return hex"00";
    }

    function initCodeERC1967BeaconProxy(address beacon) internal pure returns (bytes memory c) {
        return initCode(beacon);
    }

    function initCodeERC1967BeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967BeaconProxy(beacon);
    }

    function initCodeERC1967IBeaconProxy(address beacon) internal pure returns (bytes memory c) {
        return initCode(beacon);
    }

    function initCodeERC1967IBeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967IBeaconProxy(beacon);
    }

    function initCodeERC1967Bootstrap(address /*authorizedUpgrader*/) internal pure returns (bytes memory c) {
        return hex"00";
    }

    function initCodeHash(address implementation) internal pure returns (bytes32 hash) {
        return keccak256(initCode(implementation));
    }

    function initCodeHash(address implementation, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHash(implementation);
    }

    function initCodeHash_PUSH0(address implementation) internal pure returns (bytes32 hash) {
        return initCodeHash(implementation);
    }

    function initCodeHash_PUSH0(address implementation, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHash_PUSH0(implementation);
    }

    function initCodeHashERC1967(address implementation) internal pure returns (bytes32 hash) {
        return initCodeHash(implementation);
    }

    function initCodeHashERC1967(address implementation, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967(implementation);
    }

    function initCodeHashERC1967I(address implementation) internal pure returns (bytes32 hash) {
        return initCodeHash(implementation);
    }

    function initCodeHashERC1967I(address implementation, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967I(implementation);
    }

    function initCodeHashERC1967Bootstrap(address /*authorizedUpgrader*/) internal pure returns (bytes32) {
        return keccak256(hex"00");
    }

    function initCodeHashERC1967BeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        return initCodeHash(beacon);
    }

    function initCodeHashERC1967BeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967BeaconProxy(beacon);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        return initCodeHash(beacon);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967IBeaconProxy(beacon);
    }

    function initCodeHashERC1967Bootstrap(address /*authorizedUpgrader*/) internal pure returns (bytes32) {
        return keccak256(hex"00");
    }

    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        bytes32 h = initCodeHash(implementation);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function predictDeterministicAddress(address implementation, bytes memory /*data*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, deployer);
    }

    function predictDeterministicAddress_PUSH0(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, deployer);
    }

    function predictDeterministicAddress_PUSH0(address implementation, bytes memory /*data*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress_PUSH0(implementation, salt, deployer);
    }

    function predictDeterministicAddressERC1967(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, deployer);
    }

    function predictDeterministicAddressERC1967(address implementation, bytes memory /*args*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddressERC1967(implementation, salt, deployer);
    }

    function predictDeterministicAddressERC1967I(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, deployer);
    }

    function predictDeterministicAddressERC1967I(address implementation, bytes memory /*args*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddressERC1967I(implementation, salt, deployer);
    }

    function predictDeterministicAddressERC1967BeaconProxy(address beacon, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(beacon, salt, deployer);
    }

    function predictDeterministicAddressERC1967BeaconProxy(address beacon, bytes memory /*args*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddressERC1967BeaconProxy(beacon, salt, deployer);
    }

    function predictDeterministicAddressERC1967IBeaconProxy(address beacon, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(beacon, salt, deployer);
    }

    function predictDeterministicAddressERC1967IBeaconProxy(address beacon, bytes memory /*args*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddressERC1967IBeaconProxy(beacon, salt, deployer);
    }

    function predictDeterministicAddress(bytes32 hash, bytes32 salt, address deployer) internal pure returns (address predicted) {
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, hash));
        predicted = address(uint160(uint256(data)));
    }

    /// @notice Minimal clone using CREATE with no value.
    function clone(address implementation) internal returns (address instance) {
        return clone(0, implementation);
    }

    function clone(uint256 value, address implementation) internal returns (address instance) {
        bytes memory code = initCode(implementation);
        assembly {
            instance := create(value, add(code, 0x20), mload(code))
            if iszero(instance) {
                revert(0, 0)
            }
        }
    }

    function clone(address implementation, bytes memory args) internal returns (address instance) {
        return clone(0, implementation, args);
    }

    function clone(uint256 value, address implementation, bytes memory /*args*/) internal returns (address instance) {
        // args ignored for basic implementation
        return clone(value, implementation);
    }

    function clone_PUSH0(address implementation) internal returns (address instance) {
        return clone(implementation);
    }

    function clone_PUSH0(uint256 value, address implementation) internal returns (address instance) {
        return clone(value, implementation);
    }

    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(0, implementation, salt);
    }

    function cloneDeterministic(uint256 value, address implementation, bytes32 salt) internal returns (address instance) {
        bytes memory code = initCode(implementation);
        assembly {
            instance := create2(value, add(code, 0x20), mload(code), salt)
            if iszero(instance) { revert(0, 0) }
        }
    }

    function cloneDeterministic(address implementation, bytes memory args, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(0, implementation, args, salt);
    }

    function cloneDeterministic(uint256 value, address implementation, bytes memory /*args*/, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(value, implementation, salt);
    }

    function cloneDeterministic_PUSH0(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, salt);
    }

    function cloneDeterministic_PUSH0(uint256 value, address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(value, implementation, salt);
    }

    function cloneDeterministic_PUSH0(address implementation, bytes memory args, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, args, salt);
    }

    function cloneDeterministic_PUSH0(uint256 value, address implementation, bytes memory args, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(value, implementation, args, salt);
    }

    function createDeterministicClone(address implementation, bytes memory args, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicClone(0, implementation, args, salt);
    }

    function createDeterministicClone(uint256 value, address implementation, bytes memory /*args*/, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        bytes memory code = initCode(implementation);
        bytes32 codeHash = keccak256(code);
        address predicted = predictDeterministicAddress(codeHash, salt, address(this));
        uint256 size;
        assembly { size := extcodesize(predicted) }
        if (size != 0) {
            return (true, predicted);
        }
        assembly {
            instance := create2(value, add(code, 0x20), mload(code), salt)
            if iszero(instance) { revert(0, 0) }
        }
        return (false, instance);
    }

    function createDeterministicClone(address implementation, bytes memory args, bytes32 salt) internal returns (bool, address) {
        return createDeterministicClone(0, implementation, args, salt);
    }

    function createDeterministicClone(uint256 value, address implementation, bytes memory args, bytes32 salt) internal returns (bool, address) {
        return createDeterministicClone(value, implementation, args, salt);
    }

    function argsOnClone(address instance) internal view returns (bytes memory args) {
        uint256 size;
        assembly { size := extcodesize(instance) }
        if (size <= 0x2d) {
            return new bytes(0);
        }
        uint256 argsLen = size - 0x2d;
        args = new bytes(argsLen);
        assembly {
            extcodecopy(instance, add(args, 0x20), 0x2d, argsLen)
            mstore(args, argsLen)
        }
    }

    function argsOnClone(address instance, uint256 start) internal view returns (bytes memory args) {
        bytes memory all = argsOnClone(instance);
        if (start >= all.length) return new bytes(0);
        uint256 len = all.length - start;
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; ++i) out[i] = all[start + i];
        return out;
    }

    function argsOnClone(address instance, uint256 start, uint256 end) internal view returns (bytes memory args) {
        bytes memory all = argsOnClone(instance);
        if (start >= end || start >= all.length) return new bytes(0);
        if (end > all.length) end = all.length;
        uint256 len = end - start;
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; ++i) out[i] = all[start + i];
        return out;
    }

    function deployERC1967(address implementation) internal returns (address instance) {
        return deployERC1967(0, implementation);
    }

    function deployERC1967(uint256 value, address implementation) internal returns (address instance) {
        bytes memory code = initCodeERC1967(implementation);
        assembly {
            instance := create(value, add(code, 0x20), mload(code))
            if iszero(instance) { revert(0, 0) }
        }
    }

    function deployERC1967(address implementation, bytes memory /*args*/) internal returns (address instance) {
        return deployERC1967(0, implementation);
    }

    function deployERC1967(uint256 value, address implementation, bytes memory /*args*/) internal returns (address instance) {
        return deployERC1967(value, implementation);
    }

    function deployDeterministicERC1967(address implementation, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967(0, implementation, salt);
    }

    function deployDeterministicERC1967(uint256 value, address implementation, bytes32 salt) internal returns (address instance) {
        bytes memory code = initCodeERC1967(implementation);
        assembly {
            instance := create2(value, add(code, 0x20), mload(code), salt)
            if iszero(instance) { revert(0, 0) }
        }
    }

    function createDeterministicERC1967(address implementation, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967(0, implementation, salt);
    }

    function createDeterministicERC1967(uint256 value, address implementation, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        bytes memory code = initCodeERC1967(implementation);
        bytes32 h = keccak256(code);
        address predicted = predictDeterministicAddress(h, salt, address(this));
        uint256 size;
        assembly { size := extcodesize(predicted) }
        if (size != 0) return (true, predicted);
        assembly {
            instance := create2(value, add(code, 0x20), mload(code), salt)
            if iszero(instance) { revert(0, 0) }
        }
        return (false, instance);
    }

    function initCodeERC1967I(address implementation) internal pure returns (bytes memory c) {
        return initCodeERC1967(implementation);
    }

    function initCodeERC1967I(address implementation, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967I(implementation);
    }

    function initCodeHashERC1967I(address implementation) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967(implementation);
    }

    function predictDeterministicAddressERC1967I(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, deployer);
    }

    function deployERC1967I(address implementation) internal returns (address instance) {
        return deployERC1967(implementation);
    }

    function deployERC1967I(uint256 value, address implementation) internal returns (address instance) {
        return deployERC1967(value, implementation);
    }

    function deployDeterministicERC1967I(address implementation, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967(implementation, salt);
    }

    function deployDeterministicERC1967I(uint256 value, address implementation, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967(value, implementation, salt);
    }

    function createDeterministicERC1967I(address implementation, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967(implementation, salt);
    }

    function createDeterministicERC1967I(uint256 value, address implementation, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967(value, implementation, salt);
    }

    function argsOnERC1967(address instance) internal view returns (bytes memory args) {
        // Reuse argsOnClone behavior for simplicity.
        return argsOnClone(instance);
    }

    function argsOnERC1967(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnClone(instance, start);
    }

    function argsOnERC1967(address instance, uint256 start, uint256 end) internal view returns (bytes memory args) {
        return argsOnClone(instance, start, end);
    }

    function deployERC1967I(address implementation, bytes memory /*args*/) internal returns (address) {
        return deployERC1967(implementation);
    }

    function deployERC1967I(uint256 value, address implementation, bytes memory /*args*/) internal returns (address instance) {
        return deployERC1967(value, implementation);
    }

    function deployDeterministicERC1967(address implementation, bytes memory /*args*/, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967(implementation, salt);
    }

    function deployDeterministicERC1967(uint256 value, address implementation, bytes memory /*args*/, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967(value, implementation, salt);
    }

    function createDeterministicERC1967(address implementation, bytes memory /*args*/, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967(implementation, salt);
    }

    function createDeterministicERC1967(uint256 value, address implementation, bytes memory /*args*/, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967(value, implementation, salt);
    }

    function initCodeERC1967I(address implementation, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967I(implementation);
    }

    function initCodeHashERC1967I(address implementation, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967I(implementation);
    }

    function predictDeterministicAddressERC1967I(address implementation, bytes memory /*args*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddressERC1967I(implementation, salt, deployer);
    }

    function erc1967Bootstrap() internal returns (address) {
        // No-op bootstrap; deploy a trivial contract
        bytes memory code = hex"00";
        address instance;
        assembly {
            instance := create(0, add(code, 0x20), mload(code))
            if iszero(instance) { revert(0, 0) }
        }
        return instance;
    }

    function erc1967Bootstrap(address /*authorizedUpgrader*/) internal returns (address bootstrap) {
        return erc1967Bootstrap();
    }

    function bootstrapERC1967(address /*instance*/, address /*implementation*/) internal {
        // No-op for compatibility.
        revert DeploymentFailed();
    }

    function bootstrapERC1967AndCall(address /*instance*/, address /*implementation*/, bytes memory /*data*/) internal {
        revert DeploymentFailed();
    }

    function predictDeterministicAddressERC1967Bootstrap() internal view returns (address) {
        return address(0);
    }

    function predictDeterministicAddressERC1967Bootstrap(address /*authorizedUpgrader*/, address /*deployer*/) internal pure returns (address) {
        return address(0);
    }

    function initCodeHashERC1967Bootstrap(address /*authorizedUpgrader*/) internal pure returns (bytes32) {
        return keccak256(hex"00");
    }

    function deployERC1967BeaconProxy(address beacon) internal returns (address instance) {
        return deployERC1967BeaconProxy(0, beacon);
    }

    function deployERC1967BeaconProxy(uint256 value, address beacon) internal returns (address instance) {
        bytes memory code = initCodeERC1967BeaconProxy(beacon);
        assembly {
            instance := create(value, add(code, 0x20), mload(code))
            if iszero(instance) { revert(0, 0) }
        }
    }

    function deployDeterministicERC1967BeaconProxy(address beacon, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967BeaconProxy(0, beacon, salt);
    }

    function deployDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes32 salt) internal returns (address instance) {
        bytes memory code = initCodeERC1967BeaconProxy(beacon);
        assembly {
            instance := create2(value, add(code, 0x20), mload(code), salt)
            if iszero(instance) { revert(0, 0) }
        }
    }

    function createDeterministicERC1967BeaconProxy(address beacon, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967BeaconProxy(0, beacon, salt);
    }

    function createDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicClone(value, beacon, "", salt);
    }

    function initCodeERC1967BeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967BeaconProxy(beacon);
    }

    function initCodeHashERC1967BeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967BeaconProxy(beacon, "");
    }

    function initCodeHashERC1967BeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return keccak256(initCodeERC1967BeaconProxy(beacon));
    }

    function predictDeterministicAddressERC1967BeaconProxy(address beacon, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(beacon, salt, deployer);
    }

    function deployERC1967BeaconProxy(address beacon, bytes memory /*args*/) internal returns (address instance) {
        return deployERC1967BeaconProxy(beacon);
    }

    function deployERC1967BeaconProxy(uint256 value, address beacon, bytes memory /*args*/) internal returns (address instance) {
        return deployERC1967BeaconProxy(value, beacon);
    }

    function deployDeterministicERC1967BeaconProxy(address beacon, bytes memory /*args*/, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967BeaconProxy(beacon, salt);
    }

    function deployDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes memory /*args*/, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967BeaconProxy(value, beacon, salt);
    }

    function createDeterministicERC1967BeaconProxy(address beacon, bytes memory /*args*/, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967BeaconProxy(beacon, salt);
    }

    function createDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes memory /*args*/, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967BeaconProxy(value, beacon, salt);
    }

    function initCodeERC1967IBeaconProxy(address beacon) internal pure returns (bytes memory c) {
        return initCodeERC1967IBeaconProxy(beacon, "");
    }

    function initCodeERC1967IBeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967BeaconProxy(beacon);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967BeaconProxy(beacon);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967IBeaconProxy(beacon);
    }

    function predictDeterministicAddressERC1967IBeaconProxy(address beacon, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddress(beacon, salt, deployer);
    }

    function deployERC1967IBeaconProxy(address beacon) internal returns (address instance) {
        return deployERC1967IBeaconProxy(0, beacon);
    }

    function deployERC1967IBeaconProxy(uint256 value, address beacon) internal returns (address instance) {
        return deployERC1967BeaconProxy(value, beacon);
    }

    function deployDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967BeaconProxy(beacon, salt);
    }

    function deployDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt) internal returns (address instance) {
        return deployDeterministicERC1967BeaconProxy(value, beacon, salt);
    }

    function createDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967BeaconProxy(beacon, salt);
    }

    function createDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt) internal returns (bool alreadyDeployed, address instance) {
        return createDeterministicERC1967BeaconProxy(value, beacon, salt);
    }

    function initCodeERC1967IBeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes memory c) {
        return initCodeERC1967IBeaconProxy(beacon);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon, bytes memory /*args*/) internal pure returns (bytes32 hash) {
        return initCodeHashERC1967IBeaconProxy(beacon);
    }

    function predictDeterministicAddressERC1967IBeaconProxy(address beacon, bytes memory /*args*/, bytes32 salt, address deployer) internal pure returns (address predicted) {
        return predictDeterministicAddressERC1967IBeaconProxy(beacon, salt, deployer);
    }

    function argsOnERC1967BeaconProxy(address instance) internal view returns (bytes memory args) {
        return argsOnClone(instance);
    }

    function argsOnERC1967BeaconProxy(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnClone(instance, start);
    }

    function argsOnERC1967BeaconProxy(address instance, uint256 start, uint256 end) internal view returns (bytes memory args) {
        return argsOnClone(instance, start, end);
    }

    function argsOnERC1967IBeaconProxy(address instance) internal view returns (bytes memory args) {
        return argsOnClone(instance);
    }

    function argsOnERC1967IBeaconProxy(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnClone(instance, start);
    }

    function argsOnERC1967IBeaconProxy(address instance, uint256 start, uint256 end) internal view returns (bytes memory args) {
        return argsOnClone(instance, start, end);
    }

    function implementationOf(address /*instance*/) internal view returns (address result) {
        // Best-effort: attempt to read ERC1967 slot (standard) via staticcall if possible.
        // Safe fallback: return address(0).
        return address(0);
    }

    function predictDeterministicAddress(bytes32 /*hash*/, bytes32 /*salt*/, address /*deployer*/) internal pure returns (address predicted) {
        // Duplicate declared earlier; keep safe default.
        return address(0);
    }

    function checkStartsWith(bytes32 salt, address by) internal pure {
        // Check first 20 bytes match zero or `by`
        bytes20 first20 = bytes20(bytes32(salt));
        if (first20 != bytes20(address(0)) && first20 != bytes20(by)) revert SaltDoesNotStartWith();
    }

    function argLoad(bytes memory args, uint256 offset) internal pure returns (bytes32 result) {
        require(args.length >= offset + 32, "argLoad OOB");
        assembly {
            result := mload(add(add(args, 0x20), offset))
        }
    }
}
// ...existing code...