// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Strings {
    error StringsInvalidChar();
    error StringsInvalidAddressFormat();

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @notice Converts a `uint256` value to its ASCII `string` representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 idx = digits;
        while (value != 0) {
            idx -= 1;
            buffer[idx] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @notice Converts a signed integer to its string representation, including the sign.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        if (value < 0) {
            // Handle negative
            // Special case: int256 min
            if (value == type(int256).min) {
                // int256.min = -2**255; its abs value doesn't fit into int256
                // Convert absolute value using uint256
                uint256 abs = uint256(type(int256).max) + 1; // 2**255
                string memory s = toString(abs);
                bytes memory b = bytes(s);
                bytes memory out = new bytes(b.length + 1);
                out[0] = "-";
                for (uint256 i = 0; i < b.length; ++i) out[i + 1] = b[i];
                return string(out);
            } else {
                int256 neg = -value;
                return string(abi.encodePacked("-", toString(uint256(uint256(neg)))));
            }
        } else {
            return toString(uint256(uint256(value)));
        }
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 + 2 * length);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = buffer.length; i > 2; ) {
            unchecked { i -= 1; }
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }

    /**
     * @notice Converts an address to its non-checksummed hex string ("0x" + 40 hex chars).
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), 20);
    }

    /**
     * @notice Converts an Ethereum address into a checksummed hexadecimal string (EIP-55).
     */
    function toChecksumHexString(address addr) internal pure returns (string memory) {
        string memory hexStr = toHexString(addr); // "0x" + 40 chars, lowercase
        bytes memory hexBytes = bytes(hexStr);
        // compute keccak256 of the lower-case hex string without '0x'
        bytes memory hexPart = new bytes(40);
        for (uint256 i = 0; i < 40; ++i) {
            hexPart[i] = hexBytes[i + 2];
        }
        bytes32 hash = keccak256(abi.encodePacked(hexPart));
        bytes memory out = new bytes(2 + 40);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i = 0; i < 40; ++i) {
            bytes1 ch = hexPart[i];
            // determine the relevant nibble from the hash
            uint8 hashByte = uint8(hash[i / 2]);
            uint8 hashNibble;
            if (i % 2 == 0) {
                hashNibble = uint8(hashByte >> 4);
            } else {
                hashNibble = uint8(hashByte & 0x0f);
            }
            // if character is a-f and hash nibble > 7 then uppercase
            if (ch >= bytes1(uint8(97)) && ch <= bytes1(uint8(102)) && hashNibble > 7) {
                // uppercase by subtracting 32
                out[2 + i] = bytes1(uint8(ch) - 32);
            } else {
                out[2 + i] = ch;
            }
        }
        return string(out);
    }

    /**
     * @notice Compares two strings for equality.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        bytes memory ba = bytes(a);
        bytes memory bb = bytes(b);
        if (ba.length != bb.length) return false;
        return keccak256(ba) == keccak256(bb);
    }

    /**
     * @notice Parses entire string into uint256 (reverts on invalid char).
     */
    function parseUint(string memory input) internal pure returns (uint256) {
        (bool ok, uint256 v) = tryParseUint(input);
        if (!ok) revert StringsInvalidChar();
        return v;
    }

    /**
     * @notice Parses substring [begin, end) into uint256 (reverts on invalid char).
     */
    function parseUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool ok, uint256 v) = tryParseUint(input, begin, end);
        if (!ok) revert StringsInvalidChar();
        return v;
    }

    /**
     * @notice Attempts to parse entire string into uint256.
     */
    function tryParseUint(string memory input) internal pure returns (bool success, uint256 value) {
        bytes memory b = bytes(input);
        return tryParseUint(input, 0, b.length);
    }

    /**
     * @notice Attempts to parse substring [begin,end) into uint256.
     */
    function tryParseUint(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, uint256 value) {
        bytes memory b = bytes(input);
        if (end > b.length || begin > end) return (false, 0);
        return _tryParseUintUncheckedBounds(input, begin, end);
    }

    /**
     * @notice Internal: parse unsigned decimal in [begin,end) without bounds-checks by caller.
     */
    function _tryParseUintUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, uint256 value) {
        bytes memory b = bytes(input);
        uint256 result = 0;
        for (uint256 i = begin; i < end; ++i) {
            uint8 c = uint8(b[i]);
            if (c < 48 || c > 57) {
                return (false, 0);
            }
            unchecked {
                result = result * 10 + (c - 48);
            }
        }
        return (true, result);
    }

    /**
     * @notice Parses a string into an int256 (reverts on invalid char or out of bounds).
     */
    function parseInt(string memory input) internal pure returns (int256) {
        (bool ok, int256 v) = tryParseInt(input);
        if (!ok) revert StringsInvalidChar();
        return v;
    }

    /**
     * @notice Parses substring [begin,end) into int256 (reverts on invalid char or out of bounds).
     */
    function parseInt(string memory input, uint256 begin, uint256 end) internal pure returns (int256) {
        (bool ok, int256 v) = tryParseInt(input, begin, end);
        if (!ok) revert StringsInvalidChar();
        return v;
    }

    /**
     * @notice Attempts to parse entire string into int256.
     */
    function tryParseInt(string memory input) internal pure returns (bool success, int256 value) {
        bytes memory b = bytes(input);
        return tryParseInt(input, 0, b.length);
    }

    /**
     * @notice Attempts to parse substring [begin,end) into int256.
     */
    function tryParseInt(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, int256 value) {
        bytes memory b = bytes(input);
        if (end > b.length || begin > end) return (false, 0);
        return _tryParseIntUncheckedBounds(input, begin, end);
    }

    /**
     * @notice Internal: parse signed integer from substring without bounds-check by caller.
     */
    function _tryParseIntUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, int256 value) {
        bytes memory b = bytes(input);
        if (begin >= end || end > b.length) return (false, 0);
        bool negative = false;
        uint256 idx = begin;
        if (b[idx] == bytes1(uint8(45))) { // '-'
            negative = true;
            idx++;
        } else if (b[idx] == bytes1(uint8(43))) { // '+'
            idx++;
        }
        if (idx >= end) return (false, 0); // no digits
        (bool ok, uint256 unsignedVal) = _tryParseUintUncheckedBounds(input, idx, end);
        if (!ok) return (false, 0);
        uint256 maxInt = uint256(type(int256).max);
        if (negative) {
            // allow up to 2**255 (absolute value) for int256 min
            uint256 minAbs = (uint256(1) << 255);
            if (unsignedVal > minAbs) return (false, 0);
            if (unsignedVal == minAbs) {
                return (true, type(int256).min);
            } else {
                // safe to cast
                return (true, -int256(uint256(unsignedVal)));
            }
        } else {
            if (unsignedVal > maxInt) return (false, 0);
            return (true, int256(uint256(unsignedVal)));
        }
    }

    /**
     * @notice Parses a hexadecimal string into a uint256 (reverts on invalid).
     */
    function parseHexUint(string memory input) internal pure returns (uint256) {
        (bool ok, uint256 v) = tryParseHexUint(input);
        if (!ok) revert StringsInvalidChar();
        return v;
    }

    /**
     * @notice Parses substring [begin,end) hex into uint256 (reverts on invalid).
     */
    function parseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool ok, uint256 v) = tryParseHexUint(input, begin, end);
        if (!ok) revert StringsInvalidChar();
        return v;
    }

    /**
     * @notice Attempts to parse entire hex string into uint256.
     */
    function tryParseHexUint(string memory input) internal pure returns (bool success, uint256 value) {
        bytes memory b = bytes(input);
        return tryParseHexUint(input, 0, b.length);
    }

    /**
     * @notice Attempts to parse substring [begin,end) hex into uint256.
     */
    function tryParseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, uint256 value) {
        bytes memory b = bytes(input);
        if (end > b.length || begin > end) return (false, 0);
        return _tryParseHexUintUncheckedBounds(input, begin, end);
    }

    /**
     * @notice Internal: parse hex substring [begin,end) without bounds-check by caller.
     */
    function _tryParseHexUintUncheckedBounds(string memory input, uint256 begin, uint256 end) private pure returns (bool success, uint256 value) {
        bytes memory b = bytes(input);
        if (begin >= end || end > b.length) return (false, 0);
        uint256 i = begin;
        // handle optional "0x" or "0X"
        if (end - i >= 2 && b[i] == bytes1(uint8(48)) && (b[i + 1] == bytes1(uint8(120)) || b[i + 1] == bytes1(uint8(88)))) {
            i += 2;
        }
        if (i >= end) return (false, 0);
        uint256 result = 0;
        for (; i < end; ++i) {
            uint8 d = _tryParseChr(b[i]);
            if (d == type(uint8).max) return (false, 0);
            unchecked {
                result = result * 16 + d;
            }
        }
        return (true, result);
    }

    /**
     * @notice Parses a string input to extract an Ethereum address.
     */
    function parseAddress(string memory input) internal pure returns (address) {
        (bool ok, address a) = tryParseAddress(input);
        if (!ok) revert StringsInvalidAddressFormat();
        return a;
    }

    /**
     * @notice Parses substring [begin,end) into an Ethereum address.
     */
    function parseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (address) {
        (bool ok, address a) = tryParseAddress(input, begin, end);
        if (!ok) revert StringsInvalidAddressFormat();
        return a;
    }

    /**
     * @notice Attempts to parse an Ethereum address from entire string.
     */
    function tryParseAddress(string memory input) internal pure returns (bool success, address value) {
        bytes memory b = bytes(input);
        return tryParseAddress(input, 0, b.length);
    }

    /**
     * @notice Attempts to parse an Ethereum address from substring [begin,end).
     */
    function tryParseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (bool success, address value) {
        bytes memory b = bytes(input);
        if (end > b.length || begin > end) return (false, address(0));
        if (end - begin < 40) return (false, address(0));

        uint256 i = begin;
        bool hasPrefix = false;
        if (end - begin >= 2 && b[begin] == bytes1(uint8(48)) && (b[begin + 1] == bytes1(uint8(120)) || b[begin + 1] == bytes1(uint8(88)))) {
            hasPrefix = true;
            i = begin + 2;
        }
        uint256 expectedLen = hasPrefix ? 2 + 40 : 40;
        if (end - begin != expectedLen) return (false, address(0));
        (bool ok, uint256 v) = tryParseHexUint(input, i, end);
        if (!ok) return (false, address(0));
        if (v > type(uint160).max) return (false, address(0));
        return (true, address(uint160(v)));
    }

    /**
     * @notice Attempts to parse a single hex character into its numeric value.
     */
    function _tryParseChr(bytes1 chr) private pure returns (uint8) {
        uint8 c = uint8(chr);
        // '0' - '9'
        if (c >= 48 && c <= 57) {
            return c - 48;
        }
        // 'a' - 'f'
        if (c >= 97 && c <= 102) {
            return 10 + (c - 97);
        }
        // 'A' - 'F'
        if (c >= 65 && c <= 70) {
            return 10 + (c - 65);
        }
        return type(uint8).max;
    }

    /**
     * @notice Reads a bytes32 value from buffer at offset (memory unsafe if out of bounds).
     */
    function _unsafeReadBytesOffset(bytes memory buffer, uint256 offset) private pure returns (bytes32 value) {
        assembly {
            // buffer pointer -> location of length, data starts at buffer + 32
            value := mload(add(add(buffer, 0x20), offset))
        }
    }
}
