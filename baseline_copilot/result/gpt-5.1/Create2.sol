// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Create2 {
    /// @dev Error indicating that the caller does not have sufficient balance to perform the deployment.
    error InsufficientBalance(uint256 balance, uint256 required);

    /// @dev Error indicating that the provided bytecode is empty.
    error Create2EmptyBytecode();

    /// @dev Error indicating that the contract deployment has failed.
    error FailedDeployment(address addr);

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
        if (address(this).balance < amount) {
            revert InsufficientBalance(address(this).balance, amount);
        }

        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (addr == address(0)) {
            // If there is revert data, bubble it up
            assembly {
                let size := returndatasize()
                if gt(size, 0) {
                    returndatacopy(0, 0, size)
                    revert(0, size)
                }
            }
            revert FailedDeployment(addr);
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
     * 1. Load the free memory pointer to allocate memory for the computation.
     * 2. Store the bytecode hash, salt, and deployer address in memory.
     * 3. Adjust the memory pointer to include a 0xff byte, which is required for CREATE2 address computation.
     * 4. Compute the keccak256 hash of the memory region containing the deployer address, salt, and bytecode hash.
     * 5. Mask the hash to ensure it is a valid Ethereum address (160 bits).
     * 6. Return the computed address.
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
     * 1. Load the free memory pointer to allocate memory for the computation.
     * 2. Store the bytecode hash, salt, and deployer address in memory.
     * 3. Adjust the memory pointer to include a 0xff byte, which is required for CREATE2 address computation.
     * 4. Compute the keccak256 hash of the memory region containing the deployer address, salt, and bytecode hash.
     * 5. Mask the hash to ensure it is a valid Ethereum address (160 bits).
     * 6. Return the computed address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        bytes32 data = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash)
        );
        addr = address(uint160(uint256(data)));
    }
}