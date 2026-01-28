// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Deploy to deterministic addresses without an initcode factor.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/CREATE3.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol)
library CREATE3 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the contract.
    error DeploymentFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPLOY OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Deploys a contract deterministically using the provided initialization code and salt.
     *
     * @param initCode The bytecode of the contract to be deployed, including the constructor arguments.
     * @param salt A unique value used to ensure deterministic deployment.
     * @return deployed The address of the deployed contract.
     *
     * Steps:
     * 1. Calls the `deployDeterministic` function with a value of 0, the provided `initCode`, and `salt`.
     * 2. Returns the address of the deployed contract.
     */
    function deployDeterministic(bytes memory initCode, bytes32 salt)
        internal
        returns (address deployed)
    {
        deployed = deployDeterministic(0, initCode, salt);
    }

    /**
     * @notice Deploys a contract deterministically using the provided initialization code and salt.
     *
     * @param initCode The bytecode of the contract to be deployed, including the constructor arguments.
     * @param salt A unique value used to ensure deterministic deployment.
     * @return deployed The address of the deployed contract.
     *
     * Steps:
     * 1. Calls the `deployDeterministic` function with a value of 0, the provided `initCode`, and `salt`.
     * 2. Returns the address of the deployed contract.
     */
    function deployDeterministic(uint256 value, bytes memory initCode, bytes32 salt)
        internal
        returns (address deployed)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the proxy bytecode in memory.
            // The proxy bytecode is a minimal contract that uses CREATE to deploy the actual contract.
            // Bytecode: 0x67363d3d37363d34f03d5260086018f3
            // This is a tiny contract that:
            // - Copies calldata to memory
            // - Uses CREATE to deploy a contract with the calldata as initcode
            // - Returns the address of the deployed contract
            mstore(0x00, 0x67363d3d37363d34f03d5260086018f3)

            // Deploy the proxy using CREATE2
            let proxy := create2(0, 0x10, 0x10, salt)

            // If the deployment failed, revert
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }

            // Call the proxy with the initcode to deploy the actual contract
            if iszero(call(gas(), proxy, value, add(initCode, 0x20), mload(initCode), 0x00, 0x00)) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }

            // Calculate the deployed contract address
            // The proxy uses CREATE with nonce 1, so we compute the address using RLP encoding
            mstore(0x14, proxy)
            mstore(0x00, 0xd694)
            mstore8(0x0b, 0x94)
            deployed := keccak256(0x0b, 0x15)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PREDICT OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using CREATE2.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer who will deploy the contract.
     * @return deployed The predicted address of the contract to be deployed.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Store the deployer's address in memory.
     * 3. Store the prefix byte (0xff) in memory.
     * 4. Store the salt value in memory.
     * 5. Store the bytecode hash of the proxy contract in memory.
     *
     * 6. Compute the keccak256 hash of the deployer, prefix, salt, and bytecode hash to derive the proxy's address.
     * 7. Restore the free memory pointer.
     * 8. Store the RLP prefix and length of the address in memory.
     * 9. Store the nonce of the proxy contract (1) in memory.
     * 10. Compute the final deterministic address using keccak256 and return it.
     */
    function predictDeterministicAddress(bytes32 salt) internal view returns (address deployed) {
        deployed = predictDeterministicAddress(salt, address(this));
    }

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using CREATE2.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer who will deploy the contract.
     * @return deployed The predicted address of the contract to be deployed.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Store the deployer's address in memory.
     * 3. Store the prefix byte (0xff) in memory.
     * 4. Store the salt value in memory.
     * 5. Store the bytecode hash of the proxy contract in memory.
     *
     * 6. Compute the keccak256 hash of the deployer, prefix, salt, and bytecode hash to derive the proxy's address.
     * 7. Restore the free memory pointer.
     * 8. Store the RLP prefix and length of the address in memory.
     * 9. Store the nonce of the proxy contract (1) in memory.
     * 10. Compute the final deterministic address using keccak256 and return it.
     */
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address deployed)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Cache the free memory pointer.
            let m := mload(0x40)

            // Store the deployer's address.
            mstore(0x00, deployer)
            
            // Store the prefix byte (0xff).
            mstore8(0x0b, 0xff)
            
            // Store the salt value.
            mstore(0x20, salt)

            // Store the bytecode hash of the proxy contract.
            // keccak256(0x67363d3d37363d34f03d5260086018f3)
            mstore(0x40, 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f)

            // Compute the keccak256 hash to derive the proxy's address.
            let proxy := keccak256(0x0b, 0x55)

            // Restore the free memory pointer.
            mstore(0x40, m)

            // Store the RLP prefix and length of the address.
            mstore(0x14, proxy)
            mstore(0x00, 0xd694)
            
            // Store the nonce of the proxy contract (1).
            mstore8(0x0b, 0x94)

            // Compute the final deterministic address using keccak256 and return it.
            deployed := keccak256(0x0b, 0x15)
        }
    }
}
