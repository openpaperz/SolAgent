// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal proxy cloning utilities with support for value, deterministic deployments and immutable args.
library Clones {
    /// @dev Thrown when the contract balance is insufficient to cover a requested value.
    error InsufficientBalance(uint256 available, uint256 required);

    /// @dev Thrown when a deployment attempt fails.
    error FailedDeployment();

    /**
     * @notice Clones a contract implementation by deploying a new instance using the provided implementation address.
     *
     * @param implementation The address of the contract implementation to clone.
     * @return instance The address of the newly deployed contract instance.
     */
    function clone(address implementation) internal returns (address instance) {
        return clone(implementation, 0);
    }

    /**
     * @notice Clones a contract implementation by deploying a new instance using the provided implementation address and value.
     *
     * @param implementation The address of the contract implementation to clone.
     * @param value The amount of Ether to send with the deployment.
     * @return instance The address of the newly deployed contract instance.
     */
    function clone(address implementation, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance({ available: address(this).balance, required: value });
        }

        // Standard EIP-1167 minimal proxy creation code components
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            bytes20(implementation),
            hex"5af43d82803e903d91602b57fd5bf3"
        );

        assembly {
            let ptr := add(creationCode, 0x20)
            let size := mload(creationCode)
            instance := create(value, ptr, size)
        }

        if (instance == address(0)) revert FailedDeployment();
    }

    /**
     * @notice Clones a contract deterministically using the `create2` opcode.
     *
     * @param implementation The address of the contract implementation to clone.
     * @param salt A unique salt value to ensure deterministic address generation.
     * @return instance The address of the newly deployed contract instance.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, salt, 0);
    }

    /**
     * @notice Clones a contract deterministically using the `create2` opcode.
     *
     * @param implementation The address of the contract implementation to clone.
     * @param salt A unique salt value to ensure deterministic address generation.
     * @param value The amount of Ether to send with the deployment.
     * @return instance The address of the newly deployed contract instance.
     */
    function cloneDeterministic(address implementation, bytes32 salt, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance({ available: address(this).balance, required: value });
        }

        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            bytes20(implementation),
            hex"5af43d82803e903d91602b57fd5bf3"
        );

        assembly {
            let ptr := add(creationCode, 0x20)
            let size := mload(creationCode)
            instance := create2(value, ptr, size, salt)
        }

        if (instance == address(0)) revert FailedDeployment();
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using the CREATE2 opcode.
     *
     * @param implementation The address of the implementation contract.
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer (typically the contract deploying the new instance).
     * @return predicted The predicted deterministic address for the contract deployment.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            bytes20(implementation),
            hex"5af43d82803e903d91602b57fd5bf3"
        );

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(creationCode)));
        predicted = address(uint160(uint256(hash)));
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using the CREATE2 opcode.
     *
     * @param implementation The address of the implementation contract.
     * @param salt A unique salt value used to generate the deterministic address.
     * @return predicted The predicted deterministic address for the contract deployment.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }

    /**
     * @notice Clones a contract with immutable arguments and deploys it using the provided implementation and arguments.
     *
     * @param implementation The address of the contract implementation to clone.
     * @param args The immutable arguments to be passed to the cloned contract.
     * @return instance The address of the newly deployed contract instance.
     */
    function cloneWithImmutableArgs(address implementation, bytes memory args) internal returns (address instance) {
        return cloneWithImmutableArgs(implementation, args, 0);
    }

    /**
     * @notice Clones a contract with immutable arguments and deploys it using the provided implementation and arguments.
     *
     * @param implementation The address of the contract implementation to clone.
     * @param args The immutable arguments to be passed to the cloned contract.
     * @param value The amount of Ether to send with the deployment.
     * @return instance The address of the newly deployed contract instance.
     */
    function cloneWithImmutableArgs(address implementation, bytes memory args, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance({ available: address(this).balance, required: value });
        }

        bytes memory creationCode = _cloneCodeWithImmutableArgs(implementation, args);

        assembly {
            let ptr := add(creationCode, 0x20)
            let size := mload(creationCode)
            instance := create(value, ptr, size)
        }

        if (instance == address(0)) revert FailedDeployment();
    }

    /**
     * @notice Clones a contract deterministically with immutable arguments using a specified salt.
     *
     * @param implementation The address of the implementation contract to clone.
     * @param args The immutable arguments to be passed to the cloned contract.
     * @param salt A unique salt value to ensure deterministic deployment.
     * @return instance The address of the newly cloned contract instance.
     */
    function cloneDeterministicWithImmutableArgs(address implementation, bytes memory args, bytes32 salt) internal returns (address instance) {
        return cloneDeterministicWithImmutableArgs(implementation, args, salt, 0);
    }

    /**
     * @notice Clones a contract deterministically with immutable arguments using a specified salt.
     *
     * @param implementation The address of the implementation contract to clone.
     * @param args The immutable arguments to be passed to the cloned contract.
     * @param salt A unique salt value to ensure deterministic deployment.
     * @param value The amount of Ether to send with the deployment.
     * @return instance The address of the newly cloned contract instance.
     */
    function cloneDeterministicWithImmutableArgs(address implementation, bytes memory args, bytes32 salt, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance({ available: address(this).balance, required: value });
        }

        bytes memory creationCode = _cloneCodeWithImmutableArgs(implementation, args);

        assembly {
            let ptr := add(creationCode, 0x20)
            let size := mload(creationCode)
            instance := create2(value, ptr, size, salt)
        }

        if (instance == address(0)) revert FailedDeployment();
    }

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using Create2 with immutable arguments.
     *
     * @param implementation The address of the implementation contract.
     * @param args The immutable arguments to be encoded into the contract bytecode.
     * @param salt A unique salt used to determine the deployment address.
     * @param deployer The address of the deployer who will deploy the contract.
     *
     * @return predicted The predicted address of the contract that will be deployed.
     */
    function predictDeterministicAddressWithImmutableArgs(address implementation, bytes memory args, bytes32 salt, address deployer) internal pure returns (address predicted) {
        bytes memory creationCode = _cloneCodeWithImmutableArgs(implementation, args);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(creationCode)));
        predicted = address(uint160(uint256(hash)));
    }

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using Create2 with immutable arguments.
     *
     * @param implementation The address of the implementation contract.
     * @param args The immutable arguments to be encoded into the contract bytecode.
     * @param salt A unique salt used to determine the deployment address.
     * @return predicted The predicted address of the contract that will be deployed.
     */
    function predictDeterministicAddressWithImmutableArgs(address implementation, bytes memory args, bytes32 salt) internal view returns (address predicted) {
        return predictDeterministicAddressWithImmutableArgs(implementation, args, salt, address(this));
    }

    /**
     * @notice Fetches the clone arguments from the given instance's bytecode.
     *
     * @param instance The address of the contract instance from which to fetch the clone arguments.
     * @return result A bytes array containing the clone arguments extracted from the instance's bytecode.
     */
    function fetchCloneArgs(address instance) internal view returns (bytes memory) {
        uint256 size;
        assembly {
            size := extcodesize(instance)
        }

        // The deployed minimal proxy with immutable args created by `_cloneCodeWithImmutableArgs`
        // is assumed to have 45 bytes of header/runtime before the appended args (matching the
        // layout produced by `_cloneCodeWithImmutableArgs` above). If the code is too short, revert.
        uint256 header = 45;
        if (size <= header) revert FailedDeployment();

        uint256 argsLen = size - header;
        bytes memory result = new bytes(argsLen);

        assembly {
            // copy code starting at offset `header` into result (payload begins after 32-byte length)
            extcodecopy(instance, add(result, 0x20), header, argsLen)
        }

        return result;
    }

    /**
     * @notice Constructs bytecode for a clone contract with immutable arguments.
     *
     * @param implementation The address of the contract to delegate calls to
     * @param args The immutable arguments to embed in the cloned contract
     * @return The constructed bytecode for the clone contract
     */
    function _cloneCodeWithImmutableArgs(address implementation, bytes memory args) private pure returns (bytes memory) {
        // Limit chosen to avoid excessive memory allocations in practice (matches description)
        // 24531 is conservative upper bound; if larger, deployment may not be feasible
        if (args.length > 24531) revert FailedDeployment();

        // Build the standard minimal proxy creation code and append the immutable args at the end.
        // This mirrors the structure used by the standard EIP-1167 minimal proxy creation code.
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            bytes20(implementation),
            hex"5af43d82803e903d91602b57fd5bf3",
            args
        );

        return creationCode;
    }
}