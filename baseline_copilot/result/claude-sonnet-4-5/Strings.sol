// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "./Math.sol";
import {SignedMath} from "./SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    error StringsInvalidChar();

    error StringsInvalidAddressFormat();

    /**
     * @notice Converts a `uint256` value to its ASCII `string` representation.
     *
     * @param value The `uint256` value to be converted to a string.
     * @return A string representation of the provided `uint256` value.
     *
     * Steps:
     * 1. Calculate the length of the string representation by taking the logarithm base 10 of the value and adding 1.
     * 2. Allocate a new string buffer with the calculated length.
     * 3. Use assembly to get a pointer to the end of the buffer.
     * 4. Loop through the value, converting each digit to its ASCII representation and storing it in the buffer.
     * 5. Decrement the pointer and divide the value by 10 in each iteration.
     * 6. Break the loop when the value becomes 0.
     * 7. Return the constructed string buffer.
     *
     * Note: This function uses unchecked arithmetic for gas optimization.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @notice Converts a signed integer to its string representation, including the sign.
     *
     * @param value The signed integer to convert to a string.
     * @return A string representation of the signed integer, including the sign.
     *
     * Steps:
     * 1. Check if the value is negative.
     * 2. If negative, prepend a "-" sign to the string representation of the absolute value.
     * 3. If positive, return the string representation of the absolute value directly.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation.
     *
     * @param value The uint256 value to be converted to a hexadecimal string.
     * @return A string representing the hexadecimal value of the input.
     *
     * Steps:
     * 1. Calculate the length of the hexadecimal string using `Math.log256(value) + 1`.
     * 2. Call the `toHexString` function with the value and the calculated length.
     * 3. Return the resulting hexadecimal string.
     *
     * Note: The function uses `unchecked` to avoid overflow checks, assuming the input is valid.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation.
     *
     * @param value The uint256 value to be converted to a hexadecimal string.
     * @return A string representing the hexadecimal value of the input.
     *
     * Steps:
     * 1. Calculate the length of the hexadecimal string using `Math.log256(value) + 1`.
     * 2. Call the `toHexString` function with the value and the calculated length.
     * 3. Return the resulting hexadecimal string.
     *
     * Note: The function uses `unchecked` to avoid overflow checks, assuming the input is valid.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation.
     *
     * @param value The uint256 value to be converted to a hexadecimal string.
     * @return A string representing the hexadecimal value of the input.
     *
     * Steps:
     * 1. Calculate the length of the hexadecimal string using `Math.log256(value) + 1`.
     * 2. Call the `toHexString` function with the value and the calculated length.
     * 3. Return the resulting hexadecimal string.
     *
     * Note: The function uses `unchecked` to avoid overflow checks, assuming the input is valid.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @notice Converts an Ethereum address into a checksummed hexadecimal string.
     *
     * @dev This function ensures that the address string follows the EIP-55 checksum standard,
     * which helps prevent errors when manually entering addresses. The checksum is calculated
     * by hashing the address and using the hash to determine which characters should be uppercase.
     *
     * @param addr The Ethereum address to convert into a checksummed hexadecimal string.
     * @return A checksummed hexadecimal string representation of the address.
     *
     * Steps:
     * 1. Convert the address to a hexadecimal string.
     * 2. Hash the hexadecimal part of the string (excluding the "0x" prefix and length).
     * 3. Iterate through the hexadecimal string and adjust the case of characters based on the hash:
     *    - If the corresponding hash bit is greater than 7 and the character is lowercase, convert it to uppercase.
     * 4. Return the checksummed hexadecimal string.
     */
    function toChecksumHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = bytes(toHexString(addr));

        // hash the hex part of the string (skip length and 0x prefix)
        uint256 hashValue;
        /// @solidity memory-safe-assembly
        assembly {
            hashValue := shr(96, keccak256(add(buffer, 0x22), 40))
        }

        for (uint256 i = 41; i > 1; --i) {
            uint8 digit = uint8(buffer[i]);
            // 0x61 is 'a', 0x66 is 'f'
            if (digit > 0x60 && digit < 0x67) {
                if (hashValue & 0xf > 7) {
                    buffer[i] = bytes1(digit - 32);
                }
                hashValue >>= 4;
            }
        }
        return string(buffer);
    }

    /**
     * @notice Compares two strings for equality.
     *
     * Steps:
     * 1. Check if the lengths of the two strings are equal.
     * 2. Compare the keccak256 hash of the two strings.
     * 3. Return true if both the length and hash match, otherwise return false.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /**
     * @notice Parses a substring of a string into a `uint256` value.
     *
     * @param input The string from which to parse the substring.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return The parsed `uint256` value.
     *
     * Steps:
     * 1. Attempt to parse the substring using `tryParseUint`.
     * 2. If parsing fails, revert with the error `StringsInvalidChar`.
     * 3. Return the parsed `uint256` value if successful.
     */
    function parseUint(string memory input) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseUint(input);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @notice Parses a substring of a string into a `uint256` value.
     *
     * @param input The string from which to parse the substring.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return The parsed `uint256` value.
     *
     * Steps:
     * 1. Attempt to parse the substring using `tryParseUint`.
     * 2. If parsing fails, revert with the error `StringsInvalidChar`.
     * 3. Return the parsed `uint256` value if successful.
     */
    function parseUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseUint(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @notice Attempts to parse a substring of a string into a uint256 value.
     *
     * @param input The input string to parse.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed uint256 value if successful, otherwise 0.
     *
     * Steps:
     * 1. Check if the provided `end` index is out of bounds or if `begin` is greater than `end`.
     * 2. If either condition is true, return `false` and `0`.
     * 3. Otherwise, call the internal `_tryParseUintUncheckedBounds` function to parse the substring.
     */
    function tryParseUint(string memory input) internal pure returns (bool success, uint256 value) {
        return tryParseUint(input, 0, bytes(input).length);
    }

    /**
     * @notice Attempts to parse a substring of a string into a uint256 value.
     *
     * @param input The input string to parse.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed uint256 value if successful, otherwise 0.
     *
     * Steps:
     * 1. Check if the provided `end` index is out of bounds or if `begin` is greater than `end`.
     * 2. If either condition is true, return `false` and `0`.
     * 3. Otherwise, call the internal `_tryParseUintUncheckedBounds` function to parse the substring.
     */
    function tryParseUint(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, uint256 value) {
        if (end > bytes(input).length || begin > end) {
            return (false, 0);
        }
        return _tryParseUintUncheckedBounds(input, begin, end);
    }

    /**
     * @notice Attempts to parse a substring of a string into an unsigned integer without checking bounds.
     *
     * @param input The input string to parse.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed unsigned integer value if successful, otherwise 0.
     *
     * Steps:
     * 1. Convert the input string into a byte array.
     * 2. Initialize a result variable to store the parsed integer.
     * 3. Iterate over the specified substring range.
     * 4. For each character, attempt to parse it into a digit (0-9).
     * 5. If a character is not a digit, return `false` and `0`.
     * 6. Multiply the current result by 10 and add the parsed digit.
     * 7. Return `true` and the parsed integer if all characters are valid digits.
     */
    function _tryParseUintUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, uint256 value) {
        bytes memory buffer = bytes(input);
        uint256 result = 0;

        for (uint256 i = begin; i < end; i++) {
            uint8 chr = uint8(buffer[i]);
            if (chr < 0x30 || chr > 0x39) {
                return (false, 0);
            }
            unchecked {
                result = result * 10 + (chr - 0x30);
            }
        }
        return (true, result);
    }

    /**
     * @notice Parses a string into an integer within a specified range.
     *
     * @param input The string to parse.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     * @return The parsed integer value.
     *
     * Steps:
     * 1. Attempt to parse the substring from `begin` to `end` in the input string into an integer using `tryParseInt`.
     * 2. If parsing fails, revert with the error "StringsInvalidChar".
     * 3. Return the parsed integer value if successful.
     */
    function parseInt(string memory input) internal pure returns (int256) {
        (bool success, int256 value) = tryParseInt(input);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @notice Parses a string into an integer within a specified range.
     *
     * @param input The string to parse.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     * @return The parsed integer value.
     *
     * Steps:
     * 1. Attempt to parse the substring from `begin` to `end` in the input string into an integer using `tryParseInt`.
     * 2. If parsing fails, revert with the error "StringsInvalidChar".
     * 3. Return the parsed integer value if successful.
     */
    function parseInt(string memory input, uint256 begin, uint256 end) internal pure returns (int256) {
        (bool success, int256 value) = tryParseInt(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @notice Attempts to parse an integer from a substring of the input string.
     *
     * @param input The input string from which to parse the integer.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed integer value if successful, otherwise 0.
     *
     * Steps:
     * 1. Check if the provided indices are out of bounds or invalid.
     * 2. If invalid, return `false` and `0`.
     * 3. Otherwise, call the internal `_tryParseIntUncheckedBounds` function to parse the integer.
     */
    function tryParseInt(string memory input) internal pure returns (bool success, int256 value) {
        return tryParseInt(input, 0, bytes(input).length);
    }

    /**
     * @notice Attempts to parse an integer from a substring of the input string.
     *
     * @param input The input string from which to parse the integer.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed integer value if successful, otherwise 0.
     *
     * Steps:
     * 1. Check if the provided indices are out of bounds or invalid.
     * 2. If invalid, return `false` and `0`.
     * 3. Otherwise, call the internal `_tryParseIntUncheckedBounds` function to parse the integer.
     */
    function tryParseInt(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, int256 value) {
        if (end > bytes(input).length || begin > end) {
            return (false, 0);
        }
        return _tryParseIntUncheckedBounds(input, begin, end);
    }

    /**
     * @notice Attempts to parse a substring of a string into an integer without checking bounds.
     *
     * @param input The input string to parse.
     * @param begin The starting index of the substring to parse.
     * @param end The ending index of the substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed integer value, or 0 if parsing failed.
     *
     * Steps:
     * 1. Convert the input string into a byte array for easier manipulation.
     * 2. Check if the substring contains a negative or positive sign at the beginning.
     * 3. Determine the offset for the start of the numeric part of the substring.
     * 4. Attempt to parse the numeric part of the substring into an unsigned integer.
     * 5. If the parsing is successful and the value is within the valid range for int256:
     *    - Return the parsed value with the appropriate sign.
     *    - Handle the special case for the minimum int256 value.
     * 6. If parsing fails or the value is out of bounds, return (false, 0).
     */
    function _tryParseIntUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, int256 value) {
        bytes memory buffer = bytes(input);

        if (begin == end) {
            return (false, 0);
        }

        bool isNegative = buffer[begin] == "-";
        uint256 offset = (isNegative || buffer[begin] == "+") ? 1 : 0;

        (bool parseSuccess, uint256 absValue) = _tryParseUintUncheckedBounds(input, begin + offset, end);

        if (!parseSuccess) {
            return (false, 0);
        }

        unchecked {
            if (isNegative) {
                // Special case for type(int256).min
                if (absValue == uint256(type(int256).max) + 1) {
                    return (true, type(int256).min);
                }
                if (absValue <= uint256(type(int256).max)) {
                    return (true, -int256(absValue));
                }
            } else {
                if (absValue <= uint256(type(int256).max)) {
                    return (true, int256(absValue));
                }
            }
        }

        return (false, 0);
    }

    /**
     * @notice Parses a hexadecimal string into a uint256 value within a specified range.
     *
     * @param input The hexadecimal string to parse.
     * @param begin The starting index (inclusive) of the substring to parse.
     * @param end The ending index (exclusive) of the substring to parse.
     * @return The parsed uint256 value.
     *
     * Steps:
     * 1. Attempt to parse the hexadecimal substring using `tryParseHexUint`.
     * 2. If parsing fails, revert with the error `StringsInvalidChar`.
     * 3. Return the parsed uint256 value.
     */
    function parseHexUint(string memory input) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseHexUint(input);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @notice Parses a hexadecimal string into a uint256 value within a specified range.
     *
     * @param input The hexadecimal string to parse.
     * @param begin The starting index (inclusive) of the substring to parse.
     * @param end The ending index (exclusive) of the substring to parse.
     * @return The parsed uint256 value.
     *
     * Steps:
     * 1. Attempt to parse the hexadecimal substring using `tryParseHexUint`.
     * 2. If parsing fails, revert with the error `StringsInvalidChar`.
     * 3. Return the parsed uint256 value.
     */
    function parseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseHexUint(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @notice Attempts to parse a hexadecimal string into a uint256 value within specified bounds.
     *
     * @param input The input string containing the hexadecimal value.
     * @param begin The starting index (inclusive) of the hexadecimal substring to parse.
     * @param end The ending index (exclusive) of the hexadecimal substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed uint256 value if successful, otherwise 0.
     *
     * Steps:
     * 1. Check if the provided `end` index is out of bounds or if `begin` is greater than `end`.
     *    - If true, return `(false, 0)`.
     * 2. Otherwise, call the internal `_tryParseHexUintUncheckedBounds` function to parse the hexadecimal substring.
     * 3. Return the result of the parsing attempt.
     */
    function tryParseHexUint(string memory input) internal pure returns (bool success, uint256 value) {
        return tryParseHexUint(input, 0, bytes(input).length);
    }

    /**
     * @notice Attempts to parse a hexadecimal string into a uint256 value within specified bounds.
     *
     * @param input The input string containing the hexadecimal value.
     * @param begin The starting index (inclusive) of the hexadecimal substring to parse.
     * @param end The ending index (exclusive) of the hexadecimal substring to parse.
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed uint256 value if successful, otherwise 0.
     *
     * Steps:
     * 1. Check if the provided `end` index is out of bounds or if `begin` is greater than `end`.
     *    - If true, return `(false, 0)`.
     * 2. Otherwise, call the internal `_tryParseHexUintUncheckedBounds` function to parse the hexadecimal substring.
     * 3. Return the result of the parsing attempt.
     */
    function tryParseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, uint256 value) {
        if (end > bytes(input).length || begin > end) {
            return (false, 0);
        }
        return _tryParseHexUintUncheckedBounds(input, begin, end);
    }

    /**
     * @notice Attempts to parse a hexadecimal string into a uint256 value within specified bounds.
     *
     * Steps:
     * 1. Convert the input string into a byte array for easier manipulation.
     * 2. Check if the input string has a "0x" prefix and adjust the starting index accordingly.
     * 3. Initialize a result variable to store the parsed value.
     * 4. Iterate through the byte array, starting from the adjusted index, and parse each character.
     * 5. If any character is not a valid hexadecimal digit, return `false` and `0`.
     * 6. Multiply the result by 16 (equivalent to a left shift by 4 bits) and add the parsed digit.
     * 7. Use `unchecked` to avoid overflow checks since the multiplication and addition are safe within the bounds.
     * 8. Return `true` and the parsed value if the entire string is successfully parsed.
     */
    function _tryParseHexUintUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, uint256 value) {
        bytes memory buffer = bytes(input);

        uint256 startIndex = begin;
        if (end > begin + 1 && buffer[begin] == "0" && (buffer[begin + 1] == "x" || buffer[begin + 1] == "X")) {
            startIndex = begin + 2;
        }

        uint256 result = 0;
        for (uint256 i = startIndex; i < end; i++) {
            uint8 chr = _tryParseChr(buffer[i]);
            if (chr == type(uint8).max) {
                return (false, 0);
            }
            unchecked {
                result = (result << 4) | chr;
            }
        }
        return (true, result);
    }

    /**
     * @notice Parses a string input to extract an Ethereum address within the specified range.
     *
     * @param input The string containing the address to be parsed.
     * @param begin The starting index in the string where the address extraction should begin.
     * @param end The ending index in the string where the address extraction should end.
     *
     * @return The parsed Ethereum address.
     *
     * Steps:
     * 1. Attempt to parse the address from the input string within the specified range using `tryParseAddress`.
     * 2. If parsing fails, revert with the error "StringsInvalidAddressFormat".
     * 3. Return the successfully parsed address.
     */
    function parseAddress(string memory input) internal pure returns (address) {
        (bool success, address value) = tryParseAddress(input);
        if (!success) revert StringsInvalidAddressFormat();
        return value;
    }

    /**
     * @notice Parses a string input to extract an Ethereum address within the specified range.
     *
     * @param input The string containing the address to be parsed.
     * @param begin The starting index in the string where the address extraction should begin.
     * @param end The ending index in the string where the address extraction should end.
     *
     * @return The parsed Ethereum address.
     *
     * Steps:
     * 1. Attempt to parse the address from the input string within the specified range using `tryParseAddress`.
     * 2. If parsing fails, revert with the error "StringsInvalidAddressFormat".
     * 3. Return the successfully parsed address.
     */
    function parseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (address) {
        (bool success, address value) = tryParseAddress(input, begin, end);
        if (!success) revert StringsInvalidAddressFormat();
        return value;
    }

    /**
     * @notice Attempts to parse an Ethereum address from a substring within a given input string.
     *
     * @param input The input string containing the potential address.
     * @param begin The starting index of the substring within the input string.
     * @param end The ending index of the substring within the input string.
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed address if successful, otherwise `address(0)`.
     *
     * Steps:
     * 1. Check if the provided `begin` and `end` indices are valid within the input string.
     *    - If not, return `(false, address(0))`.
     * 2. Determine if the substring has a "0x" prefix.
     *    - This is done by checking the first two characters of the substring.
     * 3. Calculate the expected length of the address substring based on whether it has a prefix.
     *    - 40 characters for the address + 2 characters for the "0x" prefix if present.
     * 4. Verify that the substring length matches the expected length.
     *    - If it does, attempt to parse the substring as a hexadecimal number.
     *    - If successful, convert the parsed number to an address and return it.
     *    - If not, return `(false, address(0))`.
     * 5. If the substring length does not match the expected length, return `(false, address(0))`.
     */
    function tryParseAddress(string memory input) internal pure returns (bool success, address value) {
        return tryParseAddress(input, 0, bytes(input).length);
    }

    /**
     * @notice Attempts to parse an Ethereum address from a substring within a given input string.
     *
     * @param input The input string containing the potential address.
     * @param begin The starting index of the substring within the input string.
     * @param end The ending index of the substring within the input string.
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed address if successful, otherwise `address(0)`.
     *
     * Steps:
     * 1. Check if the provided `begin` and `end` indices are valid within the input string.
     *    - If not, return `(false, address(0))`.
     * 2. Determine if the substring has a "0x" prefix.
     *    - This is done by checking the first two characters of the substring.
     * 3. Calculate the expected length of the address substring based on whether it has a prefix.
     *    - 40 characters for the address + 2 characters for the "0x" prefix if present.
     * 4. Verify that the substring length matches the expected length.
     *    - If it does, attempt to parse the substring as a hexadecimal number.
     *    - If successful, convert the parsed number to an address and return it.
     *    - If not, return `(false, address(0))`.
     * 5. If the substring length does not match the expected length, return `(false, address(0))`.
     */
    function tryParseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, address value) {
        if (end > bytes(input).length || begin > end) {
            return (false, address(0));
        }

        bytes memory buffer = bytes(input);
        bool hasPrefix = (end > begin + 1 && buffer[begin] == "0" && (buffer[begin + 1] == "x" || buffer[begin + 1] == "X"));
        uint256 expectedLength = hasPrefix ? 42 : 40;

        if (end - begin == expectedLength) {
            (bool parseSuccess, uint256 parsedValue) = _tryParseHexUintUncheckedBounds(input, begin, end);
            if (parseSuccess) {
                return (true, address(uint160(parsedValue)));
            }
        }

        return (false, address(0));
    }

    /**
     * @notice Attempts to parse a single byte character into its corresponding hexadecimal value.
     * 
     * The function handles three cases:
     * 1. If the character is a digit (0-9), it returns the corresponding integer value.
     * 2. If the character is a lowercase letter (a-f), it returns the corresponding hexadecimal value.
     * 3. If the character is an uppercase letter (A-F), it returns the corresponding hexadecimal value.
     * 
     * If the character does not fall into any of the above categories, the function returns the maximum value of uint8 (255).
     * 
     * @param chr The byte character to be parsed.
     * @return The parsed hexadecimal value as a uint8, or type(uint8).max if the character is not supported.
     */
    function _tryParseChr(bytes1 chr) private pure returns (uint8) {
        uint8 c = uint8(chr);
        if (c >= 0x30 && c <= 0x39) {
            return c - 0x30;
        } else if (c >= 0x61 && c <= 0x66) {
            return c - 0x57;
        } else if (c >= 0x41 && c <= 0x46) {
            return c - 0x37;
        }
        return type(uint8).max;
    }

    /**
     * @notice Reads a bytes32 value from a specific offset within a bytes memory buffer.
     * @dev This function is marked as "memory-safe" in assembly, but it is not memory safe in the general case.
     *      It assumes that all calls to this function are within bounds.
     * @param buffer The bytes memory buffer from which to read the value.
     * @param offset The offset within the buffer to read the value from.
     * @return value The bytes32 value read from the specified offset in the buffer.
     */
    function _unsafeReadBytesOffset(bytes memory buffer, uint256 offset) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := mload(add(buffer, add(0x20, offset)))
        }
    }
}
