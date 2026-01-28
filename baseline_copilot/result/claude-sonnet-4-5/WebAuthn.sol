// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibString} from "./repository/solady/src/utils/LibString.sol";
import {P256} from "./repository/solady/src/utils/P256.sol";

library WebAuthn {
    /**
     * @notice Defines a struct for WebAuthn authentication data.
     *
     * @dev This struct is used to store WebAuthn authentication details, including:
     * - `authenticatorData`: The WebAuthn authenticator data as per the WebAuthn specification.
     * - `clientDataJSON`: The WebAuthn client data JSON as per the WebAuthn specification.
     * - `challengeIndex`: The start index of the "challenge":"..." substring within `clientDataJSON`.
     * - `typeIndex`: The start index of the "type":"..." substring within `clientDataJSON`.
     * - `r`: The r value of the secp256r1 signature.
     * - `s`: The s value of the secp256r1 signature.
     *
     * This struct is typically used in WebAuthn-based authentication mechanisms.
     */
    struct WebAuthnAuth {
        bytes authenticatorData;
        string clientDataJSON;
        uint256 challengeIndex;
        uint256 typeIndex;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @notice Verifies a WebAuthn authentication challenge using the provided parameters.
     *
     * @param challenge The challenge bytes to be verified.
     * @param requireUserVerification A boolean indicating whether user verification is required.
     * @param auth A WebAuthnAuth struct containing authentication data.
     * @param x The x-coordinate of the public key.
     * @param y The y-coordinate of the public key.
     * @return result A boolean indicating whether the verification was successful.
     *
     * Steps:
     * 1. Encode the challenge using Base64 encoding.
     * 2. Use inline assembly to perform low-level operations:
     *    - Extract and verify the type and challenge from the clientDataJSON.
     *    - Ensure the JSON type is "webauthn.get" and the challenge matches the encoded challenge.
     *    - Verify the "User Present" and "User Verified" flags in the authenticatorData.
     *    - Compute the SHA-256 hash of the clientDataJSON and authenticatorData.
     * 3. If all checks pass, verify the signature using the P256 elliptic curve.
     * 4. Return the result of the verification.
     *
     * Note: The function includes checks for JSON structure, flags, and cryptographic signatures.
     */
    function verify(
        bytes memory challenge,
        bool requireUserVerification,
        WebAuthnAuth memory auth,
        bytes32 x,
        bytes32 y
    ) internal view returns (bool result) {
        return verify(
            challenge,
            requireUserVerification,
            auth.authenticatorData,
            auth.clientDataJSON,
            auth.challengeIndex,
            auth.typeIndex,
            auth.r,
            auth.s,
            x,
            y
        );
    }

    /**
     * @notice Verifies a WebAuthn authentication challenge using the provided parameters.
     *
     * @param challenge The challenge bytes to be verified.
     * @param requireUserVerification A boolean indicating whether user verification is required.
     * @param authenticatorData The WebAuthn authenticator data.
     * @param clientDataJSON The WebAuthn client data JSON.
     * @param challengeIndex The start index of the challenge in clientDataJSON.
     * @param typeIndex The start index of the type in clientDataJSON.
     * @param r The r value of the secp256r1 signature.
     * @param s The s value of the secp256r1 signature.
     * @param x The x-coordinate of the public key.
     * @param y The y-coordinate of the public key.
     * @return result A boolean indicating whether the verification was successful.
     *
     * Steps:
     * 1. Encode the challenge using Base64 encoding.
     * 2. Use inline assembly to perform low-level operations:
     *    - Extract and verify the type and challenge from the clientDataJSON.
     *    - Ensure the JSON type is "webauthn.get" and the challenge matches the encoded challenge.
     *    - Verify the "User Present" and "User Verified" flags in the authenticatorData.
     *    - Compute the SHA-256 hash of the clientDataJSON and authenticatorData.
     * 3. If all checks pass, verify the signature using the P256 elliptic curve.
     * 4. Return the result of the verification.
     *
     * Note: The function includes checks for JSON structure, flags, and cryptographic signatures.
     */
    function verify(
        bytes memory challenge,
        bool requireUserVerification,
        bytes memory authenticatorData,
        string memory clientDataJSON,
        uint256 challengeIndex,
        uint256 typeIndex,
        bytes32 r,
        bytes32 s,
        bytes32 x,
        bytes32 y
    ) internal view returns (bool) {
        bytes memory encodedChallenge = bytes(LibString.toBase64URL(challenge, true, true));
        bytes memory clientData = bytes(clientDataJSON);

        /// @solidity memory-safe-assembly
        assembly {
            // Check type field: should be "webauthn.get"
            let typeStart := add(add(clientData, 0x20), typeIndex)
            let typeValue := mload(typeStart)
            // "type":"webauthn.get"
            // Check for: 0x747970652...
            if iszero(
                and(
                    // "type":"
                    eq(
                        and(typeValue, 0xffffffffffffff0000000000000000000000000000000000000000000000000000),
                        0x7479706522003a220000000000000000000000000000000000000000000000000000
                    ),
                    // "webauthn.get"
                    eq(
                        and(mload(add(typeStart, 7)), 0xffffffffffffffffffffffff00000000000000000000000000000000000000000000),
                        0x776562617574686e2e67657400000000000000000000000000000000000000000000
                    )
                )
            ) {
                result := 0
                leave
            }

            // Check challenge field
            let challengeStart := add(add(clientData, 0x20), challengeIndex)
            let challengeValue := mload(challengeStart)
            // "challenge":"
            if iszero(
                eq(
                    and(challengeValue, 0xffffffffffffffffffffff000000000000000000000000000000000000000000000),
                    0x6368616c6c656e676522003a2200000000000000000000000000000000000000000
                )
            ) {
                result := 0
                leave
            }

            // Verify the challenge matches
            let encodedLen := mload(encodedChallenge)
            let challengeContentStart := add(challengeStart, 13)
            let encodedStart := add(encodedChallenge, 0x20)

            for { let i := 0 } lt(i, encodedLen) { i := add(i, 0x20) } {
                if iszero(eq(mload(add(challengeContentStart, i)), mload(add(encodedStart, i)))) {
                    result := 0
                    leave
                }
            }

            // Check if the remaining bytes match
            let remaining := mod(encodedLen, 0x20)
            if remaining {
                let mask := shl(mul(8, sub(0x20, remaining)), not(0))
                if iszero(
                    eq(
                        and(mload(add(challengeContentStart, encodedLen)), mask),
                        and(mload(add(encodedStart, encodedLen)), mask)
                    )
                ) {
                    result := 0
                    leave
                }
            }

            // Verify authenticatorData flags
            let authDataPtr := add(authenticatorData, 0x20)
            let authDataLen := mload(authenticatorData)

            // Check User Present flag (bit 0)
            let flags := byte(0, mload(add(authDataPtr, 32)))
            if iszero(and(flags, 0x01)) {
                result := 0
                leave
            }

            // Check User Verified flag (bit 2) if required
            if requireUserVerification {
                if iszero(and(flags, 0x04)) {
                    result := 0
                    leave
                }
            }

            // Compute the message hash
            // message = sha256(authenticatorData || sha256(clientDataJSON))
            let clientDataHash := keccak256(add(clientData, 0x20), mload(clientData))

            // Store clientDataHash temporarily
            let memPtr := mload(0x40)
            mstore(memPtr, clientDataHash)

            // Use SHA-256 precompile for clientDataJSON hash
            pop(staticcall(gas(), 0x02, add(clientData, 0x20), mload(clientData), memPtr, 0x20))

            // Concatenate authenticatorData + sha256(clientDataJSON)
            let messageStart := add(memPtr, 0x20)
            let authLen := mload(authenticatorData)

            // Copy authenticatorData
            for { let i := 0 } lt(i, authLen) { i := add(i, 0x20) } {
                mstore(add(messageStart, i), mload(add(authDataPtr, i)))
            }

            // Copy clientDataHash
            mstore(add(messageStart, authLen), mload(memPtr))

            // Compute SHA-256 of the complete message
            let messageHash := mload(0x40)
            pop(staticcall(gas(), 0x02, messageStart, add(authLen, 0x20), messageHash, 0x20))

            // Update free memory pointer
            mstore(0x40, add(messageHash, 0x20))
        }

        // Verify the signature using P256
        bytes32 messageHash;
        /// @solidity memory-safe-assembly
        assembly {
            // Compute SHA-256 hash of authenticatorData || sha256(clientDataJSON)
            let memPtr := mload(0x40)
            let authDataPtr := add(authenticatorData, 0x20)
            let authDataLen := mload(authenticatorData)

            // Hash clientDataJSON
            let clientDataHashPtr := memPtr
            pop(staticcall(gas(), 0x02, add(clientData, 0x20), mload(clientData), clientDataHashPtr, 0x20))

            // Concatenate authenticatorData + clientDataHash
            let messagePtr := add(memPtr, 0x20)
            mcopy(messagePtr, authDataPtr, authDataLen)
            mstore(add(messagePtr, authDataLen), mload(clientDataHashPtr))

            // Hash the complete message
            let hashPtr := add(memPtr, add(0x20, add(authDataLen, 0x20)))
            pop(staticcall(gas(), 0x02, messagePtr, add(authDataLen, 0x20), hashPtr, 0x20))

            messageHash := mload(hashPtr)
            mstore(0x40, add(hashPtr, 0x20))
        }

        return P256.verify(messageHash, r, s, x, y);
    }

    /**
     * @notice Encodes a WebAuthnAuth struct into a bytes array.
     *
     * @param auth The WebAuthnAuth struct to be encoded.
     * @return bytes The encoded bytes representation of the WebAuthnAuth struct.
     */
    function encodeAuth(WebAuthnAuth memory auth) internal pure returns (bytes memory) {
        return abi.encode(
            auth.authenticatorData,
            auth.clientDataJSON,
            auth.challengeIndex,
            auth.typeIndex,
            auth.r,
            auth.s
        );
    }

    /**
     * @notice Attempts to decode WebAuthn authentication data from the provided encoded bytes.
     *
     * @param encodedAuth The encoded authentication data to be decoded.
     * @return decoded A `WebAuthnAuth` struct containing the decoded authentication data.
     *
     * Steps:
     * 1. Use inline assembly to manually decode the `encodedAuth` bytes.
     * 2. Calculate the start (`o`) and end (`e`) of the `encodedAuth` in memory.
     * 3. Extract the start of the encoded data (`p`).
     * 4. Validate that the `authenticatorData` and `clientDataJSON` pointers are within bounds.
     * 5. Validate that the lengths of `authenticatorData` and `clientDataJSON` do not exceed memory bounds.
     * 6. Store the decoded `authenticatorData`, `clientDataJSON`, `challengeIndex`, `typeIndex`, `r`, and `s` into the `decoded` struct.
     * 7. Break the loop once decoding is complete.
     *
     * @dev This function uses low-level assembly for memory-safe decoding of WebAuthn authentication data.
     */
    function tryDecodeAuth(bytes memory encodedAuth) internal pure returns (WebAuthnAuth memory decoded) {
        /// @solidity memory-safe-assembly
        assembly {
            let o := add(encodedAuth, 0x20)
            let e := add(o, mload(encodedAuth))
            let p := o

            for {} 1 {} {
                // Decode authenticatorData pointer
                let authDataOffset := mload(p)
                if gt(add(p, authDataOffset), e) { break }
                let authDataPtr := add(o, authDataOffset)
                if gt(authDataPtr, e) { break }

                let authDataLen := mload(authDataPtr)
                if gt(add(authDataPtr, add(0x20, authDataLen)), e) { break }

                mstore(decoded, authDataPtr)
                p := add(p, 0x20)

                // Decode clientDataJSON pointer
                let clientDataOffset := mload(p)
                if gt(add(p, clientDataOffset), e) { break }
                let clientDataPtr := add(o, clientDataOffset)
                if gt(clientDataPtr, e) { break }

                let clientDataLen := mload(clientDataPtr)
                if gt(add(clientDataPtr, add(0x20, clientDataLen)), e) { break }

                mstore(add(decoded, 0x20), clientDataPtr)
                p := add(p, 0x20)

                // Decode challengeIndex
                mstore(add(decoded, 0x40), mload(p))
                p := add(p, 0x20)

                // Decode typeIndex
                mstore(add(decoded, 0x60), mload(p))
                p := add(p, 0x20)

                // Decode r
                mstore(add(decoded, 0x80), mload(p))
                p := add(p, 0x20)

                // Decode s
                mstore(add(decoded, 0xa0), mload(p))

                break
            }
        }
    }

    /**
     * @notice Encodes a WebAuthnAuth struct into a compact byte array representation.
     *
     * @param auth The WebAuthnAuth struct containing the following fields:
     *             - `authenticatorData`: The authenticator data bytes.
     *             - `clientDataJSON`: The client data JSON bytes.
     *             - `challengeIndex`: The index of the challenge in the client data JSON.
     *             - `typeIndex`: The index of the type in the client data JSON.
     *             - `r`: The `r` value of the signature.
     *             - `s`: The `s` value of the signature.
     *
     * @return result The compact byte array representation of the WebAuthnAuth struct.
     *
     * Steps:
     * 1. Check if the lengths of `authenticatorData`, `clientDataJSON`, `challengeIndex`, and `typeIndex` are within the limit of `0xffff`.
     * 2. If valid, allocate memory for the result.
     * 3. Copy `authenticatorData` and `clientDataJSON` into the result.
     * 4. Encode `challengeIndex` and `typeIndex` into the result.
     * 5. Append the `r` and `s` values of the signature to the result.
     * 6. Store the length of the result.
     * 7. Zeroize the memory slot after the result to ensure no leftover data.
     * 8. Allocate additional memory for the result.
     *
     * Note: This function uses low-level assembly for memory manipulation to optimize gas usage.
     */
    function tryEncodeAuthCompact(WebAuthnAuth memory auth) internal pure returns (bytes memory result) {
        bytes memory authenticatorData = auth.authenticatorData;
        bytes memory clientDataJSON = bytes(auth.clientDataJSON);

        /// @solidity memory-safe-assembly
        assembly {
            let authDataLen := mload(authenticatorData)
            let clientDataLen := mload(clientDataJSON)
            let challengeIndex := mload(add(auth, 0x40))
            let typeIndex := mload(add(auth, 0x60))

            // Check if lengths and indices fit in uint16
            if or(
                or(gt(authDataLen, 0xffff), gt(clientDataLen, 0xffff)),
                or(gt(challengeIndex, 0xffff), gt(typeIndex, 0xffff))
            ) {
                leave
            }

            // Calculate total length: 2 + authDataLen + clientDataLen + 2 + 2 + 32 + 32
            let totalLen := add(add(add(authDataLen, clientDataLen), 70), 0)

            // Allocate memory
            result := mload(0x40)
            let resultData := add(result, 0x20)

            // Store authenticatorData length (2 bytes)
            mstore8(resultData, shr(8, authDataLen))
            mstore8(add(resultData, 1), and(authDataLen, 0xff))

            // Copy authenticatorData
            let authDataSrc := add(authenticatorData, 0x20)
            mcopy(add(resultData, 2), authDataSrc, authDataLen)

            // Copy clientDataJSON
            let clientDataSrc := add(clientDataJSON, 0x20)
            let clientDataDest := add(resultData, add(2, authDataLen))
            mcopy(clientDataDest, clientDataSrc, clientDataLen)

            // Store challengeIndex (2 bytes)
            let indexDest := add(clientDataDest, clientDataLen)
            mstore8(indexDest, shr(8, challengeIndex))
            mstore8(add(indexDest, 1), and(challengeIndex, 0xff))

            // Store typeIndex (2 bytes)
            mstore8(add(indexDest, 2), shr(8, typeIndex))
            mstore8(add(indexDest, 3), and(typeIndex, 0xff))

            // Store r (32 bytes)
            mstore(add(indexDest, 4), mload(add(auth, 0x80)))

            // Store s (32 bytes)
            mstore(add(indexDest, 36), mload(add(auth, 0xa0)))

            // Store length
            mstore(result, sub(totalLen, 2))

            // Zeroize the slot after the result
            mstore(add(result, add(0x20, sub(totalLen, 2))), 0)

            // Update free memory pointer
            mstore(0x40, add(result, add(0x40, sub(totalLen, 2))))
        }
    }

    /**
     * @notice Decodes a compact WebAuthn authentication structure from a byte array.
     *
     * @param encodedAuth The byte array containing the encoded WebAuthn authentication data.
     * @return decoded A `WebAuthnAuth` struct containing the decoded authentication data.
     *
     * Steps:
     * 1. Check if the length of `encodedAuth` is at least 0x46 bytes (70 bytes).
     * 2. Extract the length of the `authenticatorData` from the first 2 bytes of `encodedAuth`.
     * 3. Extract the `authenticatorData` from the encoded bytes.
     * 4. Extract the `clientDataJSON` from the encoded bytes.
     * 5. Extract the `challengeIndex` and `typeIndex` from the encoded bytes.
     * 6. Extract the `r` and `s` values (signature components) from the encoded bytes.
     * 7. Store the extracted data into the `decoded` struct.
     *
     * Note: This function uses inline assembly for low-level memory manipulation to efficiently decode the data.
     */
    function tryDecodeAuthCompact(bytes memory encodedAuth) internal pure returns (WebAuthnAuth memory decoded) {
        /// @solidity memory-safe-assembly
        assembly {
            let encodedLen := mload(encodedAuth)
            if lt(encodedLen, 0x46) { leave }

            let ptr := add(encodedAuth, 0x20)

            // Read authenticatorData length (2 bytes)
            let authDataLen := or(shl(8, byte(0, mload(ptr))), byte(1, mload(ptr)))
            ptr := add(ptr, 2)

            // Check bounds
            if gt(add(authDataLen, 0x44), encodedLen) { leave }

            // Allocate and copy authenticatorData
            let authData := mload(0x40)
            mstore(authData, authDataLen)
            mcopy(add(authData, 0x20), ptr, authDataLen)
            mstore(decoded, authData)
            mstore(0x40, add(add(authData, 0x20), authDataLen))
            ptr := add(ptr, authDataLen)

            // Calculate clientDataJSON length
            let clientDataLen := sub(sub(encodedLen, authDataLen), 0x46)

            // Allocate and copy clientDataJSON
            let clientData := mload(0x40)
            mstore(clientData, clientDataLen)
            mcopy(add(clientData, 0x20), ptr, clientDataLen)
            mstore(add(decoded, 0x20), clientData)
            mstore(0x40, add(add(clientData, 0x20), clientDataLen))
            ptr := add(ptr, clientDataLen)

            // Read challengeIndex (2 bytes)
            let challengeIndex := or(shl(8, byte(0, mload(ptr))), byte(1, mload(ptr)))
            mstore(add(decoded, 0x40), challengeIndex)
            ptr := add(ptr, 2)

            // Read typeIndex (2 bytes)
            let typeIndex := or(shl(8, byte(0, mload(ptr))), byte(1, mload(ptr)))
            mstore(add(decoded, 0x60), typeIndex)
            ptr := add(ptr, 2)

            // Read r (32 bytes)
            mstore(add(decoded, 0x80), mload(ptr))
            ptr := add(ptr, 32)

            // Read s (32 bytes)
            mstore(add(decoded, 0xa0), mload(ptr))
        }
    }

    /**
     * @notice Decodes a compact WebAuthn authentication data structure from calldata.
     *
     * @param encodedAuth The encoded authentication data passed as calldata.
     * @return decoded A `WebAuthnAuth` struct containing the decoded authentication data.
     *
     * Steps:
     * 1. Check if the length of `encodedAuth` is at least 0x46 bytes (minimum required length).
     * 2. Calculate the end of `encodedAuth` and the start of `authenticatorData`.
     * 3. Extract the length of `authenticatorData` from the first 2 bytes of `encodedAuth`.
     * 4. Calculate the start of `clientDataJSON` and the start of `challengeIndex`.
     * 5. Ensure that `clientDataJSON` does not overlap with `challengeIndex`.
     * 6. Decode and store the following fields in the `decoded` struct:
     *    - `authenticatorData`: Extracted from the specified offset and length.
     *    - `clientDataJSON`: Extracted from the calculated offset and length.
     *    - `challengeIndex`: Extracted from the specified offset.
     *    - `typeIndex`: Extracted from the specified offset.
     *    - `r`: Extracted from the specified offset.
     *    - `s`: Extracted from the specified offset.
     *
     * @dev This function uses inline assembly for low-level memory manipulation to efficiently decode the calldata.
     */
    function tryDecodeAuthCompactCalldata(bytes calldata encodedAuth)
        internal
        pure
        returns (WebAuthnAuth memory decoded)
    {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(encodedAuth.length, 0x46) { leave }

            let ptr := encodedAuth.offset

            // Read authenticatorData length (2 bytes)
            let authDataLen := or(shl(8, byte(0, calldataload(ptr))), byte(1, calldataload(ptr)))
            ptr := add(ptr, 2)

            // Check bounds
            if gt(add(authDataLen, 0x44), encodedAuth.length) { leave }

            // Allocate and copy authenticatorData from calldata
            let authData := mload(0x40)
            mstore(authData, authDataLen)
            calldatacopy(add(authData, 0x20), ptr, authDataLen)
            mstore(decoded, authData)
            mstore(0x40, add(add(authData, 0x20), authDataLen))
            ptr := add(ptr, authDataLen)

            // Calculate clientDataJSON length
            let clientDataLen := sub(sub(encodedAuth.length, authDataLen), 0x46)

            // Allocate and copy clientDataJSON from calldata
            let clientData := mload(0x40)
            mstore(clientData, clientDataLen)
            calldatacopy(add(clientData, 0x20), ptr, clientDataLen)
            mstore(add(decoded, 0x20), clientData)
            mstore(0x40, add(add(clientData, 0x20), clientDataLen))
            ptr := add(ptr, clientDataLen)

            // Read challengeIndex (2 bytes)
            let challengeIndex := or(shl(8, byte(0, calldataload(ptr))), byte(1, calldataload(ptr)))
            mstore(add(decoded, 0x40), challengeIndex)
            ptr := add(ptr, 2)

            // Read typeIndex (2 bytes)
            let typeIndex := or(shl(8, byte(0, calldataload(ptr))), byte(1, calldataload(ptr)))
            mstore(add(decoded, 0x60), typeIndex)
            ptr := add(ptr, 2)

            // Read r (32 bytes)
            mstore(add(decoded, 0x80), calldataload(ptr))
            ptr := add(ptr, 32)

            // Read s (32 bytes)
            mstore(add(decoded, 0xa0), calldataload(ptr))
        }
    }
}
