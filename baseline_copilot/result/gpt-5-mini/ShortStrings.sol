// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Short string optimization: stores up to 31 bytes inside a bytes32 value
// with the least-significant byte reserved for the length. If the string
// is longer than 31 bytes, the library can return a fallback sentinel and
// store the full string in an external storage slot.

type ShortString is bytes32;

library ShortStrings {
    error StringTooLong(uint256 length);
    error InvalidShortString();

    // A sentinel value whose least-significant byte is > 31 so that
    // `byteLength` will treat it as invalid and callers can detect it
    // as the "fallback" marker.
    bytes32 private constant FALLBACK_SENTINEL = bytes32(uint256(0xff));

    /**
     * @notice Converts a standard string into a `ShortString` type.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory b = bytes(str);
        uint256 len = b.length;
        if (len > 31) revert StringTooLong(len);

        bytes32 result;
        for (uint256 i = 0; i < len; ++i) {
            // place byte i at the (31 - i) position (most-significant side)
            result |= bytes32(bytes1(b[i])) << (8 * (31 - i));
        }

        // store length in the least-significant byte
        result |= bytes32(uint256(len));

        return ShortString.wrap(result);
    }

    /**
     * @notice Converts a `ShortString` type to a `string` type.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        bytes32 data = ShortString.unwrap(sstr);

        // least-significant byte holds length
        uint256 len = uint256(uint8(uint256(data)));
        if (len > 31) revert InvalidShortString();

        string memory str = new string(len);
        if (len == 0) return str;

        bytes memory bstr = bytes(str);
        for (uint256 i = 0; i < len; ++i) {
            // extract byte at position i which was stored at offset (31 - i)
            bstr[i] = bytes1(uint8(uint256(data >> (8 * (31 - i)))));
        }

        return str;
    }

    /**
     * @notice Calculates the byte length of a `ShortString` type.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 l = uint256(uint8(uint256(ShortString.unwrap(sstr))));
        if (l > 31) revert InvalidShortString();
        return l;
    }

    /**
     * @notice Converts a string to a `ShortString` if its length is less than 32 bytes.
     *         Otherwise, stores the string in `store` and returns a fallback sentinel.
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            store = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @notice Converts a `ShortString` to a string, falling back to `store` for sentinel values.
     */
    function toStringWithFallback(ShortString value, string storage store) internal view returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @notice Returns the byte length of a `ShortString` value or falls back to `store`'s length.
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}
