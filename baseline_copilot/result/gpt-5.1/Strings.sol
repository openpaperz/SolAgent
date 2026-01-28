// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Strings {
    error StringsInvalidChar();
    error StringsInvalidAddressFormat();

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        // Calculate number of digits
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        string memory buffer = new string(digits);
        uint256 ptr;
        assembly {
            ptr := add(buffer, add(32, digits))
        }

        unchecked {
            while (value != 0) {
                ptr--;
                uint8 digit = uint8(value % 10);
                bytes1 chr = bytes1(uint8(uint8(bytes1("0")) + digit));
                assembly {
                    mstore8(ptr, chr)
                }
                value /= 10;
            }
        }

        return buffer;
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
        if (value >= 0) {
            return toString(uint256(value));
        }
        // Handle negative values, including type(int256).min
        uint256 temp = uint256(-(value + 1)) + 1;
        string memory unsignedStr = toString(temp);
        bytes memory unsignedBytes = bytes(unsignedStr);
        bytes memory result = new bytes(unsignedBytes.length + 1);
        result[0] = "-";
        for (uint256 i = 0; i < unsignedBytes.length; i++) {
            result[i + 1] = unsignedBytes[i];
        }
        return string(result);
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
        if (value == 0) {
            return "0x00";
        }

        uint256 temp = value;
        uint256 length;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }

        return toHexString(value, length);
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation with fixed length.
     *
     * @param value The uint256 value to be converted to a hexadecimal string.
     * @param length The number of bytes to represent.
     * @return A string representing the hexadecimal value of the input.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";

        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }

        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation.
     *
     * @param addr The address value to be converted to a hexadecimal string.
     * @return A string representing the hexadecimal value of the input.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), 20);
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
        string memory hexString = toHexString(addr); // "0x" + 40 hex chars
        bytes memory buffer = bytes(hexString);
        bytes32 hash = keccak256(abi.encodePacked(_toLowerHexNoPrefix(addr)));

        for (uint256 i = 0; i < 40; i++) {
            uint8 hashByte = uint8(hash[i / 2]);
            uint8 hashNibble;
            if (i % 2 == 0) {
                hashNibble = hashByte >> 4;
            } else {
                hashNibble = hashByte & 0x0f;
            }

            uint256 charIndex = i + 2;
            bytes1 chr = buffer[charIndex];

            if (hashNibble > 7 && chr >= "a" && chr <= "f") {
                buffer[charIndex] = bytes1(uint8(chr) - 32);
            }
        }

        return string(buffer);
    }

    function _toLowerHexNoPrefix(address addr) private pure returns (string memory) {
        bytes memory buffer = new bytes(40);
        uint256 value = uint256(uint160(addr));
        for (uint256 i = 39; i < 40; i--) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
            if (i == 0) break;
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
        if (bytes(a).length != bytes(b).length) {
            return false;
        }
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /**
     * @notice Parses a substring of a string into a `uint256` value.
     *
     * @param input The string from which to parse the substring.
     *
     * @return The parsed `uint256` value.
     */
    function parseUint(string memory input) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseUint(input, 0, bytes(input).length);
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
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed uint256 value if successful, otherwise 0.
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
     */
    function tryParseUint(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, uint256 value) {
        bytes memory strBytes = bytes(input);
        if (end > strBytes.length || begin > end) {
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
     */
    function _tryParseUintUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, uint256 value) {
        bytes memory strBytes = bytes(input);
        uint256 result;
        for (uint256 i = begin; i < end; i++) {
            uint8 chr = uint8(strBytes[i]);
            if (chr < 48 || chr > 57) {
                return (false, 0);
            }
            unchecked {
                result = result * 10 + (chr - 48);
            }
        }
        return (true, result);
    }

    /**
     * @notice Parses a string into an integer.
     *
     * @param input The string to parse.
     * @return The parsed integer value.
     */
    function parseInt(string memory input) internal pure returns (int256) {
        (bool success, int256 value) = tryParseInt(input, 0, bytes(input).length);
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
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed integer value if successful, otherwise 0.
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
     */
    function tryParseInt(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, int256 value) {
        bytes memory strBytes = bytes(input);
        if (end > strBytes.length || begin > end) {
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
     */
    function _tryParseIntUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, int256 value) {
        bytes memory strBytes = bytes(input);
        if (begin == end) {
            return (false, 0);
        }

        bool negative;
        uint256 offset = begin;

        bytes1 first = strBytes[offset];
        if (first == "-") {
            negative = true;
            offset++;
        } else if (first == "+") {
            offset++;
        }

        if (offset >= end) {
            return (false, 0);
        }

        (bool ok, uint256 unsignedVal) = _tryParseUintUncheckedBounds(input, offset, end);
        if (!ok) {
            return (false, 0);
        }

        if (!negative) {
            if (unsignedVal > uint256(type(int256).max)) {
                return (false, 0);
            }
            return (true, int256(unsignedVal));
        }

        // negative case
        if (unsignedVal == 0) {
            return (true, -int256(0));
        }

        if (unsignedVal <= uint256(type(int256).max)) {
            int256 signed = int256(unsignedVal);
            return (true, -signed);
        }

        if (unsignedVal == uint256(type(int256).max) + 1) {
            return (true, type(int256).min);
        }

        return (false, 0);
    }

    /**
     * @notice Parses a hexadecimal string into a uint256 value.
     *
     * @param input The hexadecimal string to parse.
     * @return The parsed uint256 value.
     */
    function parseHexUint(string memory input) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseHexUint(input, 0, bytes(input).length);
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
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed uint256 value if successful, otherwise 0.
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
     */
    function tryParseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, uint256 value) {
        bytes memory strBytes = bytes(input);
        if (end > strBytes.length || begin > end) {
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
        bytes memory strBytes = bytes(input);
        if (begin == end) {
            return (false, 0);
        }

        uint256 offset = begin;

        if (end - offset >= 2 && strBytes[offset] == "0" && (strBytes[offset + 1] == "x" || strBytes[offset + 1] == "X")) {
            offset += 2;
            if (offset >= end) {
                return (false, 0);
            }
        }

        uint256 result;
        for (uint256 i = offset; i < end; i++) {
            uint8 parsed = _tryParseChr(strBytes[i]);
            if (parsed == type(uint8).max) {
                return (false, 0);
            }
            unchecked {
                result = (result << 4) | parsed;
            }
        }

        return (true, result);
    }

    /**
     * @notice Parses a string input to extract an Ethereum address.
     *
     * @param input The string containing the address to be parsed.
     *
     * @return The parsed Ethereum address.
     */
    function parseAddress(string memory input) internal pure returns (address) {
        (bool success, address value) = tryParseAddress(input, 0, bytes(input).length);
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
     *
     * @return success A boolean indicating whether the parsing was successful.
     * @return value The parsed address if successful, otherwise `address(0)`.
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
     */
    function tryParseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, address value) {
        bytes memory strBytes = bytes(input);
        if (end > strBytes.length || begin > end) {
            return (false, address(0));
        }

        if (begin == end) {
            return (false, address(0));
        }

        uint256 offset = begin;
        bool hasPrefix = false;

        if (end - offset >= 2 && strBytes[offset] == "0" && (strBytes[offset + 1] == "x" || strBytes[offset + 1] == "X")) {
            hasPrefix = true;
        }

        uint256 expectedLength = hasPrefix ? 42 : 40;
        if (end - begin != expectedLength) {
            return (false, address(0));
        }

        uint256 hexBegin = hasPrefix ? begin : begin;
        uint256 hexOffset = hasPrefix ? begin : begin;
        if (hasPrefix) {
            hexOffset += 2;
        }

        (bool ok, uint256 parsed) = _tryParseHexUintUncheckedBounds(input, hexOffset, end);
        if (!ok) {
            return (false, address(0));
        }

        if (parsed > type(uint160).max) {
            return (false, address(0));
        }

        return (true, address(uint160(parsed)));
    }

    /**
     * @notice Attempts to parse a single byte character into its corresponding hexadecimal value.
     *
     * @param chr The byte character to be parsed.
     * @return The parsed hexadecimal value as a uint8, or type(uint8).max if the character is not supported.
     */
    function _tryParseChr(bytes1 chr) private pure returns (uint8) {
        uint8 c = uint8(chr);
        if (c >= 48 && c <= 57) {
            return c - 48;
        }
        if (c >= 97 && c <= 102) {
            return c - 87;
        }
        if (c >= 65 && c <= 70) {
            return c - 55;
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
        assembly ("memory-safe") {
            value := mload(add(add(buffer, 32), offset))
        }
    }
}