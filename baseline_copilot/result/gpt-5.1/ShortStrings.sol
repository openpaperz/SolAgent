// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev A compact representation of a short string.
 *
 * The encoding uses a single word where the higher-order 31 bytes store the UTF-8
 * string data (right-padded with zeros) and the lowest-order byte stores the length.
 * A value with length > 31 is considered invalid.
 */
type ShortString is bytes32;

/**
 * @dev Error raised when attempting to convert a string longer than 31 bytes
 * into a {ShortString}.
 */
error StringTooLong(string str);

/**
 * @dev Error raised when operating on an invalid {ShortString}. This happens
 * when the encoded length in the lowest-order byte is greater than 31.
 */
error InvalidShortString(ShortString sstr);

/**
 * @dev Sentinel value used to indicate that the real string is stored externally
 * (e.g. in a dedicated storage slot) because its length is >= 32 bytes.
 */
ShortString constant FALLBACK_SENTINEL = ShortString.wrap(
    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
);

library ShortStrings {
    /**
     * @notice Converts a standard string into a `ShortString` type, which is optimized for storage.
     *
     * @param str The input string to be converted.
     * @return A `ShortString` representation of the input string.
     *
     * Steps:
     * 1. Convert the input string into a bytes array.
     * 2. Check if the length of the bytes array exceeds 31 bytes.
     *    - If it does, revert with an error indicating the string is too long.
     * 3. Encode the bytes array into a `bytes32` value, combining it with the length of the string.
     * 4. Return the `ShortString` representation of the encoded value.
     *
     * @dev This function is useful for optimizing storage when dealing with short strings.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory data = bytes(str);
        uint256 len = data.length;
        if (len > 31) {
            revert StringTooLong(str);
        }

        bytes32 result;
        // Pack the string bytes into the higher 31 bytes of the word and store length in the lowest byte.
        assembly {
            // data points to the location where the first 32 bytes store the length, followed by the data.
            let dataPtr := add(data, 0x20)
            // Load first 32 bytes of data (string is <= 31 bytes so it's entirely in this word).
            let word := mload(dataPtr)
            // Shift left by 8 bits to make room for the length in the lowest byte.
            // This moves the string bytes into the higher 31 bytes of the word.
            word := shl(8, word)
            // OR the length into the last byte.
            result := or(word, len)
        }

        return ShortString.wrap(result);
    }

    /**
     * @notice Converts a `ShortString` type to a `string` type.
     *
     * @param sstr The `ShortString` to be converted to a string.
     * @return str The resulting string representation of the `ShortString`.
     *
     * Steps:
     * 1. Calculate the length of the `ShortString` using `byteLength`.
     * 2. Create a new string with a fixed length of 32 bytes (memory-safe approach).
     * 3. Use inline assembly to store the length and the `ShortString` data in the string's memory.
     * 4. Return the constructed string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        bytes32 raw = ShortString.unwrap(sstr);
        string memory str;

        assembly {
            // Allocate 32 (length) + 32 (data) bytes of memory for the string.
            str := mload(0x40)
            // Store new free memory pointer.
            mstore(0x40, add(str, 0x40))
            // Store length.
            mstore(str, len)
            // The data of the string starts at str + 0x20.
            let dataPtr := add(str, 0x20)
            // Shift the raw data right by 8 bits to drop the length byte and move content back.
            let shifted := shr(8, raw)
            // Store the shifted data word.
            mstore(dataPtr, shifted)
        }

        return str;
    }

    /**
     * @notice Calculates the byte length of a `ShortString` type.
     *
     * @param sstr The `ShortString` instance whose byte length is to be determined.
     * @return result The byte length of the `ShortString`, which must be less than or equal to 31.
     *
     * Steps:
     * 1. Extract the least significant byte from the `ShortString` by performing a bitwise AND operation with 0xFF.
     * 2. Check if the extracted byte length is greater than 31.
     *    - If true, revert with an `InvalidShortString` error.
     * 3. Return the extracted byte length.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256 result) {
        bytes32 raw = ShortString.unwrap(sstr);
        // Extract the lowest-order byte where the length is stored.
        result = uint256(raw) & 0xFF;
        if (result > 31) {
            revert InvalidShortString(sstr);
        }
    }

    /**
     * @notice Converts a string to a `ShortString` if its length is less than 32 bytes.
     *         Otherwise, stores the string in a storage slot and returns a fallback sentinel.
     *
     * @param value The string to be converted or stored.
     * @param store The storage slot where the string will be stored if it exceeds 31 bytes.
     * @return ShortString Returns a `ShortString` if the input string is short, otherwise returns a fallback sentinel.
     *
     * Steps:
     * 1. Check if the length of the input string (`value`) is less than 32 bytes.
     * 2. If true, convert the string to a `ShortString` using `toShortString`.
     * 3. If false, store the string in the provided storage slot (`store`) and return a fallback sentinel (`FALLBACK_SENTINEL`).
     */
    function toShortStringWithFallback(
        string memory value,
        string storage store
    ) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        }

        store = value;
        return FALLBACK_SENTINEL;
    }

    /**
     * @notice Converts a `ShortString` to a string, falling back to a provided storage string if the `ShortString` is a sentinel value.
     *
     * @param value The `ShortString` to convert.
     * @param store The fallback string to use if the `ShortString` is a sentinel value.
     * @return The resulting string, either from the `ShortString` or the fallback storage string.
     *
     * Steps:
     * 1. Check if the `ShortString` is not the fallback sentinel value.
     * 2. If true, convert the `ShortString` to a string using `toString`.
     * 3. If false, return the provided fallback storage string.
     */
    function toStringWithFallback(
        ShortString value,
        string storage store
    ) internal view returns (string memory) {
        if (ShortString.unwrap(value) != ShortString.unwrap(FALLBACK_SENTINEL)) {
            return toString(value);
        }

        return store;
    }

    /**
     * @notice Returns the byte length of a `ShortString` value or falls back to the length of a provided string if the `ShortString` is a fallback sentinel.
     *
     * @param value The `ShortString` value to check.
     * @param store The fallback string storage reference to use if the `ShortString` is a fallback sentinel.
     * @return The byte length of the `ShortString` or the fallback string.
     *
     * Steps:
     * 1. Check if the `ShortString` value is not the fallback sentinel.
     * 2. If true, return the byte length of the `ShortString` using the `byteLength` function.
     * 3. If false, return the byte length of the provided fallback string (`store`).
     */
    function byteLengthWithFallback(
        ShortString value,
        string storage store
    ) internal view returns (uint256) {
        if (ShortString.unwrap(value) != ShortString.unwrap(FALLBACK_SENTINEL)) {
            return byteLength(value);
        }

        return bytes(store).length;
    }
}