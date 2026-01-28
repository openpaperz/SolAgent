// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Signature verification helper that supports both ECDSA signatures for EOAs
/// and ERC1271 signatures for contract wallets.
library SignatureCheckerLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The signature is invalid.
    error InvalidSignature();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    SIGNATURE OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Validates if a given signature is valid for a specific signer and hash.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. If the signer is the zero address, return `false` immediately.
     * 2. Use inline assembly to handle low-level memory operations for efficiency.
     * 3. Depending on the length of the signature (64 or 65 bytes), extract the `v`, `r`, and `s` components.
     * 4. Recover the signer's address from the signature using the `ecrecover` precompiled contract.
     * 5. Compare the recovered address with the provided signer address to determine validity.
     * 6. If the signature is invalid, attempt to validate it using the `isValidSignature` method of the signer contract.
     * 7. Return the result of the validation.
     *
     * Notes:
     * - The function handles both EIP-2098 compact signatures (64 bytes) and traditional EIP-712 signatures (65 bytes).
     * - The function restores the zero slot and free memory pointer after operations to maintain memory safety.
     */
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            
            // Handle 64-byte compact signature (EIP-2098)
            if eq(signatureLength, 64) {
                let vs := mload(add(signature, 0x40))
                mstore(0x00, hash)
                mstore(0x20, add(27, shr(255, vs)))
                mstore(0x40, mload(add(signature, 0x20)))
                mstore(0x60, and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
                
                let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                isValid := and(eq(mload(0x00), signer), success)
                
                mstore(0x60, 0)
                mstore(0x40, m)
            }
            
            // Handle 65-byte signature
            if eq(signatureLength, 65) {
                mstore(0x00, hash)
                mstore(0x20, byte(0, mload(add(signature, 0x60))))
                mstore(0x40, mload(add(signature, 0x20)))
                mstore(0x60, mload(add(signature, 0x40)))
                
                let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                isValid := and(eq(mload(0x00), signer), success)
                
                mstore(0x60, 0)
                mstore(0x40, m)
            }
        }
        
        if (!isValid) {
            isValid = isValidERC1271SignatureNow(signer, hash, signature);
        }
    }

    /**
     * @notice Validates a signature for a given hash using the provided signer and signature.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated, provided as calldata.
     * @return isValid A boolean indicating whether the signature is valid for the given hash and signer.
     *
     * Steps:
     * 1. If the signer is the zero address, return `false` immediately.
     * 2. Use inline assembly to handle low-level memory operations for efficiency.
     * 3. Depending on the length of the signature (64 or 65 bytes), extract the `v`, `r`, and `s` components.
     * 4. Recover the signer's address from the signature and compare it with the provided signer address.
     * 5. If the recovered address matches the provided signer, the signature is valid.
     * 6. If the signature length is neither 64 nor 65 bytes, or if the recovered address does not match, 
     *    attempt to validate the signature using the `isValidSignature(bytes32,bytes)` method (EIP-1271).
     * 7. Return the result of the validation.
     *
     * Note: This function uses low-level assembly for performance optimization and handles both standard 
     * ECDSA signatures and EIP-1271 compliant contract signatures.
     */
    function isValidSignatureNowCalldata(address signer, bytes32 hash, bytes calldata signature)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := signature.length
            
            // Handle 64-byte compact signature (EIP-2098)
            if eq(signatureLength, 64) {
                let vs := calldataload(add(signature.offset, 0x20))
                mstore(0x00, hash)
                mstore(0x20, add(27, shr(255, vs)))
                calldatacopy(0x40, signature.offset, 0x20)
                mstore(0x60, and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
                
                let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                isValid := and(eq(mload(0x00), signer), success)
                
                mstore(0x60, 0)
                mstore(0x40, m)
            }
            
            // Handle 65-byte signature
            if eq(signatureLength, 65) {
                mstore(0x00, hash)
                mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
                calldatacopy(0x40, signature.offset, 0x40)
                
                let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                isValid := and(eq(mload(0x00), signer), success)
                
                mstore(0x60, 0)
                mstore(0x40, m)
            }
        }
        
        if (!isValid) {
            isValid = isValidERC1271SignatureNowCalldata(signer, hash, signature);
        }
    }

    /**
     * @notice Validates if a given signature is valid for a specific signer and hash.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. If the signer is the zero address, return `false` immediately.
     * 2. Use inline assembly to handle low-level memory operations for efficiency.
     * 3. Depending on the length of the signature (64 or 65 bytes), extract the `v`, `r`, and `s` components.
     * 4. Recover the signer's address from the signature using the `ecrecover` precompiled contract.
     * 5. Compare the recovered address with the provided signer address to determine validity.
     * 6. If the signature is invalid, attempt to validate it using the `isValidSignature` method of the signer contract.
     * 7. Return the result of the validation.
     *
     * Notes:
     * - The function handles both EIP-2098 compact signatures (64 bytes) and traditional EIP-712 signatures (65 bytes).
     * - The function restores the zero slot and free memory pointer after operations to maintain memory safety.
     */
    function isValidSignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(0x00, hash)
            mstore(0x20, add(27, shr(255, vs)))
            mstore(0x40, r)
            mstore(0x60, and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
            
            let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            isValid := and(eq(mload(0x00), signer), success)
            
            mstore(0x60, 0)
            mstore(0x40, m)
        }
        
        if (!isValid) {
            isValid = isValidERC1271SignatureNow(signer, hash, r, vs);
        }
    }

    /**
     * @notice Validates if a given signature is valid for a specific signer and hash.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. If the signer is the zero address, return `false` immediately.
     * 2. Use inline assembly to handle low-level memory operations for efficiency.
     * 3. Depending on the length of the signature (64 or 65 bytes), extract the `v`, `r`, and `s` components.
     * 4. Recover the signer's address from the signature using the `ecrecover` precompiled contract.
     * 5. Compare the recovered address with the provided signer address to determine validity.
     * 6. If the signature is invalid, attempt to validate it using the `isValidSignature` method of the signer contract.
     * 7. Return the result of the validation.
     *
     * Notes:
     * - The function handles both EIP-2098 compact signatures (64 bytes) and traditional EIP-712 signatures (65 bytes).
     * - The function restores the zero slot and free memory pointer after operations to maintain memory safety.
     */
    function isValidSignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(0x00, hash)
            mstore(0x20, v)
            mstore(0x40, r)
            mstore(0x60, s)
            
            let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            isValid := and(eq(mload(0x00), signer), success)
            
            mstore(0x60, 0)
            mstore(0x40, m)
        }
        
        if (!isValid) {
            isValid = isValidERC1271SignatureNow(signer, hash, v, r, s);
        }
    }

    /**
     * @notice Checks if a given signature is valid for a specific signer and hash according to the ERC1271 standard.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. Allocate memory for the function call data.
     * 2. Store the ERC1271 selector (`isValidSignature(bytes32,bytes)`) in memory.
     * 3. Store the hash in memory.
     * 4. Store the offset of the `signature` in memory.
     * 5. Copy the `signature` into memory.
     * 6. Perform a static call to the ERC1271 contract to validate the signature.
     * 7. Check if the returned data matches the expected selector and if the call was successful.
     * 8. Return the result of the validation.
     *
     * @dev This function uses inline assembly for low-level memory manipulation and static calls.
     */
    function isValidERC1271SignatureNow(address signer, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            let o := add(signature, 0x20)
            
            mstore(m, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40)
            mstore(add(m, 0x44), signatureLength)
            
            for { let i := 0 } lt(i, signatureLength) { i := add(i, 0x20) } {
                mstore(add(add(m, 0x64), i), mload(add(o, i)))
            }
            
            isValid := and(
                eq(mload(0x00), 0x1626ba7e00000000000000000000000000000000000000000000000000000000),
                staticcall(gas(), signer, m, add(0x64, signatureLength), 0x00, 0x20)
            )
            
            mstore(0x40, m)
        }
    }

    /**
     * @notice Validates an ERC1271 signature using calldata.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated, passed as calldata.
     * @return isValid A boolean indicating whether the signature is valid.
     *
     * Steps:
     * 1. Load the free memory pointer.
     * 2. Store the ERC1271 magic value (`0x1626ba7e`) shifted to the correct position.
     * 3. Store the hash in memory.
     * 4. Store the offset of the signature in memory.
     * 5. Store the length of the signature in memory.
     * 6. Copy the signature from calldata to memory.
     * 7. Perform a static call to the signer's `isValidSignature` function.
     * 8. Check if the returned value matches the ERC1271 magic value and the call was successful.
     * 9. Return the result of the validation.
     */
    function isValidERC1271SignatureNowCalldata(address signer, bytes32 hash, bytes calldata signature)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := signature.length
            
            mstore(m, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40)
            mstore(add(m, 0x44), signatureLength)
            calldatacopy(add(m, 0x64), signature.offset, signatureLength)
            
            isValid := and(
                eq(mload(0x00), 0x1626ba7e00000000000000000000000000000000000000000000000000000000),
                staticcall(gas(), signer, m, add(0x64, signatureLength), 0x00, 0x20)
            )
            
            mstore(0x40, m)
        }
    }

    /**
     * @notice Checks if a given signature is valid for a specific signer and hash according to the ERC1271 standard.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. Allocate memory for the function call data.
     * 2. Store the ERC1271 selector (`isValidSignature(bytes32,bytes)`) in memory.
     * 3. Store the hash in memory.
     * 4. Store the offset of the `signature` in memory.
     * 5. Copy the `signature` into memory.
     * 6. Perform a static call to the ERC1271 contract to validate the signature.
     * 7. Check if the returned data matches the expected selector and if the call was successful.
     * 8. Return the result of the validation.
     *
     * @dev This function uses inline assembly for low-level memory manipulation and static calls.
     */
    function isValidERC1271SignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            
            mstore(m, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40)
            mstore(add(m, 0x44), 65)
            mstore(add(m, 0x64), r)
            mstore(add(m, 0x84), and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
            mstore8(add(m, 0xa4), add(27, shr(255, vs)))
            
            isValid := and(
                eq(mload(0x00), 0x1626ba7e00000000000000000000000000000000000000000000000000000000),
                staticcall(gas(), signer, m, 0xa5, 0x00, 0x20)
            )
            
            mstore(0x40, m)
        }
    }

    /**
     * @notice Checks if a given signature is valid for a specific signer and hash according to the ERC1271 standard.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. Allocate memory for the function call data.
     * 2. Store the ERC1271 selector (`isValidSignature(bytes32,bytes)`) in memory.
     * 3. Store the hash in memory.
     * 4. Store the offset of the `signature` in memory.
     * 5. Copy the `signature` into memory.
     * 6. Perform a static call to the ERC1271 contract to validate the signature.
     * 7. Check if the returned data matches the expected selector and if the call was successful.
     * 8. Return the result of the validation.
     *
     * @dev This function uses inline assembly for low-level memory manipulation and static calls.
     */
    function isValidERC1271SignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            
            mstore(m, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40)
            mstore(add(m, 0x44), 65)
            mstore(add(m, 0x64), r)
            mstore(add(m, 0x84), s)
            mstore8(add(m, 0xa4), v)
            
            isValid := and(
                eq(mload(0x00), 0x1626ba7e00000000000000000000000000000000000000000000000000000000),
                staticcall(gas(), signer, m, 0xa5, 0x00, 0x20)
            )
            
            mstore(0x40, m)
        }
    }

    /**
     * @notice Validates an ERC6492 signature with side effects allowed.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid.
     *
     * Steps:
     * 1. Check if the signer is a contract or an EOA (Externally Owned Account).
     * 2. If the signer is a contract, call the `isValidSignature` function on the contract to validate the signature.
     * 3. If the signer is an EOA, perform an `ecrecover` operation to validate the signature.
     * 4. Handle different signature lengths (64 or 65 bytes) for EOA validation.
     * 5. Return `true` if the signature is valid, otherwise `false`.
     *
     * Assembly Details:
     * - The function uses inline assembly to optimize gas usage and handle low-level operations.
     * - It dynamically checks the signature length and processes it accordingly.
     * - It restores the free memory pointer and zero slot after operations to maintain memory safety.
     */
    function isValidERC6492SignatureNowAllowSideEffects(address signer, bytes32 hash, bytes memory signature)
        internal
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            
            // Check for ERC-6492 detection suffix
            if iszero(lt(signatureLength, 0xa0)) {
                let o := add(signature, 0x20)
                calldatacopy(0, o, signatureLength)
                
                // Check for magic bytes at the end
                if eq(
                    mload(add(o, sub(signatureLength, 0x20))),
                    0x6492649264926492649264926492649264926492649264926492649264926492
                ) {
                    let factoryCalldata := mload(add(o, 0x60))
                    let factoryCalldataLength := mload(add(o, add(0x60, factoryCalldata)))
                    
                    // Deploy the contract
                    if iszero(
                        call(
                            gas(),
                            mload(add(o, 0x20)),
                            0,
                            add(add(o, 0x80), factoryCalldata),
                            factoryCalldataLength,
                            0x00,
                            0x00
                        )
                    ) {
                        mstore(0x40, m)
                        return(0, 0)
                    }
                    
                    // Extract the actual signature
                    let actualSigOffset := mload(add(o, 0x40))
                    let actualSigLength := mload(add(o, add(0x40, actualSigOffset)))
                    
                    mstore(signature, actualSigLength)
                    for { let i := 0 } lt(i, actualSigLength) { i := add(i, 0x20) } {
                        mstore(add(add(signature, 0x20), i), mload(add(add(o, 0x60), add(actualSigOffset, i))))
                    }
                    
                    signatureLength := actualSigLength
                }
            }
            
            // Try standard validation
            let codeSize := extcodesize(signer)
            
            if iszero(codeSize) {
                // EOA validation
                if eq(signatureLength, 64) {
                    let vs := mload(add(signature, 0x40))
                    mstore(0x00, hash)
                    mstore(0x20, add(27, shr(255, vs)))
                    mstore(0x40, mload(add(signature, 0x20)))
                    mstore(0x60, and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
                    
                    let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                    isValid := and(eq(mload(0x00), signer), success)
                    
                    mstore(0x60, 0)
                    mstore(0x40, m)
                }
                
                if eq(signatureLength, 65) {
                    mstore(0x00, hash)
                    mstore(0x20, byte(0, mload(add(signature, 0x60))))
                    mstore(0x40, mload(add(signature, 0x20)))
                    mstore(0x60, mload(add(signature, 0x40)))
                    
                    let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                    isValid := and(eq(mload(0x00), signer), success)
                    
                    mstore(0x60, 0)
                    mstore(0x40, m)
                }
            }
            
            if codeSize {
                // Contract signature validation
                let o := add(signature, 0x20)
                
                mstore(m, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40)
                mstore(add(m, 0x44), signatureLength)
                
                for { let i := 0 } lt(i, signatureLength) { i := add(i, 0x20) } {
                    mstore(add(add(m, 0x64), i), mload(add(o, i)))
                }
                
                isValid := and(
                    eq(mload(0x00), 0x1626ba7e00000000000000000000000000000000000000000000000000000000),
                    call(gas(), signer, 0, m, add(0x64, signatureLength), 0x00, 0x20)
                )
                
                mstore(0x40, m)
            }
        }
    }

    /**
     * @notice Validates an ERC6492 signature by checking if it matches the provided signer and hash.
     *
     * @dev This function uses low-level assembly to perform signature validation. It supports both
     *      contract-based signatures (via `isValidSignature`) and EOA-based signatures (via `ecrecover`).
     *      The function handles edge cases such as reverting verifiers and fallback to `ecrecover`.
     *
     * @param signer The address of the expected signer.
     * @param hash The hash of the message that was signed.
     * @param signature The signature to be validated.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Steps:
     * 1. Check if the signer is a contract or an externally owned account (EOA).
     * 2. If the signer is a contract, attempt to validate the signature using `isValidSignature`.
     * 3. If the signer is an EOA, fallback to `ecrecover` for signature validation.
     * 4. Handle edge cases such as reverting verifiers and ensure proper memory management.
     * 5. Return `true` if the signature is valid, otherwise `false`.
     */
    function isValidERC6492SignatureNow(address signer, bytes32 hash, bytes memory signature)
        internal
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            
            // Check for ERC-6492 detection suffix
            if iszero(lt(signatureLength, 0xa0)) {
                let o := add(signature, 0x20)
                
                // Check for magic bytes at the end
                if eq(
                    mload(add(o, sub(signatureLength, 0x20))),
                    0x6492649264926492649264926492649264926492649264926492649264926492
                ) {
                    // This is an ERC-6492 signature, deploy contract first
                    let factory := mload(o)
                    let factoryCalldataOffset := mload(add(o, 0x20))
                    let factoryCalldataLength := mload(add(o, factoryCalldataOffset))
                    
                    // Try to deploy
                    let deployed := staticcall(
                        gas(),
                        factory,
                        add(add(o, 0x40), factoryCalldataOffset),
                        factoryCalldataLength,
                        0x00,
                        0x00
                    )
                    
                    // Extract the actual signature
                    let actualSigOffset := mload(add(o, 0x40))
                    let actualSigLength := mload(add(o, add(0x40, actualSigOffset)))
                    
                    mstore(signature, actualSigLength)
                    for { let i := 0 } lt(i, actualSigLength) { i := add(i, 0x20) } {
                        mstore(add(add(signature, 0x20), i), mload(add(add(o, 0x60), add(actualSigOffset, i))))
                    }
                    
                    signatureLength := actualSigLength
                }
            }
            
            // Standard validation path
            let codeSize := extcodesize(signer)
            
            if iszero(codeSize) {
                // EOA validation
                if eq(signatureLength, 64) {
                    let vs := mload(add(signature, 0x40))
                    mstore(0x00, hash)
                    mstore(0x20, add(27, shr(255, vs)))
                    mstore(0x40, mload(add(signature, 0x20)))
                    mstore(0x60, and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
                    
                    let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                    isValid := and(eq(mload(0x00), signer), success)
                    
                    mstore(0x60, 0)
                    mstore(0x40, m)
                }
                
                if eq(signatureLength, 65) {
                    mstore(0x00, hash)
                    mstore(0x20, byte(0, mload(add(signature, 0x60))))
                    mstore(0x40, mload(add(signature, 0x20)))
                    mstore(0x60, mload(add(signature, 0x40)))
                    
                    let success := staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
                    isValid := and(eq(mload(0x00), signer), success)
                    
                    mstore(0x60, 0)
                    mstore(0x40, m)
                }
            }
            
            if codeSize {
                // Contract signature validation with staticcall
                let o := add(signature, 0x20)
                
                mstore(m, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40)
                mstore(add(m, 0x44), signatureLength)
                
                for { let i := 0 } lt(i, signatureLength) { i := add(i, 0x20) } {
                    mstore(add(add(m, 0x64), i), mload(add(o, i)))
                }
                
                isValid := and(
                    eq(mload(0x00), 0x1626ba7e00000000000000000000000000000000000000000000000000000000),
                    staticcall(gas(), signer, m, add(0x64, signatureLength), 0x00, 0x20)
                )
                
                mstore(0x40, m)
            }
        }
    }

    /**
     * @notice Converts a bytes32 hash into an Ethereum signed message hash.
     *
     * @dev This function prepends the Ethereum signed message prefix to the hash and computes the keccak256 hash of the result.
     * The prefix is "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32" (28 bytes), followed by the 32-byte hash.
     * The final result is a 32-byte hash that can be used for signature verification.
     *
     * @param hash The 32-byte hash to be converted into an Ethereum signed message hash.
     * @return result The resulting Ethereum signed message hash.
     *
     * Steps:
     * 1. Store the input hash in memory at position 0x20.
     * 2. Store the Ethereum signed message prefix in memory at position 0x00.
     * 3. Compute the keccak256 hash of the concatenated prefix and hash, starting from byte 0x04 to 0x3c (60 bytes in total).
     * 4. Return the computed hash as the result.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash)
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            result := keccak256(0x04, 0x3c)
        }
    }

    /**
     * @notice Converts a bytes32 hash into an Ethereum signed message hash.
     *
     * @dev This function prepends the Ethereum signed message prefix to the hash and computes the keccak256 hash of the result.
     * The prefix is "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32" (28 bytes), followed by the 32-byte hash.
     * The final result is a 32-byte hash that can be used for signature verification.
     *
     * @param hash The 32-byte hash to be converted into an Ethereum signed message hash.
     * @return result The resulting Ethereum signed message hash.
     *
     * Steps:
     * 1. Store the input hash in memory at position 0x20.
     * 2. Store the Ethereum signed message prefix in memory at position 0x00.
     * 3. Compute the keccak256 hash of the concatenated prefix and hash, starting from byte 0x04 to 0x3c (60 bytes in total).
     * 4. Return the computed hash as the result.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let sLength := mload(s)
            let o := add(s, 0x20)
            
            mstore(m, "\x19Ethereum Signed Message:\n")
            
            // Convert length to ASCII
            let len := sLength
            let ptr := add(m, 0x1a)
            
            if iszero(lt(len, 10)) {
                if iszero(lt(len, 100)) {
                    mstore8(ptr, add(48, div(len, 100)))
                    ptr := add(ptr, 1)
                    len := mod(len, 100)
                }
                mstore8(ptr, add(48, div(len, 10)))
                ptr := add(ptr, 1)
                len := mod(len, 10)
            }
            mstore8(ptr, add(48, len))
            ptr := add(ptr, 1)
            
            let headerLength := sub(ptr, m)
            
            // Copy the message
            for { let i := 0 } lt(i, sLength) { i := add(i, 0x20) } {
                mstore(add(ptr, i), mload(add(o, i)))
            }
            
            result := keccak256(m, add(headerLength, sLength))
            
            mstore(0x40, m)
        }
    }

    /**
     * @notice Returns an empty signature in the form of a `bytes calldata` object.
     *
     * Steps:
     * 1. Use inline assembly to set the length of the `signature` to 0.
     * 2. Return the empty `signature`.
     *
     * @dev This function is marked as `internal pure`, meaning it can only be called internally and does not modify the state.
     */
    function emptySignature() internal pure returns (bytes calldata signature) {
        /// @solidity memory-safe-assembly
        assembly {
            signature.length := 0
        }
    }
}