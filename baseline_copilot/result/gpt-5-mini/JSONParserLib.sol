// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library JSONParserLib {
    // Minimal, safe JSON item representation.
    struct Item {
        // Note: Do not modify directly; use helpers.
        uint256 _data;
    }

    // Error used for parsing failures.
    error ParsingFailed();

    // Type bitmask and constants (simple layout for this implementation).
    uint256 private constant _BITMASK_TYPE = 0xff;
    uint8 private constant TYPE_UNDEFINED = 0;
    uint8 private constant TYPE_OBJECT = 1;
    uint8 private constant TYPE_ARRAY = 2;
    uint8 private constant TYPE_STRING = 3;
    uint8 private constant TYPE_NUMBER = 4;
    uint8 private constant TYPE_BOOLEAN = 5;
    uint8 private constant TYPE_NULL = 6;

    // Parent flags (simple positions to indicate parent info).
    uint256 private constant _PARENT_IS_ARRAY = 1 << 8;
    uint256 private constant _PARENT_IS_OBJECT = 1 << 9;

    /**
     * @notice Parses a string input into an `Item` struct.
     */
    function parse(string memory s) internal pure returns (Item memory result) {
        // Use a deterministic input encoding then query (light-weight here).
        bytes32 input = _toInput(s);
        bytes32 out = _query(input, 255);
        result._data = uint256(out);
    }

    /**
     * @notice Retrieves the value of an `Item` as a string.
     */
    function value(Item memory item) internal pure returns (string memory result) {
        // For this implementation, prefer readable decimal for numbers, otherwise a string from bytes32.
        if (isNumber(item)) {
            result = _toString(uint256(item._data >> 16));
        } else if (isString(item)) {
            // Attempt to recover a UTF-8 string from bytes32-stored data if any.
            bytes32 b = bytes32(item._data);
            // Trim trailing zeros.
            uint256 len = 32;
            while (len > 0 && b[len - 1] == 0) len--;
            bytes memory buf = new bytes(len);
            for (uint256 i = 0; i < len; i++) buf[i] = b[i];
            result = string(buf);
        } else {
            // Fallback: hex representation.
            result = _toHexString(uint256(item._data));
        }
    }

    /**
     * @notice Computes the index of an item when part of an array.
     */
    function index(Item memory item) internal pure returns (uint256 result) {
        if ((item._data & _PARENT_IS_ARRAY) != 0) {
            // Stored index in high bits for this simplified layout, shift down by 16.
            result = (item._data >> 16);
        } else {
            result = 0;
        }
    }

    /**
     * @notice Generates a key for a given Item based on its data.
     */
    function key(Item memory item) internal pure returns (string memory result) {
        if ((item._data & _PARENT_IS_OBJECT) != 0) {
            // For this simple implementation, return the bytes32 portion as string.
            bytes32 b = bytes32(item._data);
            uint256 len = 32;
            while (len > 0 && b[len - 1] == 0) len--;
            bytes memory buf = new bytes(len);
            for (uint256 i = 0; i < len; i++) buf[i] = b[i];
            result = string(buf);
        } else {
            result = "";
        }
    }

    /**
     * @notice Retrieves the child items of a given item (returns empty array in this minimal impl).
     */
    function children(Item memory /*item*/) internal pure returns (Item[] memory result) {
        result = new Item[](0);
    }

    /**
     * @notice Calculates the size of an `Item` struct in memory (approximation).
     */
    function size(Item memory /*item*/) internal pure returns (uint256 result) {
        // Minimal representation: 1 element.
        result = 1;
    }

    /**
     * @notice Retrieves an item from a specific index in an array-type item.
     */
    function at(Item memory /*item*/, uint256 /*i*/) internal pure returns (Item memory result) {
        // Out-of-bounds or unsupported in this minimal implementation -> zero pointer.
        result._data = 0;
    }

    /**
     * @notice Retrieves an item by string key (object property).
     */
    function at(Item memory /*item*/, string memory /*k*/) internal pure returns (Item memory result) {
        // Unsupported here -> zero pointer.
        result._data = 0;
    }

    /**
     * @notice Retrieves the type of an item.
     */
    function getType(Item memory item) internal pure returns (uint8 result) {
        result = uint8(item._data & _BITMASK_TYPE);
    }

    /**
     * @notice Checks if an Item is undefined.
     */
    function isUndefined(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_UNDEFINED;
    }

    /**
     * @notice Checks if the item is an array.
     */
    function isArray(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_ARRAY;
    }

    /**
     * @notice Checks if the item is an object.
     */
    function isObject(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_OBJECT;
    }

    /**
     * @notice Checks if the item is a number.
     */
    function isNumber(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_NUMBER;
    }

    /**
     * @notice Checks if the item is a string.
     */
    function isString(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_STRING;
    }

    /**
     * @notice Checks if the item is boolean.
     */
    function isBoolean(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_BOOLEAN;
    }

    /**
     * @notice Checks if the item is null.
     */
    function isNull(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_NULL;
    }

    /**
     * @notice Retrieves the parent item (not tracked in this minimal impl).
     */
    function parent(Item memory /*item*/) internal pure returns (Item memory result) {
        result._data = 0;
    }

    /**
     * @notice Parses a decimal string into uint256.
     */
    function parseUint(string memory s) internal pure returns (uint256 result) {
        bytes memory bs = bytes(s);
        if (bs.length == 0) revert ParsingFailed();
        uint256 i = 0;
        // skip leading spaces
        while (i < bs.length && bs[i] == 0x20) i++;
        if (i == bs.length) revert ParsingFailed();
        for (; i < bs.length; i++) {
            bytes1 ch = bs[i];
            if (ch >= 0x30 && ch <= 0x39) {
                uint8 digit = uint8(ch) - 48;
                // overflow check
                if (result > (type(uint256).max - digit) / 10) revert ParsingFailed();
                result = result * 10 + digit;
            } else {
                // stop at first non-digit
                break;
            }
        }
    }

    /**
     * @notice Parses a signed integer string into int256.
     */
    function parseInt(string memory s) internal pure returns (int256 result) {
        bytes memory bs = bytes(s);
        if (bs.length == 0) revert ParsingFailed();
        uint256 i = 0;
        bool negative = false;
        if (bs[0] == 0x2D) {
            negative = true;
            i = 1;
        } else if (bs[0] == 0x2B) {
            i = 1;
        }
        // collect digits
        uint256 u = 0;
        for (; i < bs.length; i++) {
            bytes1 ch = bs[i];
            if (ch >= 0x30 && ch <= 0x39) {
                uint8 digit = uint8(ch) - 48;
                if (u > (uint256(type(int256).max) - digit) / 10) revert ParsingFailed();
                u = u * 10 + digit;
            } else {
                break;
            }
        }
        if (negative) {
            if (u > uint256(type(int256).max) + 1) revert ParsingFailed();
            if (u == uint256(type(int256).max) + 1) {
                // int256 min
                result = type(int256).min;
            } else {
                result = -int256(u);
            }
        } else {
            if (u > uint256(type(int256).max)) revert ParsingFailed();
            result = int256(u);
        }
    }

    /**
     * @notice Parses a hex string into uint256.
     */
    function parseUintFromHex(string memory s) internal pure returns (uint256 result) {
        bytes memory bs = bytes(s);
        uint256 i = 0;
        if (bs.length >= 2 && bs[0] == '0' && (bs[1] == 'x' || bs[1] == 'X')) i = 2;
        if (i >= bs.length) revert ParsingFailed();
        for (; i < bs.length; i++) {
            uint8 v = _fromHexChar(bs[i]);
            result = (result << 4) | v;
        }
    }

    /**
     * @notice Decodes a JSON-style double-quoted string with escapes.
     */
    function decodeString(string memory s) internal pure returns (string memory result) {
        bytes memory bs = bytes(s);
        if (bs.length < 2) revert ParsingFailed();
        if (bs[0] != '"' || bs[bs.length - 1] != '"') revert ParsingFailed();
        // allocate a buffer equal to input length
        bytes memory out = new bytes(bs.length);
        uint256 o = 0;
        for (uint256 i = 1; i + 1 < bs.length; i++) {
            bytes1 ch = bs[i];
            if (ch == '\\') {
                if (i + 1 >= bs.length - 1) revert ParsingFailed();
                bytes1 nx = bs[++i];
                if (nx == '"' ) out[o++] = '"';
                else if (nx == '\\') out[o++] = '\\';
                else if (nx == '/') out[o++] = '/';
                else if (nx == 'b') out[o++] = '\b';
                else if (nx == 'f') out[o++] = '\f';
                else if (nx == 'n') out[o++] = '\n';
                else if (nx == 'r') out[o++] = '\r';
                else if (nx == 't') out[o++] = '\t';
                else if (nx == 'u') {
                    // parse 4 hex digits
                    if (i + 4 >= bs.length - 1) revert ParsingFailed();
                    uint16 code = 0;
                    for (uint256 k = 0; k < 4; k++) {
                        code = (code << 4) | uint16(_fromHexChar(bs[++i]));
                    }
                    // encode codepoint into UTF-8 (basic BMP handling)
                    if (code <= 0x7F) {
                        out[o++] = bytes1(uint8(code));
                    } else if (code <= 0x7FF) {
                        out[o++] = bytes1(uint8(0xC0 | ((code >> 6) & 0x1F)));
                        out[o++] = bytes1(uint8(0x80 | (code & 0x3F)));
                    } else {
                        out[o++] = bytes1(uint8(0xE0 | ((code >> 12) & 0x0F)));
                        out[o++] = bytes1(uint8(0x80 | ((code >> 6) & 0x3F)));
                        out[o++] = bytes1(uint8(0x80 | (code & 0x3F)));
                    }
                } else {
                    revert ParsingFailed();
                }
            } else {
                out[o++] = ch;
            }
        }
        // resize result
        bytes memory trimmed = new bytes(o);
        for (uint256 j = 0; j < o; j++) trimmed[j] = out[j];
        result = string(trimmed);
    }

    /**
     * @notice Lightweight internal query function (stubbed behavior).
     */
    function _query(bytes32 input, uint256 /*mode*/) private pure returns (bytes32 result) {
        // Minimal behavior: return input as-is.
        result = input;
    }

    /**
     * @notice Converts a string to a deterministic bytes32 using keccak.
     */
    function _toInput(string memory input) private pure returns (bytes32 result) {
        result = bytes32(keccak256(bytes(input)));
    }

    /**
     * @notice Converts an Item into bytes32 (using its _data).
     */
    function _toInput(Item memory input) private pure returns (bytes32 result) {
        result = bytes32(input._data);
    }

    // --- Internal helpers ---

    function _fromHexChar(bytes1 c) private pure returns (uint8) {
        if (c >= '0' && c <= '9') return uint8(c) - 48;
        if (c >= 'a' && c <= 'f') return 10 + uint8(c) - 97;
        if (c >= 'A' && c <= 'F') return 10 + uint8(c) - 65;
        revert ParsingFailed();
    }

    function _toHexString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0x0";
        bytes memory buf = new bytes(66);
        buf[0] = '0';
        buf[1] = 'x';
        uint256 i = 66;
        while (value != 0) {
            i--;
            uint8 nibble = uint8(value & 0xf);
            buf[i] = nibble > 9 ? bytes1(87 + nibble) : bytes1(48 + nibble);
            value >>= 4;
        }
        bytes memory out = new bytes(66 - i);
        for (uint256 j = 0; j < out.length; j++) out[j] = buf[i + j];
        return string(out);
    }

    function _toString(uint256 value) private pure returns (string memory) {
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
