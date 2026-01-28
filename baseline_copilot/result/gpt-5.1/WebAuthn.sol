// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice WebAuthn utilities for verifying P-256 signatures and encoding/decoding auth data.
library WebAuthn {
    /// @notice WebAuthn authentication data.
    /// @dev
    /// - `authenticatorData`: The WebAuthn authenticator data as per the WebAuthn specification.
    /// - `clientDataJSON`: The WebAuthn client data JSON as per the WebAuthn specification.
    /// - `challengeIndex`: The start index of the `"challenge":"..."` substring within `clientDataJSON`.
    /// - `typeIndex`: The start index of the `"type":"..."` substring within `clientDataJSON`.
    /// - `r`: The r value of the secp256r1 signature.
    /// - `s`: The s value of the secp256r1 signature.
    struct WebAuthnAuth {
        bytes authenticatorData;
        bytes clientDataJSON;
        uint256 challengeIndex;
        uint256 typeIndex;
        bytes32 r;
        bytes32 s;
    }

    // === External interface ==================================================

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
            string(auth.clientDataJSON),
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
     * @param authenticatorData The raw authenticator data.
     * @param clientDataJSON The JSON-encoded client data.
     * @param challengeIndex The start index of the `"challenge":"..."` substring within `clientDataJSON`.
     * @param typeIndex The start index of the `"type":"..."` substring within `clientDataJSON`.
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
        // Step 1: Base64-URL encode the challenge.
        bytes memory encodedChallenge = _base64UrlEncode(challenge);

        bytes memory clientBytes = bytes(clientDataJSON);
        uint256 len = clientBytes.length;

        // Basic bounds checks for indices, require they point somewhere inside JSON.
        if (len == 0 || challengeIndex >= len || typeIndex >= len) {
            return false;
        }

        // 2. Verify the `"type":"webauthn.get"` field using the provided typeIndex.
        // We expect something like: ..."type":"webauthn.get"...
        bytes memory expectedTypePrefix = '"type":"';
        bytes memory expectedTypeValue = "webauthn.get";

        if (!_matchStringAt(clientBytes, typeIndex, expectedTypePrefix)) {
            return false;
        }
        uint256 typeValueStart = typeIndex + expectedTypePrefix.length;
        if (!_matchStringAt(clientBytes, typeValueStart, expectedTypeValue)) {
            return false;
        }

        // 3. Verify the `"challenge":"<base64url(challenge)>"` field.
        bytes memory expectedChallengePrefix = '"challenge":"';
        if (!_matchStringAt(clientBytes, challengeIndex, expectedChallengePrefix)) {
            return false;
        }
        uint256 challengeValueStart = challengeIndex + expectedChallengePrefix.length;

        // Ensure the encoded challenge fully fits within clientDataJSON and is followed by a quote.
        if (challengeValueStart + encodedChallenge.length >= len) {
            return false;
        }
        for (uint256 i = 0; i < encodedChallenge.length; i++) {
            if (clientBytes[challengeValueStart + i] != encodedChallenge[i]) {
                return false;
            }
        }
        if (clientBytes[challengeValueStart + encodedChallenge.length] != '"') {
            return false;
        }

        // 4. Verify flags in authenticatorData.
        // authenticatorData layout (per spec):
        // - rpIdHash: 32 bytes
        // - flags: 1 byte (bit 0: User Present, bit 2: User Verified)
        // ...
        if (authenticatorData.length < 33) {
            return false;
        }
        uint8 flags = uint8(authenticatorData[32]);
        // User Present flag (bit 0) must be set.
        if ((flags & 0x01) == 0) {
            return false;
        }
        // If requireUserVerification, the User Verified flag (bit 2) must be set.
        if (requireUserVerification && (flags & 0x04) == 0) {
            return false;
        }

        // 5. Compute SHA-256(clientDataJSON) and SHA-256(authenticatorData), then SHA-256(authenticatorData || clientDataJSONHash).
        bytes32 clientHash = sha256(abi.encodePacked(clientDataJSON));
        bytes32 authHash = sha256(authenticatorData);
        bytes32 msgHash = sha256(abi.encodePacked(authenticatorData, clientHash));

        // 6. Verify the P-256 signature (r, s) over msgHash with public key (x, y).
        return _p256Verify(msgHash, r, s, x, y);
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
        // For safety and simplicity, rely on abi.decode and treat malformed input as empty.
        if (encodedAuth.length == 0) {
            return decoded;
        }
        // We expect the encoding layout from `encodeAuth`.
        (
            bytes memory authenticatorData,
            bytes memory clientDataJSON,
            uint256 challengeIndex,
            uint256 typeIndex,
            bytes32 r,
            bytes32 s
        ) = abi.decode(encodedAuth, (bytes, bytes, uint256, uint256, bytes32, bytes32));

        decoded.authenticatorData = authenticatorData;
        decoded.clientDataJSON = clientDataJSON;
        decoded.challengeIndex = challengeIndex;
        decoded.typeIndex = typeIndex;
        decoded.r = r;
        decoded.s = s;
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
        bytes memory ad = auth.authenticatorData;
        bytes memory cd = auth.clientDataJSON;

        uint256 adLen = ad.length;
        uint256 cdLen = cd.length;

        if (
            adLen > 0xffff ||
            cdLen > 0xffff ||
            auth.challengeIndex > 0xffff ||
            auth.typeIndex > 0xffff
        ) {
            return result;
        }

        // Layout:
        // [0..1]   authenticatorData length (uint16)
        // [2..]    authenticatorData bytes
        // [...]    clientDataJSON bytes
        // [..+4]   challengeIndex (uint16) | typeIndex (uint16)
        // [..+32]  r
        // [..+32]  s
        uint256 header = 2;
        uint256 afterAd = header + adLen;
        uint256 afterCd = afterAd + cdLen;
        uint256 meta = 4; // challengeIndex + typeIndex (2 bytes each)
        uint256 sig = 64; // r + s
        uint256 totalLen = afterCd + meta + sig;

        result = new bytes(totalLen);
        uint256 p;
        assembly {
            p := add(result, 32)
        }

        // Store authenticatorData length (uint16 big-endian).
        result[0] = bytes1(uint8(adLen >> 8));
        result[1] = bytes1(uint8(adLen));

        // Copy authenticatorData.
        _memcpy(p + header, _ptr(ad), adLen);
        // Copy clientDataJSON.
        _memcpy(p + afterAd, _ptr(cd), cdLen);

        // Encode challengeIndex and typeIndex as uint16 big-endian.
        uint256 metaPos = p + afterCd;
        assembly {
            mstore8(metaPos, shr(8, mload(add(auth, 0xa0)))) // challengeIndex high
            mstore8(add(metaPos, 1), mload(add(auth, 0xa0))) // challengeIndex low
            mstore8(add(metaPos, 2), shr(8, mload(add(auth, 0xc0)))) // typeIndex high
            mstore8(add(metaPos, 3), mload(add(auth, 0xc0))) // typeIndex low
        }

        // Append r and s.
        bytes32 r = auth.r;
        bytes32 s = auth.s;
        assembly {
            mstore(add(metaPos, 4), r)
            mstore(add(metaPos, 36), s)
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
        uint256 len = encodedAuth.length;
        if (len < 0x46) {
            return decoded;
        }

        uint256 p;
        assembly {
            p := add(encodedAuth, 32)
        }

        // Read authenticatorData length (uint16 big-endian).
        uint256 adLen = (uint8(encodedAuth[0]) << 8) | uint8(encodedAuth[1]);
        if (2 + adLen + 2 + 2 + 64 > len) {
            return decoded;
        }

        uint256 adStart = 2;
        uint256 cdStart = adStart + adLen;

        // Metadata and signature start.
        uint256 metaStart;
        unchecked {
            // metaStart = len - 4 - 64;
            metaStart = len - 68;
        }

        if (cdStart > metaStart) {
            return decoded;
        }

        uint256 cdLen = metaStart - cdStart;

        // Copy authenticatorData.
        decoded.authenticatorData = new bytes(adLen);
        _memcpy(_ptr(decoded.authenticatorData), p + adStart, adLen);

        // Copy clientDataJSON.
        decoded.clientDataJSON = new bytes(cdLen);
        _memcpy(_ptr(decoded.clientDataJSON), p + cdStart, cdLen);

        // Extract challengeIndex and typeIndex.
        decoded.challengeIndex =
            (uint256(uint8(encodedAuth[metaStart])) << 8) |
            uint256(uint8(encodedAuth[metaStart + 1]));
        decoded.typeIndex =
            (uint256(uint8(encodedAuth[metaStart + 2])) << 8) |
            uint256(uint8(encodedAuth[metaStart + 3]));

        // Extract r and s.
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(p, add(metaStart, 4)))
            s := mload(add(p, add(metaStart, 36)))
        }
        decoded.r = r;
        decoded.s = s;
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
    function tryDecodeAuthCompactCalldata(
        bytes calldata encodedAuth
    ) internal pure returns (WebAuthnAuth memory decoded) {
        uint256 len = encodedAuth.length;
        if (len < 0x46) {
            return decoded;
        }

        // Read authenticatorData length (uint16 big-endian) from calldata.
        uint256 adLen = (uint16(uint8(encodedAuth[0])) << 8) | uint16(uint8(encodedAuth[1]));
        if (2 + adLen + 2 + 2 + 64 > len) {
            return decoded;
        }

        uint256 adStart = 2;
        uint256 cdStart = adStart + adLen;

        uint256 metaStart;
        unchecked {
            metaStart = len - 68;
        }
        if (cdStart > metaStart) {
            return decoded;
        }

        uint256 cdLen = metaStart - cdStart;

        // Copy authenticatorData.
        decoded.authenticatorData = new bytes(adLen);
        _calldataCopy(encodedAuth, adStart, decoded.authenticatorData, 0, adLen);

        // Copy clientDataJSON.
        decoded.clientDataJSON = new bytes(cdLen);
        _calldataCopy(encodedAuth, cdStart, decoded.clientDataJSON, 0, cdLen);

        // Extract challengeIndex and typeIndex.
        decoded.challengeIndex =
            (uint256(uint8(encodedAuth[metaStart])) << 8) |
            uint256(uint8(encodedAuth[metaStart + 1]));
        decoded.typeIndex =
            (uint256(uint8(encodedAuth[metaStart + 2])) << 8) |
            uint256(uint8(encodedAuth[metaStart + 3]));

        // Extract r and s.
        bytes32 r;
        bytes32 s;
        assembly {
            // encodedAuth.offset is stored in the first word of the calldata slice.
            let base := encodedAuth.offset
            r := calldataload(add(base, add(metaStart, 4)))
            s := calldataload(add(base, add(metaStart, 36)))
        }
        decoded.r = r;
        decoded.s = s;
    }

    // === Internal helpers ====================================================

    /// @dev Compare `needle` with `haystack` starting at `offset`.
    function _matchStringAt(
        bytes memory haystack,
        uint256 offset,
        bytes memory needle
    ) private pure returns (bool) {
        uint256 hLen = haystack.length;
        uint256 nLen = needle.length;
        if (offset + nLen > hLen) {
            return false;
        }
        for (uint256 i = 0; i < nLen; i++) {
            if (haystack[offset + i] != needle[i]) {
                return false;
            }
        }
        return true;
    }

    /// @dev Get pointer to the data area of a bytes array in memory.
    function _ptr(bytes memory b) private pure returns (uint256 p) {
        assembly {
            p := add(b, 32)
        }
    }

    /// @dev Memory copy `len` bytes from `src` to `dst`.
    function _memcpy(uint256 dst, uint256 src, uint256 len) private pure {
        if (len == 0) return;
        assembly {
            for {

            } lt(0, len) {

            } {
                let chunk := mload(src)
                mstore(dst, chunk)
                src := add(src, 32)
                dst := add(dst, 32)
                len := sub(len, 32)
                if lt(len, 32) {
                    // Handle tail.
                    let mask := sub(shl(mul(8, sub(32, len)), 1), 1)
                    let s := mload(src)
                    let d := mload(dst)
                    mstore(dst, or(and(d, not(mask)), and(s, mask)))
                    len := 0
                }
            }
        }
    }

    /// @dev Copy from calldata bytes slice to memory bytes slice.
    function _calldataCopy(
        bytes calldata src,
        uint256 srcOffset,
        bytes memory dst,
        uint256 dstOffset,
        uint256 len
    ) private pure {
        if (len == 0) return;
        uint256 dstPtr;
        assembly {
            dstPtr := add(add(dst, 32), dstOffset)
        }
        uint256 srcPtr = srcOffset + src.offset;
        assembly {
            for {

            } lt(0, len) {

            } {
                let chunk := calldataload(srcPtr)
                mstore(dstPtr, chunk)
                srcPtr := add(srcPtr, 32)
                dstPtr := add(dstPtr, 32)
                len := sub(len, 32)
                if lt(len, 32) {
                    // Tail
                    let mask := sub(shl(mul(8, sub(32, len)), 1), 1)
                    let s := calldataload(srcPtr)
                    let d := mload(dstPtr)
                    mstore(dstPtr, or(and(d, not(mask)), and(s, mask)))
                    len := 0
                }
            }
        }
    }

    /// @dev Base64 URL-safe encoding (no padding) of arbitrary bytes.
    /// This is a minimal implementation suitable for WebAuthn challenges.
    function _base64UrlEncode(bytes memory data) private pure returns (bytes memory) {
        if (data.length == 0) return new bytes(0);

        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

        uint256 len = data.length;
        // 4 * ceil(len / 3)
        uint256 encodedLen = 4 * ((len + 2) / 3);

        bytes memory result = new bytes(encodedLen);

        uint256 i = 0;
        uint256 j = 0;

        while (i + 3 <= len) {
            (result[j], result[j + 1], result[j + 2], result[j + 3]) =
                _encode3(
                    table,
                    uint8(data[i]),
                    uint8(data[i + 1]),
                    uint8(data[i + 2])
                );
            i += 3;
            j += 4;
        }

        // Handle remaining bytes (1 or 2).
        uint256 rem = len - i;
        if (rem == 1) {
            (result[j], result[j + 1], result[j + 2], result[j + 3]) =
                _encode1(table, uint8(data[i]));
        } else if (rem == 2) {
            (result[j], result[j + 1], result[j + 2], result[j + 3]) =
                _encode2(table, uint8(data[i]), uint8(data[i + 1]));
        }

        // Remove padding characters ('='). Our helpers never emit '=', so nothing to trim.
        return result;
    }

    function _encode3(
        bytes memory table,
        uint8 a0,
        uint8 a1,
        uint8 a2
    ) private pure returns (bytes1, bytes1, bytes1, bytes1) {
        uint32 n = (uint32(a0) << 16) | (uint32(a1) << 8) | uint32(a2);

        uint8 b0 = uint8(n >> 18) & 63;
        uint8 b1 = uint8(n >> 12) & 63;
        uint8 b2 = uint8(n >> 6) & 63;
        uint8 b3 = uint8(n) & 63;

        return (
            table[b0],
            table[b1],
            table[b2],
            table[b3]
        );
    }

    function _encode2(
        bytes memory table,
        uint8 a0,
        uint8 a1
    ) private pure returns (bytes1, bytes1, bytes1, bytes1) {
        uint32 n = (uint32(a0) << 16) | (uint32(a1) << 8);

        uint8 b0 = uint8(n >> 18) & 63;
        uint8 b1 = uint8(n >> 12) & 63;
        uint8 b2 = uint8(n >> 6) & 63;

        return (
            table[b0],
            table[b1],
            table[b2],
            bytes1(0)
        );
    }

    function _encode1(
        bytes memory table,
        uint8 a0
    ) private pure returns (bytes1, bytes1, bytes1, bytes1) {
        uint32 n = uint32(a0) << 16;

        uint8 b0 = uint8(n >> 18) & 63;
        uint8 b1 = uint8(n >> 12) & 63;

        return (
            table[b0],
            table[b1],
            bytes1(0),
            bytes1(0)
        );
    }

    /// @dev Placeholder P-256 verification. Returns false by default.
    /// In a production environment, this must be replaced with a full P-256 verifier.
    function _p256Verify(
        bytes32 msgHash,
        bytes32 r,
        bytes32 s,
        bytes32 x,
        bytes32 y
    ) private view returns (bool) {
        msgHash; r; s; x; y;
        // NOTE: A full implementation of P-256 signature verification is non-trivial
        // and typically relies on a precompile or specialized library.
        // This placeholder returns false to keep the contract compilable.
        return false;
    }
}