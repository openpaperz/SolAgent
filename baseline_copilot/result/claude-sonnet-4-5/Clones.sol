// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev ERC-1167 minimal proxy implementation library.
 * https://eips.ethereum.org/EIPS/eip-1167
 */
library Clones {
    error InsufficientBalance(uint256 balance, uint256 needed);
    error FailedDeployment();

    /**
     * @notice Clones a contract implementation by deploying a new instance using the provided implementation address and value.
     *
     * @param implementation The address of the contract implementation to clone.
     * @return instance The address of the newly deployed contract instance.
     *
     * Steps:
     * 1. Check if the contract's balance is sufficient to cover the provided value. If not, revert with an `InsufficientBalance` error.
     * 2. Use inline assembly to:
     *    - Clean the upper 96 bits of the `implementation` address.
     *    - Pack the first 3 bytes of the `implementation` address with the bytecode before the address.
     *    - Pack the remaining 17 bytes of the `implementation` address with the bytecode after the address.
     *    - Deploy the new contract instance using the `create` opcode with the provided value and bytecode.
     * 3. If the deployment fails (i.e., the instance address is 0), revert with a `FailedDeployment` error.
     * 4. Return the address of the newly deployed contract instance.
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
     *
     * Steps:
     * 1. Check if the contract's balance is sufficient to cover the provided value. If not, revert with an `InsufficientBalance` error.
     * 2. Use inline assembly to:
     *    - Clean the upper 96 bits of the `implementation` address.
     *    - Pack the first 3 bytes of the `implementation` address with the bytecode before the address.
     *    - Pack the remaining 17 bytes of the `implementation` address with the bytecode after the address.
     *    - Deploy the new contract instance using the `create` opcode with the provided value and bytecode.
     * 3. If the deployment fails (i.e., the instance address is 0), revert with a `FailedDeployment` error.
     * 4. Return the address of the newly deployed contract instance.
     */
    function clone(address implementation, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance(address(this).balance, value);
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` address, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(value, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert FailedDeployment();
        }
    }

    /**
     * @notice Clones a contract deterministically using the `create2` opcode.
     *
     * @param implementation The address of the contract implementation to clone.
     * @param salt A unique salt value to ensure deterministic address generation.
     * @return instance The address of the newly deployed contract instance.
     *
     * Steps:
     * 1. Check if the contract has sufficient balance to cover the `value`. If not, revert with an `InsufficientBalance` error.
     * 2. Use inline assembly to:
     *    - Clean the upper 96 bits of the `implementation` address.
     *    - Pack the first 3 bytes of the `implementation` address with the bytecode before the address.
     *    - Pack the remaining 17 bytes of the `implementation` address with the bytecode after the address.
     *    - Deploy the contract using `create2` with the provided `value`, bytecode, and `salt`.
     * 3. If the deployment fails (i.e., `instance` is `address(0)`), revert with a `FailedDeployment` error.
     * 4. Return the address of the newly deployed contract instance.
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
     *
     * Steps:
     * 1. Check if the contract has sufficient balance to cover the `value`. If not, revert with an `InsufficientBalance` error.
     * 2. Use inline assembly to:
     *    - Clean the upper 96 bits of the `implementation` address.
     *    - Pack the first 3 bytes of the `implementation` address with the bytecode before the address.
     *    - Pack the remaining 17 bytes of the `implementation` address with the bytecode after the address.
     *    - Deploy the contract using `create2` with the provided `value`, bytecode, and `salt`.
     * 3. If the deployment fails (i.e., `instance` is `address(0)`), revert with a `FailedDeployment` error.
     * 4. Return the address of the newly deployed contract instance.
     */
    function cloneDeterministic(address implementation, bytes32 salt, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance(address(this).balance, value);
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` address, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(value, 0x09, 0x37, salt)
        }
        if (instance == address(0)) {
            revert FailedDeployment();
        }
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using the CREATE2 opcode.
     *
     * @param implementation The address of the implementation contract.
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer (typically the contract deploying the new instance).
     * @return predicted The predicted deterministic address for the contract deployment.
     *
     * Steps:
     * 1. Load the free memory pointer.
     * 2. Store the deployer address, implementation address, and salt in memory.
     * 3. Use the CREATE2 opcode formula to compute the deterministic address:
     *    - The formula involves hashing the deployer address, implementation address, and salt.
     *    - The result is masked to ensure it is a valid Ethereum address.
     * 4. Return the predicted address.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using the CREATE2 opcode.
     *
     * @param implementation The address of the implementation contract.
     * @param salt A unique salt value used to generate the deterministic address.
     * @return predicted The predicted deterministic address for the contract deployment.
     *
     * Steps:
     * 1. Load the free memory pointer.
     * 2. Store the deployer address, implementation address, and salt in memory.
     * 3. Use the CREATE2 opcode formula to compute the deterministic address:
     *    - The formula involves hashing the deployer address, implementation address, and salt.
     *    - The result is masked to ensure it is a valid Ethereum address.
     * 4. Return the predicted address.
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
     *
     * Steps:
     * 1. Check if the contract has sufficient balance to cover the `value` sent with the deployment.
     *    - If not, revert with an `InsufficientBalance` error.
     * 2. Generate the bytecode for the cloned contract with the provided implementation and immutable arguments.
     * 3. Use assembly to deploy the contract with the generated bytecode and the specified `value`.
     * 4. Check if the deployment was successful (i.e., `instance` is not `address(0)`).
     *    - If not, revert with a `FailedDeployment` error.
     * 5. Return the address of the deployed contract instance.
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
     *
     * Steps:
     * 1. Check if the contract has sufficient balance to cover the `value` sent with the deployment.
     *    - If not, revert with an `InsufficientBalance` error.
     * 2. Generate the bytecode for the cloned contract with the provided implementation and immutable arguments.
     * 3. Use assembly to deploy the contract with the generated bytecode and the specified `value`.
     * 4. Check if the deployment was successful (i.e., `instance` is not `address(0)`).
     *    - If not, revert with a `FailedDeployment` error.
     * 5. Return the address of the deployed contract instance.
     */
    function cloneWithImmutableArgs(address implementation, bytes memory args, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance(address(this).balance, value);
        }
        bytes memory code = _cloneCodeWithImmutableArgs(implementation, args);
        /// @solidity memory-safe-assembly
        assembly {
            instance := create(value, add(code, 0x20), mload(code))
        }
        if (instance == address(0)) {
            revert FailedDeployment();
        }
    }

    /**
     * @notice Clones a contract deterministically with immutable arguments using a specified salt.
     *
     * @param implementation The address of the implementation contract to clone.
     * @param args The immutable arguments to be passed to the cloned contract.
     * @param salt A unique salt value to ensure deterministic deployment.
     * @return instance The address of the newly cloned contract instance.
     *
     * Steps:
     * 1. Calls an internal function `cloneDeterministicWithImmutableArgs` with the provided implementation, args, salt, and an additional parameter set to 0.
     * 2. Returns the address of the cloned contract instance.
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
     *
     * Steps:
     * 1. Calls an internal function `cloneDeterministicWithImmutableArgs` with the provided implementation, args, salt, and an additional parameter set to 0.
     * 2. Returns the address of the cloned contract instance.
     */
    function cloneDeterministicWithImmutableArgs(address implementation, bytes memory args, bytes32 salt, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert InsufficientBalance(address(this).balance, value);
        }
        bytes memory code = _cloneCodeWithImmutableArgs(implementation, args);
        /// @solidity memory-safe-assembly
        assembly {
            instance := create2(value, add(code, 0x20), mload(code), salt)
        }
        if (instance == address(0)) {
            revert FailedDeployment();
        }
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
     *
     * Steps:
     * 1. Generate the contract bytecode with the provided immutable arguments using `_cloneCodeWithImmutableArgs`.
     * 2. Compute the deterministic address using Create2's `computeAddress` function, which takes the salt, the keccak256 hash of the bytecode, and the deployer's address.
     * 3. Return the predicted address.
     */
    function predictDeterministicAddressWithImmutableArgs(address implementation, bytes memory args, bytes32 salt, address deployer) internal pure returns (address predicted) {
        bytes memory code = _cloneCodeWithImmutableArgs(implementation, args);
        bytes32 hash = keccak256(code);
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x40), hash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)
            predicted := keccak256(start, 0x55)
        }
    }

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using Create2 with immutable arguments.
     *
     * @param implementation The address of the implementation contract.
     * @param args The immutable arguments to be encoded into the contract bytecode.
     * @param salt A unique salt used to determine the deployment address.
     *
     * @return predicted The predicted address of the contract that will be deployed.
     *
     * Steps:
     * 1. Generate the contract bytecode with the provided immutable arguments using `_cloneCodeWithImmutableArgs`.
     * 2. Compute the deterministic address using Create2's `computeAddress` function, which takes the salt, the keccak256 hash of the bytecode, and the deployer's address.
     * 3. Return the predicted address.
     */
    function predictDeterministicAddressWithImmutableArgs(address implementation, bytes memory args, bytes32 salt) internal view returns (address predicted) {
        return predictDeterministicAddressWithImmutableArgs(implementation, args, salt, address(this));
    }

    /**
     * @notice Fetches the clone arguments from the given instance's bytecode.
     *
     * @param instance The address of the contract instance from which to fetch the clone arguments.
     * @return result A bytes array containing the clone arguments extracted from the instance's bytecode.
     *
     * Steps:
     * 1. Allocate a new bytes array (`result`) with a length equal to the instance's bytecode length minus 45 bytes.
     *    - This assumes that the first 45 bytes of the bytecode are not part of the clone arguments.
     *    - If the bytecode is too short, the function will revert.
     * 2. Use inline assembly to copy the relevant portion of the instance's bytecode into the `result` array.
     *    - `extcodecopy` is used to copy the bytecode starting from byte 45 to the end of the bytecode.
     * 3. Return the `result` array containing the extracted clone arguments.
     */
    function fetchCloneArgs(address instance) internal view returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let codeSize := extcodesize(instance)
            let argsSize := sub(codeSize, 45)
            result := mload(0x40)
            mstore(result, argsSize)
            extcodecopy(instance, add(result, 0x20), 45, argsSize)
            mstore(0x40, add(add(result, 0x20), argsSize))
        }
    }

    /**
     * @notice Constructs bytecode for a clone contract with immutable arguments.
     *
     * This function generates calldata for deploying a minimal proxy contract that
     * delegates calls to an implementation address while embedding immutable arguments.
     *
     * Steps:
     * 1. Reverts if the provided arguments exceed the maximum allowed length (24531 bytes).
     * 2. Packs the following components into a byte array:
     *    - A PUSH2 instruction with the total length of the resulting bytecode
     *    - A RETURN instruction to return the constructed bytecode
     *    - A PUSH20 instruction with the implementation address
     *    - A delegatecall pattern to forward calls to the implementation
     *    - The provided arguments data
     *
     * @param implementation The address of the contract to delegate calls to
     * @param args The immutable arguments to embed in the cloned contract
     * @return The constructed bytecode for the clone contract
     */
    function _cloneCodeWithImmutableArgs(address implementation, bytes memory args) private pure returns (bytes memory) {
        uint256 argsSize = args.length;
        require(argsSize <= 0x5fd3, "Clones: args too long");
        
        uint256 codeSize = 0x2d + argsSize;
        bytes memory code = new bytes(codeSize);
        
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := add(code, 0x20)
            // PUSH1 0x2d + argsSize
            mstore(ptr, 0x3d61000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(ptr, 2), add(0x2d, argsSize))
            // RETURNDATASIZE RETURNDATASIZE DUP2 CODECOPY RETURNDATASIZE RETURN
            mstore(add(ptr, 3), 0x80600a3d3981f3363d3d373d3d3d363d7300000000000000000000000000000000)
            // PUSH20 implementation
            mstore(add(ptr, 0x13), shl(0x60, implementation))
            // PUSH1 0x2d + argsSize
            mstore(add(ptr, 0x27), 0x5af43d82803e903d91602a57fd5bf30000000000000000000000000000000000)
            
            // Copy args
            let argsPtr := add(args, 0x20)
            let destPtr := add(ptr, 0x2d)
            for { let i := 0 } lt(i, argsSize) { i := add(i, 0x20) } {
                mstore(add(destPtr, i), mload(add(argsPtr, i)))
            }
        }
        
        return code;
    }
}
