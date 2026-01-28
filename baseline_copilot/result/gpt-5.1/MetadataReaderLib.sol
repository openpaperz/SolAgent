// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for safely reading metadata from other contracts using low-level calls.
library MetadataReaderLib {
    /// @notice Reads the name of a target contract using a low-level call with a default byte limit and gas stipend.
    ///
    /// @param target The address of the target contract from which to read the name.
    /// @return The name of the target contract as a string.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, the function selector for `name()` (0x06fdde03), 
    ///    a default byte limit, and a default gas stipend.
    /// 2. Returns the name of the target contract as a string.
    function readName(address target) internal view returns (string memory) {
        // Default: read up to 96 bytes of string data, with a modest gas stipend.
        return _string(target, _ptr(0x06fdde03), 96, 25_000);
    }

    /// @notice Reads the name of a target contract using a low-level call with a specified byte limit.
    ///
    /// @param target The address of the target contract from which to read the name.
    /// @param limit The maximum number of bytes to read from the target contract.
    /// @return The name of the target contract as a string.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, the function selector for `name()` (0x06fdde03), 
    ///    the byte limit, and a default gas stipend.
    /// 2. Returns the name of the target contract as a string.
    function readName(address target, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), limit, 25_000);
    }

    /// @notice Reads the name of a target contract using a low-level call with a specified byte limit and gas stipend.
    ///
    /// @param target The address of the target contract from which to read the name.
    /// @param limit The maximum number of bytes to read from the target contract.
    /// @param gasStipend The amount of gas to stipend for the low-level call.
    /// @return The name of the target contract as a string.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, the function selector for `name()` (0x06fdde03), 
    ///    the byte limit, and the gas stipend.
    /// 2. Returns the name of the target contract as a string.
    function readName(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), limit, gasStipend);
    }

    /// @notice Reads the symbol of an ERC20 token from a target contract address with default limit and gas stipend.
    ///
    /// @param target The address of the target ERC20 token contract.
    /// @return The symbol of the ERC20 token as a string.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, the function selector for `symbol()` (0x95d89b41),
    ///    a default byte limit, and a default gas stipend.
    /// 2. Returns the symbol of the token as a string.
    function readSymbol(address target) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), 96, 25_000);
    }

    /// @notice Reads the symbol of an ERC20 token from a target contract address with specified byte limit.
    ///
    /// @param target The address of the target ERC20 token contract.
    /// @param limit The maximum number of bytes to read from the target contract.
    /// @return The symbol of the ERC20 token as a string.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, the function selector for `symbol()` (0x95d89b41), the byte limit, and a default gas stipend.
    /// 2. Returns the symbol of the token as a string.
    function readSymbol(address target, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), limit, 25_000);
    }

    /// @notice Reads the symbol of an ERC20 token from a target contract address with specified byte limit and gas stipend.
    ///
    /// @param target The address of the target ERC20 token contract.
    /// @param limit The maximum number of bytes to read from the target contract.
    /// @param gasStipend The amount of gas to stipend for the call.
    /// @return The symbol of the ERC20 token as a string.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, the function selector for `symbol()` (0x95d89b41), the byte limit, and the gas stipend.
    /// 2. Returns the symbol of the token as a string.
    function readSymbol(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), limit, gasStipend);
    }

    /// @notice Reads a string from a target contract using the provided data and a default byte limit and gas stipend.
    ///
    /// @param target The address of the target contract from which to read the string.
    /// @param data The data to be passed to the target contract for the string read operation.
    /// @return string memory The string read from the target contract.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, data pointer, a default byte limit, and a default gas stipend.
    /// 2. Returns the string read from the target contract.
    function readString(address target, bytes memory data) internal view returns (string memory) {
        return _string(target, _ptr(data), 96, 25_000);
    }

    /// @notice Reads a string from a target contract using the provided data and byte limit with a default gas stipend.
    ///
    /// @param target The address of the target contract from which to read the string.
    /// @param data The data to be passed to the target contract for the string read operation.
    /// @param limit The maximum length (in bytes) of the string slice to be returned.
    /// @return string memory The string read from the target contract.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, data pointer, the byte limit, and a default gas stipend.
    /// 2. Returns the string read from the target contract.
    function readString(address target, bytes memory data, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(data), limit, 25_000);
    }

    /// @notice Reads a string from a target contract using the provided data, byte limit, and gas stipend.
    ///
    /// @param target The address of the target contract from which to read the string.
    /// @param data The data to be passed to the target contract for the string read operation.
    /// @param limit The maximum length (in bytes) of the string slice to be returned.
    /// @param gasStipend The amount of gas to be provided for the read operation.
    /// @return string memory The string read from the target contract.
    ///
    /// Steps:
    /// 1. Calls the internal `_string` function with the target address, data pointer, the byte limit, and the gas stipend.
    /// 2. Returns the string read from the target contract.
    function readString(
        address target,
        bytes memory data,
        uint256 limit,
        uint256 gasStipend
    ) internal view returns (string memory) {
        return _string(target, _ptr(data), limit, gasStipend);
    }

    /// @notice Reads the decimals of an ERC20 token at the specified address with a default gas stipend.
    ///
    /// @param target The address of the ERC20 token contract.
    /// @return uint8 The number of decimals the token uses.
    ///
    /// Steps:
    /// 1. Calls the `_uint` function with the target address, the function selector for `decimals()` (0x313ce567), 
    ///    and a gas stipend to avoid griefing attacks.
    /// 2. Casts the result to `uint8` and returns it.
    function readDecimals(address target) internal view returns (uint8) {
        uint256 v = _uint(target, _ptr(0x313ce567), 25_000);
        return uint8(v);
    }

    /// @notice Reads the decimals of an ERC20 token at the specified address with the specified gas stipend.
    ///
    /// @param target The address of the ERC20 token contract.
    /// @param gasStipend The amount of gas to be provided for the read operation.
    /// @return uint8 The number of decimals the token uses.
    ///
    /// Steps:
    /// 1. Calls the `_uint` function with the target address, the function selector for `decimals()` (0x313ce567), 
    ///    and the given gas stipend to avoid griefing attacks.
    /// 2. Casts the result to `uint8` and returns it.
    function readDecimals(address target, uint256 gasStipend) internal view returns (uint8) {
        uint256 v = _uint(target, _ptr(0x313ce567), gasStipend);
        return uint8(v);
    }

    /// @notice Reads a `uint256` value from a target contract using the provided data and a default gas stipend.
    ///
    /// @param target The address of the target contract from which to read the `uint256` value.
    /// @param data The encoded data to be sent to the target contract for the read operation.
    /// @return The `uint256` value read from the target contract.
    ///
    /// Steps:
    /// 1. Calls the internal `_uint` function with the target address, the pointer to the data, and the gas stipend.
    /// 2. Returns the `uint256` value obtained from the target contract.
    function readUint(address target, bytes memory data) internal view returns (uint256) {
        return _uint(target, _ptr(data), 25_000);
    }

    /// @notice Reads a `uint256` value from a target contract using the provided data and gas stipend.
    ///
    /// @param target The address of the target contract from which to read the `uint256` value.
    /// @param data The encoded data to be sent to the target contract for the read operation.
    /// @param gasStipend The amount of gas to be provided for the read operation.
    /// @return The `uint256` value read from the target contract.
    ///
    /// Steps:
    /// 1. Calls the internal `_uint` function with the target address, the pointer to the data, and the gas stipend.
    /// 2. Returns the `uint256` value obtained from the target contract.
    function readUint(address target, bytes memory data, uint256 gasStipend) internal view returns (uint256) {
        return _uint(target, _ptr(data), gasStipend);
    }

    /// @notice A private view function that retrieves a string from a target contract using low-level assembly.
    ///
    /// @param target The address of the target contract to call.
    /// @param ptr A pointer to the data to be passed to the target contract.
    /// @param limit The maximum length of the string slice (in bytes) to be returned.
    /// @param gasStipend The amount of gas to be provided for the static call.
    /// @return result The resulting string retrieved from the target contract.
    ///
    /// Notes:
    /// - If ABI decoding as `string` fails, the returndata is interpreted as a null-terminated byte sequence.
    /// - The string is truncated to `limit` bytes if necessary.
    function _string(
        address target,
        bytes32 ptr,
        uint256 limit,
        uint256 gasStipend
    ) private view returns (string memory result) {
        assembly {
            // `ptr` is the memory pointer for call data, and the length is stored at `ptr`.
            let cdPtr := ptr
            let cdLen := mload(cdPtr)

            // Perform staticcall.
            let success := staticcall(gasStipend, target, add(cdPtr, 0x20), cdLen, 0, 0)
            let returndatasize_ := returndatasize()

            // If call failed or no data, return empty string.
            if iszero(and(success, returndatasize_)) {
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x20))
            }
            // Try ABI decode as string.
            // ABI encoded string layout: [offset (32)][length (32)][data...].
            // We require at least 64 bytes: offset + length.
            if and(success, iszero(iszero(returndatasize_))) {
                // Allocate a buffer for the returndata.
                let rptr := mload(0x40)
                returndatacopy(rptr, 0, returndatasize_)

                // Check that we can read offset and length.
                if iszero(lt(returndatasize_, 0x40)) {
                    let off := mload(rptr)
                    // offset must be >= 32 and <= returndatasize_ - 32.
                    if and(iszero(lt(off, 0x20)), lt(off, sub(returndatasize_, 0x20))) {
                        let strLen := mload(add(rptr, off))
                        let strData := add(add(rptr, off), 0x20)

                        // Ensure strData + strLen does not overflow returndata.
                        if lt(add(off, add(0x20, strLen)), add(returndatasize_, 1)) {
                            // Truncate to limit if needed.
                            if gt(strLen, limit) { strLen := limit }

                            // Allocate result string.
                            result := mload(0x40)
                            mstore(result, strLen)
                            let dest := add(result, 0x20)
                            // Copy string bytes.
                            // round up to next word.
                            let copyLen := and(add(strLen, 0x1f), not(0x1f))
                            for { let i := 0 } lt(i, copyLen) { i := add(i, 0x20) } {
                                mstore(add(dest, i), mload(add(strData, i)))
                            }
                            // Update free memory pointer.
                            mstore(0x40, add(dest, copyLen))
                            leave
                        }
                    }
                }

                // If ABI decoding fails, fall through to raw / null-terminated handling below.
                // Interpret returndata as a null-terminated byte sequence.
                let maxLen := returndatasize_
                if gt(maxLen, limit) { maxLen := limit }

                // Scan for null terminator.
                let len := 0
                for { let i := 0 } lt(i, maxLen) { i := add(i, 1) } {
                    let b
                    returndatacopy(0x00, i, 1)
                    b := byte(0, mload(0x00))
                    if iszero(b) {
                        maxLen := i
                        break
                    }
                }
                len := maxLen

                result := mload(0x40)
                mstore(result, len)
                let dest2 := add(result, 0x20)
                returndatacopy(dest2, 0, len)
                // Round to word.
                let rounded := and(add(len, 0x1f), not(0x1f))
                mstore(0x40, add(dest2, rounded))
            }
        }
    }

    /// @notice A private view function that performs a low-level static call to a target address and returns a uint256 result.
    ///
    /// @param target The address of the contract to call.
    /// @param ptr The pointer to the memory location where the call data is stored.
    /// @param gasStipend The amount of gas to stipend for the call.
    ///
    /// @return result The uint256 result of the static call.
    ///
    /// Steps:
    /// 1. Perform a low-level static call to the target address using the provided gas stipend.
    /// 2. Ensure that the call returns at least 32 bytes of data.
    /// 3. Return the decoded `uint256` value (or 0 if decoding fails).
    function _uint(address target, bytes32 ptr, uint256 gasStipend) private view returns (uint256 result) {
        assembly {
            let cdPtr := ptr
            let cdLen := mload(cdPtr)

            let success := staticcall(gasStipend, target, add(cdPtr, 0x20), cdLen, 0, 0)
            let size := returndatasize()

            // Only try to decode if call succeeded and we have at least 32 bytes.
            if and(success, iszero(lt(size, 0x20))) {
                returndatacopy(0x00, 0, 0x20)
                result := mload(0x00)
            }
        }
    }

    /// @notice A private pure function that prepares call data for a 4‑byte function selector.
    /// Stores `s` as selector at memory offset 0x00 and sets the length (4 bytes).
    ///
    /// @param s The 4-byte selector (passed as uint256) to be stored in memory.
    /// @return result A bytes32 value representing the pointer to the bytes array in memory.
    function _ptr(uint256 s) private pure returns (bytes32 result) {
        assembly {
            // Get free memory pointer.
            let ptr := mload(0x40)
            // We will store length (4) at ptr, and the selector at ptr + 0x20.
            mstore(ptr, 4)
            mstore(ptr, 4)
            mstore(add(ptr, 0x20), shl(224, s)) // left-align selector in 32 bytes
            // Bump free memory pointer by 0x40 (length + 32 bytes data).
            mstore(0x40, add(ptr, 0x40))
            result := ptr
        }
    }

    /// @notice A private pure function that prepares call data for arbitrary bytes.
    ///
    /// @param data The bytes array to be used as call data.
    /// @return result A bytes32 value representing the pointer to the bytes array in memory.
    function _ptr(bytes memory data) private pure returns (bytes32 result) {
        assembly {
            result := data
        }
    }
}