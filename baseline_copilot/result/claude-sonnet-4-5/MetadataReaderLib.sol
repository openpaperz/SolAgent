// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for reading metadata from contracts with gas-efficient low-level calls.
library MetadataReaderLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Default gas stipend to prevent griefing attacks.
    uint256 private constant _GAS_STIPEND = 50000;

    /// @dev Default byte limit for string reads.
    uint256 private constant _LIMIT = 0xffffffff;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      NAME FUNCTIONS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Reads the name of a target contract using a low-level call with a specified gas stipend.
     *
     * @param target The address of the target contract from which to read the name.
     * @return The name of the target contract as a string.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, the function selector for `name()` (0x06fdde03), 
     *    the byte limit, and the gas stipend.
     * 2. Returns the name of the target contract as a string.
     */
    function readName(address target) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), _LIMIT, _GAS_STIPEND);
    }

    /**
     * @notice Reads the name of a target contract using a low-level call with a specified gas stipend.
     *
     * @param target The address of the target contract from which to read the name.
     * @param limit The maximum number of bytes to read from the target contract.
     * @return The name of the target contract as a string.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, the function selector for `name()` (0x06fdde03), 
     *    the byte limit, and the gas stipend.
     * 2. Returns the name of the target contract as a string.
     */
    function readName(address target, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), limit, _GAS_STIPEND);
    }

    /**
     * @notice Reads the name of a target contract using a low-level call with a specified gas stipend.
     *
     * @param target The address of the target contract from which to read the name.
     * @param limit The maximum number of bytes to read from the target contract.
     * @param gasStipend The amount of gas to stipend for the low-level call.
     * @return The name of the target contract as a string.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, the function selector for `name()` (0x06fdde03), 
     *    the byte limit, and the gas stipend.
     * 2. Returns the name of the target contract as a string.
     */
    function readName(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), limit, gasStipend);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     SYMBOL FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Reads the symbol of an ERC20 token from a target contract address.
     *
     * @param target The address of the target ERC20 token contract.
     * @return The symbol of the ERC20 token as a string.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, the function selector for `symbol()` (0x95d89b41), the byte limit, and the gas stipend.
     * 2. Returns the symbol of the token as a string.
     */
    function readSymbol(address target) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), _LIMIT, _GAS_STIPEND);
    }

    /**
     * @notice Reads the symbol of an ERC20 token from a target contract address.
     *
     * @param target The address of the target ERC20 token contract.
     * @param limit The maximum number of bytes to read from the target contract.
     * @return The symbol of the ERC20 token as a string.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, the function selector for `symbol()` (0x95d89b41), the byte limit, and the gas stipend.
     * 2. Returns the symbol of the token as a string.
     */
    function readSymbol(address target, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), limit, _GAS_STIPEND);
    }

    /**
     * @notice Reads the symbol of an ERC20 token from a target contract address.
     *
     * @param target The address of the target ERC20 token contract.
     * @param limit The maximum number of bytes to read from the target contract.
     * @param gasStipend The amount of gas to stipend for the call.
     *
     * @return The symbol of the ERC20 token as a string.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, the function selector for `symbol()` (0x95d89b41), the byte limit, and the gas stipend.
     * 2. Returns the symbol of the token as a string.
     */
    function readSymbol(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), limit, gasStipend);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     STRING FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Reads a string from a target contract using the provided data and gas limit.
     *
     * @param target The address of the target contract from which to read the string.
     * @param data The data to be passed to the target contract for the string read operation.
     * @return string memory The string read from the target contract.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, data pointer, gas limit, and a predefined gas stipend.
     * 2. Returns the string read from the target contract.
     */
    function readString(address target, bytes memory data) internal view returns (string memory) {
        return _string(target, _ptr(data), _LIMIT, _GAS_STIPEND);
    }

    /**
     * @notice Reads a string from a target contract using the provided data and gas limit.
     *
     * @param target The address of the target contract from which to read the string.
     * @param data The data to be passed to the target contract for the string read operation.
     * @param limit The maximum gas limit to be used for the read operation.
     * @return string memory The string read from the target contract.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, data pointer, gas limit, and a predefined gas stipend.
     * 2. Returns the string read from the target contract.
     */
    function readString(address target, bytes memory data, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(data), limit, _GAS_STIPEND);
    }

    /**
     * @notice Reads a string from a target contract using the provided data and gas limit.
     *
     * @param target The address of the target contract from which to read the string.
     * @param data The data to be passed to the target contract for the string read operation.
     * @param limit The maximum gas limit to be used for the read operation.
     * @return string memory The string read from the target contract.
     *
     * Steps:
     * 1. Calls the internal `_string` function with the target address, data pointer, gas limit, and a predefined gas stipend.
     * 2. Returns the string read from the target contract.
     */
    function readString(address target, bytes memory data, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(data), limit, gasStipend);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DECIMALS FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Reads the decimals of an ERC20 token at the specified address.
     *
     * @param target The address of the ERC20 token contract.
     * @return uint8 The number of decimals the token uses.
     *
     * Steps:
     * 1. Calls the `_uint` function with the target address, the function selector for `decimals()` (0x313ce567), 
     *    and a gas stipend to avoid griefing attacks.
     * 2. Casts the result to `uint8` and returns it.
     */
    function readDecimals(address target) internal view returns (uint8) {
        return uint8(_uint(target, _ptr(0x313ce567), _GAS_STIPEND));
    }

    /**
     * @notice Reads the decimals of an ERC20 token at the specified address.
     *
     * @param target The address of the ERC20 token contract.
     * @return uint8 The number of decimals the token uses.
     *
     * Steps:
     * 1. Calls the `_uint` function with the target address, the function selector for `decimals()` (0x313ce567), 
     *    and a gas stipend to avoid griefing attacks.
     * 2. Casts the result to `uint8` and returns it.
     */
    function readDecimals(address target, uint256 gasStipend) internal view returns (uint8) {
        return uint8(_uint(target, _ptr(0x313ce567), gasStipend));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      UINT FUNCTIONS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Reads a `uint256` value from a target contract using the provided data and gas stipend.
     *
     * @param target The address of the target contract from which to read the `uint256` value.
     * @param data The encoded data to be sent to the target contract for the read operation.
     * @return The `uint256` value read from the target contract.
     *
     * Steps:
     * 1. Calls the internal `_uint` function with the target address, the pointer to the data, and the gas stipend.
     * 2. Returns the `uint256` value obtained from the target contract.
     */
    function readUint(address target, bytes memory data) internal view returns (uint256) {
        return _uint(target, _ptr(data), _GAS_STIPEND);
    }

    /**
     * @notice Reads a `uint256` value from a target contract using the provided data and gas stipend.
     *
     * @param target The address of the target contract from which to read the `uint256` value.
     * @param data The encoded data to be sent to the target contract for the read operation.
     * @param gasStipend The amount of gas to be provided for the read operation.
     * @return The `uint256` value read from the target contract.
     *
     * Steps:
     * 1. Calls the internal `_uint` function with the target address, the pointer to the data, and the gas stipend.
     * 2. Returns the `uint256` value obtained from the target contract.
     */
    function readUint(address target, bytes memory data, uint256 gasStipend) internal view returns (uint256) {
        return _uint(target, _ptr(data), gasStipend);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL HELPERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice A private view function that retrieves a string from a target contract using low-level assembly.
     *
     * @param target The address of the target contract to call.
     * @param ptr A pointer to the data to be passed to the target contract.
     * @param limit The maximum length of the string to be returned.
     * @param gasStipend The amount of gas to be provided for the static call.
     * @return result The resulting string retrieved from the target contract.
     *
     * Steps:
     * 1. Perform a static call to the target contract with the provided gas stipend and data pointer.
     * 2. Check if the returndata size is sufficient (>= 64 bytes) to attempt ABI decoding.
     * 3. If the string's offset is within bounds, copy the string's length and bytes from returndata.
     * 4. Truncate the string if it exceeds the specified limit.
     * 5. Allocate memory for the string and store it in the result.
     * 6. If ABI decoding fails, interpret the returndata as a null-terminated string.
     * 7. Copy the string's bytes, place a null terminator, and calculate the string's length.
     * 8. Allocate memory for the string and store it in the result.
     *
     * Notes:
     * - The function uses low-level assembly for memory-safe operations.
     * - The function ensures compliance by aborting if the full string cannot be safely decoded.
     */
    function _string(address target, bytes32 ptr, uint256 limit, uint256 gasStipend) private view returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector at the free memory pointer.
            mstore(0x00, ptr)
            
            // Perform the staticcall.
            if iszero(staticcall(gasStipend, target, 0x1c, mload(ptr), 0x00, 0x00)) {
                // If the call fails, return an empty string.
                mstore(0x40, add(result, 0x20))
                leave
            }
            
            // Get the size of the returndata.
            let rdSize := returndatasize()
            
            // If returndata is large enough to try ABI decoding.
            if iszero(lt(rdSize, 0x40)) {
                // Copy the returndata to memory.
                returndatacopy(0x00, 0x00, rdSize)
                
                // Load the offset and check if it's valid.
                let offset := mload(0x00)
                
                // Check if offset points within bounds.
                if iszero(gt(offset, 0x3f)) {
                    // Calculate the position of the string length.
                    let strLenPos := add(offset, 0x20)
                    
                    // Check if we can read the string length.
                    if iszero(gt(strLenPos, sub(rdSize, 0x20))) {
                        // Load the string length.
                        let strLen := mload(strLenPos)
                        
                        // Truncate if exceeds limit.
                        if gt(strLen, limit) {
                            strLen := limit
                        }
                        
                        // Calculate the end of the string data.
                        let strEnd := add(strLenPos, add(0x20, strLen))
                        
                        // Check if the string fits within returndata.
                        if iszero(gt(strEnd, rdSize)) {
                            // Allocate memory for the string.
                            result := mload(0x40)
                            
                            // Store the string length.
                            mstore(result, strLen)
                            
                            // Copy the string data.
                            let dest := add(result, 0x20)
                            let src := add(strLenPos, 0x20)
                            
                            // Copy in 32-byte chunks.
                            for { let i := 0 } lt(i, strLen) { i := add(i, 0x20) } {
                                mstore(add(dest, i), mload(add(src, i)))
                            }
                            
                            // Update the free memory pointer.
                            mstore(0x40, add(dest, and(add(strLen, 0x1f), not(0x1f))))
                            
                            leave
                        }
                    }
                }
            }
            
            // Fallback: interpret as null-terminated string.
            // Allocate memory for worst case.
            result := mload(0x40)
            
            // Copy returndata to result.
            returndatacopy(add(result, 0x20), 0x00, rdSize)
            
            // Find the length (look for null terminator or use full size).
            let strLen := rdSize
            
            // Truncate if exceeds limit.
            if gt(strLen, limit) {
                strLen := limit
            }
            
            // Store the length.
            mstore(result, strLen)
            
            // Update the free memory pointer.
            mstore(0x40, add(add(result, 0x20), and(add(strLen, 0x1f), not(0x1f))))
        }
    }

    /**
     * @notice A private view function that performs a low-level static call to a target address and returns a uint256 result.
     *
     * @param target The address of the contract to call.
     * @param ptr The pointer to the memory location where the call data is stored.
     * @param gasStipend The amount of gas to stipend for the call.
     *
     * @return result The uint256 result of the static call.
     *
     * Steps:
     * 1. Perform a low-level static call to the target address using the provided gas stipend.
     * 2. Ensure that the call returns at least 32 bytes of data.
     * 3. Multiply the result by the value stored at memory location 0x20.
     * 4. Return the final result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation and gas optimization.
     */
    function _uint(address target, bytes32 ptr, uint256 gasStipend) private view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector at memory position 0x00.
            mstore(0x00, ptr)
            
            // Perform the staticcall.
            if staticcall(gasStipend, target, 0x1c, mload(ptr), 0x00, 0x20) {
                // If the call is successful and returns at least 32 bytes.
                if iszero(lt(returndatasize(), 0x20)) {
                    // Load the result from memory.
                    result := mload(0x00)
                }
            }
        }
    }

    /**
     * @notice A private pure function that manipulates memory to store a function selector and length.
     * 
     * Steps:
     * 1. Use inline assembly to perform low-level memory operations.
     * 2. Store the provided uint256 value `s` at memory offset 0x04.
     * 3. Store the length (4 bytes) in the `result` variable.
     * 
     * @param s The uint256 value to be stored in memory.
     * @return result A bytes32 value representing the length stored in memory.
     */
    function _ptr(uint256 s) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the selector in the scratch space.
            mstore(0x04, s)
            // Return the length (4 bytes).
            result := 4
        }
    }

    /**
     * @notice A private pure function that manipulates memory to store a function selector and length.
     * 
     * Steps:
     * 1. Use inline assembly to perform low-level memory operations.
     * 2. Store the provided uint256 value `s` at memory offset 0x04.
     * 3. Store the length (4 bytes) in the `result` variable.
     * 
     * @param data The bytes memory data to be stored.
     * @return result A bytes32 value representing the length stored in memory.
     */
    function _ptr(bytes memory data) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Return the length of the data.
            result := mload(data)
        }
    }
}
