// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for encoding and decoding Base64.
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
    function encode(bytes memory data, bool fileSafe, bool noPadding)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let dataLength := mload(data)

            if dataLength {
                // Multiply by 4/3 rounded up.
                let encodedLength := shl(2, div(add(dataLength, 2), 3))

                // Add some extra buffer space for safety.
                result := mload(0x40)
                mstore(0x40, add(result, add(encodedLength, 0x20)))
                mstore(result, encodedLength)

                // Prepare the lookup table.
                let tablePtr := add(result, 0x20)
                let dataPtr := add(data, 0x20)
                let endPtr := add(dataPtr, dataLength)

                // Store the Base64 table in scratch space.
                // Cheaper than allocating memory.
                mstore(0x1f, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef")
                mstore(0x3f, "ghijklmnopqrstuvwxyz0123456789+/")

                // If file-safe, replace '+' and '/' with '-' and '_'.
                if fileSafe {
                    mstore(0x3e, "-_")
                }

                // Process each 3-byte chunk.
                for {} lt(dataPtr, endPtr) {} {
                    dataPtr := add(dataPtr, 3)
                    let input := mload(sub(dataPtr, 3))

                    // Encode 3 bytes into 4 Base64 characters.
                    mstore8(tablePtr, mload(and(shr(18, input), 0x3F)))
                    mstore8(add(tablePtr, 1), mload(and(shr(12, input), 0x3F)))
                    mstore8(add(tablePtr, 2), mload(and(shr(6, input), 0x3F)))
                    mstore8(add(tablePtr, 3), mload(and(input, 0x3F)))

                    tablePtr := add(tablePtr, 4)
                }

                // Handle padding.
                let paddingBytes := mod(sub(0, dataLength), 3)
                if paddingBytes {
                    let mod3 := mod(dataLength, 3)
                    // Adjust the last encoded chunk based on data length.
                    if eq(mod3, 1) {
                        mstore8(sub(tablePtr, 2), 0x3d) // '='
                        mstore8(sub(tablePtr, 1), 0x3d)
                    }
                    if eq(mod3, 2) {
                        mstore8(sub(tablePtr, 1), 0x3d)
                    }

                    // Remove padding if requested.
                    if noPadding {
                        mstore(result, sub(encodedLength, paddingBytes))
                    }
                }
            }
        }
    }

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
    function encode(bytes memory data, bool fileSafe)
        internal
        pure
        returns (string memory result)
    {
        return encode(data, fileSafe, false);
    }

    /**
     * @notice Decodes a base64 encoded string into bytes.
     *
     * @dev This function uses inline assembly to efficiently decode the base64 string.
     * It handles both padded and non-padded base64 strings.
     *
     * @param data The base64 encoded string to decode.
     * @return result The decoded bytes.
     *
     * Steps:
     * 1. Load the length of the input data.
     * 2. Calculate the decoded length based on the input length.
     * 3. Adjust the decoded length if the input is padded.
     * 4. Allocate memory for the result and store the decoded length.
     * 5. Use a lookup table to decode the base64 string into bytes.
     * 6. Write the decoded bytes into the allocated memory.
     * 7. Handle memory cleanup and return the decoded bytes.
     *
     * Assembly Details:
     * - The function uses a custom lookup table stored in memory to map base64 characters to their corresponding values.
     * - It processes 4 bytes of input at a time and writes 3 bytes of output.
     * - The function ensures that memory is properly allocated and cleaned up after decoding.
     */
    function decode(string memory data) internal pure returns (bytes memory result) {
        assembly {
            let dataLength := mload(data)

            if dataLength {
                let decodedLength := mul(div(dataLength, 4), 3)
                let dataPtr := add(data, 0x20)
                let endPtr := add(dataPtr, dataLength)

                // Check for padding and adjust decoded length.
                let padding := 0
                if gt(dataLength, 1) {
                    if eq(and(mload(sub(endPtr, 1)), 0xff), 0x3d) {
                        padding := add(padding, 1)
                        if eq(and(mload(sub(endPtr, 2)), 0xff), 0x3d) {
                            padding := add(padding, 1)
                        }
                    }
                }
                decodedLength := sub(decodedLength, padding)

                // Allocate memory for the result.
                result := mload(0x40)
                mstore(0x40, add(result, add(decodedLength, 0x20)))
                mstore(result, decodedLength)

                // Prepare the lookup table (inverse Base64 mapping).
                // We store a lookup table in scratch space.
                // Characters not in Base64 alphabet map to 0xff.
                let tablePtr := 0x00

                // Initialize lookup table to 0xff (invalid).
                for { let i := 0 } lt(i, 0x80) { i := add(i, 0x20) } {
                    mstore(add(tablePtr, i), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                }

                // Set valid Base64 character mappings.
                // 'A'-'Z' (65-90) -> 0-25
                for { let i := 0 } lt(i, 26) { i := add(i, 1) } {
                    mstore8(add(tablePtr, add(65, i)), i)
                }

                // 'a'-'z' (97-122) -> 26-51
                for { let i := 0 } lt(i, 26) { i := add(i, 1) } {
                    mstore8(add(tablePtr, add(97, i)), add(26, i))
                }

                // '0'-'9' (48-57) -> 52-61
                for { let i := 0 } lt(i, 10) { i := add(i, 1) } {
                    mstore8(add(tablePtr, add(48, i)), add(52, i))
                }

                // '+' (43) -> 62, '/' (47) -> 63
                mstore8(add(tablePtr, 43), 62)
                mstore8(add(tablePtr, 47), 63)

                // '-' (45) -> 62, '_' (95) -> 63 (file-safe variants)
                mstore8(add(tablePtr, 45), 62)
                mstore8(add(tablePtr, 95), 63)

                // Decode the data.
                let resultPtr := add(result, 0x20)
                for {} lt(dataPtr, endPtr) {} {
                    // Read 4 Base64 characters.
                    let input := 0
                    let validChars := 0

                    for { let i := 0 } lt(i, 4) { i := add(i, 1) } {
                        if lt(dataPtr, endPtr) {
                            let char := and(mload(dataPtr), 0xff)
                            dataPtr := add(dataPtr, 1)

                            // Skip invalid characters (padding or whitespace).
                            if iszero(eq(char, 0x3d)) {
                                let value := mload8(add(tablePtr, char))
                                if lt(value, 64) {
                                    input := or(input, shl(sub(18, mul(validChars, 6)), value))
                                    validChars := add(validChars, 1)
                                }
                            }
                        }
                    }

                    // Write decoded bytes (3 bytes from 4 Base64 characters).
                    if gt(validChars, 1) {
                        mstore8(resultPtr, shr(16, input))
                        resultPtr := add(resultPtr, 1)
                    }
                    if gt(validChars, 2) {
                        mstore8(resultPtr, and(shr(8, input), 0xff))
                        resultPtr := add(resultPtr, 1)
                    }
                    if gt(validChars, 3) {
                        mstore8(resultPtr, and(input, 0xff))
                        resultPtr := add(resultPtr, 1)
                    }
                }
            }
        }
    }
}
