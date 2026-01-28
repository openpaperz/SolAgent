// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SafeCastLib {
    /*//////////////////////////////////////////////////////////////
                             UINT TO UINT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts a uint256 value to a uint8 value, reverting if the value exceeds the uint8 range.
     *
     * @param x The uint256 value to be converted.
     * @return uint8 The converted uint8 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^8 (256), which is the maximum value for uint8.
     * 2. If the value exceeds the uint8 range, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint8 and return it.
     */
    function toUint8(uint256 x) internal pure returns (uint8) {
        if (x >= (1 << 8)) _revertOverflow();
        return uint8(x);
    }

    /**
     * @notice Converts a uint256 value to a uint16 value, reverting if the value exceeds the uint16 range.
     *
     * @param x The uint256 value to be converted.
     * @return uint16 The converted uint16 value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by a uint16 (2^16 - 1).
     * 2. If the value exceeds the range, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as a uint16.
     */
    function toUint16(uint256 x) internal pure returns (uint16) {
        if (x >= (1 << 16)) _revertOverflow();
        return uint16(x);
    }

    /**
     * @notice Converts a uint256 value to a uint24 value, reverting if the value exceeds the uint24 range.
     *
     * @param x The uint256 value to be converted.
     * @return uint24 The converted uint24 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^24 (the maximum value for uint24).
     * 2. If the value exceeds the uint24 range, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint24 and return it.
     */
    function toUint24(uint256 x) internal pure returns (uint24) {
        if (x >= (1 << 24)) _revertOverflow();
        return uint24(x);
    }

    /**
     * @notice Converts a uint256 value to a uint32 value, reverting if the value exceeds the uint32 range.
     *
     * @param x The uint256 value to be converted.
     * @return uint32 The converted uint32 value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by a uint32 (2^32 - 1).
     * 2. If the value exceeds the range, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint32 and return it.
     */
    function toUint32(uint256 x) internal pure returns (uint32) {
        if (x >= (1 << 32)) _revertOverflow();
        return uint32(x);
    }

    /**
     * @notice Converts a uint256 value to a uint40 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted to uint40.
     * @return uint40 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^40 (1 << 40).
     * 2. If the value is too large, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint40 and return it.
     */
    function toUint40(uint256 x) internal pure returns (uint40) {
        if (x >= (1 << 40)) _revertOverflow();
        return uint40(x);
    }

    /**
     * @notice Converts a uint256 value to a uint48 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint48 The converted uint48 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^48 (the maximum value for uint48).
     * 2. If the value is too large, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint48 and return it.
     */
    function toUint48(uint256 x) internal pure returns (uint48) {
        if (x >= (1 << 48)) _revertOverflow();
        return uint48(x);
    }

    /**
     * @notice Converts a uint256 value to a uint56 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint56 The converted uint56 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^56 (1 << 56).
     * 2. If the check passes, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint56 and return it.
     */
    function toUint56(uint256 x) internal pure returns (uint56) {
        if (x >= (1 << 56)) _revertOverflow();
        return uint56(x);
    }

    /**
     * @notice Converts a uint256 value to a uint64, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint64 The converted uint64 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^64 (the maximum value for uint64).
     * 2. If the value exceeds the uint64 range, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint64.
     */
    function toUint64(uint256 x) internal pure returns (uint64) {
        if (x >= (1 << 64)) _revertOverflow();
        return uint64(x);
    }

    /**
     * @notice Converts a uint256 value to a uint72 value, reverting if the input exceeds the uint72 range.
     *
     * @param x The uint256 value to be converted.
     * @return uint72 The converted uint72 value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by a uint72 (2^72 - 1).
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint72 and return it.
     */
    function toUint72(uint256 x) internal pure returns (uint72) {
        if (x >= (1 << 72)) _revertOverflow();
        return uint72(x);
    }

    /**
     * @notice Converts a uint256 value to uint80, ensuring it does not overflow.
     *
     * @param x The uint256 value to be converted.
     * @return uint80 The converted uint80 value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by uint80.
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint80.
     */
    function toUint80(uint256 x) internal pure returns (uint80) {
        if (x >= (1 << 80)) _revertOverflow();
        return uint80(x);
    }

    /**
     * @notice Converts a uint256 value to uint88, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint88 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^88.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint88 and return it.
     */
    function toUint88(uint256 x) internal pure returns (uint88) {
        if (x >= (1 << 88)) _revertOverflow();
        return uint88(x);
    }

    /**
     * @notice Converts a uint256 value to uint96, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint96 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^96.
     * 2. If it is, revert with an overflow error.
     * 3. Otherwise, safely cast the value to uint96 and return it.
     */
    function toUint96(uint256 x) internal pure returns (uint96) {
        if (x >= (1 << 96)) _revertOverflow();
        return uint96(x);
    }

    /**
     * @notice Safely converts a uint256 value to uint104, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint104 The converted value, if it fits within the uint104 range.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by uint104 (2^104 - 1).
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint104 and return the result.
     */
    function toUint104(uint256 x) internal pure returns (uint104) {
        if (x >= (1 << 104)) _revertOverflow();
        return uint104(x);
    }

    /**
     * @notice Converts a uint256 value to uint112, ensuring it does not overflow.
     *
     * @param x The uint256 value to be converted.
     * @return uint112 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^112.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint112 and return it.
     */
    function toUint112(uint256 x) internal pure returns (uint112) {
        if (x >= (1 << 112)) _revertOverflow();
        return uint112(x);
    }

    /**
     * @notice Converts a uint256 value to uint120, reverting if the value exceeds the uint120 range.
     *
     * @param x The uint256 value to be converted.
     * @return uint120 The converted uint120 value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by uint120 (2^120 - 1).
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint120 and return it.
     */
    function toUint120(uint256 x) internal pure returns (uint120) {
        if (x >= (1 << 120)) _revertOverflow();
        return uint120(x);
    }

    /**
     * @notice Converts a uint256 value to uint128, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint128 The converted uint128 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^128.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint128 and return the result.
     */
    function toUint128(uint256 x) internal pure returns (uint128) {
        if (x >= (1 << 128)) _revertOverflow();
        return uint128(x);
    }

    /**
     * @notice Converts a uint256 value to uint136, ensuring it does not overflow.
     *
     * @param x The uint256 value to be converted.
     * @return uint136 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^136.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint136.
     */
    function toUint136(uint256 x) internal pure returns (uint136) {
        if (x >= (1 << 136)) _revertOverflow();
        return uint136(x);
    }

    /**
     * @notice Converts a uint256 value to a uint144 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint144 The converted uint144 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^144.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint144.
     */
    function toUint144(uint256 x) internal pure returns (uint144) {
        if (x >= (1 << 144)) _revertOverflow();
        return uint144(x);
    }

    /**
     * @notice Converts a uint256 value to uint152, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint152 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by uint152 (i.e., 2^152 - 1).
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint152.
     */
    function toUint152(uint256 x) internal pure returns (uint152) {
        if (x >= (1 << 152)) _revertOverflow();
        return uint152(x);
    }

    /**
     * @notice Converts a uint256 value to uint160, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint160 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^160 (the maximum value for uint160).
     * 2. If the value exceeds the limit, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint160 and return it.
     */
    function toUint160(uint256 x) internal pure returns (uint160) {
        if (x >= (1 << 160)) _revertOverflow();
        return uint160(x);
    }

    /**
     * @notice Converts a uint256 value to uint168, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint168 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by a uint168.
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint168.
     */
    function toUint168(uint256 x) internal pure returns (uint168) {
        if (x >= (1 << 168)) _revertOverflow();
        return uint168(x);
    }

    /**
     * @notice Converts a uint256 value to uint176, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint176 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^176.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint176 and return it.
     */
    function toUint176(uint256 x) internal pure returns (uint176) {
        if (x >= (1 << 176)) _revertOverflow();
        return uint176(x);
    }

    /**
     * @notice Converts a uint256 value to uint184, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint184 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^184.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint184 and return the result.
     */
    function toUint184(uint256 x) internal pure returns (uint184) {
        if (x >= (1 << 184)) _revertOverflow();
        return uint184(x);
    }

    /**
     * @notice Converts a uint256 value to a uint192 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint192 The converted uint192 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^192.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint192 and return the result.
     */
    function toUint192(uint256 x) internal pure returns (uint192) {
        if (x >= (1 << 192)) _revertOverflow();
        return uint192(x);
    }

    /**
     * @notice Converts a uint256 value to uint200, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint200 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^200.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint200.
     */
    function toUint200(uint256 x) internal pure returns (uint200) {
        if (x >= (1 << 200)) _revertOverflow();
        return uint200(x);
    }

    /**
     * @notice Converts a uint256 value to uint208, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint208 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^208.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint208 and return the result.
     */
    function toUint208(uint256 x) internal pure returns (uint208) {
        if (x >= (1 << 208)) _revertOverflow();
        return uint208(x);
    }

    /**
     * @notice Converts a uint256 value to uint216, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint216 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^216.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint216 and return the result.
     */
    function toUint216(uint256 x) internal pure returns (uint216) {
        if (x >= (1 << 216)) _revertOverflow();
        return uint216(x);
    }

    /**
     * @notice Converts a uint256 value to uint224, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint224 The converted uint224 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^224.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint224.
     */
    function toUint224(uint256 x) internal pure returns (uint224) {
        if (x >= (1 << 224)) _revertOverflow();
        return uint224(x);
    }

    /**
     * @notice Converts a uint256 value to a uint232 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint232 The converted uint232 value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^232.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast `x` to uint232 and return the result.
     */
    function toUint232(uint256 x) internal pure returns (uint232) {
        if (x >= (1 << 232)) _revertOverflow();
        return uint232(x);
    }

    /**
     * @notice Converts a uint256 value to uint240, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint240 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` exceeds the maximum value that can be represented by uint240 (i.e., 2^240 - 1).
     * 2. If it does, revert with an overflow error.
     * 3. Otherwise, safely cast the uint256 value to uint240 and return it.
     */
    function toUint240(uint256 x) internal pure returns (uint240) {
        if (x >= (1 << 240)) _revertOverflow();
        return uint240(x);
    }

    /**
     * @notice Converts a uint256 value to uint248, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted.
     * @return uint248 The converted value.
     *
     * Steps:
     * 1. Check if the input value `x` is greater than or equal to 2^248.
     * 2. If true, revert with an overflow error.
     * 3. Otherwise, safely cast and return the value as uint248.
     */
    function toUint248(uint256 x) internal pure returns (uint248) {
        if (x >= (1 << 248)) _revertOverflow();
        return uint248(x);
    }

    /*//////////////////////////////////////////////////////////////
                             INT TO INT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts a 256-bit integer to an 8-bit integer, checking for overflow.
     *
     * @param x The 256-bit integer to be converted.
     * @return int8 The resulting 8-bit integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within an 8-bit integer by verifying that the upper bits are zero.
     * 2. If the value fits, return the 8-bit integer representation of `x`.
     * 3. If the value does not fit, revert with an overflow error.
     *
     * @dev This function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt8(int256 x) internal pure returns (int8) {
        int8 y = int8(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit integer to a 16-bit integer, reverting on overflow.
     *
     * @param x The 256-bit integer to be converted.
     * @return int16 The resulting 16-bit integer.
     *
     * Steps:
     * 1. Check if the value of `x` can be safely represented as a 16-bit integer.
     * 2. If the value is within the valid range, return the 16-bit integer.
     * 3. If the value is out of range, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt16(int256 x) internal pure returns (int16) {
        int16 y = int16(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int24, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted to int24.
     * @return int24 The converted int24 value.
     *
     * Steps:
     * 1. Check if the value `x` can fit within the int24 range without overflow.
     * 2. If it fits, return the value as int24.
     * 3. If it does not fit, revert with an overflow error.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt24(int256 x) internal pure returns (int24) {
        int24 y = int24(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 32-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to an `int32` without overflow.
     *      If the value is within the valid range for `int32`, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int32 The 32-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be represented as a 32-bit signed integer by verifying that the upper bits are zero.
     * 2. If the value is within the valid range, return the cast value as `int32`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt32(int256 x) internal pure returns (int32) {
        int32 y = int32(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 40-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to a 40-bit integer.
     *      If the value is within the valid range for a 40-bit integer, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int40 The 40-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can fit within a 40-bit integer by verifying if the 40th bit is not set.
     * 2. If the value is within the valid range, return the cast value as `int40`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt40(int256 x) internal pure returns (int40) {
        int40 y = int40(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 48-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int48 The resulting 48-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely cast to a 48-bit integer without overflow.
     * 2. If the value is within the valid range, return the casted 48-bit integer.
     * 3. If the value exceeds the 48-bit range, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt48(int256 x) internal pure returns (int48) {
        int48 y = int48(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 56-bit signed integer.
     *
     * @dev This function performs an unchecked conversion to ensure efficiency.
     *      It checks if the input value `x` can fit within the 56-bit range.
     *      If the value is within the valid range, it returns the converted value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int56 The converted 56-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can fit within the 56-bit range by performing a bitwise operation.
     * 2. If the value is within the valid range, return the converted value as `int56`.
     * 3. If the value exceeds the 56-bit range, revert with an overflow error.
     */
    function toInt56(int256 x) internal pure returns (int56) {
        int56 y = int56(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 64-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to `int64` without overflow.
     *      If the value is within the valid range for `int64`, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int64 The 64-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be safely represented as a 64-bit integer by verifying that the upper bits are zero.
     * 2. If the value is within the valid range, return the cast value as `int64`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt64(int256 x) internal pure returns (int64) {
        int64 y = int64(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer (`int256`) to a 72-bit signed integer (`int72`).
     *
     * @dev This function performs a safe downcast from `int256` to `int72`. It checks if the value of `x`
     *      fits within the range of a 72-bit signed integer. If the value is out of bounds, it reverts
     *      with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int72 The converted 72-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within the range of a 72-bit signed integer by performing
     *    a bitwise operation. Specifically, it checks if the value, when shifted and masked, is zero.
     * 2. If the value fits, return the downcasted `int72` value.
     * 3. If the value does not fit, revert with an overflow error using `_revertOverflow()`.
     */
    function toInt72(int256 x) internal pure returns (int72) {
        int72 y = int72(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to an 80-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int80 The resulting 80-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely represented as an 80-bit integer.
     * 2. If the value is within the valid range, return the converted 80-bit integer.
     * 3. If the value exceeds the range of an 80-bit integer, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt80(int256 x) internal pure returns (int80) {
        int80 y = int80(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to an 88-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int88 The resulting 88-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within the range of an 88-bit integer.
     * 2. If it fits, return the value as an 88-bit integer.
     * 3. If it does not fit, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to avoid unnecessary gas costs.
     *      The overflow check ensures that the value does not exceed the bounds of an 88-bit integer.
     */
    function toInt88(int256 x) internal pure returns (int88) {
        int88 y = int88(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int96, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int96 The converted value, if it fits within the int96 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int96 by verifying it does not exceed the 96-bit range.
     * 2. If the value fits within the range, return it as int96.
     * 3. If the value exceeds the range, revert with an overflow error.
     */
    function toInt96(int256 x) internal pure returns (int96) {
        int96 y = int96(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 104-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int104 The resulting 104-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely downcasted to a 104-bit integer.
     * 2. If the value is within the valid range for a 104-bit integer, return the downcasted value.
     * 3. If the value exceeds the valid range, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt104(int256 x) internal pure returns (int104) {
        int104 y = int104(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit integer to a 112-bit integer, reverting on overflow.
     *
     * @param x The 256-bit integer to be converted.
     * @return int112 The converted 112-bit integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within a 112-bit integer by verifying that the upper bits (beyond 112 bits) are zero.
     * 2. If the value fits, return the value as a 112-bit integer.
     * 3. If the value does not fit, revert with an overflow error.
     *
     * Note: The function uses `unchecked` to avoid unnecessary overflow checks, but explicitly reverts if the value exceeds the 112-bit range.
     */
    function toInt112(int256 x) internal pure returns (int112) {
        int112 y = int112(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 120-bit signed integer.
     * @dev This function performs an unchecked conversion and checks for overflow.
     * If the value of `x` is within the valid range for a 120-bit integer, it is returned.
     * Otherwise, the function reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int120 The converted 120-bit signed integer.
     *
     * Steps:
     * 1. Perform an unchecked operation to avoid overflow checks during arithmetic.
     * 2. Check if the value of `x` is within the valid range for a 120-bit integer.
     *    - If valid, return the value as an `int120`.
     *    - If invalid, revert with an overflow error using `_revertOverflow()`.
     */
    function toInt120(int256 x) internal pure returns (int120) {
        int120 y = int120(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 128-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to `int128` without overflow.
     *      If the value is within the valid range for `int128`, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int128 The 128-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be safely represented as an `int128` by verifying that the upper 128 bits are zero.
     * 2. If the value is within the valid range, return the cast value as `int128`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt128(int256 x) internal pure returns (int128) {
        int128 y = int128(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 136-bit signed integer.
     *
     * @dev This function performs an overflow check to ensure the input value fits within the 136-bit range.
     * If the input value is within the valid range, it is cast to `int136` and returned.
     * If the input value exceeds the 136-bit range, the function reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int136 The converted 136-bit signed integer.
     *
     * Steps:
     * 1. Perform an unchecked block to avoid overflow checks during arithmetic operations.
     * 2. Check if the input value `x` fits within the 136-bit range by shifting and comparing.
     * 3. If the value is within range, return it as `int136`.
     * 4. If the value exceeds the range, revert with an overflow error.
     */
    function toInt136(int256 x) internal pure returns (int136) {
        int136 y = int136(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 144-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int144 The resulting 144-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely represented as a 144-bit signed integer.
     * 2. If the value is within the valid range, return the value cast to `int144`.
     * 3. If the value exceeds the valid range, revert with an overflow error.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt144(int256 x) internal pure returns (int144) {
        int144 y = int144(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int152, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int152 The converted value, if it fits within the int152 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int152 by verifying it does not exceed the range of int152.
     * 2. If the value is within the valid range, return it as int152.
     * 3. If the value exceeds the range, revert with an overflow error.
     *
     * @dev This function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt152(int256 x) internal pure returns (int152) {
        int152 y = int152(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer (`int256`) to a 160-bit signed integer (`int160`).
     * @dev This function checks for overflow conditions. If the value of `x` cannot be represented
     *      as a 160-bit signed integer, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int160 The 160-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value of `x` can be safely represented as a 160-bit signed integer.
     *    - This is done by shifting and masking to ensure the upper bits are zero.
     * 2. If the value is within the valid range, return the converted `int160` value.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt160(int256 x) internal pure returns (int160) {
        int160 y = int160(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 168-bit signed integer.
     * @dev This function ensures that the input value fits within the 168-bit range.
     * If the value exceeds the range, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int168 The resulting 168-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` fits within the 168-bit range by performing bitwise operations.
     * 2. If the value fits, return the value as a 168-bit integer.
     * 3. If the value exceeds the range, revert with an overflow error.
     */
    function toInt168(int256 x) internal pure returns (int168) {
        int168 y = int168(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 176-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int176 The resulting 176-bit signed integer.
     *
     * Steps:
     * 1. Check if the input `x` can be safely represented as a 176-bit integer.
     * 2. If the conversion is safe, return the 176-bit integer.
     * 3. If the conversion would result in overflow, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt176(int256 x) internal pure returns (int176) {
        int176 y = int176(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 184-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to a 184-bit integer.
     *      If the value is within the valid range for a 184-bit integer, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int184 The 184-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be represented as a 184-bit integer by verifying that the
     *    most significant bits (beyond the 184th bit) are zero.
     * 2. If the value is within the valid range, return the cast value as `int184`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt184(int256 x) internal pure returns (int184) {
        int184 y = int184(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer (`int256`) to a 192-bit signed integer (`int192`).
     * @dev This function ensures that the value of `x` fits within the range of a 192-bit integer.
     * If the value is out of range, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int192 The converted 192-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` fits within the range of a 192-bit integer by performing a bitwise operation.
     * 2. If the value is within range, return the value as an `int192`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt192(int256 x) internal pure returns (int192) {
        int192 y = int192(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 200-bit signed integer.
     *
     * @dev This function performs an unchecked conversion from `int256` to `int200`.
     * It checks if the value of `x` can fit within the range of a 200-bit signed integer.
     * If the value is within the valid range, it returns the value as `int200`.
     * If the value exceeds the range, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int200 The converted 200-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within the range of a 200-bit signed integer.
     * 2. If it fits, return the value as `int200`.
     * 3. If it does not fit, revert with an overflow error.
     */
    function toInt200(int256 x) internal pure returns (int200) {
        int200 y = int200(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int208, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int208 The converted int208 value.
     *
     * Steps:
     * 1. Check if the value `x` can fit within the int208 range by verifying that the most significant bits are zero.
     * 2. If the value fits, return the converted int208 value.
     * 3. If the value does not fit (overflow), revert with an overflow error.
     */
    function toInt208(int256 x) internal pure returns (int208) {
        int208 y = int208(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int216, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int216 The converted int216 value.
     *
     * Steps:
     * 1. Check if the value `x` can fit within the range of int216.
     * 2. If it fits, return the value as int216.
     * 3. If it does not fit, revert with an overflow error.
     */
    function toInt216(int256 x) internal pure returns (int216) {
        int216 y = int216(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int224, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int224 The converted value, if it fits within the int224 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int224 by verifying it does not exceed the int224 range.
     * 2. If the value is within the valid range, return it as int224.
     * 3. If the value exceeds the range, revert with an overflow error.
     */
    function toInt224(int256 x) internal pure returns (int224) {
        int224 y = int224(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int232, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int232 The converted int232 value.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int232 without overflow.
     * 2. If the value is within the valid range, return the casted int232 value.
     * 3. If the value exceeds the valid range, revert with an overflow error.
     */
    function toInt232(int256 x) internal pure returns (int232) {
        int232 y = int232(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts a 256-bit signed integer to a 240-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to a 240-bit integer without overflow.
     * If the value is within the valid range for a 240-bit integer, it returns the cast value.
     * Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int240 The 240-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be safely represented as a 240-bit integer by verifying that the upper bits (above 240) are zero.
     * 2. If the value is valid, return the cast value as `int240`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt240(int256 x) internal pure returns (int240) {
        int240 y = int240(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /**
     * @notice Converts an int256 value to int248, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int248 The converted value if it fits within the int248 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int248 without overflow.
     * 2. If the value is within the valid range, return it as int248.
     * 3. If the value overflows, revert with an overflow error.
     */
    function toInt248(int256 x) internal pure returns (int248) {
        int248 y = int248(x);
        if (x != int256(y)) _revertOverflow();
        return y;
    }

    /*//////////////////////////////////////////////////////////////
                       UINT TO INT (SIGNED RESULT)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts a 256-bit integer to an 8-bit integer, checking for overflow.
     *
     * @param x The 256-bit integer to be converted.
     * @return int8 The resulting 8-bit integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within an 8-bit integer by verifying that the upper bits are zero.
     * 2. If the value fits, return the 8-bit integer representation of `x`.
     * 3. If the value does not fit, revert with an overflow error.
     *
     * @dev This function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt8(uint256 x) internal pure returns (int8) {
        if (x >= (1 << 7)) _revertOverflow();
        return int8(int256(x));
    }

    /**
     * @notice Converts a 256-bit integer to a 16-bit integer, reverting on overflow.
     *
     * @param x The 256-bit integer to be converted.
     * @return int16 The resulting 16-bit integer.
     *
     * Steps:
     * 1. Check if the value of `x` can be safely represented as a 16-bit integer.
     * 2. If the value is within the valid range, return the 16-bit integer.
     * 3. If the value is out of range, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt16(uint256 x) internal pure returns (int16) {
        if (x >= (1 << 15)) _revertOverflow();
        return int16(int256(x));
    }

    /**
     * @notice Converts an int256 value to int24, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted to int24.
     * @return int24 The converted int24 value.
     *
     * Steps:
     * 1. Check if the value `x` can fit within the int24 range without overflow.
     * 2. If it fits, return the value as int24.
     * 3. If it does not fit, revert with an overflow error.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt24(uint256 x) internal pure returns (int24) {
        if (x >= (1 << 23)) _revertOverflow();
        return int24(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 32-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to an `int32` without overflow.
     *      If the value is within the valid range for `int32`, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int32 The 32-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be represented as a 32-bit signed integer by verifying that the upper bits are zero.
     * 2. If the value is within the valid range, return the cast value as `int32`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt32(uint256 x) internal pure returns (int32) {
        if (x >= (1 << 31)) _revertOverflow();
        return int32(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 40-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to a 40-bit integer.
     *      If the value is within the valid range for a 40-bit integer, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int40 The 40-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can fit within a 40-bit integer by verifying if the 40th bit is not set.
     * 2. If the value is within the valid range, return the cast value as `int40`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt40(uint256 x) internal pure returns (int40) {
        if (x >= (1 << 39)) _revertOverflow();
        return int40(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 48-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int48 The resulting 48-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely cast to a 48-bit integer without overflow.
     * 2. If the value is within the valid range, return the casted 48-bit integer.
     * 3. If the value exceeds the 48-bit range, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt48(uint256 x) internal pure returns (int48) {
        if (x >= (1 << 47)) _revertOverflow();
        return int48(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 56-bit signed integer.
     *
     * @dev This function performs an unchecked conversion to ensure efficiency.
     *      It checks if the input value `x` can fit within the 56-bit range.
     *      If the value is within the valid range, it returns the converted value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int56 The converted 56-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can fit within the 56-bit range by performing a bitwise operation.
     * 2. If the value is within the valid range, return the converted value as `int56`.
     * 3. If the value exceeds the 56-bit range, revert with an overflow error.
     */
    function toInt56(uint256 x) internal pure returns (int56) {
        if (x >= (1 << 55)) _revertOverflow();
        return int56(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 64-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to `int64` without overflow.
     *      If the value is within the valid range for `int64`, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int64 The 64-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be safely represented as a 64-bit integer by verifying that the upper bits are zero.
     * 2. If the value is within the valid range, return the cast value as `int64`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt64(uint256 x) internal pure returns (int64) {
        if (x >= (1 << 63)) _revertOverflow();
        return int64(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer (`int256`) to a 72-bit signed integer (`int72`).
     *
     * @dev This function performs a safe downcast from `int256` to `int72`. It checks if the value of `x`
     *      fits within the range of a 72-bit signed integer. If the value is out of bounds, it reverts
     *      with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int72 The converted 72-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within the range of a 72-bit signed integer by performing
     *    a bitwise operation. Specifically, it checks if the value, when shifted and masked, is zero.
     * 2. If the value fits, return the downcasted `int72` value.
     * 3. If the value does not fit, revert with an overflow error using `_revertOverflow()`.
     */
    function toInt72(uint256 x) internal pure returns (int72) {
        if (x >= (1 << 71)) _revertOverflow();
        return int72(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to an 80-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int80 The resulting 80-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely represented as an 80-bit integer.
     * 2. If the value is within the valid range, return the converted 80-bit integer.
     * 3. If the value exceeds the range of an 80-bit integer, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt80(uint256 x) internal pure returns (int80) {
        if (x >= (1 << 79)) _revertOverflow();
        return int80(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to an 88-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int88 The resulting 88-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within the range of an 88-bit integer.
     * 2. If it fits, return the value as an 88-bit integer.
     * 3. If it does not fit, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to avoid unnecessary gas costs.
     *      The overflow check ensures that the value does not exceed the bounds of an 88-bit integer.
     */
    function toInt88(uint256 x) internal pure returns (int88) {
        if (x >= (1 << 87)) _revertOverflow();
        return int88(int256(x));
    }

    /**
     * @notice Converts an int256 value to int96, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int96 The converted value, if it fits within the int96 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int96 by verifying it does not exceed the 96-bit range.
     * 2. If the value fits within the range, return it as int96.
     * 3. If the value exceeds the range, revert with an overflow error.
     */
    function toInt96(uint256 x) internal pure returns (int96) {
        if (x >= (1 << 95)) _revertOverflow();
        return int96(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 104-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int104 The resulting 104-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely downcasted to a 104-bit integer.
     * 2. If the value is within the valid range for a 104-bit integer, return the downcasted value.
     * 3. If the value exceeds the valid range, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt104(uint256 x) internal pure returns (int104) {
        if (x >= (1 << 103)) _revertOverflow();
        return int104(int256(x));
    }

    /**
     * @notice Converts a 256-bit integer to a 112-bit integer, reverting on overflow.
     *
     * @param x The 256-bit integer to be converted.
     * @return int112 The converted 112-bit integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within a 112-bit integer by verifying that the upper bits (beyond 112 bits) are zero.
     * 2. If the value fits, return the value as a 112-bit integer.
     * 3. If the value does not fit, revert with an overflow error.
     *
     * Note: The function uses `unchecked` to avoid unnecessary overflow checks, but explicitly reverts if the value exceeds the 112-bit range.
     */
    function toInt112(uint256 x) internal pure returns (int112) {
        if (x >= (1 << 111)) _revertOverflow();
        return int112(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 120-bit signed integer.
     * @dev This function performs an unchecked conversion and checks for overflow.
     * If the value of `x` is within the valid range for a 120-bit integer, it is returned.
     * Otherwise, the function reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int120 The converted 120-bit signed integer.
     *
     * Steps:
     * 1. Perform an unchecked operation to avoid overflow checks during arithmetic.
     * 2. Check if the value of `x` is within the valid range for a 120-bit integer.
     *    - If valid, return the value as an `int120`.
     *    - If invalid, revert with an overflow error using `_revertOverflow()`.
     */
    function toInt120(uint256 x) internal pure returns (int120) {
        if (x >= (1 << 119)) _revertOverflow();
        return int120(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 128-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to `int128` without overflow.
     *      If the value is within the valid range for `int128`, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int128 The 128-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be safely represented as an `int128` by verifying that the upper 128 bits are zero.
     * 2. If the value is within the valid range, return the cast value as `int128`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt128(uint256 x) internal pure returns (int128) {
        if (x >= (1 << 127)) _revertOverflow();
        return int128(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 136-bit signed integer.
     *
     * @dev This function performs an overflow check to ensure the input value fits within the 136-bit range.
     * If the input value is within the valid range, it is cast to `int136` and returned.
     * If the input value exceeds the 136-bit range, the function reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int136 The converted 136-bit signed integer.
     *
     * Steps:
     * 1. Perform an unchecked block to avoid overflow checks during arithmetic operations.
     * 2. Check if the input value `x` fits within the 136-bit range by shifting and comparing.
     * 3. If the value is within range, return it as `int136`.
     * 4. If the value exceeds the range, revert with an overflow error.
     */
    function toInt136(uint256 x) internal pure returns (int136) {
        if (x >= (1 << 135)) _revertOverflow();
        return int136(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 144-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int144 The resulting 144-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` can be safely represented as a 144-bit signed integer.
     * 2. If the value is within the valid range, return the value cast to `int144`.
     * 3. If the value exceeds the valid range, revert with an overflow error.
     *
     * Note: The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt144(uint256 x) internal pure returns (int144) {
        if (x >= (1 << 143)) _revertOverflow();
        return int144(int256(x));
    }

    /**
     * @notice Converts an int256 value to int152, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int152 The converted value, if it fits within the int152 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int152 by verifying it does not exceed the range of int152.
     * 2. If the value is within the valid range, return it as int152.
     * 3. If the value exceeds the range, revert with an overflow error.
     *
     * @dev This function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt152(uint256 x) internal pure returns (int152) {
        if (x >= (1 << 151)) _revertOverflow();
        return int152(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer (`int256`) to a 160-bit signed integer (`int160`).
     * @dev This function checks for overflow conditions. If the value of `x` cannot be represented
     *      as a 160-bit signed integer, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int160 The 160-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value of `x` can be safely represented as a 160-bit signed integer.
     *    - This is done by shifting and masking to ensure the upper bits are zero.
     * 2. If the value is within the valid range, return the converted `int160` value.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt160(uint256 x) internal pure returns (int160) {
        if (x >= (1 << 159)) _revertOverflow();
        return int160(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 168-bit signed integer.
     * @dev This function ensures that the input value fits within the 168-bit range.
     * If the value exceeds the range, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int168 The resulting 168-bit signed integer.
     *
     * Steps:
     * 1. Check if the input value `x` fits within the 168-bit range by performing bitwise operations.
     * 2. If the value fits, return the value as a 168-bit integer.
     * 3. If the value exceeds the range, revert with an overflow error.
     */
    function toInt168(uint256 x) internal pure returns (int168) {
        if (x >= (1 << 167)) _revertOverflow();
        return int168(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 176-bit signed integer.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int176 The resulting 176-bit signed integer.
     *
     * Steps:
     * 1. Check if the input `x` can be safely represented as a 176-bit integer.
     * 2. If the conversion is safe, return the 176-bit integer.
     * 3. If the conversion would result in overflow, revert with an overflow error.
     *
     * @dev The function uses unchecked arithmetic to optimize gas usage.
     */
    function toInt176(uint256 x) internal pure returns (int176) {
        if (x >= (1 << 175)) _revertOverflow();
        return int176(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 184-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to a 184-bit integer.
     *      If the value is within the valid range for a 184-bit integer, it returns the cast value.
     *      Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int184 The 184-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be represented as a 184-bit integer by verifying that the
     *    most significant bits (beyond the 184th bit) are zero.
     * 2. If the value is within the valid range, return the cast value as `int184`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt184(uint256 x) internal pure returns (int184) {
        if (x >= (1 << 183)) _revertOverflow();
        return int184(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer (`int256`) to a 192-bit signed integer (`int192`).
     * @dev This function ensures that the value of `x` fits within the range of a 192-bit integer.
     * If the value is out of range, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int192 The converted 192-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` fits within the range of a 192-bit integer by performing a bitwise operation.
     * 2. If the value is within range, return the value as an `int192`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt192(uint256 x) internal pure returns (int192) {
        if (x >= (1 << 191)) _revertOverflow();
        return int192(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 200-bit signed integer.
     *
     * @dev This function performs an unchecked conversion from `int256` to `int200`.
     * It checks if the value of `x` can fit within the range of a 200-bit signed integer.
     * If the value is within the valid range, it returns the value as `int200`.
     * If the value exceeds the range, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int200 The converted 200-bit signed integer.
     *
     * Steps:
     * 1. Check if the value of `x` can fit within the range of a 200-bit signed integer.
     * 2. If it fits, return the value as `int200`.
     * 3. If it does not fit, revert with an overflow error.
     */
    function toInt200(uint256 x) internal pure returns (int200) {
        if (x >= (1 << 199)) _revertOverflow();
        return int200(int256(x));
    }

    /**
     * @notice Converts an int256 value to int208, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int208 The converted int208 value.
     *
     * Steps:
     * 1. Check if the value `x` can fit within the int208 range by verifying that the most significant bits are zero.
     * 2. If the value fits, return the converted int208 value.
     * 3. If the value does not fit (overflow), revert with an overflow error.
     */
    function toInt208(uint256 x) internal pure returns (int208) {
        if (x >= (1 << 207)) _revertOverflow();
        return int208(int256(x));
    }

    /**
     * @notice Converts an int256 value to int216, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int216 The converted int216 value.
     *
     * Steps:
     * 1. Check if the value `x` can fit within the range of int216.
     * 2. If it fits, return the value as int216.
     * 3. If it does not fit, revert with an overflow error.
     */
    function toInt216(uint256 x) internal pure returns (int216) {
        if (x >= (1 << 215)) _revertOverflow();
        return int216(int256(x));
    }

    /**
     * @notice Converts an int256 value to int224, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int224 The converted value, if it fits within the int224 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int224 by verifying it does not exceed the int224 range.
     * 2. If the value is within the valid range, return it as int224.
     * 3. If the value exceeds the range, revert with an overflow error.
     */
    function toInt224(uint256 x) internal pure returns (int224) {
        if (x >= (1 << 223)) _revertOverflow();
        return int224(int256(x));
    }

    /**
     * @notice Converts an int256 value to int232, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int232 The converted int232 value.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int232 without overflow.
     * 2. If the value is within the valid range, return the casted int232 value.
     * 3. If the value exceeds the valid range, revert with an overflow error.
     */
    function toInt232(uint256 x) internal pure returns (int232) {
        if (x >= (1 << 231)) _revertOverflow();
        return int232(int256(x));
    }

    /**
     * @notice Converts a 256-bit signed integer to a 240-bit signed integer.
     * @dev This function checks if the input value `x` can be safely cast to a 240-bit integer without overflow.
     * If the value is within the valid range for a 240-bit integer, it returns the cast value.
     * Otherwise, it reverts with an overflow error.
     *
     * @param x The 256-bit signed integer to be converted.
     * @return int240 The 240-bit signed integer representation of `x`.
     *
     * Steps:
     * 1. Check if the value `x` can be safely represented as a 240-bit integer by verifying that the upper bits (above 240) are zero.
     * 2. If the value is valid, return the cast value as `int240`.
     * 3. If the value is out of range, revert with an overflow error.
     */
    function toInt240(uint256 x) internal pure returns (int240) {
        if (x >= (1 << 239)) _revertOverflow();
        return int240(int256(x));
    }

    /**
     * @notice Converts an int256 value to int248, ensuring it does not overflow.
     *
     * @param x The int256 value to be converted.
     * @return int248 The converted value if it fits within the int248 range.
     *
     * Steps:
     * 1. Check if the value `x` can be safely cast to int248 without overflow.
     * 2. If the value is within the valid range, return it as int248.
     * 3. If the value overflows, revert with an overflow error.
     */
    function toInt248(uint256 x) internal pure returns (int248) {
        if (x >= (1 << 247)) _revertOverflow();
        return int248(int256(x));
    }

    /*//////////////////////////////////////////////////////////////
                         UINT <-> INT256
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts a uint256 value to an int256 value, ensuring no overflow occurs.
     *
     * @param x The uint256 value to be converted to int256.
     * @return int256 The converted int256 value.
     *
     * Steps:
     * 1. Check if the uint256 value can be safely cast to int256 (i.e., it is within the valid range for int256).
     * 2. If the value is within the valid range, return the cast int256 value.
     * 3. If the value is outside the valid range (i.e., it would cause an overflow), revert with an overflow error.
     */
    function toInt256(uint256 x) internal pure returns (int256) {
        if (x > uint256(type(int256).max)) _revertOverflow();
        return int256(x);
    }

    /**
     * @notice Converts an int256 to a uint256. Reverts if the input is negative.
     *
     * @param x The int256 value to be converted to uint256.
     * @return uint256 The converted unsigned integer value.
     *
     * Steps:
     * 1. Check if the input `x` is non-negative.
     * 2. If `x` is non-negative, safely cast it to uint256 and return.
     * 3. If `x` is negative, revert with an overflow error.
     */
    function toUint256(int256 x) internal pure returns (uint256) {
        if (x < 0) _revertOverflow();
        return uint256(x);
    }

    /**
     * @notice A private pure function that reverts with an overflow error.
     *
     * Steps:
     * 1. Use inline assembly to store the function selector of `Overflow()` at memory location 0x00.
     * 2. Revert the transaction with the stored function selector, indicating an overflow error.
     */
    function _revertOverflow() private pure {
        assembly {
            mstore(0x00, 0x35278d1200000000000000000000000000000000000000000000000000000000)
            revert(0x00, 0x04)
        }
    }
}