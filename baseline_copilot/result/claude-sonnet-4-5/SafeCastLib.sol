// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe casting library that reverts on overflow.
library SafeCastLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error Overflow();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*          UNSIGNED INTEGER SAFE CASTING OPERATIONS          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Converts a uint256 value to a uint8 value, reverting if the value exceeds the uint8 range.
    function toUint8(uint256 x) internal pure returns (uint8) {
        unchecked {
            if (x >= 1 << 8) _revertOverflow();
            return uint8(x);
        }
    }

    /// @notice Converts a uint256 value to a uint16 value, reverting if the value exceeds the uint16 range.
    function toUint16(uint256 x) internal pure returns (uint16) {
        unchecked {
            if (x >= 1 << 16) _revertOverflow();
            return uint16(x);
        }
    }

    /// @notice Converts a uint256 value to a uint24 value, reverting if the value exceeds the uint24 range.
    function toUint24(uint256 x) internal pure returns (uint24) {
        unchecked {
            if (x >= 1 << 24) _revertOverflow();
            return uint24(x);
        }
    }

    /// @notice Converts a uint256 value to a uint32 value, reverting if the value exceeds the uint32 range.
    function toUint32(uint256 x) internal pure returns (uint32) {
        unchecked {
            if (x >= 1 << 32) _revertOverflow();
            return uint32(x);
        }
    }

    /// @notice Converts a uint256 value to a uint40 value, ensuring no overflow occurs.
    function toUint40(uint256 x) internal pure returns (uint40) {
        unchecked {
            if (x >= 1 << 40) _revertOverflow();
            return uint40(x);
        }
    }

    /// @notice Converts a uint256 value to a uint48 value, ensuring no overflow occurs.
    function toUint48(uint256 x) internal pure returns (uint48) {
        unchecked {
            if (x >= 1 << 48) _revertOverflow();
            return uint48(x);
        }
    }

    /// @notice Converts a uint256 value to a uint56 value, ensuring no overflow occurs.
    function toUint56(uint256 x) internal pure returns (uint56) {
        unchecked {
            if (x >= 1 << 56) _revertOverflow();
            return uint56(x);
        }
    }

    /// @notice Converts a uint256 value to a uint64, ensuring no overflow occurs.
    function toUint64(uint256 x) internal pure returns (uint64) {
        unchecked {
            if (x >= 1 << 64) _revertOverflow();
            return uint64(x);
        }
    }

    /// @notice Converts a uint256 value to a uint72 value, reverting if the input exceeds the uint72 range.
    function toUint72(uint256 x) internal pure returns (uint72) {
        unchecked {
            if (x >= 1 << 72) _revertOverflow();
            return uint72(x);
        }
    }

    /// @notice Converts a uint256 value to uint80, ensuring it does not overflow.
    function toUint80(uint256 x) internal pure returns (uint80) {
        unchecked {
            if (x >= 1 << 80) _revertOverflow();
            return uint80(x);
        }
    }

    /// @notice Converts a uint256 value to uint88, ensuring no overflow occurs.
    function toUint88(uint256 x) internal pure returns (uint88) {
        unchecked {
            if (x >= 1 << 88) _revertOverflow();
            return uint88(x);
        }
    }

    /// @notice Converts a uint256 value to uint96, ensuring no overflow occurs.
    function toUint96(uint256 x) internal pure returns (uint96) {
        unchecked {
            if (x >= 1 << 96) _revertOverflow();
            return uint96(x);
        }
    }

    /// @notice Safely converts a uint256 value to uint104, ensuring no overflow occurs.
    function toUint104(uint256 x) internal pure returns (uint104) {
        unchecked {
            if (x >= 1 << 104) _revertOverflow();
            return uint104(x);
        }
    }

    /// @notice Converts a uint256 value to uint112, ensuring it does not overflow.
    function toUint112(uint256 x) internal pure returns (uint112) {
        unchecked {
            if (x >= 1 << 112) _revertOverflow();
            return uint112(x);
        }
    }

    /// @notice Converts a uint256 value to uint120, reverting if the value exceeds the uint120 range.
    function toUint120(uint256 x) internal pure returns (uint120) {
        unchecked {
            if (x >= 1 << 120) _revertOverflow();
            return uint120(x);
        }
    }

    /// @notice Converts a uint256 value to uint128, ensuring no overflow occurs.
    function toUint128(uint256 x) internal pure returns (uint128) {
        unchecked {
            if (x >= 1 << 128) _revertOverflow();
            return uint128(x);
        }
    }

    /// @notice Converts a uint256 value to uint136, ensuring it does not overflow.
    function toUint136(uint256 x) internal pure returns (uint136) {
        unchecked {
            if (x >= 1 << 136) _revertOverflow();
            return uint136(x);
        }
    }

    /// @notice Converts a uint256 value to a uint144 value, ensuring no overflow occurs.
    function toUint144(uint256 x) internal pure returns (uint144) {
        unchecked {
            if (x >= 1 << 144) _revertOverflow();
            return uint144(x);
        }
    }

    /// @notice Converts a uint256 value to uint152, ensuring no overflow occurs.
    function toUint152(uint256 x) internal pure returns (uint152) {
        unchecked {
            if (x >= 1 << 152) _revertOverflow();
            return uint152(x);
        }
    }

    /// @notice Converts a uint256 value to uint160, ensuring no overflow occurs.
    function toUint160(uint256 x) internal pure returns (uint160) {
        unchecked {
            if (x >= 1 << 160) _revertOverflow();
            return uint160(x);
        }
    }

    /// @notice Converts a uint256 value to uint168, ensuring no overflow occurs.
    function toUint168(uint256 x) internal pure returns (uint168) {
        unchecked {
            if (x >= 1 << 168) _revertOverflow();
            return uint168(x);
        }
    }

    /// @notice Converts a uint256 value to uint176, ensuring no overflow occurs.
    function toUint176(uint256 x) internal pure returns (uint176) {
        unchecked {
            if (x >= 1 << 176) _revertOverflow();
            return uint176(x);
        }
    }

    /// @notice Converts a uint256 value to uint184, ensuring no overflow occurs.
    function toUint184(uint256 x) internal pure returns (uint184) {
        unchecked {
            if (x >= 1 << 184) _revertOverflow();
            return uint184(x);
        }
    }

    /// @notice Converts a uint256 value to a uint192 value, ensuring no overflow occurs.
    function toUint192(uint256 x) internal pure returns (uint192) {
        unchecked {
            if (x >= 1 << 192) _revertOverflow();
            return uint192(x);
        }
    }

    /// @notice Converts a uint256 value to uint200, ensuring no overflow occurs.
    function toUint200(uint256 x) internal pure returns (uint200) {
        unchecked {
            if (x >= 1 << 200) _revertOverflow();
            return uint200(x);
        }
    }

    /// @notice Converts a uint256 value to uint208, ensuring no overflow occurs.
    function toUint208(uint256 x) internal pure returns (uint208) {
        unchecked {
            if (x >= 1 << 208) _revertOverflow();
            return uint208(x);
        }
    }

    /// @notice Converts a uint256 value to uint216, ensuring no overflow occurs.
    function toUint216(uint256 x) internal pure returns (uint216) {
        unchecked {
            if (x >= 1 << 216) _revertOverflow();
            return uint216(x);
        }
    }

    /// @notice Converts a uint256 value to uint224, ensuring no overflow occurs.
    function toUint224(uint256 x) internal pure returns (uint224) {
        unchecked {
            if (x >= 1 << 224) _revertOverflow();
            return uint224(x);
        }
    }

    /// @notice Converts a uint256 value to a uint232 value, ensuring no overflow occurs.
    function toUint232(uint256 x) internal pure returns (uint232) {
        unchecked {
            if (x >= 1 << 232) _revertOverflow();
            return uint232(x);
        }
    }

    /// @notice Converts a uint256 value to uint240, ensuring no overflow occurs.
    function toUint240(uint256 x) internal pure returns (uint240) {
        unchecked {
            if (x >= 1 << 240) _revertOverflow();
            return uint240(x);
        }
    }

    /// @notice Converts a uint256 value to uint248, ensuring no overflow occurs.
    function toUint248(uint256 x) internal pure returns (uint248) {
        unchecked {
            if (x >= 1 << 248) _revertOverflow();
            return uint248(x);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*           SIGNED INTEGER SAFE CASTING OPERATIONS           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Converts a 256-bit integer to an 8-bit integer, checking for overflow.
    function toInt8(int256 x) internal pure returns (int8) {
        unchecked {
            if (((x << 248) >> 248) != x) _revertOverflow();
            return int8(x);
        }
    }

    /// @notice Converts a 256-bit integer to a 16-bit integer, reverting on overflow.
    function toInt16(int256 x) internal pure returns (int16) {
        unchecked {
            if (((x << 240) >> 240) != x) _revertOverflow();
            return int16(x);
        }
    }

    /// @notice Converts an int256 value to int24, ensuring it does not overflow.
    function toInt24(int256 x) internal pure returns (int24) {
        unchecked {
            if (((x << 232) >> 232) != x) _revertOverflow();
            return int24(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 32-bit signed integer.
    function toInt32(int256 x) internal pure returns (int32) {
        unchecked {
            if (((x << 224) >> 224) != x) _revertOverflow();
            return int32(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 40-bit signed integer.
    function toInt40(int256 x) internal pure returns (int40) {
        unchecked {
            if (((x << 216) >> 216) != x) _revertOverflow();
            return int40(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 48-bit signed integer.
    function toInt48(int256 x) internal pure returns (int48) {
        unchecked {
            if (((x << 208) >> 208) != x) _revertOverflow();
            return int48(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 56-bit signed integer.
    function toInt56(int256 x) internal pure returns (int56) {
        unchecked {
            if (((x << 200) >> 200) != x) _revertOverflow();
            return int56(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 64-bit signed integer.
    function toInt64(int256 x) internal pure returns (int64) {
        unchecked {
            if (((x << 192) >> 192) != x) _revertOverflow();
            return int64(x);
        }
    }

    /// @notice Converts a 256-bit signed integer (`int256`) to a 72-bit signed integer (`int72`).
    function toInt72(int256 x) internal pure returns (int72) {
        unchecked {
            if (((x << 184) >> 184) != x) _revertOverflow();
            return int72(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to an 80-bit signed integer.
    function toInt80(int256 x) internal pure returns (int80) {
        unchecked {
            if (((x << 176) >> 176) != x) _revertOverflow();
            return int80(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to an 88-bit signed integer.
    function toInt88(int256 x) internal pure returns (int88) {
        unchecked {
            if (((x << 168) >> 168) != x) _revertOverflow();
            return int88(x);
        }
    }

    /// @notice Converts an int256 value to int96, ensuring it does not overflow.
    function toInt96(int256 x) internal pure returns (int96) {
        unchecked {
            if (((x << 160) >> 160) != x) _revertOverflow();
            return int96(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 104-bit signed integer.
    function toInt104(int256 x) internal pure returns (int104) {
        unchecked {
            if (((x << 152) >> 152) != x) _revertOverflow();
            return int104(x);
        }
    }

    /// @notice Converts a 256-bit integer to a 112-bit integer, reverting on overflow.
    function toInt112(int256 x) internal pure returns (int112) {
        unchecked {
            if (((x << 144) >> 144) != x) _revertOverflow();
            return int112(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 120-bit signed integer.
    function toInt120(int256 x) internal pure returns (int120) {
        unchecked {
            if (((x << 136) >> 136) != x) _revertOverflow();
            return int120(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 128-bit signed integer.
    function toInt128(int256 x) internal pure returns (int128) {
        unchecked {
            if (((x << 128) >> 128) != x) _revertOverflow();
            return int128(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 136-bit signed integer.
    function toInt136(int256 x) internal pure returns (int136) {
        unchecked {
            if (((x << 120) >> 120) != x) _revertOverflow();
            return int136(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 144-bit signed integer.
    function toInt144(int256 x) internal pure returns (int144) {
        unchecked {
            if (((x << 112) >> 112) != x) _revertOverflow();
            return int144(x);
        }
    }

    /// @notice Converts an int256 value to int152, ensuring it does not overflow.
    function toInt152(int256 x) internal pure returns (int152) {
        unchecked {
            if (((x << 104) >> 104) != x) _revertOverflow();
            return int152(x);
        }
    }

    /// @notice Converts a 256-bit signed integer (`int256`) to a 160-bit signed integer (`int160`).
    function toInt160(int256 x) internal pure returns (int160) {
        unchecked {
            if (((x << 96) >> 96) != x) _revertOverflow();
            return int160(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 168-bit signed integer.
    function toInt168(int256 x) internal pure returns (int168) {
        unchecked {
            if (((x << 88) >> 88) != x) _revertOverflow();
            return int168(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 176-bit signed integer.
    function toInt176(int256 x) internal pure returns (int176) {
        unchecked {
            if (((x << 80) >> 80) != x) _revertOverflow();
            return int176(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 184-bit signed integer.
    function toInt184(int256 x) internal pure returns (int184) {
        unchecked {
            if (((x << 72) >> 72) != x) _revertOverflow();
            return int184(x);
        }
    }

    /// @notice Converts a 256-bit signed integer (`int256`) to a 192-bit signed integer (`int192`).
    function toInt192(int256 x) internal pure returns (int192) {
        unchecked {
            if (((x << 64) >> 64) != x) _revertOverflow();
            return int192(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 200-bit signed integer.
    function toInt200(int256 x) internal pure returns (int200) {
        unchecked {
            if (((x << 56) >> 56) != x) _revertOverflow();
            return int200(x);
        }
    }

    /// @notice Converts an int256 value to int208, ensuring it does not overflow.
    function toInt208(int256 x) internal pure returns (int208) {
        unchecked {
            if (((x << 48) >> 48) != x) _revertOverflow();
            return int208(x);
        }
    }

    /// @notice Converts an int256 value to int216, ensuring it does not overflow.
    function toInt216(int256 x) internal pure returns (int216) {
        unchecked {
            if (((x << 40) >> 40) != x) _revertOverflow();
            return int216(x);
        }
    }

    /// @notice Converts an int256 value to int224, ensuring it does not overflow.
    function toInt224(int256 x) internal pure returns (int224) {
        unchecked {
            if (((x << 32) >> 32) != x) _revertOverflow();
            return int224(x);
        }
    }

    /// @notice Converts an int256 value to int232, ensuring it does not overflow.
    function toInt232(int256 x) internal pure returns (int232) {
        unchecked {
            if (((x << 24) >> 24) != x) _revertOverflow();
            return int232(x);
        }
    }

    /// @notice Converts a 256-bit signed integer to a 240-bit signed integer.
    function toInt240(int256 x) internal pure returns (int240) {
        unchecked {
            if (((x << 16) >> 16) != x) _revertOverflow();
            return int240(x);
        }
    }

    /// @notice Converts an int256 value to int248, ensuring it does not overflow.
    function toInt248(int256 x) internal pure returns (int248) {
        unchecked {
            if (((x << 8) >> 8) != x) _revertOverflow();
            return int248(x);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    UINT TO INT CONVERSIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Converts a 256-bit integer to an 8-bit integer, checking for overflow.
    function toInt8(uint256 x) internal pure returns (int8) {
        unchecked {
            if (x >= 1 << 7) _revertOverflow();
            return int8(int256(x));
        }
    }

    /// @notice Converts a 256-bit integer to a 16-bit integer, reverting on overflow.
    function toInt16(uint256 x) internal pure returns (int16) {
        unchecked {
            if (x >= 1 << 15) _revertOverflow();
            return int16(int256(x));
        }
    }

    /// @notice Converts an int256 value to int24, ensuring it does not overflow.
    function toInt24(uint256 x) internal pure returns (int24) {
        unchecked {
            if (x >= 1 << 23) _revertOverflow();
            return int24(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 32-bit signed integer.
    function toInt32(uint256 x) internal pure returns (int32) {
        unchecked {
            if (x >= 1 << 31) _revertOverflow();
            return int32(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 40-bit signed integer.
    function toInt40(uint256 x) internal pure returns (int40) {
        unchecked {
            if (x >= 1 << 39) _revertOverflow();
            return int40(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 48-bit signed integer.
    function toInt48(uint256 x) internal pure returns (int48) {
        unchecked {
            if (x >= 1 << 47) _revertOverflow();
            return int48(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 56-bit signed integer.
    function toInt56(uint256 x) internal pure returns (int56) {
        unchecked {
            if (x >= 1 << 55) _revertOverflow();
            return int56(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 64-bit signed integer.
    function toInt64(uint256 x) internal pure returns (int64) {
        unchecked {
            if (x >= 1 << 63) _revertOverflow();
            return int64(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer (`int256`) to a 72-bit signed integer (`int72`).
    function toInt72(uint256 x) internal pure returns (int72) {
        unchecked {
            if (x >= 1 << 71) _revertOverflow();
            return int72(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to an 80-bit signed integer.
    function toInt80(uint256 x) internal pure returns (int80) {
        unchecked {
            if (x >= 1 << 79) _revertOverflow();
            return int80(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to an 88-bit signed integer.
    function toInt88(uint256 x) internal pure returns (int88) {
        unchecked {
            if (x >= 1 << 87) _revertOverflow();
            return int88(int256(x));
        }
    }

    /// @notice Converts an int256 value to int96, ensuring it does not overflow.
    function toInt96(uint256 x) internal pure returns (int96) {
        unchecked {
            if (x >= 1 << 95) _revertOverflow();
            return int96(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 104-bit signed integer.
    function toInt104(uint256 x) internal pure returns (int104) {
        unchecked {
            if (x >= 1 << 103) _revertOverflow();
            return int104(int256(x));
        }
    }

    /// @notice Converts a 256-bit integer to a 112-bit integer, reverting on overflow.
    function toInt112(uint256 x) internal pure returns (int112) {
        unchecked {
            if (x >= 1 << 111) _revertOverflow();
            return int112(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 120-bit signed integer.
    function toInt120(uint256 x) internal pure returns (int120) {
        unchecked {
            if (x >= 1 << 119) _revertOverflow();
            return int120(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 128-bit signed integer.
    function toInt128(uint256 x) internal pure returns (int128) {
        unchecked {
            if (x >= 1 << 127) _revertOverflow();
            return int128(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 136-bit signed integer.
    function toInt136(uint256 x) internal pure returns (int136) {
        unchecked {
            if (x >= 1 << 135) _revertOverflow();
            return int136(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 144-bit signed integer.
    function toInt144(uint256 x) internal pure returns (int144) {
        unchecked {
            if (x >= 1 << 143) _revertOverflow();
            return int144(int256(x));
        }
    }

    /// @notice Converts an int256 value to int152, ensuring it does not overflow.
    function toInt152(uint256 x) internal pure returns (int152) {
        unchecked {
            if (x >= 1 << 151) _revertOverflow();
            return int152(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer (`int256`) to a 160-bit signed integer (`int160`).
    function toInt160(uint256 x) internal pure returns (int160) {
        unchecked {
            if (x >= 1 << 159) _revertOverflow();
            return int160(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 168-bit signed integer.
    function toInt168(uint256 x) internal pure returns (int168) {
        unchecked {
            if (x >= 1 << 167) _revertOverflow();
            return int168(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 176-bit signed integer.
    function toInt176(uint256 x) internal pure returns (int176) {
        unchecked {
            if (x >= 1 << 175) _revertOverflow();
            return int176(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 184-bit signed integer.
    function toInt184(uint256 x) internal pure returns (int184) {
        unchecked {
            if (x >= 1 << 183) _revertOverflow();
            return int184(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer (`int256`) to a 192-bit signed integer (`int192`).
    function toInt192(uint256 x) internal pure returns (int192) {
        unchecked {
            if (x >= 1 << 191) _revertOverflow();
            return int192(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 200-bit signed integer.
    function toInt200(uint256 x) internal pure returns (int200) {
        unchecked {
            if (x >= 1 << 199) _revertOverflow();
            return int200(int256(x));
        }
    }

    /// @notice Converts an int256 value to int208, ensuring it does not overflow.
    function toInt208(uint256 x) internal pure returns (int208) {
        unchecked {
            if (x >= 1 << 207) _revertOverflow();
            return int208(int256(x));
        }
    }

    /// @notice Converts an int256 value to int216, ensuring it does not overflow.
    function toInt216(uint256 x) internal pure returns (int216) {
        unchecked {
            if (x >= 1 << 215) _revertOverflow();
            return int216(int256(x));
        }
    }

    /// @notice Converts an int256 value to int224, ensuring it does not overflow.
    function toInt224(uint256 x) internal pure returns (int224) {
        unchecked {
            if (x >= 1 << 223) _revertOverflow();
            return int224(int256(x));
        }
    }

    /// @notice Converts an int256 value to int232, ensuring it does not overflow.
    function toInt232(uint256 x) internal pure returns (int232) {
        unchecked {
            if (x >= 1 << 231) _revertOverflow();
            return int232(int256(x));
        }
    }

    /// @notice Converts a 256-bit signed integer to a 240-bit signed integer.
    function toInt240(uint256 x) internal pure returns (int240) {
        unchecked {
            if (x >= 1 << 239) _revertOverflow();
            return int240(int256(x));
        }
    }

    /// @notice Converts an int256 value to int248, ensuring it does not overflow.
    function toInt248(uint256 x) internal pure returns (int248) {
        unchecked {
            if (x >= 1 << 247) _revertOverflow();
            return int248(int256(x));
        }
    }

    /// @notice Converts a uint256 value to an int256 value, ensuring no overflow occurs.
    function toInt256(uint256 x) internal pure returns (int256) {
        unchecked {
            if (x >= 1 << 255) _revertOverflow();
            return int256(x);
        }
    }

    /// @notice Converts an int256 to a uint256. Reverts if the input is negative.
    function toUint256(int256 x) internal pure returns (uint256) {
        unchecked {
            if (x < 0) _revertOverflow();
            return uint256(x);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice A private pure function that reverts with an overflow error.
    function _revertOverflow() private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x35278d12) // `Overflow()`.
            revert(0x1c, 0x04)
        }
    }
}