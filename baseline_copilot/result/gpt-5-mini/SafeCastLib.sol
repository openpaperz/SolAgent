// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SafeCastLib {
    error Overflow();

    /* ==========================
       Unsigned downcasts
       ========================== */

    /// @notice Converts a uint256 value to a uint8 value, reverting on overflow.
    function toUint8(uint256 x) internal pure returns (uint8) {
        if (x > type(uint8).max) _revertOverflow();
        return uint8(x);
    }

    /// @notice Converts a uint256 value to a uint16 value, reverting on overflow.
    function toUint16(uint256 x) internal pure returns (uint16) {
        if (x > type(uint16).max) _revertOverflow();
        return uint16(x);
    }

    /// @notice Converts a uint256 value to a uint24 value, reverting on overflow.
    function toUint24(uint256 x) internal pure returns (uint24) {
        if (x > type(uint24).max) _revertOverflow();
        return uint24(x);
    }

    /// @notice Converts a uint256 value to a uint32 value, reverting on overflow.
    function toUint32(uint256 x) internal pure returns (uint32) {
        if (x > type(uint32).max) _revertOverflow();
        return uint32(x);
    }

    /// @notice Converts a uint256 value to a uint40 value, reverting on overflow.
    function toUint40(uint256 x) internal pure returns (uint40) {
        if (x > type(uint40).max) _revertOverflow();
        return uint40(x);
    }

    /// @notice Converts a uint256 value to a uint48 value, reverting on overflow.
    function toUint48(uint256 x) internal pure returns (uint48) {
        if (x > type(uint48).max) _revertOverflow();
        return uint48(x);
    }

    /// @notice Converts a uint256 value to a uint56 value, reverting on overflow.
    function toUint56(uint256 x) internal pure returns (uint56) {
        if (x > type(uint56).max) _revertOverflow();
        return uint56(x);
    }

    /// @notice Converts a uint256 value to a uint64 value, reverting on overflow.
    function toUint64(uint256 x) internal pure returns (uint64) {
        if (x > type(uint64).max) _revertOverflow();
        return uint64(x);
    }

    /// @notice Converts a uint256 value to a uint72 value, reverting on overflow.
    function toUint72(uint256 x) internal pure returns (uint72) {
        if (x > type(uint72).max) _revertOverflow();
        return uint72(x);
    }

    /// @notice Converts a uint256 value to uint80, reverting on overflow.
    function toUint80(uint256 x) internal pure returns (uint80) {
        if (x > type(uint80).max) _revertOverflow();
        return uint80(x);
    }

    /// @notice Converts a uint256 value to uint88, reverting on overflow.
    function toUint88(uint256 x) internal pure returns (uint88) {
        if (x > type(uint88).max) _revertOverflow();
        return uint88(x);
    }

    /// @notice Converts a uint256 value to uint96, reverting on overflow.
    function toUint96(uint256 x) internal pure returns (uint96) {
        if (x > type(uint96).max) _revertOverflow();
        return uint96(x);
    }

    /// @notice Safely converts a uint256 value to uint104, reverting on overflow.
    function toUint104(uint256 x) internal pure returns (uint104) {
        if (x > type(uint104).max) _revertOverflow();
        return uint104(x);
    }

    /// @notice Converts a uint256 value to uint112, reverting on overflow.
    function toUint112(uint256 x) internal pure returns (uint112) {
        if (x > type(uint112).max) _revertOverflow();
        return uint112(x);
    }

    /// @notice Converts a uint256 value to uint120, reverting on overflow.
    function toUint120(uint256 x) internal pure returns (uint120) {
        if (x > type(uint120).max) _revertOverflow();
        return uint120(x);
    }

    /// @notice Converts a uint256 value to uint128, reverting on overflow.
    function toUint128(uint256 x) internal pure returns (uint128) {
        if (x > type(uint128).max) _revertOverflow();
        return uint128(x);
    }

    /// @notice Converts a uint256 value to uint136, reverting on overflow.
    function toUint136(uint256 x) internal pure returns (uint136) {
        if (x > type(uint136).max) _revertOverflow();
        return uint136(x);
    }

    /// @notice Converts a uint256 value to a uint144 value, reverting on overflow.
    function toUint144(uint256 x) internal pure returns (uint144) {
        if (x > type(uint144).max) _revertOverflow();
        return uint144(x);
    }

    /// @notice Converts a uint256 value to uint152, reverting on overflow.
    function toUint152(uint256 x) internal pure returns (uint152) {
        if (x > type(uint152).max) _revertOverflow();
        return uint152(x);
    }

    /// @notice Converts a uint256 value to uint160, reverting on overflow.
    function toUint160(uint256 x) internal pure returns (uint160) {
        if (x > type(uint160).max) _revertOverflow();
        return uint160(x);
    }

    /// @notice Converts a uint256 value to uint168, reverting on overflow.
    function toUint168(uint256 x) internal pure returns (uint168) {
        if (x > type(uint168).max) _revertOverflow();
        return uint168(x);
    }

    /// @notice Converts a uint256 value to uint176, reverting on overflow.
    function toUint176(uint256 x) internal pure returns (uint176) {
        if (x > type(uint176).max) _revertOverflow();
        return uint176(x);
    }

    /// @notice Converts a uint256 value to uint184, reverting on overflow.
    function toUint184(uint256 x) internal pure returns (uint184) {
        if (x > type(uint184).max) _revertOverflow();
        return uint184(x);
    }

    /// @notice Converts a uint256 value to a uint192 value, reverting on overflow.
    function toUint192(uint256 x) internal pure returns (uint192) {
        if (x > type(uint192).max) _revertOverflow();
        return uint192(x);
    }

    /// @notice Converts a uint256 value to uint200, reverting on overflow.
    function toUint200(uint256 x) internal pure returns (uint200) {
        if (x > type(uint200).max) _revertOverflow();
        return uint200(x);
    }

    /// @notice Converts a uint256 value to uint208, reverting on overflow.
    function toUint208(uint256 x) internal pure returns (uint208) {
        if (x > type(uint208).max) _revertOverflow();
        return uint208(x);
    }

    /// @notice Converts a uint256 value to uint216, reverting on overflow.
    function toUint216(uint256 x) internal pure returns (uint216) {
        if (x > type(uint216).max) _revertOverflow();
        return uint216(x);
    }

    /// @notice Converts a uint256 value to uint224, reverting on overflow.
    function toUint224(uint256 x) internal pure returns (uint224) {
        if (x > type(uint224).max) _revertOverflow();
        return uint224(x);
    }

    /// @notice Converts a uint256 value to a uint232 value, reverting on overflow.
    function toUint232(uint256 x) internal pure returns (uint232) {
        if (x > type(uint232).max) _revertOverflow();
        return uint232(x);
    }

    /// @notice Converts a uint256 value to uint240, reverting on overflow.
    function toUint240(uint256 x) internal pure returns (uint240) {
        if (x > type(uint240).max) _revertOverflow();
        return uint240(x);
    }

    /// @notice Converts a uint256 value to uint248, reverting on overflow.
    function toUint248(uint256 x) internal pure returns (uint248) {
        if (x > type(uint248).max) _revertOverflow();
        return uint248(x);
    }

    /* ==========================
       Signed downcasts (from int256)
       ========================== */

    /// @notice Converts a 256-bit integer to an 8-bit integer, checking for overflow.
    function toInt8(int256 x) internal pure returns (int8) {
        if (x < type(int8).min || x > type(int8).max) _revertOverflow();
        return int8(x);
    }

    /// @notice Converts a 256-bit integer to a 16-bit integer, reverting on overflow.
    function toInt16(int256 x) internal pure returns (int16) {
        if (x < type(int16).min || x > type(int16).max) _revertOverflow();
        return int16(x);
    }

    /// @notice Converts an int256 value to int24, ensuring it does not overflow.
    function toInt24(int256 x) internal pure returns (int24) {
        if (x < type(int24).min || x > type(int24).max) _revertOverflow();
        return int24(x);
    }

    /// @notice Converts a 256-bit signed integer to a 32-bit signed integer.
    function toInt32(int256 x) internal pure returns (int32) {
        if (x < type(int32).min || x > type(int32).max) _revertOverflow();
        return int32(x);
    }

    /// @notice Converts a 256-bit signed integer to a 40-bit signed integer.
    function toInt40(int256 x) internal pure returns (int40) {
        if (x < type(int40).min || x > type(int40).max) _revertOverflow();
        return int40(x);
    }

    /// @notice Converts a 256-bit signed integer to a 48-bit signed integer.
    function toInt48(int256 x) internal pure returns (int48) {
        if (x < type(int48).min || x > type(int48).max) _revertOverflow();
        return int48(x);
    }

    /// @notice Converts a 256-bit signed integer to a 56-bit signed integer.
    function toInt56(int256 x) internal pure returns (int56) {
        if (x < type(int56).min || x > type(int56).max) _revertOverflow();
        return int56(x);
    }

    /// @notice Converts a 256-bit signed integer to a 64-bit signed integer.
    function toInt64(int256 x) internal pure returns (int64) {
        if (x < type(int64).min || x > type(int64).max) _revertOverflow();
        return int64(x);
    }

    /// @notice Converts a 256-bit signed integer to a 72-bit signed integer.
    function toInt72(int256 x) internal pure returns (int72) {
        if (x < type(int72).min || x > type(int72).max) _revertOverflow();
        return int72(x);
    }

    /// @notice Converts a 256-bit signed integer to an 80-bit signed integer.
    function toInt80(int256 x) internal pure returns (int80) {
        if (x < type(int80).min || x > type(int80).max) _revertOverflow();
        return int80(x);
    }

    /// @notice Converts a 256-bit signed integer to an 88-bit signed integer.
    function toInt88(int256 x) internal pure returns (int88) {
        if (x < type(int88).min || x > type(int88).max) _revertOverflow();
        return int88(x);
    }

    /// @notice Converts an int256 value to int96, ensuring it does not overflow.
    function toInt96(int256 x) internal pure returns (int96) {
        if (x < type(int96).min || x > type(int96).max) _revertOverflow();
        return int96(x);
    }

    /// @notice Converts a 256-bit signed integer to a 104-bit signed integer.
    function toInt104(int256 x) internal pure returns (int104) {
        if (x < type(int104).min || x > type(int104).max) _revertOverflow();
        return int104(x);
    }

    /// @notice Converts a 256-bit integer to a 112-bit integer, reverting on overflow.
    function toInt112(int256 x) internal pure returns (int112) {
        if (x < type(int112).min || x > type(int112).max) _revertOverflow();
        return int112(x);
    }

    /// @notice Converts a 256-bit signed integer to a 120-bit signed integer.
    function toInt120(int256 x) internal pure returns (int120) {
        if (x < type(int120).min || x > type(int120).max) _revertOverflow();
        return int120(x);
    }

    /// @notice Converts a 256-bit signed integer to a 128-bit signed integer.
    function toInt128(int256 x) internal pure returns (int128) {
        if (x < type(int128).min || x > type(int128).max) _revertOverflow();
        return int128(x);
    }

    /// @notice Converts a 256-bit signed integer to a 136-bit signed integer.
    function toInt136(int256 x) internal pure returns (int136) {
        if (x < type(int136).min || x > type(int136).max) _revertOverflow();
        return int136(x);
    }

    /// @notice Converts a 256-bit signed integer to a 144-bit signed integer.
    function toInt144(int256 x) internal pure returns (int144) {
        if (x < type(int144).min || x > type(int144).max) _revertOverflow();
        return int144(x);
    }

    /// @notice Converts an int256 value to int152, ensuring it does not overflow.
    function toInt152(int256 x) internal pure returns (int152) {
        if (x < type(int152).min || x > type(int152).max) _revertOverflow();
        return int152(x);
    }

    /// @notice Converts a 256-bit signed integer to a 160-bit signed integer.
    function toInt160(int256 x) internal pure returns (int160) {
        if (x < type(int160).min || x > type(int160).max) _revertOverflow();
        return int160(x);
    }

    /// @notice Converts a 256-bit signed integer to a 168-bit signed integer.
    function toInt168(int256 x) internal pure returns (int168) {
        if (x < type(int168).min || x > type(int168).max) _revertOverflow();
        return int168(x);
    }

    /// @notice Converts a 256-bit signed integer to a 176-bit signed integer.
    function toInt176(int256 x) internal pure returns (int176) {
        if (x < type(int176).min || x > type(int176).max) _revertOverflow();
        return int176(x);
    }

    /// @notice Converts a 256-bit signed integer to a 184-bit signed integer.
    function toInt184(int256 x) internal pure returns (int184) {
        if (x < type(int184).min || x > type(int184).max) _revertOverflow();
        return int184(x);
    }

    /// @notice Converts a 256-bit signed integer to a 192-bit signed integer.
    function toInt192(int256 x) internal pure returns (int192) {
        if (x < type(int192).min || x > type(int192).max) _revertOverflow();
        return int192(x);
    }

    /// @notice Converts a 256-bit signed integer to a 200-bit signed integer.
    function toInt200(int256 x) internal pure returns (int200) {
        if (x < type(int200).min || x > type(int200).max) _revertOverflow();
        return int200(x);
    }

    /// @notice Converts an int256 value to int208, ensuring it does not overflow.
    function toInt208(int256 x) internal pure returns (int208) {
        if (x < type(int208).min || x > type(int208).max) _revertOverflow();
        return int208(x);
    }

    /// @notice Converts an int256 value to int216, ensuring it does not overflow.
    function toInt216(int256 x) internal pure returns (int216) {
        if (x < type(int216).min || x > type(int216).max) _revertOverflow();
        return int216(x);
    }

    /// @notice Converts an int256 value to int224, ensuring it does not overflow.
    function toInt224(int256 x) internal pure returns (int224) {
        if (x < type(int224).min || x > type(int224).max) _revertOverflow();
        return int224(x);
    }

    /// @notice Converts an int256 value to int232, ensuring it does not overflow.
    function toInt232(int256 x) internal pure returns (int232) {
        if (x < type(int232).min || x > type(int232).max) _revertOverflow();
        return int232(x);
    }

    /// @notice Converts a 256-bit signed integer to a 240-bit signed integer.
    function toInt240(int256 x) internal pure returns (int240) {
        if (x < type(int240).min || x > type(int240).max) _revertOverflow();
        return int240(x);
    }

    /// @notice Converts an int256 value to int248, ensuring it does not overflow.
    function toInt248(int256 x) internal pure returns (int248) {
        if (x < type(int248).min || x > type(int248).max) _revertOverflow();
        return int248(x);
    }

    /* ==========================
       Signed conversions from uint256 (unsigned input)
       ========================== */

    /// @notice Converts a uint256 value to an int8, reverting on overflow.
    function toInt8(uint256 x) internal pure returns (int8) {
        if (x > uint256(type(int8).max)) _revertOverflow();
        return int8(int256(x));
    }

    /// @notice Converts a uint256 value to an int16, reverting on overflow.
    function toInt16(uint256 x) internal pure returns (int16) {
        if (x > uint256(type(int16).max)) _revertOverflow();
        return int16(int256(x));
    }

    /// @notice Converts a uint256 value to int24, reverting on overflow.
    function toInt24(uint256 x) internal pure returns (int24) {
        if (x > uint256(type(int24).max)) _revertOverflow();
        return int24(int256(x));
    }

    /// @notice Converts a uint256 value to an int32, reverting on overflow.
    function toInt32(uint256 x) internal pure returns (int32) {
        if (x > uint256(type(int32).max)) _revertOverflow();
        return int32(int256(x));
    }

    /// @notice Converts a uint256 value to an int40, reverting on overflow.
    function toInt40(uint256 x) internal pure returns (int40) {
        if (x > uint256(type(int40).max)) _revertOverflow();
        return int40(int256(x));
    }

    /// @notice Converts a uint256 value to an int48, reverting on overflow.
    function toInt48(uint256 x) internal pure returns (int48) {
        if (x > uint256(type(int48).max)) _revertOverflow();
        return int48(int256(x));
    }

    /// @notice Converts a uint256 value to an int56, reverting on overflow.
    function toInt56(uint256 x) internal pure returns (int56) {
        if (x > uint256(type(int56).max)) _revertOverflow();
        return int56(int256(x));
    }

    /// @notice Converts a uint256 value to an int64, reverting on overflow.
    function toInt64(uint256 x) internal pure returns (int64) {
        if (x > uint256(type(int64).max)) _revertOverflow();
        return int64(int256(x));
    }

    /// @notice Converts a uint256 value to an int72, reverting on overflow.
    function toInt72(uint256 x) internal pure returns (int72) {
        if (x > uint256(type(int72).max)) _revertOverflow();
        return int72(int256(x));
    }

    /// @notice Converts a uint256 value to an int80, reverting on overflow.
    function toInt80(uint256 x) internal pure returns (int80) {
        if (x > uint256(type(int80).max)) _revertOverflow();
        return int80(int256(x));
    }

    /// @notice Converts a uint256 value to an int88, reverting on overflow.
    function toInt88(uint256 x) internal pure returns (int88) {
        if (x > uint256(type(int88).max)) _revertOverflow();
        return int88(int256(x));
    }

    /// @notice Converts a uint256 value to an int96, reverting on overflow.
    function toInt96(uint256 x) internal pure returns (int96) {
        if (x > uint256(type(int96).max)) _revertOverflow();
        return int96(int256(x));
    }

    /// @notice Converts a uint256 value to an int104, reverting on overflow.
    function toInt104(uint256 x) internal pure returns (int104) {
        if (x > uint256(type(int104).max)) _revertOverflow();
        return int104(int256(x));
    }

    /// @notice Converts a uint256 value to an int112, reverting on overflow.
    function toInt112(uint256 x) internal pure returns (int112) {
        if (x > uint256(type(int112).max)) _revertOverflow();
        return int112(int256(x));
    }

    /// @notice Converts a uint256 value to an int120, reverting on overflow.
    function toInt120(uint256 x) internal pure returns (int120) {
        if (x > uint256(type(int120).max)) _revertOverflow();
        return int120(int256(x));
    }

    /// @notice Converts a uint256 value to an int128, reverting on overflow.
    function toInt128(uint256 x) internal pure returns (int128) {
        if (x > uint256(type(int128).max)) _revertOverflow();
        return int128(int256(x));
    }

    /// @notice Converts a uint256 value to an int136, reverting on overflow.
    function toInt136(uint256 x) internal pure returns (int136) {
        if (x > uint256(type(int136).max)) _revertOverflow();
        return int136(int256(x));
    }

    /// @notice Converts a uint256 value to an int144, reverting on overflow.
    function toInt144(uint256 x) internal pure returns (int144) {
        if (x > uint256(type(int144).max)) _revertOverflow();
        return int144(int256(x));
    }

    /// @notice Converts a uint256 value to an int152, reverting on overflow.
    function toInt152(uint256 x) internal pure returns (int152) {
        if (x > uint256(type(int152).max)) _revertOverflow();
        return int152(int256(x));
    }

    /// @notice Converts a uint256 value to an int160, reverting on overflow.
    function toInt160(uint256 x) internal pure returns (int160) {
        if (x > uint256(type(int160).max)) _revertOverflow();
        return int160(int256(x));
    }

    /// @notice Converts a uint256 value to an int168, reverting on overflow.
    function toInt168(uint256 x) internal pure returns (int168) {
        if (x > uint256(type(int168).max)) _revertOverflow();
        return int168(int256(x));
    }

    /// @notice Converts a uint256 value to an int176, reverting on overflow.
    function toInt176(uint256 x) internal pure returns (int176) {
        if (x > uint256(type(int176).max)) _revertOverflow();
        return int176(int256(x));
    }

    /// @notice Converts a uint256 value to an int184, reverting on overflow.
    function toInt184(uint256 x) internal pure returns (int184) {
        if (x > uint256(type(int184).max)) _revertOverflow();
        return int184(int256(x));
    }

    /// @notice Converts a uint256 value to an int192, reverting on overflow.
    function toInt192(uint256 x) internal pure returns (int192) {
        if (x > uint256(type(int192).max)) _revertOverflow();
        return int192(int256(x));
    }

    /// @notice Converts a uint256 value to an int200, reverting on overflow.
    function toInt200(uint256 x) internal pure returns (int200) {
        if (x > uint256(type(int200).max)) _revertOverflow();
        return int200(int256(x));
    }

    /// @notice Converts a uint256 value to an int208, reverting on overflow.
    function toInt208(uint256 x) internal pure returns (int208) {
        if (x > uint256(type(int208).max)) _revertOverflow();
        return int208(int256(x));
    }

    /// @notice Converts a uint256 value to an int216, reverting on overflow.
    function toInt216(uint256 x) internal pure returns (int216) {
        if (x > uint256(type(int216).max)) _revertOverflow();
        return int216(int256(x));
    }

    /// @notice Converts a uint256 value to an int224, reverting on overflow.
    function toInt224(uint256 x) internal pure returns (int224) {
        if (x > uint256(type(int224).max)) _revertOverflow();
        return int224(int256(x));
    }

    /// @notice Converts a uint256 value to an int232, reverting on overflow.
    function toInt232(uint256 x) internal pure returns (int232) {
        if (x > uint256(type(int232).max)) _revertOverflow();
        return int232(int256(x));
    }

    /// @notice Converts a uint256 value to an int240, reverting on overflow.
    function toInt240(uint256 x) internal pure returns (int240) {
        if (x > uint256(type(int240).max)) _revertOverflow();
        return int240(int256(x));
    }

    /// @notice Converts a uint256 value to an int248, reverting on overflow.
    function toInt248(uint256 x) internal pure returns (int248) {
        if (x > uint256(type(int248).max)) _revertOverflow();
        return int248(int256(x));
    }

    /* ==========================
       Conversions between signed/unsigned full-width
       ========================== */

    /// @notice Converts a uint256 value to an int256 value, ensuring no overflow occurs.
    function toInt256(uint256 x) internal pure returns (int256) {
        if (x > uint256(type(int256).max)) _revertOverflow();
        return int256(x);
    }

    /// @notice Converts an int256 to a uint256. Reverts if the input is negative.
    function toUint256(int256 x) internal pure returns (uint256) {
        if (x < 0) _revertOverflow();
        return uint256(x);
    }

    /* ==========================
       Internal helpers
       ========================== */

    /// @notice A private pure function that reverts with an overflow error.
    function _revertOverflow() private pure {
        bytes4 selector = Overflow.selector;
        assembly {
            // Store the 4-byte selector left-aligned in memory (mstore stores 32 bytes).
            mstore(0x00, shl(224, selector))
            revert(0x00, 0x04)
        }
    }
}