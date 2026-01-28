// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Create2 helper
/// @notice Utilities for deploying contracts using CREATE2 and computing their addresses
library Create2 {
    /// @dev Thrown when the contract does not have enough balance for a deployment
    error InsufficientBalance();

    /// @dev Thrown when the provided bytecode is empty
    error Create2EmptyBytecode();

    /// @dev Thrown when the deployment failed without returning a revert reason
    error FailedDeployment();

    /**
     * @notice Deploys a new contract using the CREATE2 opcode with the provided bytecode and salt.
     *
     * @param amount The amount of Ether to send with the deployment.
     * @param salt A unique salt to ensure deterministic address generation.
     * @param bytecode The bytecode of the contract to be deployed.
     * @return addr The address of the newly deployed contract.
     *
     * Steps:
     * 1. Check if the contract has sufficient balance to cover the deployment cost. If not, revert with `InsufficientBalance` error.
     * 2. Check if the provided bytecode is empty. If so, revert with `Create2EmptyBytecode` error.
     * 3. Use inline assembly to deploy the contract using the CREATE2 opcode:
     *    - Pass the amount of Ether, bytecode, and salt to the CREATE2 opcode.
     *    - If the deployment fails and returndata is not empty, revert with the returned error data.
     * 4. If the deployment address is `address(0)`, revert with `FailedDeployment` error.
     * 5. Return the address of the deployed contract.
     */
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        // 1. Ensure sufficient balance
        if (address(this).balance < amount) revert InsufficientBalance();

        // 2. Ensure bytecode is not empty
        if (bytecode.length == 0) revert Create2EmptyBytecode();

        // 3. Deploy using CREATE2
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }

        // 4. If deployment failed, try to bubble up revert reason if provided
        if (addr == address(0)) {
            assembly {
                let size := returndatasize()
                // If there is revert data, bubble it up
                if gt(size, 0) {
                    returndatacopy(0x00, 0x00, size)
                    revert(0x00, size)
                }
            }

            // 5. No revert reason available
            revert FailedDeployment();
        }
    }

    /**
     * @notice Computes the address of a contract that will be deployed using the CREATE2 opcode.
     * 
     * @param salt A random value used to ensure the uniqueness of the deployed contract's address.
     * @param bytecodeHash The keccak256 hash of the contract's bytecode.
     * 
     * @return addr The computed address of the contract that will be deployed.
     * 
     * Steps:
     * 1. Use the current contract address as the deployer and delegate to the 3-arg overload.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @notice Computes the address of a contract that will be deployed using the CREATE2 opcode.
     * 
     * @param salt A random value used to ensure the uniqueness of the deployed contract's address.
     * @param bytecodeHash The keccak256 hash of the contract's bytecode.
     * @param deployer The address of the account deploying the contract.
     * 
     * @return addr The computed address of the contract that will be deployed.
     * 
     * Steps:
     * 1. Compute keccak256(0xff ++ deployer ++ salt ++ bytecodeHash) and return the last 20 bytes as the address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        addr = address(uint160(uint256(hash)));
    }
}
