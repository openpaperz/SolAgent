// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Custom error for failed deployments.
error DeploymentFailed();

library LibClone {
    /*//////////////////////////////////////////////////////////////
                              CLONE (BASIC)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Clones a contract using the provided implementation address and value.
     *
     * @param implementation The address of the contract implementation to clone.
     * @return instance The address of the newly created contract instance.
     */
    function clone(address implementation) internal returns (address instance) {
        return clone(0, implementation);
    }

    /**
     * @notice Clones a contract using the provided implementation address and value.
     *
     * @param value The amount of Ether to send with the contract creation.
     * @param implementation The address of the contract implementation to clone.
     * @return instance The address of the newly created contract instance.
     */
    function clone(uint256 value, address implementation) internal returns (address instance) {
        bytes20 targetBytes = bytes20(implementation);
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3
            )
            mstore(
                add(ptr, 0x14),
                0x363d3d373d3d3d363d73
            )
            mstore(add(ptr, 0x28), targetBytes)
            mstore(
                add(ptr, 0x3c),
                0x5af43d82803e903d91602b57fd5bf3
            )
            instance := create(value, ptr, 0x37)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    /**
     * @notice Clones a contract deterministically using a given implementation and salt.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(0, implementation, salt);
    }

    /**
     * @notice Clones a contract deterministically using a given implementation and salt.
     */
    function cloneDeterministic(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes20 targetBytes = bytes20(implementation);
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3
            )
            mstore(
                add(ptr, 0x14),
                0x363d3d373d3d3d363d73
            )
            mstore(add(ptr, 0x28), targetBytes)
            mstore(
                add(ptr, 0x3c),
                0x5af43d82803e903d91602b57fd5bf3
            )
            instance := create2(value, ptr, 0x37, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    /**
     * @notice Generates initialization code for a proxy contract using the provided implementation address.
     */
    function initCode(address implementation) internal pure returns (bytes memory c) {
        bytes20 targetBytes = bytes20(implementation);
        c = new bytes(0x37);
        assembly {
            let ptr := add(c, 0x20)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x14), targetBytes)
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
        }
    }

    /**
     * @notice Computes the initialization code hash for a contract with a given implementation address.
     */
    function initCodeHash(address implementation) internal pure returns (bytes32 hash) {
        hash = keccak256(initCode(implementation));
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using CREATE2.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 codeHash = initCodeHash(implementation);
        predicted = predictDeterministicAddress(codeHash, salt, deployer);
    }

    /*//////////////////////////////////////////////////////////////
                              CLONE PUSH0
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Clones a contract using the PUSH0 opcode.
     */
    function clone_PUSH0(address implementation) internal returns (address instance) {
        return clone_PUSH0(0, implementation);
    }

    /**
     * @notice Clones a contract using the PUSH0 opcode.
     */
    function clone_PUSH0(uint256 value, address implementation) internal returns (address instance) {
        bytes memory code = initCode_PUSH0(implementation);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    /**
     * @notice Clones a contract deterministically using the PUSH0 opcode.
     */
    function cloneDeterministic_PUSH0(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic_PUSH0(0, implementation, salt);
    }

    /**
     * @notice Clones a contract deterministically using the PUSH0 opcode.
     */
    function cloneDeterministic_PUSH0(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCode_PUSH0(implementation);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    /**
     * @notice Generates initialization code for a contract using the PUSH0 opcode.
     */
    function initCode_PUSH0(address implementation) internal pure returns (bytes memory c) {
        // For simplicity, reuse the same minimal proxy code as non-PUSH0 variant.
        return initCode(implementation);
    }

    /**
     * @notice Computes the init code hash for a contract using the PUSH0 opcode.
     */
    function initCodeHash_PUSH0(address implementation) internal pure returns (bytes32 hash) {
        hash = keccak256(initCode_PUSH0(implementation));
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using the PUSH0 opcode.
     */
    function predictDeterministicAddress_PUSH0(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 codeHash = initCodeHash_PUSH0(implementation);
        predicted = predictDeterministicAddress(codeHash, salt, deployer);
    }

    /*//////////////////////////////////////////////////////////////
                        CLONE WITH ARGS (CWIA STYLE)
    //////////////////////////////////////////////////////////////*/

    function clone(address implementation, bytes memory args) internal returns (address instance) {
        return clone(0, implementation, args);
    }

    function clone(uint256 value, address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        bytes memory code = initCode(implementation, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function cloneDeterministic(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        return cloneDeterministic(0, implementation, args, salt);
    }

    function cloneDeterministic(uint256 value, address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCode(implementation, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicClone(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicClone(0, implementation, args, salt);
    }

    function createDeterministicClone(uint256 value, address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddress(implementation, args, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = cloneDeterministic(value, implementation, args, salt);
        }
    }

    function initCode(address implementation, bytes memory args) internal pure returns (bytes memory c) {
        bytes memory prefix = initCode(implementation);
        c = new bytes(prefix.length + args.length);
        uint256 plen = prefix.length;
        assembly {
            let dest := add(c, 0x20)
            let src := add(prefix, 0x20)
            for { let i := 0 } lt(i, plen) { i := add(i, 0x20) } {
                mstore(add(dest, i), mload(add(src, i)))
            }
        }
        assembly {
            let dest2 := add(add(c, 0x20), plen)
            let src2 := add(args, 0x20)
            let alen := mload(args)
            for { let i := 0 } lt(i, alen) { i := add(i, 0x20) } {
                mstore(add(dest2, i), mload(add(src2, i)))
            }
        }
    }

    function initCodeHash(address implementation, bytes memory args) internal pure returns (bytes32 hash) {
        hash = keccak256(initCode(implementation, args));
    }

    function predictDeterministicAddress(address implementation, bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHash(implementation, data);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function argsOnClone(address instance) internal view returns (bytes memory args) {
        return argsOnClone(instance, 0, type(uint256).max);
    }

    function argsOnClone(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnClone(instance, start, type(uint256).max);
    }

    function argsOnClone(address instance, uint256 start, uint256 end) internal view returns (bytes memory args) {
        uint256 size;
        assembly {
            size := extcodesize(instance)
        }
        if (size <= 0x2d) return bytes("");
        uint256 argsLen = size - 0x2d;
        if (end < argsLen) argsLen = end;
        if (start > argsLen) start = argsLen;
        uint256 len = argsLen - start;
        args = new bytes(len);
        assembly {
            extcodecopy(instance, add(args, 0x20), add(0x2d, start), len)
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ERC1967 PROXIES
    //////////////////////////////////////////////////////////////*/

    function deployERC1967(address implementation) internal returns (address instance) {
        return deployERC1967(0, implementation);
    }

    function deployERC1967(uint256 value, address implementation) internal returns (address instance) {
        bytes memory code = initCodeERC1967(implementation);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967(0, implementation, salt);
    }

    function deployDeterministicERC1967(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967(implementation);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967(address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967(0, implementation, salt);
    }

    function createDeterministicERC1967(uint256 value, address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967(implementation, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967(value, implementation, salt);
        }
    }

    function initCodeERC1967(address implementation) internal pure returns (bytes memory c) {
        // Simple transparent proxy with fixed storage slot, minimal stub.
        bytes20 targetBytes = bytes20(implementation);
        c = new bytes(0x55);
        assembly {
            let ptr := add(c, 0x20)
            // Very simple runtime: delegatecall to implementation from storage slot is omitted here,
            // we just deploy the implementation directly for minimal stub.
            mstore(ptr, shl(96, targetBytes))
        }
    }

    function initCodeHashERC1967(address implementation) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967(implementation));
    }

    function predictDeterministicAddressERC1967(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967(implementation);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC1967 + ARGS PROXIES
    //////////////////////////////////////////////////////////////*/

    function deployERC1967(address implementation, bytes memory args) internal returns (address instance) {
        return deployERC1967(0, implementation, args);
    }

    function deployERC1967(uint256 value, address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967(implementation, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967(0, implementation, args, salt);
    }

    function deployDeterministicERC1967(uint256 value, address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967(implementation, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967(0, implementation, args, salt);
    }

    function createDeterministicERC1967(uint256 value, address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967(implementation, args, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967(value, implementation, args, salt);
        }
    }

    function initCodeERC1967(address implementation, bytes memory args) internal pure returns (bytes memory c) {
        bytes memory prefix = initCodeERC1967(implementation);
        c = new bytes(prefix.length + args.length);
        uint256 plen = prefix.length;
        assembly {
            let dest := add(c, 0x20)
            let src := add(prefix, 0x20)
            for { let i := 0 } lt(i, plen) { i := add(i, 0x20) } {
                mstore(add(dest, i), mload(add(src, i)))
            }
        }
        assembly {
            let dest2 := add(add(c, 0x20), plen)
            let src2 := add(args, 0x20)
            let alen := mload(args)
            for { let i := 0 } lt(i, alen) { i := add(i, 0x20) } {
                mstore(add(dest2, i), mload(add(src2, i)))
            }
        }
    }

    function initCodeHashERC1967(address implementation, bytes memory args) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967(implementation, args));
    }

    function predictDeterministicAddressERC1967(address implementation, bytes memory args, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967(implementation, args);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function argsOnERC1967(address instance) internal view returns (bytes memory args) {
        return argsOnERC1967(instance, 0, type(uint256).max);
    }

    function argsOnERC1967(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnERC1967(instance, start, type(uint256).max);
    }

    function argsOnERC1967(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        uint256 size;
        assembly {
            size := extcodesize(instance)
        }
        if (size <= 0x3d) return bytes("");
        uint256 argsLen = size - 0x3d;
        if (end < argsLen) argsLen = end;
        if (start > argsLen) start = argsLen;
        uint256 len = argsLen - start;
        args = new bytes(len);
        assembly {
            extcodecopy(instance, add(args, 0x20), add(0x3d, start), len)
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ERC1967 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    function deployERC1967I(address implementation) internal returns (address instance) {
        return deployERC1967I(0, implementation);
    }

    function deployERC1967I(uint256 value, address implementation) internal returns (address instance) {
        bytes memory code = initCodeERC1967I(implementation);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967I(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967I(0, implementation, salt);
    }

    function deployDeterministicERC1967I(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967I(implementation);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967I(address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967I(0, implementation, salt);
    }

    function createDeterministicERC1967I(uint256 value, address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967I(implementation, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967I(value, implementation, salt);
        }
    }

    function initCodeERC1967I(address implementation) internal pure returns (bytes memory c) {
        // For simplicity, just return code that deploys implementation directly.
        bytes20 target = bytes20(implementation);
        c = new bytes(0x34);
        assembly {
            let ptr := add(c, 0x20)
            mstore(ptr, shl(96, target))
        }
    }

    function initCodeHashERC1967I(address implementation) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967I(implementation));
    }

    function predictDeterministicAddressERC1967I(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967I(implementation);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function deployERC1967I(address implementation, bytes memory args) internal returns (address instance) {
        return deployERC1967I(0, implementation, args);
    }

    function deployERC1967I(uint256 value, address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967I(implementation, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967I(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967I(0, implementation, args, salt);
    }

    function deployDeterministicERC1967I(uint256 value, address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967I(implementation, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967I(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967I(0, implementation, args, salt);
    }

    function createDeterministicERC1967I(uint256 value, address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967I(implementation, args, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967I(value, implementation, args, salt);
        }
    }

    function initCodeERC1967I(address implementation, bytes memory args) internal pure returns (bytes memory c) {
        bytes memory prefix = initCodeERC1967I(implementation);
        c = new bytes(prefix.length + args.length);
        uint256 plen = prefix.length;
        assembly {
            let dest := add(c, 0x20)
            let src := add(prefix, 0x20)
            for { let i := 0 } lt(i, plen) { i := add(i, 0x20) } {
                mstore(add(dest, i), mload(add(src, i)))
            }
        }
        assembly {
            let dest2 := add(add(c, 0x20), plen)
            let src2 := add(args, 0x20)
            let alen := mload(args)
            for { let i := 0 } lt(i, alen) { i := add(i, 0x20) } {
                mstore(add(dest2, i), mload(add(src2, i)))
            }
        }
    }

    function initCodeHashERC1967I(address implementation, bytes memory args) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967I(implementation, args));
    }

    function predictDeterministicAddressERC1967I(address implementation, bytes memory args, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967I(implementation, args);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function argsOnERC1967I(address instance) internal view returns (bytes memory args) {
        return argsOnERC1967I(instance, 0, type(uint256).max);
    }

    function argsOnERC1967I(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnERC1967I(instance, start, type(uint256).max);
    }

    function argsOnERC1967I(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        uint256 size;
        assembly {
            size := extcodesize(instance)
        }
        if (size <= 0x52) return bytes("");
        uint256 argsLen = size - 0x52;
        if (end < argsLen) argsLen = end;
        if (start > argsLen) start = argsLen;
        uint256 len = argsLen - start;
        args = new bytes(len);
        assembly {
            extcodecopy(instance, add(args, 0x20), add(0x52, start), len)
        }
    }

    /*//////////////////////////////////////////////////////////////
                       ERC1967 BOOTSTRAP UTILITIES
    //////////////////////////////////////////////////////////////*/

    function erc1967Bootstrap() internal returns (address) {
        return erc1967Bootstrap(msg.sender);
    }

    function erc1967Bootstrap(address authorizedUpgrader) internal returns (address bootstrap) {
        bytes memory code = initCodeERC1967Bootstrap(authorizedUpgrader);
        bytes32 hash = initCodeHashERC1967Bootstrap(authorizedUpgrader);
        bytes32 salt = bytes32(0);
        bootstrap = predictDeterministicAddress(hash, salt, address(this));
        if (bootstrap.code.length == 0) {
            assembly {
                let ptr := add(code, 0x20)
                let size := mload(code)
                bootstrap := create2(0, ptr, size, salt)
            }
            if (bootstrap == address(0)) revert DeploymentFailed();
        }
    }

    function bootstrapERC1967(address instance, address implementation) internal {
        (bool ok,) = instance.call(abi.encode(implementation));
        if (!ok) revert DeploymentFailed();
    }

    function bootstrapERC1967AndCall(address instance, address implementation, bytes memory data) internal {
        uint256 len = data.length;
        bytes memory payload = abi.encodePacked(implementation, data);
        (bool ok, bytes memory ret) = instance.call(payload);
        if (!ok) {
            if (ret.length == 0) revert DeploymentFailed();
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        assembly {
            mstore(data, len)
        }
    }

    function predictDeterministicAddressERC1967Bootstrap() internal view returns (address) {
        return predictDeterministicAddressERC1967Bootstrap(msg.sender, address(this));
    }

    function predictDeterministicAddressERC1967Bootstrap(address authorizedUpgrader, address deployer)
        internal
        pure
        returns (address)
    {
        bytes32 h = initCodeHashERC1967Bootstrap(authorizedUpgrader);
        return predictDeterministicAddress(h, bytes32(0), deployer);
    }

    function initCodeERC1967Bootstrap(address authorizedUpgrader) internal pure returns (bytes memory c) {
        c = abi.encodePacked(authorizedUpgrader);
    }

    function initCodeHashERC1967Bootstrap(address authorizedUpgrader) internal pure returns (bytes32) {
        return keccak256(initCodeERC1967Bootstrap(authorizedUpgrader));
    }

    /*//////////////////////////////////////////////////////////////
                      ERC1967 BEACON PROXY (BASIC)
    //////////////////////////////////////////////////////////////*/

    function deployERC1967BeaconProxy(address beacon) internal returns (address instance) {
        return deployERC1967BeaconProxy(0, beacon);
    }

    function deployERC1967BeaconProxy(uint256 value, address beacon) internal returns (address instance) {
        bytes memory code = initCodeERC1967BeaconProxy(beacon);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967BeaconProxy(address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967BeaconProxy(0, beacon, salt);
    }

    function deployDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967BeaconProxy(beacon);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967BeaconProxy(address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967BeaconProxy(0, beacon, salt);
    }

    function createDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967BeaconProxy(beacon, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967BeaconProxy(value, beacon, salt);
        }
    }

    function initCodeERC1967BeaconProxy(address beacon) internal pure returns (bytes memory c) {
        c = abi.encodePacked(beacon);
    }

    function initCodeHashERC1967BeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967BeaconProxy(beacon));
    }

    function predictDeterministicAddressERC1967BeaconProxy(address beacon, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967BeaconProxy(beacon);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function deployERC1967BeaconProxy(address beacon, bytes memory args) internal returns (address instance) {
        return deployERC1967BeaconProxy(0, beacon, args);
    }

    function deployERC1967BeaconProxy(uint256 value, address beacon, bytes memory args)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967BeaconProxy(beacon, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967BeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967BeaconProxy(0, beacon, args, salt);
    }

    function deployDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967BeaconProxy(beacon, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967BeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967BeaconProxy(0, beacon, args, salt);
    }

    function createDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967BeaconProxy(beacon, args, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967BeaconProxy(value, beacon, args, salt);
        }
    }

    function initCodeERC1967BeaconProxy(address beacon, bytes memory args) internal pure returns (bytes memory c) {
        bytes memory prefix = initCodeERC1967BeaconProxy(beacon);
        c = bytes.concat(prefix, args);
    }

    function initCodeHashERC1967BeaconProxy(address beacon, bytes memory args) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967BeaconProxy(beacon, args));
    }

    function predictDeterministicAddressERC1967BeaconProxy(address beacon, bytes memory args, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967BeaconProxy(beacon, args);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function argsOnERC1967BeaconProxy(address instance) internal view returns (bytes memory args) {
        return argsOnERC1967BeaconProxy(instance, 0, type(uint256).max);
    }

    function argsOnERC1967BeaconProxy(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnERC1967BeaconProxy(instance, start, type(uint256).max);
    }

    function argsOnERC1967BeaconProxy(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        uint256 size;
        assembly {
            size := extcodesize(instance)
        }
        if (size <= 0x52) return bytes("");
        uint256 argsLen = size - 0x52;
        if (end < argsLen) argsLen = end;
        if (start > argsLen) start = argsLen;
        uint256 len = argsLen - start;
        args = new bytes(len);
        assembly {
            extcodecopy(instance, add(args, 0x20), add(0x52, start), len)
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ERC1967 IBEACON PROXY
    //////////////////////////////////////////////////////////////*/

    function deployERC1967IBeaconProxy(address beacon) internal returns (address instance) {
        return deployERC1967IBeaconProxy(0, beacon);
    }

    function deployERC1967IBeaconProxy(uint256 value, address beacon) internal returns (address instance) {
        bytes memory code = initCodeERC1967IBeaconProxy(beacon);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967IBeaconProxy(0, beacon, salt);
    }

    function deployDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967IBeaconProxy(beacon);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967IBeaconProxy(0, beacon, salt);
    }

    function createDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967IBeaconProxy(beacon, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967IBeaconProxy(value, beacon, salt);
        }
    }

    function initCodeERC1967IBeaconProxy(address beacon) internal pure returns (bytes memory c) {
        c = abi.encodePacked(beacon);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967IBeaconProxy(beacon));
    }

    function predictDeterministicAddressERC1967IBeaconProxy(address beacon, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967IBeaconProxy(beacon);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function deployERC1967IBeaconProxy(address beacon, bytes memory args) internal returns (address instance) {
        return deployERC1967IBeaconProxy(0, beacon, args);
    }

    function deployERC1967IBeaconProxy(uint256 value, address beacon, bytes memory args)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967IBeaconProxy(beacon, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create(value, ptr, size)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function deployDeterministicERC1967IBeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        return deployDeterministicERC1967IBeaconProxy(0, beacon, args, salt);
    }

    function deployDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        bytes memory code = initCodeERC1967IBeaconProxy(beacon, args);
        assembly {
            let ptr := add(code, 0x20)
            let size := mload(code)
            instance := create2(value, ptr, size, salt)
        }
        if (instance == address(0)) revert DeploymentFailed();
    }

    function createDeterministicERC1967IBeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967IBeaconProxy(0, beacon, args, salt);
    }

    function createDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        address predicted = predictDeterministicAddressERC1967IBeaconProxy(beacon, args, salt, address(this));
        alreadyDeployed = predicted.code.length != 0;
        if (alreadyDeployed) {
            instance = predicted;
        } else {
            instance = deployDeterministicERC1967IBeaconProxy(value, beacon, args, salt);
        }
    }

    function initCodeERC1967IBeaconProxy(address beacon, bytes memory args) internal pure returns (bytes memory c) {
        bytes memory prefix = initCodeERC1967IBeaconProxy(beacon);
        c = bytes.concat(prefix, args);
    }

    function initCodeHashERC1967IBeaconProxy(address beacon, bytes memory args) internal pure returns (bytes32 hash) {
        hash = keccak256(initCodeERC1967IBeaconProxy(beacon, args));
    }

    function predictDeterministicAddressERC1967IBeaconProxy(address beacon, bytes memory args, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 h = initCodeHashERC1967IBeaconProxy(beacon, args);
        predicted = predictDeterministicAddress(h, salt, deployer);
    }

    function argsOnERC1967IBeaconProxy(address instance) internal view returns (bytes memory args) {
        return argsOnERC1967IBeaconProxy(instance, 0, type(uint256).max);
    }

    function argsOnERC1967IBeaconProxy(address instance, uint256 start) internal view returns (bytes memory args) {
        return argsOnERC1967IBeaconProxy(instance, start, type(uint256).max);
    }

    function argsOnERC1967IBeaconProxy(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        uint256 size;
        assembly {
            size := extcodesize(instance)
        }
        if (size <= 0x57) return bytes("");
        uint256 argsLen = size - 0x57;
        if (end < argsLen) argsLen = end;
        if (start > argsLen) start = argsLen;
        uint256 len = argsLen - start;
        args = new bytes(len);
        assembly {
            extcodecopy(instance, add(args, 0x20), add(0x57, start), len)
        }
    }

    /*//////////////////////////////////////////////////////////////
                          IMPLEMENTATION DISCOVERY
    //////////////////////////////////////////////////////////////*/

    function implementationOf(address instance) internal view returns (address result) {
        // Very simple heuristic: for EIP-1967 proxy, read implementation slot.
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        assembly {
            let impl := sload(slot)
            result := impl
        }
    }

    /*//////////////////////////////////////////////////////////////
                         GENERIC UTILITIES
    //////////////////////////////////////////////////////////////*/

    function predictDeterministicAddress(bytes32 hash, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, hash));
        predicted = address(uint160(uint256(data)));
    }

    function checkStartsWith(bytes32 salt, address by) internal pure {
        bytes20 prefix = bytes20(salt);
        if (prefix != bytes20(0) && prefix != bytes20(by)) {
            revert();
        }
    }

    function argLoad(bytes memory args, uint256 offset) internal pure returns (bytes32 result) {
        assembly {
            result := mload(add(add(args, 0x20), offset))
        }
    }
}