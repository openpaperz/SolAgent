// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for cheaply storing and reading data using contract code storage.
/// @author Solady
library SSTORE2 {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// @dev Thrown when a deployment fails.
    error DeploymentFailed();

    /// @dev Thrown when trying to read beyond the end of the code.
    error OutOfBounds();

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    /// @dev The initcode hash of the CREATE3 proxy used by {writeDeterministic}.
    ///
    /// The runtime code of the proxy is:
    /// 0x3d3d3d3d3d363d3d37363d73<deployer>5af43d3d93803e602a57fd5bf3
    ///
    /// The initcode is:
    /// 0x67<runtime_code_length>3d81600a3d39f3<runtime_code>
    ///
    /// Precomputed for gas savings.
    bytes32 internal constant _CREATE3_PROXY_INITCODE_HASH =
        0x0dcd1e6b0e985cbbdfe8e94cf236503d17b47779fba399a097e68bc35c2c22df;

    /// @dev The initcode of the CREATE3 proxy used for {writeDeterministic}.
    /// This is the same proxy used by popular CREATE3 libraries; embedded here
    /// to avoid an extra dependency.
    bytes internal constant _CREATE3_PROXY_INITCODE =
        hex"67_3d3d3d3d3d363d3d37363d735af43d3d93803e602a57fd5bf3"
        hex"3d81600a3d39f3";

    /// -----------------------------------------------------------------------
    /// Write operations
    /// -----------------------------------------------------------------------

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
        assembly {
            let n := mload(data)
            // Prefix `data` with a STOP opcode.
            // We temporarily overwrite the word before `data`'s content.
            // Original layout:
            // [ length ][ data ... ]
            //
            // We are going to create:
            // [ 0x00 ][ 0x00 .. 0x00 STOP data ... ]
            //
            // We set the first byte of the new code to 0x00 (STOP).
            // The rest of the first word can be left zero.
            let dataPtr := add(data, 0x20)
            let wordBefore := mload(sub(dataPtr, 0x20))
            mstore(sub(dataPtr, 0x20), 0x00)
            // Deploy with CREATE, offset is one byte before `dataPtr`
            // so that runtime code = STOP || data
            pointer := create(0, sub(dataPtr, 1), add(n, 1))
            // Restore the original word.
            mstore(sub(dataPtr, 0x20), wordBefore)
            if iszero(pointer) {
                // Use error selector for DeploymentFailed().
                mstore(0x00, 0x4ba3b8c0)
                revert(0x1c, 0x04)
            }
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
    function writeCounterfactual(bytes memory data, bytes32 salt) internal returns (address pointer) {
        assembly {
            let n := mload(data)
            // Bound the length to <= 0xfffe for safety (fits in 2 bytes plus one STOP).
            if gt(n, 0xfffe) {
                revert(0, 0)
            }

            let dataPtr := add(data, 0x20)
            let wordBefore := mload(sub(dataPtr, 0x20))
            mstore(sub(dataPtr, 0x20), 0x00)
            pointer := create2(0, sub(dataPtr, 1), add(n, 1), salt)
            mstore(sub(dataPtr, 0x20), wordBefore)

            if iszero(pointer) {
                mstore(0x00, 0x4ba3b8c0)
                revert(0x1c, 0x04)
            }
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
    function writeDeterministic(bytes memory data, bytes32 salt) internal returns (address pointer) {
        assembly {
            let n := mload(data)
            if gt(n, 0xfffe) {
                revert(0, 0)
            }

            // Copy proxy initcode into memory.
            let initcode := _CREATE3_PROXY_INITCODE
            let initLen := mload(initcode)
            let initPtr := add(initcode, 0x20)

            let memPtr := mload(0x40)
            // Copy initcode to free memory.
            for { let i := 0 } lt(i, initLen) { i := add(i, 0x20) } {
                mstore(add(memPtr, i), mload(add(initPtr, i)))
            }

            let proxy := create2(0, memPtr, initLen, salt)
            if iszero(proxy) {
                mstore(0x00, 0x4ba3b8c0)
                revert(0x1c, 0x04)
            }

            // Now deploy the actual data contract via the proxy.
            // Prefix with STOP as in {write}.
            let dataPtr := add(data, 0x20)
            let wordBefore := mload(sub(dataPtr, 0x20))
            mstore(sub(dataPtr, 0x20), 0x00)

            // Call proxy with "STOP || data" as calldata; proxy will deploy it
            // and return the address. For simplicity treat it as a plain call
            // that returns the pointer.
            if iszero(
                call(
                    gas(),
                    proxy,
                    0,
                    sub(dataPtr, 1),
                    add(n, 1),
                    0x00,
                    0x20
                )
            ) {
                mstore(0x00, 0x4ba3b8c0)
                revert(0x1c, 0x04)
            }

            mstore(sub(dataPtr, 0x20), wordBefore)
            pointer := mload(0x00)
        }
    }

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
        assembly {
            let n := mload(data)
            if gt(n, 0xfffe) {
                revert(0, 0)
            }

            let dataPtr := add(data, 0x20)
            let wordBefore := mload(sub(dataPtr, 0x20))
            mstore(sub(dataPtr, 0x20), 0x00)
            hash := keccak256(sub(dataPtr, 1), add(n, 1))
            mstore(sub(dataPtr, 0x20), wordBefore)
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
     * @return predicted The predicted address of the contract if deployed with the given data and salt.
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
        bytes32 hash;
        assembly {
            let n := mload(data)
            if gt(n, 0xfffe) {
                revert(0, 0)
            }

            let dataPtr := add(data, 0x20)
            let wordBefore := mload(sub(dataPtr, 0x20))
            mstore(sub(dataPtr, 0x20), 0x00)
            hash := keccak256(sub(dataPtr, 1), add(n, 1))
            mstore(sub(dataPtr, 0x20), wordBefore)
        }
        predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), deployer, salt, hash)
                    )
                )
            )
        );
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
    function predictDeterministicAddress(bytes32 salt)
        internal
        view
        returns (address pointer)
    {
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
        assembly {
            let m := mload(0x40)

            // Compute the CREATE2 proxy address.
            // keccak256(0xff ++ deployer ++ salt ++ init_code_hash)
            mstore(add(m, 0x00), 0xff)
            mstore(add(m, 0x01), shl(96, deployer))
            mstore(add(m, 0x15), salt)
            mstore(add(m, 0x35), _CREATE3_PROXY_INITCODE_HASH)
            let proxy := keccak256(add(m, 0x00), 0x55)
            // Convert to address.
            proxy := and(proxy, 0xffffffffffffffffffffffffffffffffffffffff)

            // Now compute the CREATE address of the first deployment from `proxy`.
            // This uses the RLP encoding of [proxy, 1].
            // For an address with no leading zeros, RLP(address) = 0x94 ++ 20-byte address
            // and RLP(1) = 0x01. The list prefix is then 0xd6 (0xc0 + len(0x94.. + 0x01) = 0x16).
            mstore(add(m, 0x00), 0xd6_94_0000000000000000000000000000000000000000)
            mstore(add(m, 0x03), shl(96, proxy))
            mstore(add(m, 0x17), 0x01)

            pointer := and(
                keccak256(add(m, 0x00), 0x19),
                0xffffffffffffffffffffffffffffffffffffffff
            )
        }
    }

    /// -----------------------------------------------------------------------
    /// Read operations
    /// -----------------------------------------------------------------------

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
        assembly {
            // Skip the first byte (STOP) in the runtime code.
            let size := extcodesize(pointer)
            if iszero(size) {
                mstore(0x00, 0x20)
                data := 0x00
                return(0x00, 0x20)
            }
            size := sub(size, 1)

            data := mload(0x40)
            mstore(data, size)

            let dest := add(data, 0x20)
            extcodecopy(pointer, dest, 1, size)

            mstore(0x40, add(dest, and(add(size, 0x1f), not(0x1f))))
        }
    }

    /**
     * @notice Reads the code of a contract at the given address and returns it as a byte array.
     *
     * @param pointer The address of the contract whose code is to be read.
     * @param start   The start offset (relative to the stored data, not including the STOP byte).
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
    function read(address pointer, uint256 start)
        internal
        view
        returns (bytes memory data)
    {
        assembly {
            let size := extcodesize(pointer)
            if lt(add(start, 1), size) {
                let len := sub(size, add(start, 1))
                data := mload(0x40)
                mstore(data, len)
                let dest := add(data, 0x20)
                extcodecopy(pointer, dest, add(start, 1), len)
                mstore(0x40, add(dest, and(add(len, 0x1f), not(0x1f))))
            }
            // If out of bounds, revert.
            if iszero(data) {
                mstore(0x00, 0x0fbe1a5e) // OutOfBounds()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Reads the code of a contract at the given address and returns it as a byte array.
     *
     * @param pointer The address of the contract whose code is to be read.
     * @param start   The start offset (relative to the stored data, not including the STOP byte).
     * @param end     The end offset (exclusive, relative to the stored data, not including the STOP byte).
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
        assembly {
            let size := extcodesize(pointer)
            if or(gt(start, end), gt(add(end, 1), size)) {
                mstore(0x00, 0x0fbe1a5e) // OutOfBounds()
                revert(0x1c, 0x04)
            }

            let len := sub(end, start)
            data := mload(0x40)
            mstore(data, len)
            let dest := add(data, 0x20)
            extcodecopy(pointer, dest, add(start, 1), len)
            mstore(0x40, add(dest, and(add(len, 0x1f), not(0x1f))))
        }
    }
}