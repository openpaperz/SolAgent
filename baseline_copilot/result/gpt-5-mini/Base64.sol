// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Base64
/// @notice Library for Base64 encoding and decoding with options for file-safe alphabet and optional padding.
library Base64 {
    /**
     * @notice Encodes the given data into a Base64 string, with options for file-safe encoding and padding.
     *
     * @param data The input data to be encoded.
     * @param fileSafe If true, uses a file-safe Base64 alphabet (replaces '+' and '/' with '-' and '_').
     * @param noPadding If true, removes the padding characters ('=') from the output.
     * @return result The Base64 encoded string.
     *
     * Steps:
     * 1. Calculate the length of the input data.
     * 2. Compute the encoded length by multiplying the data length by 4/3 and rounding up.
     * 3. Allocate memory for the result and store the Base64 alphabet in scratch space.
     * 4. Iterate over the input data in chunks of 3 bytes, encoding each chunk into 4 Base64 characters.
     * 5. Handle padding by adjusting the result length and adding padding characters if necessary.
     * 6. Restore the original value at the end of the input data and update the free memory pointer.
     * 7. Return the encoded Base64 string.
     */
    function encode(bytes memory data, bool fileSafe, bool noPadding) internal pure returns (string memory result) {
        uint256 len = data.length;
        if (len == 0) return "";
        bytes memory table = fileSafe
            ? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
            : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 fullGroups = len / 3;
        uint256 remainder = len % 3;
        uint256 encodedLen = (fullGroups * 4) + (remainder == 0 ? 0 : 4);
        // If noPadding is requested, reduce the output length according to remainder.
        uint256 outLen = encodedLen;
        if (noPadding && remainder != 0) {
            // remainder==1 -> produce 2 chars (no '=='), remainder==2 -> produce 3 chars (no '=')
            outLen = fullGroups * 4 + (remainder == 1 ? 2 : 3);
        }

        bytes memory out = new bytes(outLen);

        uint256 di = 0; // destination index
        uint256 si = 0; // source index

        // Process all full 3-byte groups.
        for (uint256 i = 0; i < fullGroups; ++i) {
            uint256 a = uint8(data[si++]);
            uint256 b = uint8(data[si++]);
            uint256 c = uint8(data[si++]);

            uint256 triple = (a << 16) | (b << 8) | c;

            out[di++] = table[(triple >> 18) & 0x3F];
            out[di++] = table[(triple >> 12) & 0x3F];
            out[di++] = table[(triple >> 6) & 0x3F];
            out[di++] = table[triple & 0x3F];
        }

        // Handle remainder.
        if (remainder == 1) {
            uint256 a = uint8(data[si++]);
            uint256 triple = (a << 16);

            // Always write first two chars
            out[di++] = table[(triple >> 18) & 0x3F];
            out[di++] = table[(triple >> 12) & 0x3F];

            if (!noPadding) {
                // two padding chars
                if (di + 2 <= out.length) {
                    out[di++] = bytes1("=");
                    out[di++] = bytes1("=");
                }
            }
        } else if (remainder == 2) {
            uint256 a = uint8(data[si++]);
            uint256 b = uint8(data[si++]);
            uint256 triple = (a << 16) | (b << 8);

            out[di++] = table[(triple >> 18) & 0x3F];
            out[di++] = table[(triple >> 12) & 0x3F];
            out[di++] = table[(triple >> 6) & 0x3F];

            if (!noPadding) {
                if (di + 1 <= out.length) {
                    out[di++] = bytes1("=");
                }
            }
        }

        // If noPadding trimmed output shorter than allocated encodedLen, di matches out.length.
        return string(out);
    }

    /**
     * @notice Encodes the given data into a Base64 string, with options for file-safe encoding and padding.
     *
     * @param data The input data to be encoded.
     * @param fileSafe If true, uses a file-safe Base64 alphabet (replaces '+' and '/' with '-' and '_').
     * @param noPadding If true, removes the padding characters ('=') from the output.
     * @return result The Base64 encoded string.
     */
    function encode(bytes memory data) internal pure returns (string memory result) {
        return encode(data, false, false);
    }

    /**
     * @notice Encodes the given data into a Base64 string, with options for file-safe encoding and padding.
     *
     * @param data The input data to be encoded.
     * @param fileSafe If true, uses a file-safe Base64 alphabet (replaces '+' and '/' with '-' and '_').
     * @param noPadding If true, removes the padding characters ('=') from the output.
     * @return result The Base64 encoded string.
     */
    function encode(bytes memory data, bool fileSafe) internal pure returns (string memory result) {
        return encode(data, fileSafe, false);
    }

    /**
     * @notice Decodes a base64 encoded string into bytes.
     *
     * @dev This function uses pure-Solidity decoding. It handles both padded and non-padded base64 strings.
     *
     * @param data The base64 encoded string to decode.
     * @return result The decoded bytes.
     *
     * Steps:
     * 1. Load the length of the input data.
     * 2. Calculate the decoded length based on the input length.
     * 3. Adjust the decoded length if the input is padded.
     * 4. Allocate memory for the result and store the decoded length.
     * 5. Use a lookup logic to decode the base64 string into bytes.
     * 6. Write the decoded bytes into the allocated memory.
     * 7. Return the decoded bytes.
     */
    function decode(string memory data) internal pure returns (bytes memory result) {
        bytes memory src = bytes(data);
        uint256 len = src.length;
        if (len == 0) return "";

        // Reject invalid lengths
        // Valid base64 lengths: mod 4 == 0 when padded, but unpadded can be mod 4 == 2 or 3.
        require(len % 4 != 1, "Invalid base64 input");

        // Count padding characters (if present)
        uint256 pad = 0;
        if (len >= 1 && src[len - 1] == "=") { pad++; }
        if (len >= 2 && src[len - 2] == "=") { pad++; }

        // Compute output length
        uint256 outLen = (len / 4) * 3;
        if (pad > 0) outLen -= pad;
        // For unpadded input where len%4 == 2 or 3, adjust:
        if (len % 4 == 2) outLen = (len / 4) * 3 + 1;
        else if (len % 4 == 3) outLen = (len / 4) * 3 + 2;

        bytes memory out = new bytes(outLen);

        uint256 di = 0;
        uint256 i = 0;

        while (i + 4 <= len) {
            uint8 a = _fromBase64Char(src[i]);
            uint8 b = _fromBase64Char(src[i + 1]);
            uint8 c = _fromBase64Char(src[i + 2]);
            uint8 d = _fromBase64Char(src[i + 3]);

            uint32 triple = (uint32(a) << 18) | (uint32(b) << 12) | (uint32(c) << 6) | uint32(d);

            if (di < outLen) out[di++] = bytes1(uint8(triple >> 16));
            if (di < outLen) out[di++] = bytes1(uint8(triple >> 8));
            if (di < outLen) out[di++] = bytes1(uint8(triple));
            i += 4;
        }

        // Handle remainder (2 or 3 chars unpadded)
        uint256 rem = len - i;
        if (rem == 2) {
            uint8 a = _fromBase64Char(src[i]);
            uint8 b = _fromBase64Char(src[i + 1]);
            uint32 triple = (uint32(a) << 18) | (uint32(b) << 12);
            if (di < outLen) out[di++] = bytes1(uint8(triple >> 16));
        } else if (rem == 3) {
            uint8 a = _fromBase64Char(src[i]);
            uint8 b = _fromBase64Char(src[i + 1]);
            uint8 c = _fromBase64Char(src[i + 2]);
            uint32 triple = (uint32(a) << 18) | (uint32(b) << 12) | (uint32(c) << 6);
            if (di < outLen) out[di++] = bytes1(uint8(triple >> 16));
            if (di < outLen) out[di++] = bytes1(uint8(triple >> 8));
        }

        return out;
    }

    /// @dev Returns the 6-bit value of a base64 character. Accepts both standard and URL-safe characters.
    function _fromBase64Char(bytes1 char) private pure returns (uint8) {
        uint8 c = uint8(char);

        // 'A' - 'Z'
        if (c >= 65 && c <= 90) {
            return c - 65;
        }
        // 'a' - 'z'
        if (c >= 97 && c <= 122) {
            return c - 97 + 26;
        }
        // '0' - '9'
        if (c >= 48 && c <= 57) {
            return c - 48 + 52;
        }
        // '+' (62) or '-' (file-safe)
        if (c == 43 || c == 45) {
            return 62;
        }
        // '/' (63) or '_' (file-safe)
        if (c == 47 || c == 95) {
            return 63;
        }
        // '=' padding yields 0 when used in triple reconstruction; handled in length logic
        if (c == 61) {
            return 0;
        }

        revert("Invalid base64 character");
    }
}