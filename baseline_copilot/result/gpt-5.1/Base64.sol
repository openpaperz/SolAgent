// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Base64 encoding and decoding library.
/// @author Solady
library Base64 {
    /// @notice Encodes the given data into a Base64 string, with options for file-safe encoding and padding.
    ///
    /// @param data The input data to be encoded.
    /// @param fileSafe If true, uses a file-safe Base64 alphabet (replaces '+' and '/' with '-' and '_').
    /// @param noPadding If true, removes the padding characters ('=') from the output.
    /// @return result The Base64 encoded string.
    function encode(bytes memory data, bool fileSafe, bool noPadding)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let dataLength := mload(data)
            if dataLength {
                // The encoded length is `4 * ceil(n / 3)`.
                let encodedLength := shl(2, div(add(dataLength, 2), 3))

                // Allocate the result string.
                result := mload(0x40)
                // Set the actual output length; may be reduced later if noPadding is true.
                mstore(result, encodedLength)

                // Pointer to the output buffer (after length).
                let resultPtr := add(result, 0x20)

                // Prepare the encoding table in scratch space.
                // Standard Base64 table.
                let table := add(resultPtr, encodedLength)
                mstore(
                    table,
                    0x4142434445464748494a4b4c4d4e4f505152535455565758595a616263646566
                )
                mstore(
                    add(table, 0x20),
                    0x6768696a6b6c6d6e6f707172737475767778797a303132333435363738392b2f
                )

                // Replace '+' and '/' with '-' and '_' for fileSafe encoding.
                if fileSafe {
                    mstore8(add(table, 0x3e), 0x2d) // '-'
                    mstore8(add(table, 0x3f), 0x5f) // '_'
                }

                // Input pointer, end pointer.
                let dataPtr := add(data, 0x20)
                let endPtr := add(dataPtr, dataLength)

                for {

                } lt(dataPtr, endPtr) {

                } {
                    // Read 3 bytes (24 bits) from input.
                    let input := mload(dataPtr)

                    // Write 4 bytes (4 * 6 bits) to output.
                    mstore8(
                        resultPtr,
                        mload(add(table, and(shr(18, input), 0x3f)))
                    )
                    mstore8(
                        add(resultPtr, 1),
                        mload(add(table, and(shr(12, input), 0x3f)))
                    )
                    mstore8(
                        add(resultPtr, 2),
                        mload(add(table, and(shr(6, input), 0x3f)))
                    )
                    mstore8(
                        add(resultPtr, 3),
                        mload(add(table, and(input, 0x3f)))
                    )

                    dataPtr := add(dataPtr, 3)
                    resultPtr := add(resultPtr, 4)
                }

                // Handle padding.
                let modLen := mod(dataLength, 3)
                if modLen {
                    // Overwrite the extra encoded bytes with '=' or adjust length for noPadding.
                    switch modLen
                    case 1 {
                        // One byte of input -> two actual Base64 chars, two '=' padding.
                        // We over-wrote four chars; we need to pad the last two.
                        if noPadding {
                            // Reduce length by 2.
                            encodedLength := sub(encodedLength, 2)
                            mstore(result, encodedLength)
                        } else {
                            mstore8(sub(resultPtr, 1), 0x3d) // '='
                            mstore8(sub(resultPtr, 2), 0x3d) // '='
                        }
                    }
                    case 2 {
                        // Two bytes of input -> three actual Base64 chars, one '=' padding.
                        if noPadding {
                            // Reduce length by 1.
                            encodedLength := sub(encodedLength, 1)
                            mstore(result, encodedLength)
                        } else {
                            mstore8(sub(resultPtr, 1), 0x3d) // '='
                        }
                    }
                }

                // Move free memory pointer.
                mstore(0x40, add(add(result, 0x20), encodedLength))
            }
            if iszero(result) {
                // Return empty string for empty input.
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x20))
            }
        }
    }

    /// @notice Encodes the given data into a Base64 string (standard alphabet, with padding).
    ///
    /// @param data The input data to be encoded.
    /// @return result The Base64 encoded string.
    function encode(bytes memory data) internal pure returns (string memory result) {
        result = encode(data, false, false);
    }

    /// @notice Encodes the given data into a Base64 string, with optional file-safe encoding (with padding).
    ///
    /// @param data The input data to be encoded.
    /// @param fileSafe If true, uses a file-safe Base64 alphabet (replaces '+' and '/' with '-' and '_').
    /// @return result The Base64 encoded string.
    function encode(bytes memory data, bool fileSafe)
        internal
        pure
        returns (string memory result)
    {
        result = encode(data, fileSafe, false);
    }

    /// @notice Decodes a base64 encoded string into bytes.
    ///
    /// @dev This function uses inline assembly to efficiently decode the base64 string.
    /// It handles both padded and non-padded base64 strings.
    ///
    /// @param data The base64 encoded string to decode.
    /// @return result The decoded bytes.
    function decode(string memory data) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let dataPtr := add(data, 0x20)
            let dataLength := mload(data)

            if iszero(dataLength) {
                // Return empty bytes for empty input.
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x20))
            }
            if dataLength {
                // Build the decoding table in scratch space.
                let table := mload(0x40)
                // Initialize all entries to 0xFF (invalid).
                // 0..255 -> 256 bytes -> 8 words
                for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                    mstore(add(table, shl(5, i)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                }

                // Fill in the valid mapping.
                // 'A'-'Z' -> 0..25
                for { let c := 0x41 } lt(c, 0x5b) { c := add(c, 1) } {
                    mstore8(add(table, c), sub(c, 0x41))
                }
                // 'a'-'z' -> 26..51
                for { let c := 0x61 } lt(c, 0x7b) { c := add(c, 1) } {
                    mstore8(add(table, c), add(sub(c, 0x61), 26))
                }
                // '0'-'9' -> 52..61
                for { let c := 0x30 } lt(c, 0x3a) { c := add(c, 1) } {
                    mstore8(add(table, c), add(sub(c, 0x30), 52))
                }
                // '+' or '-' -> 62
                mstore8(add(table, 0x2b), 62)
                mstore8(add(table, 0x2d), 62)
                // '/' or '_' -> 63
                mstore8(add(table, 0x2f), 63)
                mstore8(add(table, 0x5f), 63)
                // '=' -> padding marker 0
                mstore8(add(table, 0x3d), 0)

                // Compute the decoded length.
                // Each 4 bytes of input give 3 bytes of output.
                let decodedLength := div(mul(dataLength, 3), 4)

                // Account for padding '=' characters at the end.
                // If padded, last one or two chars are '='.
                if eq(mload(sub(add(dataPtr, dataLength), 1)), 0x3d00000000000000000000000000000000000000000000000000000000000000) {
                    decodedLength := sub(decodedLength, 1)
                    if eq(mload(sub(add(dataPtr, dataLength), 2)), 0x3d00000000000000000000000000000000000000000000000000000000000000) {
                        decodedLength := sub(decodedLength, 1)
                    }
                }

                // Allocate result.
                result := add(table, 0x100) // reuse memory after table
                mstore(result, decodedLength)
                let resultPtr := add(result, 0x20)

                // End pointer for input.
                let endPtr := add(dataPtr, dataLength)

                for {

                } lt(dataPtr, endPtr) {

                } {
                    // Read 4 input characters.
                    let input := mload(dataPtr)

                    // Extract bytes.
                    let c0 := byte(0, input)
                    let c1 := byte(1, input)
                    let c2 := byte(2, input)
                    let c3 := byte(3, input)

                    // Lookup 6-bit values.
                    let v0 := byte(0, mload(add(table, c0)))
                    let v1 := byte(0, mload(add(table, c1)))
                    let v2 := byte(0, mload(add(table, c2)))
                    let v3 := byte(0, mload(add(table, c3)))

                    // Pack into 24 bits.
                    let triple := or(
                        or(shl(18, v0), shl(12, v1)),
                        or(shl(6, v2), v3)
                    )

                    // Write the 3 bytes, but be careful about padding.
                    // We rely on decodedLength to avoid writing beyond the end.
                    // First byte.
                    if gt(decodedLength, 0) {
                        mstore8(resultPtr, byte(2, triple))
                        resultPtr := add(resultPtr, 1)
                        decodedLength := sub(decodedLength, 1)
                    }
                    // Second byte.
                    if gt(decodedLength, 0) {
                        mstore8(resultPtr, byte(1, triple))
                        resultPtr := add(resultPtr, 1)
                        decodedLength := sub(decodedLength, 1)
                    }
                    // Third byte.
                    if gt(decodedLength, 0) {
                        mstore8(resultPtr, byte(0, triple))
                        resultPtr := add(resultPtr, 1)
                        decodedLength := sub(decodedLength, 1)
                    }

                    dataPtr := add(dataPtr, 4)
                }

                // Move free memory pointer past result.
                mstore(0x40, resultPtr)
            }
        }
    }
}