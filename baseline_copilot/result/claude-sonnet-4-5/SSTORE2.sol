// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for reading and writing contract bytecode as data storage.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SSTORE2.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/sstore2/blob/master/contracts/SSTORE2.sol)
library SSTORE2 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The proxy initialization code for CREATE3.
    uint256 private constant _CREATE3_PROXY_INITCODE = 0x67363d3d37363d34f03d5260086018f3;

    /// @dev Hash of the `_CREATE3_PROXY_INITCODE`.
    /// Equivalent to `keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))`.
    bytes32 internal constant CREATE3_PROXY_INITCODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     CUSTOM ERRORS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the contract.
    error DeploymentFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         WRITE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Writes the provided data to a new contract and returns the contract's address.
     *
     * @dev This function uses inline assembly to deploy a new contract with the provided data.
     * The data is prefixed with a STOP opcode to ensure the contract cannot be called directly.
     * The function also handles edge cases, such as ensuring the data length does not exceed the maximum allowed size.
     * If the deployment fails, the function reverts with a custom error `DeploymentFailed()`.
     *
     * @param data The bytecode data to be written to the new contract.
     * @return pointer The address of the newly deployed contract.
     *
     * Steps:
     * 1. Load the length of the data into `n`.
     * 2. Prefix the data with a STOP opcode and additional assembly instructions to ensure the contract cannot be called.
     * 3. Deploy a new contract using the modified data.
     * 4. If the deployment fails, revert with the `DeploymentFailed()` error.
     * 5. Restore the original length of the data in memory.
     * 6. Return the address of the newly deployed contract.
     */
    function write(bytes memory data) internal returns (address pointer) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Prefix the data with a STOP opcode (0x00) followed by a return of the data.
            // Deploy code: 0x00 (STOP) + data
            // We use the following trick: we store the deploy code at data - 1, which is
            // the 32nd byte of the length slot. We temporarily overwrite it.
            let originalByte := mload(sub(data, 0x01))
            mstore(sub(data, 0x01), 0x00)
            // Deploy using CREATE with the modified initcode.
            pointer := create(0, sub(data, 0x01), add(n, 0x01))
            // Restore the original byte.
            mstore(sub(data, 0x01), originalByte)
            // If the deployment failed, revert.
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            // Restore the length.
            mstore(data, n)
        }
    }

    /**
     * @notice Deploys a new contract using the `create2` opcode with the provided data and salt.
     * @dev This function is used to deploy a contract counterfactually, meaning the contract's address 
     *      can be computed before deployment. The function uses inline assembly for low-level operations.
     *
     * @param data The bytecode and constructor arguments for the contract to be deployed.
     * @param salt A unique value used to determine the contract's address.
     * @return pointer The address of the newly deployed contract.
     *
     * Steps:
     * 1. Load the length of the `data` into `n`.
     * 2. Perform a gas check to ensure the data length is within bounds (less than or equal to 0xfffe).
     * 3. Modify the data to include the necessary creation code for the contract.
     * 4. Use the `create2` opcode to deploy the contract with the provided data and salt.
     * 5. If the deployment fails, revert with the `DeploymentFailed()` error.
     * 6. Restore the original length of `data` in memory.
     * 7. Return the address of the deployed contract.
     *
     * Notes:
     * - The function uses inline assembly for low-level memory manipulation and contract deployment.
     * - The `create2` opcode allows deterministic contract address generation based on the salt.
     */
    function writeCounterfactual(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Perform an out-of-gas revert if `n + 1` is more than 2 bytes.
            // This check ensures the data length is within acceptable bounds.
            if iszero(lt(n, 0xfffe)) {
                returndatacopy(returndatasize(), returndatasize(), add(gt(n, 0xffff), 0x01))
            }
            // Prefix the data with a STOP opcode.
            let originalByte := mload(sub(data, 0x01))
            mstore(sub(data, 0x01), 0x00)
            // Deploy using CREATE2 with the modified initcode.
            pointer := create2(0, sub(data, 0x01), add(n, 0x01), salt)
            // Restore the original byte.
            mstore(sub(data, 0x01), originalByte)
            // If the deployment failed, revert.
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            // Restore the length.
            mstore(data, n)
        }
    }

    /**
     * @notice Deploys a deterministic proxy contract using CREATE2 and initializes it with the provided data.
     *
     * @param data The data to be passed to the proxy contract for initialization.
     * @param salt A unique salt value used to determine the address of the deployed proxy contract.
     * @return pointer The address of the deployed proxy contract.
     *
     * Steps:
     * 1. Load the length of the data into `n`.
     * 2. Store the `_CREATE3_PROXY_INITCODE` in memory.
     * 3. Deploy the proxy contract using `create2` with the provided salt.
     * 4. If the deployment fails, revert with the `DeploymentFailed()` error.
     * 5. Store the proxy contract's address in memory.
     * 6. Calculate the address of the proxy contract using `keccak256`.
     * 7. Ensure that the length of the data (`n + 1`) does not exceed 2 bytes, otherwise revert.
     * 8. Initialize the proxy contract by calling it with the provided data.
     * 9. If the initialization fails, revert with the `DeploymentFailed()` error.
     * 10. Restore the original length of the data in memory.
     */
    function writeDeterministic(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Perform an out-of-gas revert if `n + 1` is more than 2 bytes.
            if iszero(lt(n, 0xfffe)) {
                returndatacopy(returndatasize(), returndatasize(), add(gt(n, 0xffff), 0x01))
            }
            // Prefix the data with a STOP opcode.
            let originalByte := mload(sub(data, 0x01))
            mstore(sub(data, 0x01), 0x00)
            
            // Cache the free memory pointer.
            let m := mload(0x40)
            // Store the `_CREATE3_PROXY_INITCODE` in memory.
            mstore(0x00, _CREATE3_PROXY_INITCODE)
            // Deploy the proxy contract using CREATE2.
            let proxy := create2(0, 0x10, 0x10, salt)
            // Restore the free memory pointer.
            mstore(0x40, m)
            // If the deployment of the proxy failed, revert.
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            
            // Deploy the contract via the proxy.
            if iszero(
                call(
                    gas(), // Gas remaining.
                    proxy, // Proxy address.
                    0, // Value.
                    sub(data, 0x01), // Start of initcode.
                    add(n, 0x01), // Length of initcode.
                    0x00, // Return data offset.
                    0x00 // Return data length.
                )
            ) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            
            // Restore the original byte.
            mstore(sub(data, 0x01), originalByte)
            // Restore the length.
            mstore(data, n)
            
            // Compute the deterministic address.
            mstore(0x14, proxy)
            mstore(0x00, 0xd694)
            pointer := keccak256(0x1e, 0x17)
            mstore(0x40, m)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ADDRESS PREDICTION                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Computes the keccak256 hash of the given bytecode data with a specific prefix.
     * 
     * Steps:
     * 1. Load the length of the data into `n`.
     * 2. Perform an out-of-gas revert if `n + 1` exceeds 2 bytes.
     * 3. Prepend a specific prefix to the data in memory.
     * 4. Compute the keccak256 hash of the modified data.
     * 5. Restore the original length of the data in memory.
     * 
     * @param data The bytecode data to compute the hash for.
     * @return hash The computed keccak256 hash of the modified data.
     */
    function initCodeHash(bytes memory data) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Perform an out-of-gas revert if `n + 1` is more than 2 bytes.
            if iszero(lt(n, 0xfffe)) {
                returndatacopy(returndatasize(), returndatasize(), add(gt(n, 0xffff), 0x01))
            }
            // Prefix the data with a STOP opcode.
            let originalByte := mload(sub(data, 0x01))
            mstore(sub(data, 0x01), 0x00)
            // Compute the hash.
            hash := keccak256(sub(data, 0x01), add(n, 0x01))
            // Restore the original byte.
            mstore(sub(data, 0x01), originalByte)
            // Restore the length.
            mstore(data, n)
        }
    }

    /**
     * @notice Predicts the counterfactual address for a contract deployment using the provided data and salt.
     *
     * @param data The bytecode or initialization data for the contract.
     * @param salt A unique value used to influence the resulting address.
     * @return pointer The predicted address of the contract if deployed with the given data and salt.
     *
     * Steps:
     * 1. Calls an internal helper function `predictCounterfactualAddress` with the provided data, salt, and the current contract's address (`address(this)`).
     * 2. Returns the predicted address.
     */
    function predictCounterfactualAddress(bytes memory data, bytes32 salt)
        internal
        view
        returns (address pointer)
    {
        pointer = predictCounterfactualAddress(data, salt, address(this));
    }

    /**
     * @notice Predicts the counterfactual address for a contract deployment using the provided data and salt.
     *
     * @param data The bytecode or initialization data for the contract.
     * @param salt A unique value used to influence the resulting address.
     * @return pointer The predicted address of the contract if deployed with the given data and salt.
     *
     * Steps:
     * 1. Calls an internal helper function `predictCounterfactualAddress` with the provided data, salt, and the current contract's address (`address(this)`).
     * 2. Returns the predicted address.
     */
    function predictCounterfactualAddress(bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(data);
        /// @solidity memory-safe-assembly
        assembly {
            // Cache the free memory pointer.
            let m := mload(0x40)
            // Store the deployer address.
            mstore(0x00, deployer)
            // Store the prefix byte (0xff).
            mstore8(0x0b, 0xff)
            // Store the salt.
            mstore(0x20, salt)
            // Store the init code hash.
            mstore(0x40, hash)
            // Compute the CREATE2 address.
            predicted := keccak256(0x0b, 0x55)
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using CREATE3.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer that will deploy the contract.
     * @return pointer The predicted deterministic address for the contract deployment.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Store the deployer address in memory.
     * 3. Store the prefix byte (0xff) in memory.
     * 4. Store the salt value in memory.
     * 5. Store the CREATE3 proxy's initialization code hash in memory.
     * 6. Compute the proxy's address by hashing the relevant memory region.
     * 7. Restore the free memory pointer.
     * 8. Prepare the RLP-encoded data for the deterministic address calculation.
     * 9. Store the nonce of the proxy contract (1) in memory.
     * 10. Compute the deterministic address by hashing the RLP-encoded data.
     */
    function predictDeterministicAddress(bytes32 salt) internal view returns (address pointer) {
        pointer = predictDeterministicAddress(salt, address(this));
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using CREATE3.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer that will deploy the contract.
     * @return pointer The predicted deterministic address for the contract deployment.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Store the deployer address in memory.
     * 3. Store the prefix byte (0xff) in memory.
     * 4. Store the salt value in memory.
     * 5. Store the CREATE3 proxy's initialization code hash in memory.
     * 6. Compute the proxy's address by hashing the relevant memory region.
     * 7. Restore the free memory pointer.
     * 8. Prepare the RLP-encoded data for the deterministic address calculation.
     * 9. Store the nonce of the proxy contract (1) in memory.
     * 10. Compute the deterministic address by hashing the RLP-encoded data.
     */
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Cache the free memory pointer.
            let m := mload(0x40)
            // Store the deployer address.
            mstore(0x00, deployer)
            // Store the prefix byte (0xff).
            mstore8(0x0b, 0xff)
            // Store the salt.
            mstore(0x20, salt)
            // Store the CREATE3 proxy's init code hash.
            mstore(0x40, CREATE3_PROXY_INITCODE_HASH)
            // Compute the proxy's address.
            let proxy := keccak256(0x0b, 0x55)
            // Restore the free memory pointer.
            mstore(0x40, m)
            // Prepare RLP-encoded data for deterministic address calculation.
            // RLP encoding: [0xd6, 0x94, proxy (20 bytes), 0x01]
            mstore(0x14, proxy)
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01)
            // Compute the deterministic address.
            pointer := keccak256(0x1e, 0x17)
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         READ LOGIC                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Reads the code of a contract at the given address and returns it as a byte array.
     *
     * @param pointer The address of the contract whose code is to be read.
     * @return data A byte array containing the contract's code.
     *
     * Steps:
     * 1. Allocate memory for the byte array using `mload(0x40)`.
     * 2. Calculate the length of the code to be copied, ensuring it is within bounds.
     * 3. Copy the contract's code into the allocated memory using `extcodecopy`.
     * 4. Store the length of the code in the first 32 bytes of the allocated memory.
     * 5. Update the free memory pointer (`0x40`) to allocate memory for the next operation.
     *
     * @dev This function uses inline assembly for low-level memory manipulation.
     */
    function read(address pointer) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            // Get the size of the code at the pointer address.
            let n := extcodesize(pointer)
            // If there is code, skip the STOP opcode (first byte).
            if iszero(iszero(n)) {
                // Allocate memory for the byte array.
                data := mload(0x40)
                // Set the length of the byte array (n - 1, skipping the STOP opcode).
                mstore(data, sub(n, 0x01))
                // Copy the code into memory, starting from byte 1 (skipping STOP opcode).
                extcodecopy(pointer, add(data, 0x20), 0x01, sub(n, 0x01))
                // Update the free memory pointer.
                mstore(0x40, add(add(data, 0x20), sub(n, 0x01)))
            }
        }
    }

    /**
     * @notice Reads the code of a contract at the given address and returns it as a byte array.
     *
     * @param pointer The address of the contract whose code is to be read.
     * @return data A byte array containing the contract's code.
     *
     * Steps:
     * 1. Allocate memory for the byte array using `mload(0x40)`.
     * 2. Calculate the length of the code to be copied, ensuring it is within bounds.
     * 3. Copy the contract's code into the allocated memory using `extcodecopy`.
     * 4. Store the length of the code in the first 32 bytes of the allocated memory.
     * 5. Update the free memory pointer (`0x40`) to allocate memory for the next operation.
     *
     * @dev This function uses inline assembly for low-level memory manipulation.
     */
    function read(address pointer, uint256 start) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            // Get the size of the code at the pointer address.
            let n := extcodesize(pointer)
            // If there is code, skip the STOP opcode (first byte).
            if iszero(iszero(n)) {
                // Allocate memory for the byte array.
                data := mload(0x40)
                // Calculate the actual length to read.
                // n is total code size, we skip the first byte (STOP opcode).
                // Adjust start to account for the STOP opcode.
                let adjustedStart := add(start, 0x01)
                // Calculate the length to copy.
                let len := sub(n, adjustedStart)
                // Clamp len to be non-negative.
                if sgt(adjustedStart, n) { len := 0 }
                // Set the length of the byte array.
                mstore(data, len)
                // Copy the code into memory.
                extcodecopy(pointer, add(data, 0x20), adjustedStart, len)
                // Update the free memory pointer.
                mstore(0x40, add(add(data, 0x20), len))
            }
        }
    }

    /**
     * @notice Reads the code of a contract at the given address and returns it as a byte array.
     *
     * @param pointer The address of the contract whose code is to be read.
     * @return data A byte array containing the contract's code.
     *
     * Steps:
     * 1. Allocate memory for the byte array using `mload(0x40)`.
     * 2. Calculate the length of the code to be copied, ensuring it is within bounds.
     * 3. Copy the contract's code into the allocated memory using `extcodecopy`.
     * 4. Store the length of the code in the first 32 bytes of the allocated memory.
     * 5. Update the free memory pointer (`0x40`) to allocate memory for the next operation.
     *
     * @dev This function uses inline assembly for low-level memory manipulation.
     */
    function read(address pointer, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory data)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Get the size of the code at the pointer address.
            let n := extcodesize(pointer)
            // If there is code, skip the STOP opcode (first byte).
            if iszero(iszero(n)) {
                // Allocate memory for the byte array.
                data := mload(0x40)
                // Adjust start and end to account for the STOP opcode.
                let adjustedStart := add(start, 0x01)
                let adjustedEnd := add(end, 0x01)
                // Clamp adjustedEnd to the actual code size.
                if gt(adjustedEnd, n) { adjustedEnd := n }
                // Calculate the length to copy.
                let len := sub(adjustedEnd, adjustedStart)
                // Clamp len to be non-negative.
                if sgt(adjustedStart, adjustedEnd) { len := 0 }
                // Set the length of the byte array.
                mstore(data, len)
                // Copy the code into memory.
                extcodecopy(pointer, add(data, 0x20), adjustedStart, len)
                // Update the free memory pointer.
                mstore(0x40, add(add(data, 0x20), len))
            }
        }
    }
}
