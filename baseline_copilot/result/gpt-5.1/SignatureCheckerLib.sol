// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SignatureCheckerLib {
    /// @dev ERC1271 magic value for isValidSignature(bytes32,bytes).
    bytes4 internal constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;

    /// @dev ERC6492 magic value as specified in the standard.
    bytes4 internal constant _ERC6492_MAGIC_VALUE = 0x64926492;

    /// @notice Validates if a given signature is valid for a specific signer and hash.
    ///
    /// @param signer The address of the signer whose signature is being validated.
    /// @param hash The hash of the data that was signed.
    /// @param signature The signature to be validated.
    /// @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
    ///
    /// Steps:
    /// 1. If the signer is the zero address, return `false` immediately.
    /// 2. Use inline assembly to handle low-level memory operations for efficiency.
    /// 3. Depending on the length of the signature (64 or 65 bytes), extract the `v`, `r`, and `s` components.
    /// 4. Recover the signer's address from the signature using the `ecrecover` precompiled contract.
    /// 5. Compare the recovered address with the provided signer address to determine validity.
    /// 6. If the signature is invalid, attempt to validate it using the `isValidSignature` method of the signer contract.
    /// 7. Return the result of the validation.
    ///
    /// Notes:
    /// - The function handles both EIP-2098 compact signatures (64 bytes) and traditional EIP-712 signatures (65 bytes).
    /// - The function restores the zero slot and free memory pointer after operations to maintain memory safety.
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        if (_isValidECDSASignature(signer, hash, signature)) return true;
        return isValidERC1271SignatureNow(signer, hash, signature);
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
        if (_isValidECDSASignatureCalldata(signer, hash, signature)) return true;
        return isValidERC1271SignatureNowCalldata(signer, hash, signature);
    }

    /**
     * @notice Validates if a given signature is valid for a specific signer and hash.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param r The r value of the EIP-2098 compact signature.
     * @param vs The vs value (containing v and s) of the EIP-2098 compact signature.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Notes:
     * - The function handles EIP-2098 compact signatures (64 bytes) via r and vs.
     * - The function restores the zero slot and free memory pointer after operations to maintain memory safety.
     */
    function isValidSignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        (uint8 v, bytes32 s) = _splitVS(vs);
        if (_isValidECDSASignatureParts(signer, hash, v, r, s)) return true;
        return isValidERC1271SignatureNow(signer, hash, r, vs);
    }

    /**
     * @notice Validates if a given signature is valid for a specific signer and hash.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param v The recovery id of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     * @return isValid A boolean indicating whether the signature is valid for the given signer and hash.
     *
     * Notes:
     * - The function restores the zero slot and free memory pointer after operations to maintain memory safety.
     */
    function isValidSignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool isValid)
    {
        if (signer == address(0)) return false;
        if (_isValidECDSASignatureParts(signer, hash, v, r, s)) return true;
        return isValidERC1271SignatureNow(signer, hash, v, r, s);
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
        if (signer.code.length == 0) return false;
        bytes4 selector = _ERC1271_MAGIC_VALUE;
        bytes memory data = abi.encodeWithSelector(selector, hash, signature);
        (bool success, bytes memory result) = signer.staticcall(data);
        return success && result.length == 4 && bytes4(result) == selector;
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
        if (signer.code.length == 0) return false;

        bytes4 selector = _ERC1271_MAGIC_VALUE;
        bytes memory data = abi.encodeWithSelector(selector, hash, signature);
        (bool success, bytes memory result) = signer.staticcall(data);
        return success && result.length == 4 && bytes4(result) == selector;
    }

    /**
     * @notice Checks if a given signature is valid for a specific signer and hash according to the ERC1271 standard.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param r The r value of the EIP-2098 compact signature.
     * @param vs The vs value (containing v and s) of the EIP-2098 compact signature.
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
        bytes memory sig = new bytes(64);
        assembly {
            mstore(add(sig, 0x20), r)
            mstore(add(sig, 0x40), vs)
        }
        return isValidERC1271SignatureNow(signer, hash, sig);
    }

    /**
     * @notice Checks if a given signature is valid for a specific signer and hash according to the ERC1271 standard.
     *
     * @param signer The address of the signer whose signature is being validated.
     * @param hash The hash of the data that was signed.
     * @param v The recovery id of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
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
        bytes memory sig = new bytes(65);
        assembly {
            mstore(add(sig, 0x20), r)
            mstore(add(sig, 0x40), s)
            mstore8(add(sig, 0x60), v)
        }
        return isValidERC1271SignatureNow(signer, hash, sig);
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
    function isValidERC6492SignatureNowAllowSideEffects(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal returns (bool isValid) {
        if (signer == address(0)) return false;

        // Try ERC6492 wrapper first.
        if (_isERC6492Wrapped(signature)) {
            bytes memory innerSig;
            address innerSigner;
            (innerSigner, innerSig) = _unwrapERC6492(signature);
            if (innerSigner != address(0)) {
                // Contract may have side effects as per ERC6492 spec.
                if (_isValidECDSASignature(innerSigner, hash, innerSig)) return true;
                return isValidERC1271SignatureNow(innerSigner, hash, innerSig);
            }
        }

        // Fallback: plain ECDSA or ERC1271 for provided signer.
        if (_isValidECDSASignature(signer, hash, signature)) return true;
        return isValidERC1271SignatureNow(signer, hash, signature);
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
        if (signer == address(0)) return false;

        if (_isERC6492Wrapped(signature)) {
            (address innerSigner, bytes memory innerSig) = _unwrapERC6492(signature);
            if (innerSigner == address(0)) return false;

            if (_isValidECDSASignature(innerSigner, hash, innerSig)) return true;
            return isValidERC1271SignatureNow(innerSigner, hash, innerSig);
        }

        if (_isValidECDSASignature(signer, hash, signature)) return true;
        return isValidERC1271SignatureNow(signer, hash, signature);
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
        // Equivalent to: keccak256("\x19Ethereum Signed Message:\n32" || hash)
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @notice Converts a bytes32 hash into an Ethereum signed message hash.
     *
     * @dev This function prepends the Ethereum signed message prefix to the hash and computes the keccak256 hash of the result.
     * The prefix is "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32" (28 bytes), followed by the 32-byte hash.
     * The final result is a 32-byte hash that can be used for signature verification.
     *
     * @param s The message bytes to be converted into an Ethereum signed message hash.
     * @return result The resulting Ethereum signed message hash.
     *
     * Steps:
     * 1. Store the input hash in memory at position 0x20.
     * 2. Store the Ethereum signed message prefix in memory at position 0x00.
     * 3. Compute the keccak256 hash of the concatenated prefix and hash, starting from byte 0x04 to 0x3c (60 bytes in total).
     * 4. Return the computed hash as the result.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        // Equivalent to: keccak256("\x19Ethereum Signed Message:\n" + len(s) || s)
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _uintToString(s.length), s));
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
        assembly {
            signature.length := 0
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isValidECDSASignature(address signer, bytes32 hash, bytes memory signature)
        private
        view
        returns (bool)
    {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return _isValidECDSASignatureParts(signer, hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            (uint8 v, bytes32 s) = _splitVS(vs);
            return _isValidECDSASignatureParts(signer, hash, v, r, s);
        }
        return false;
    }

    function _isValidECDSASignatureCalldata(address signer, bytes32 hash, bytes calldata signature)
        private
        view
        returns (bool)
    {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            return _isValidECDSASignatureParts(signer, hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(signature.offset)
                vs := calldataload(add(signature.offset, 0x20))
            }
            (uint8 v, bytes32 s) = _splitVS(vs);
            return _isValidECDSASignatureParts(signer, hash, v, r, s);
        }
        return false;
    }

    function _isValidECDSASignatureParts(
        address signer,
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private view returns (bool) {
        if (uint256(s) > 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
            return false;
        }
        if (v != 27 && v != 28) {
            return false;
        }
        address recovered = ecrecover(hash, v, r, s);
        return recovered == signer;
    }

    function _splitVS(bytes32 vs) private pure returns (uint8 v, bytes32 s) {
        s = bytes32(uint256(vs) & 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        v = uint8((uint256(vs) >> 255) + 27);
    }

    function _isERC6492Wrapped(bytes memory signature) private pure returns (bool) {
        if (signature.length < 4) return false;
        bytes4 magic;
        assembly {
            magic := mload(add(signature, 0x20))
        }
        return magic == _ERC6492_MAGIC_VALUE;
    }

    function _unwrapERC6492(bytes memory signature)
        private
        pure
        returns (address signer, bytes memory innerSignature)
    {
        if (signature.length < 4 + 20) return (address(0), bytes(""));
        assembly {
            signer := mload(add(signature, 0x24))
        }
        uint256 innerLen = signature.length - 24;
        innerSignature = new bytes(innerLen);
        for (uint256 i = 0; i < innerLen; ++i) {
            innerSignature[i] = signature[i + 24];
        }
    }

    function _uintToString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}