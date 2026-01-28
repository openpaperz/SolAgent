// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized ECDSA wrapper.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ECDSA.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ECDSA.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)
library ECDSA {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The signature is invalid.
    error InvalidSignature();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The order of the secp256k1 elliptic curve.
    bytes32 internal constant _N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

    /// @dev `N / 2 + 1`, used for signature malleability checks.
    bytes32 internal constant _HALF_N_PLUS_1 = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    RECOVERY OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Recovers the address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the address from.
     * @return result The recovered address from the signature.
     *
     * Steps:
     * 1. Use inline assembly to handle low-level memory operations.
     * 2. Check the length of the signature:
     *    - If the signature length is 64 bytes, extract `v` and `s` from the signature.
     *    - If the signature length is 65 bytes, extract `v`, `r`, and `s` from the signature.
     * 3. Revert with an "InvalidSignature" error if the signature length is neither 64 nor 65 bytes.
     * 4. Use the `staticcall` opcode to perform an ECDSA recovery operation on the hash and signature.
     * 5. If the recovery is successful, return the recovered address.
     * 6. Restore the zero slot and free memory pointer after the operation.
     */
    function recover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            let s := mload(add(signature, 0x40))
            let v := byte(0, mload(add(signature, 0x60)))
            
            for {} 1 {} {
                if eq(signatureLength, 64) {
                    // EIP-2098 compact signature format
                    v := add(27, shr(255, s))
                    s := and(s, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    break
                }
                if eq(signatureLength, 65) {
                    // Standard 65-byte signature
                    break
                }
                // Invalid signature length
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            // Store hash at memory position 0x00
            mstore(0x00, hash)
            // Store r at memory position 0x20
            mstore(0x20, mload(add(signature, 0x20)))
            // Store s at memory position 0x40
            mstore(0x40, s)
            // Store v at memory position 0x60
            mstore(0x60, v)
            
            // Call ecrecover precompile at address 1
            let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            
            // Check if the call was successful and result is not zero
            if iszero(and(eq(returndatasize(), 0x20), success)) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            result := mload(0x00)
            
            // Revert if result is zero
            if iszero(result) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Recovers the signer's address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer.
     *
     * Steps:
     * 1. Use inline assembly to handle low-level memory operations.
     * 2. Check the length of the signature:
     *    - If the signature length is 64 bytes, extract `v`, `r`, and `s` from the signature.
     *    - If the signature length is 65 bytes, extract `v`, `r`, and `s` from the signature.
     *    - If the signature length is neither 64 nor 65 bytes, continue the loop.
     * 3. Store the hash and signature components in memory.
     * 4. Perform a static call to the `ecrecover` precompiled contract to recover the signer's address.
     * 5. If the recovery is successful, return the signer's address.
     * 6. If the recovery fails, revert with an "InvalidSignature" error.
     * 7. Restore the zero slot and free memory pointer after the operation.
     */
    function recoverCalldata(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := signature.length
            
            for {} 1 {} {
                if eq(signatureLength, 64) {
                    // EIP-2098 compact signature format
                    let vs := calldataload(add(signature.offset, 0x20))
                    let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    let v := add(27, shr(255, vs))
                    
                    mstore(0x00, hash)
                    calldatacopy(0x20, signature.offset, 0x20) // r
                    mstore(0x40, s)
                    mstore(0x60, v)
                    break
                }
                if eq(signatureLength, 65) {
                    // Standard 65-byte signature
                    mstore(0x00, hash)
                    calldatacopy(0x20, signature.offset, 0x40) // r, s
                    mstore(0x60, byte(0, calldataload(add(signature.offset, 0x40))))
                    break
                }
                // Invalid signature length
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            // Call ecrecover precompile at address 1
            let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            
            // Check if the call was successful and result is not zero
            if iszero(and(eq(returndatasize(), 0x20), success)) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            result := mload(0x00)
            
            // Revert if result is zero
            if iszero(result) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Recovers the address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the address from.
     * @return result The recovered address from the signature.
     *
     * Steps:
     * 1. Use inline assembly to handle low-level memory operations.
     * 2. Check the length of the signature:
     *    - If the signature length is 64 bytes, extract `v` and `s` from the signature.
     *    - If the signature length is 65 bytes, extract `v`, `r`, and `s` from the signature.
     * 3. Revert with an "InvalidSignature" error if the signature length is neither 64 nor 65 bytes.
     * 4. Use the `staticcall` opcode to perform an ECDSA recovery operation on the hash and signature.
     * 5. If the recovery is successful, return the recovered address.
     * 6. Restore the zero slot and free memory pointer after the operation.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            
            // Extract s and v from vs
            let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            let v := add(27, shr(255, vs))
            
            // Store hash, r, s, v in memory
            mstore(0x00, hash)
            mstore(0x20, r)
            mstore(0x40, s)
            mstore(0x60, v)
            
            // Call ecrecover precompile at address 1
            let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            
            // Check if the call was successful and result is not zero
            if iszero(and(eq(returndatasize(), 0x20), success)) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            result := mload(0x00)
            
            // Revert if result is zero
            if iszero(result) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Recovers the address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the address from.
     * @return result The recovered address from the signature.
     *
     * Steps:
     * 1. Use inline assembly to handle low-level memory operations.
     * 2. Check the length of the signature:
     *    - If the signature length is 64 bytes, extract `v` and `s` from the signature.
     *    - If the signature length is 65 bytes, extract `v`, `r`, and `s` from the signature.
     * 3. Revert with an "InvalidSignature" error if the signature length is neither 64 nor 65 bytes.
     * 4. Use the `staticcall` opcode to perform an ECDSA recovery operation on the hash and signature.
     * 5. If the recovery is successful, return the recovered address.
     * 6. Restore the zero slot and free memory pointer after the operation.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            
            // Store hash, r, s, v in memory
            mstore(0x00, hash)
            mstore(0x20, r)
            mstore(0x40, s)
            mstore(0x60, v)
            
            // Call ecrecover precompile at address 1
            let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            
            // Check if the call was successful and result is not zero
            if iszero(and(eq(returndatasize(), 0x20), success)) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            result := mload(0x00)
            
            // Revert if result is zero
            if iszero(result) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`
                revert(0x1c, 0x04)
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature.
     *
     * @dev This function uses inline assembly to handle the signature recovery process.
     * It supports both 64-byte and 65-byte signatures (standard ECDSA signatures).
     * The function is marked as `internal` and `view`, meaning it can only be called
     * internally and does not modify the state.
     *
     * @param hash The hash of the message that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer if the recovery is successful, otherwise 0.
     *
     * Steps:
     * 1. Load the free memory pointer (`mload(0x40)`) to manage memory allocation.
     * 2. Check the length of the signature:
     *    - If the signature is 64 bytes, extract `v` and `s` from the signature.
     *    - If the signature is 65 bytes, extract `v`, `r`, and `s` from the signature.
     * 3. Store the hash, `r`, `s`, and `v` in memory for the `ecrecover` operation.
     * 4. Use `staticcall` to invoke the `ecrecover` precompiled contract (address 1).
     * 5. Check the `returndatasize` to determine if the recovery was successful:
     *    - If successful, return the recovered address.
     *    - If unsuccessful, return 0.
     * 6. Restore the free memory pointer and zero slot to clean up memory.
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            
            for {} 1 {} {
                if eq(signatureLength, 64) {
                    // EIP-2098 compact signature format
                    let vs := mload(add(signature, 0x40))
                    let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    let v := add(27, shr(255, vs))
                    
                    mstore(0x00, hash)
                    mstore(0x20, mload(add(signature, 0x20))) // r
                    mstore(0x40, s)
                    mstore(0x60, v)
                    break
                }
                if eq(signatureLength, 65) {
                    // Standard 65-byte signature
                    mstore(0x00, hash)
                    mstore(0x20, mload(add(signature, 0x20))) // r
                    mstore(0x40, mload(add(signature, 0x40))) // s
                    mstore(0x60, byte(0, mload(add(signature, 0x60)))) // v
                    break
                }
                // Invalid signature length, return 0
                result := 0
                mstore(0x60, 0)
                mstore(0x40, m)
                leave
            }
            
            // Call ecrecover precompile at address 1
            pop(staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20))
            
            // Check if the call was successful
            result := mload(0x00)
            if iszero(eq(returndatasize(), 0x20)) {
                result := 0
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer if the recovery is successful, otherwise returns 0.
     *
     * Steps:
     * 1. Load the free memory pointer into `m`.
     * 2. Check the length of the signature:
     *    - If the signature length is 64 bytes:
     *      a. Extract `v` from the signature and adjust it to the correct format.
     *      b. Extract `r` and `s` from the signature.
     *    - If the signature length is 65 bytes:
     *      a. Extract `v` from the signature.
     *      b. Copy `r` and `s` from the signature.
     *    - If the signature length is neither 64 nor 65 bytes, break out of the loop.
     * 3. Store the hash at memory location 0x00.
     * 4. Perform a static call to the `ecrecover` precompiled contract (address 1) to recover the signer's address.
     * 5. Check the return data size to determine if the recovery was successful:
     *    - If successful, store the recovered address in `result`.
     *    - If unsuccessful, store 0 in `result`.
     * 6. Restore the zero slot and free memory pointer.
     * 7. Return the result.
     */
    function tryRecoverCalldata(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := signature.length
            
            for {} 1 {} {
                if eq(signatureLength, 64) {
                    // EIP-2098 compact signature format
                    let vs := calldataload(add(signature.offset, 0x20))
                    let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    let v := add(27, shr(255, vs))
                    
                    mstore(0x00, hash)
                    calldatacopy(0x20, signature.offset, 0x20) // r
                    mstore(0x40, s)
                    mstore(0x60, v)
                    break
                }
                if eq(signatureLength, 65) {
                    // Standard 65-byte signature
                    mstore(0x00, hash)
                    calldatacopy(0x20, signature.offset, 0x40) // r, s
                    mstore(0x60, byte(0, calldataload(add(signature.offset, 0x40))))
                    break
                }
                // Invalid signature length, return 0
                result := 0
                mstore(0x60, 0)
                mstore(0x40, m)
                leave
            }
            
            // Call ecrecover precompile at address 1
            pop(staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20))
            
            // Check if the call was successful
            result := mload(0x00)
            if iszero(eq(returndatasize(), 0x20)) {
                result := 0
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature.
     *
     * @dev This function uses inline assembly to handle the signature recovery process.
     * It supports both 64-byte and 65-byte signatures (standard ECDSA signatures).
     * The function is marked as `internal` and `view`, meaning it can only be called
     * internally and does not modify the state.
     *
     * @param hash The hash of the message that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer if the recovery is successful, otherwise 0.
     *
     * Steps:
     * 1. Load the free memory pointer (`mload(0x40)`) to manage memory allocation.
     * 2. Check the length of the signature:
     *    - If the signature is 64 bytes, extract `v` and `s` from the signature.
     *    - If the signature is 65 bytes, extract `v`, `r`, and `s` from the signature.
     * 3. Store the hash, `r`, `s`, and `v` in memory for the `ecrecover` operation.
     * 4. Use `staticcall` to invoke the `ecrecover` precompiled contract (address 1).
     * 5. Check the `returndatasize` to determine if the recovery was successful:
     *    - If successful, return the recovered address.
     *    - If unsuccessful, return 0.
     * 6. Restore the free memory pointer and zero slot to clean up memory.
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            
            // Extract s and v from vs
            let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            let v := add(27, shr(255, vs))
            
            // Store hash, r, s, v in memory
            mstore(0x00, hash)
            mstore(0x20, r)
            mstore(0x40, s)
            mstore(0x60, v)
            
            // Call ecrecover precompile at address 1
            pop(staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20))
            
            // Check if the call was successful
            result := mload(0x00)
            if iszero(eq(returndatasize(), 0x20)) {
                result := 0
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature.
     *
     * @dev This function uses inline assembly to handle the signature recovery process.
     * It supports both 64-byte and 65-byte signatures (standard ECDSA signatures).
     * The function is marked as `internal` and `view`, meaning it can only be called
     * internally and does not modify the state.
     *
     * @param hash The hash of the message that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer if the recovery is successful, otherwise 0.
     *
     * Steps:
     * 1. Load the free memory pointer (`mload(0x40)`) to manage memory allocation.
     * 2. Check the length of the signature:
     *    - If the signature is 64 bytes, extract `v` and `s` from the signature.
     *    - If the signature is 65 bytes, extract `v`, `r`, and `s` from the signature.
     * 3. Store the hash, `r`, `s`, and `v` in memory for the `ecrecover` operation.
     * 4. Use `staticcall` to invoke the `ecrecover` precompiled contract (address 1).
     * 5. Check the `returndatasize` to determine if the recovery was successful:
     *    - If successful, return the recovered address.
     *    - If unsuccessful, return 0.
     * 6. Restore the free memory pointer and zero slot to clean up memory.
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            
            // Store hash, r, s, v in memory
            mstore(0x00, hash)
            mstore(0x20, r)
            mstore(0x40, s)
            mstore(0x60, v)
            
            // Call ecrecover precompile at address 1
            pop(staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20))
            
            // Check if the call was successful
            result := mload(0x00)
            if iszero(eq(returndatasize(), 0x20)) {
                result := 0
            }
            
            // Restore zero slot and free memory pointer
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HASHING OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Converts a bytes32 hash into an Ethereum signed message hash.
     * 
     * @dev This function prepends the Ethereum signed message prefix to the hash and then computes the keccak256 hash of the result.
     * The prefix is "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32", which is 28 bytes long.
     * The function uses inline assembly to efficiently perform the operation.
     * 
     * @param hash The original bytes32 hash to be converted.
     * @return result The resulting Ethereum signed message hash.
     * 
     * Steps:
     * 1. Store the original hash in memory at position 0x20.
     * 2. Store the Ethereum signed message prefix in memory at position 0x00.
     * 3. Compute the keccak256 hash of the combined prefix and hash, starting from byte 0x04 and spanning 0x3c (60) bytes.
     * 4. Return the computed hash as the result.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the hash at position 0x20
            mstore(0x20, hash)
            // Store the prefix "\x19Ethereum Signed Message:\n32" at position 0x00
            // The prefix is stored as: 0x00000000 19 "Ethereum Signed Message:\n32"
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            // Compute keccak256 hash starting from byte 0x04 (skip first 4 zero bytes)
            // spanning 0x3c (60) bytes: 28 bytes of prefix + 32 bytes of hash
            result := keccak256(0x04, 0x3c)
        }
    }

    /**
     * @notice Converts a bytes32 hash into an Ethereum signed message hash.
     * 
     * @dev This function prepends the Ethereum signed message prefix to the hash and then computes the keccak256 hash of the result.
     * The prefix is "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32", which is 28 bytes long.
     * The function uses inline assembly to efficiently perform the operation.
     * 
     * @param hash The original bytes32 hash to be converted.
     * @return result The resulting Ethereum signed message hash.
     * 
     * Steps:
     * 1. Store the original hash in memory at position 0x20.
     * 2. Store the Ethereum signed message prefix in memory at position 0x00.
     * 3. Compute the keccak256 hash of the combined prefix and hash, starting from byte 0x04 and spanning 0x3c (60) bytes.
     * 4. Return the computed hash as the result.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let sLength := mload(s)
            
            // Convert length to ASCII decimal string
            let ptr := add(m, 0x20)
            let end := ptr
            
            // Write length as ASCII string backwards
            for { let temp := sLength } 1 {} {
                end := sub(end, 1)
                mstore8(end, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            
            // Calculate the length of the ASCII length string
            let lengthOfLength := sub(add(m, 0x20), end)
            
            // Store prefix "\x19Ethereum Signed Message:\n"
            mstore(m, "\x00\x00\x00\x00\x00\x00\x19Ethereum Signed Message:\n")
            
            // Copy the length string
            let prefixLength := add(26, lengthOfLength)
            let prefixStart := sub(add(m, 26), lengthOfLength)
            
            // Move the length digits to the correct position
            for { let i := 0 } lt(i, lengthOfLength) { i := add(i, 1) } {
                mstore8(add(add(m, 26), i), mload8(add(end, i)))
            }
            
            // Copy the message
            let dataStart := add(m, prefixLength)
            for { let i := 0 } lt(i, sLength) { i := add(i, 32) } {
                mstore(add(dataStart, i), mload(add(add(s, 0x20), i)))
            }
            
            // Compute keccak256 hash
            // Skip first 6 zero bytes, hash the rest
            result := keccak256(add(m, 6), add(sub(prefixLength, 6), sLength))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   CANONICAL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Computes the canonical hash of a given signature.
     *
     * @dev This function processes the signature to generate a canonical hash. It handles both 64-byte and 65-byte signatures.
     *      For 64-byte signatures, it adjusts the `v` value and ensures `s` is within the valid range.
     *      For 65-byte signatures, it uses the provided `v` and `s` values directly.
     *      If the signature length is neither 64 nor 65 bytes, it returns a uniquely corrupted hash.
     *
     * @param signature The signature bytes to be hashed.
     * @return result The canonical hash of the signature.
     *
     * Steps:
     * 1. Load the length of the signature.
     * 2. For 64-byte signatures:
     *    a. Adjust the `v` value by adding 27 to the shifted `s` value.
     *    b. Ensure `s` is within the valid range by shifting and masking.
     * 3. For 65-byte signatures:
     *    a. Use the provided `v` and `s` values directly.
     * 4. If `s` is not less than `_HALF_N_PLUS_1`, adjust `v` and `s` to ensure canonical form.
     * 5. Compute the Keccak-256 hash of the processed signature.
     * 6. If the signature length is invalid, return a uniquely corrupted hash.
     */
    function canonicalHash(bytes memory signature) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let signatureLength := mload(signature)
            let r := mload(add(signature, 0x20))
            let s := mload(add(signature, 0x40))
            let v := byte(0, mload(add(signature, 0x60)))
            
            for {} 1 {} {
                if eq(signatureLength, 64) {
                    // EIP-2098 compact signature format
                    v := add(27, shr(255, s))
                    s := and(s, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    break
                }
                if eq(signatureLength, 65) {
                    // Standard 65-byte signature
                    break
                }
                // Invalid signature length - return uniquely corrupted hash
                result := xor(keccak256(add(signature, 0x20), signatureLength), 0x8baa579f)
                leave
            }
            
            // Ensure canonical form: s should be in the lower half of the curve order
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                // Flip s to the lower half: s = N - s
                s := sub(_N, s)
                // Flip v: 27 <-> 28
                v := xor(v, 1)
            }
            
            // Store r, s, v and compute hash
            mstore(0x00, r)
            mstore(0x20, s)
            mstore(0x40, v)
            result := keccak256(0x00, 0x60)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature calldata.
     *
     * @dev This function processes the signature calldata to generate a canonical hash.
     * It handles both 64-byte and 65-byte signatures, adjusting the `v` and `s` values
     * to ensure canonical representation. If the signature length is invalid, it returns
     * a uniquely corrupted hash to indicate an error.
     *
     * @param signature The signature calldata to be hashed.
     * @return result The canonical hash of the signature calldata.
     *
     * Steps:
     * 1. Load the `r` value from the signature calldata.
     * 2. Load the `s` and `v` values from the signature calldata.
     * 3. If the signature length is 64 bytes:
     *    - Adjust `v` to be either 27 or 28 based on the highest bit of `s`.
     *    - Ensure `s` is within the valid range by masking the highest bit.
     * 4. If `s` is not less than `_HALF_N_PLUS_1`, adjust `v` and `s` to ensure canonical form.
     * 5. Compute the Keccak-256 hash of the combined `r`, `s`, and `v` values.
     * 6. If the signature length is neither 64 nor 65 bytes, return a uniquely corrupted hash
     *    by XORing the hash of the signature with a specific error code.
     */
    function canonicalHashCalldata(bytes calldata signature) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let signatureLength := signature.length
            let r := calldataload(signature.offset)
            let s := calldataload(add(signature.offset, 0x20))
            let v := byte(0, calldataload(add(signature.offset, 0x40)))
            
            for {} 1 {} {
                if eq(signatureLength, 64) {
                    // EIP-2098 compact signature format
                    v := add(27, shr(255, s))
                    s := and(s, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    break
                }
                if eq(signatureLength, 65) {
                    // Standard 65-byte signature
                    break
                }
                // Invalid signature length - return uniquely corrupted hash
                calldatacopy(0x00, signature.offset, signatureLength)
                result := xor(keccak256(0x00, signatureLength), 0x8baa579f)
                leave
            }
            
            // Ensure canonical form: s should be in the lower half of the curve order
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                // Flip s to the lower half: s = N - s
                s := sub(_N, s)
                // Flip v: 27 <-> 28
                v := xor(v, 1)
            }
            
            // Store r, s, v and compute hash
            mstore(0x00, r)
            mstore(0x20, s)
            mstore(0x40, v)
            result := keccak256(0x00, 0x60)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature.
     *
     * @dev This function processes the signature to generate a canonical hash. It handles both 64-byte and 65-byte signatures.
     *      For 64-byte signatures, it adjusts the `v` value and ensures `s` is within the valid range.
     *      For 65-byte signatures, it uses the provided `v` and `s` values directly.
     *      If the signature length is neither 64 nor 65 bytes, it returns a uniquely corrupted hash.
     *
     * @param signature The signature bytes to be hashed.
     * @return result The canonical hash of the signature.
     *
     * Steps:
     * 1. Load the length of the signature.
     * 2. For 64-byte signatures:
     *    a. Adjust the `v` value by adding 27 to the shifted `s` value.
     *    b. Ensure `s` is within the valid range by shifting and masking.
     * 3. For 65-byte signatures:
     *    a. Use the provided `v` and `s` values directly.
     * 4. If `s` is not less than `_HALF_N_PLUS_1`, adjust `v` and `s` to ensure canonical form.
     * 5. Compute the Keccak-256 hash of the processed signature.
     * 6. If the signature length is invalid, return a uniquely corrupted hash.
     */
    function canonicalHash(bytes32 r, bytes32 vs) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Extract s and v from vs (EIP-2098 format)
            let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            let v := add(27, shr(255, vs))
            
            // Ensure canonical form: s should be in the lower half of the curve order
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                // Flip s to the lower half: s = N - s
                s := sub(_N, s)
                // Flip v: 27 <-> 28
                v := xor(v, 1)
            }
            
            // Store r, s, v and compute hash
            mstore(0x00, r)
            mstore(0x20, s)
            mstore(0x40, v)
            result := keccak256(0x00, 0x60)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature.
     *
     * @dev This function processes the signature to generate a canonical hash. It handles both 64-byte and 65-byte signatures.
     *      For 64-byte signatures, it adjusts the `v` value and ensures `s` is within the valid range.
     *      For 65-byte signatures, it uses the provided `v` and `s` values directly.
     *      If the signature length is neither 64 nor 65 bytes, it returns a uniquely corrupted hash.
     *
     * @param signature The signature bytes to be hashed.
     * @return result The canonical hash of the signature.
     *
     * Steps:
     * 1. Load the length of the signature.
     * 2. For 64-byte signatures:
     *    a. Adjust the `v` value by adding 27 to the shifted `s` value.
     *    b. Ensure `s` is within the valid range by shifting and masking.
     * 3. For 65-byte signatures:
     *    a. Use the provided `v` and `s` values directly.
     * 4. If `s` is not less than `_HALF_N_PLUS_1`, adjust `v` and `s` to ensure canonical form.
     * 5. Compute the Keccak-256 hash of the processed signature.
     * 6. If the signature length is invalid, return a uniquely corrupted hash.
     */
    function canonicalHash(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Ensure canonical form: s should be in the lower half of the curve order
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                // Flip s to the lower half: s = N - s
                s := sub(_N, s)
                // Flip v: 27 <-> 28
                v := xor(v, 1)
            }
            
            // Store r, s, v and compute hash
            mstore(0x00, r)
            mstore(0x20, s)
            mstore(0x40, v)
            result := keccak256(0x00, 0x60)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EMPTY SIGNATURE                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns an empty signature in the form of a `bytes calldata` object.
     *
     * This function is marked as `internal` and `pure`, meaning it does not modify the state and can only be called internally.
     * It uses inline assembly to set the length of the signature to 0, effectively returning an empty signature.
     *
     * @return signature An empty `bytes calldata` object with a length of 0.
     */
    function emptySignature() internal pure returns (bytes calldata signature) {
        /// @solidity memory-safe-assembly
        assembly {
            signature.length := 0
        }
    }
}
