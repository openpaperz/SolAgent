// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Dynamic, auto-growing in-memory bytes buffer library.
/// @dev This is a standalone reconstruction tailored to the provided API.
library DynamicBufferLib {
    /**
     * @notice Defines a struct named `DynamicBuffer` to store dynamic byte data.
     *
     * @param data A bytes array to hold the dynamic data.
     */
    struct DynamicBuffer {
        bytes data;
    }

    /**
     * @notice Returns the length of the data stored in the DynamicBuffer.
     *
     * @param buffer The DynamicBuffer whose data length is to be retrieved.
     * @return uint256 The length of the data stored in the buffer.
     */
    function length(DynamicBuffer memory buffer) internal pure returns (uint256) {
        return buffer.data.length;
    }

    /**
     * @notice Reserves additional memory for a DynamicBuffer if the current length is less than the specified minimum.
     *
     * @param buffer The DynamicBuffer to reserve memory for.
     * @param minimum The minimum length required for the buffer.
     * @return result The updated DynamicBuffer with potentially increased memory allocation.
     */
    function reserve(DynamicBuffer memory buffer, uint256 minimum)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = buffer;
        uint256 currentLength = buffer.data.length;
        if (currentLength >= minimum) {
            return result;
        }

        // Next power of 2 >= minimum.
        uint256 capacity = 1;
        while (capacity < minimum) {
            capacity <<= 1;
        }

        bytes memory newData = new bytes(capacity);
        uint256 copyLen = currentLength;
        if (copyLen != 0) {
            // Copy existing data.
            assembly {
                let src := add(mload(add(buffer, 0x20)), 0x20)
                let dst := add(newData, 0x20)
                for { let end := add(dst, copyLen) } lt(dst, end) { dst := add(dst, 0x20) src := add(src, 0x20) } {
                    mstore(dst, mload(src))
                }
            }
        }

        // Set logical length back to currentLength.
        assembly {
            mstore(newData, currentLength)
        }

        result.data = newData;

        // Store capacity * prime in word before length as a simple capacity tag.
        assembly {
            let prime := 0x1000003d
            mstore(sub(newData, 0x20), mul(capacity, prime))
        }
    }

    /**
     * @notice Clears the contents of a DynamicBuffer by deallocating its memory and resetting its length.
     *
     * @param buffer The DynamicBuffer to be cleared.
     * @return result The cleared DynamicBuffer with its length reset to 0.
     */
    function clear(DynamicBuffer memory buffer)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(buffer);
        result.data = new bytes(0);
    }

    /**
     * @notice Converts a DynamicBuffer to a string.
     *
     * @param buffer The DynamicBuffer containing the data to be converted.
     * @return The string representation of the buffer's data.
     */
    function s(DynamicBuffer memory buffer) internal pure returns (string memory) {
        return string(buffer.data);
    }

    // -------------------------------------------------------------------------
    // Core packed append operations
    // -------------------------------------------------------------------------

    function p(DynamicBuffer memory buffer, bytes memory data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = buffer;
        if (data.length == 0) return result;

        bytes memory buf = result.data;
        uint256 bufLen = buf.length;
        uint256 dataLen = data.length;
        uint256 newLen = bufLen + dataLen;

        // Ensure capacity.
        uint256 capacity;
        assembly {
            capacity := mload(sub(buf, 0x20))
        }
        uint256 prime = 0x1000003d;
        if (capacity % prime == 0 && capacity != 0) {
            capacity /= prime;
        } else {
            capacity = bufLen;
        }

        if (capacity < newLen) {
            // grow to next power of 2
            uint256 newCap = capacity == 0 ? 1 : capacity;
            while (newCap < newLen) {
                newCap <<= 1;
            }
            bytes memory newBuf = new bytes(newCap);
            // copy old content
            assembly {
                let src := add(buf, 0x20)
                let dst := add(newBuf, 0x20)
                let len := bufLen
                for { let end := add(dst, len) } lt(dst, end) { dst := add(dst, 0x20) src := add(src, 0x20) } {
                    mstore(dst, mload(src))
                }
                mstore(newBuf, bufLen)
            }
            result.data = newBuf;
            buf = newBuf;
            capacity = newCap;
        }

        // Append data (backwards copy by words).
        assembly {
            let dst := add(add(buf, 0x20), bufLen)
            let src := add(add(data, 0x20), dataLen)
            let n := dataLen
            for { } gt(n, 0x20) { n := sub(n, 0x20) } {
                src := sub(src, 0x20)
                dst := sub(dst, 0x20)
                mstore(dst, mload(src))
            }
            if n {
                src := sub(src, 0x20)
                dst := sub(dst, 0x20)
                let mask := sub(shl(mul(8, sub(0x20, n)), 1), 1)
                let srcWord := mload(src)
                let dstWord := mload(dst)
                mstore(dst, or(and(dstWord, mask), and(srcWord, not(mask))))
            }

            // zeroize word after buffer
            mstore(add(add(buf, 0x20), newLen), 0)

            // store new length
            mstore(buf, newLen)

            // store capacity * prime
            mstore(sub(buf, 0x20), mul(capacity, prime))
        }

        return result;
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1
    ) internal pure returns (DynamicBuffer memory result) {
        result = p(buffer, data0);
        result = p(result, data1);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2
    ) internal pure returns (DynamicBuffer memory result) {
        result = p(buffer, data0);
        result = p(result, data1);
        result = p(result, data2);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3
    ) internal pure returns (DynamicBuffer memory result) {
        result = p(buffer, data0);
        result = p(result, data1);
        result = p(result, data2);
        result = p(result, data3);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4
    ) internal pure returns (DynamicBuffer memory result) {
        result = p(buffer, data0);
        result = p(result, data1);
        result = p(result, data2);
        result = p(result, data3);
        result = p(result, data4);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5
    ) internal pure returns (DynamicBuffer memory result) {
        result = p(buffer, data0);
        result = p(result, data1);
        result = p(result, data2);
        result = p(result, data3);
        result = p(result, data4);
        result = p(result, data5);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5,
        bytes memory data6
    ) internal pure returns (DynamicBuffer memory result) {
        result = p(buffer, data0);
        result = p(result, data1);
        result = p(result, data2);
        result = p(result, data3);
        result = p(result, data4);
        result = p(result, data5);
        result = p(result, data6);
    }

    // -------------------------------------------------------------------------
    // Typed append with explicit buffer
    // -------------------------------------------------------------------------

    function pBool(DynamicBuffer memory buffer, bool data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        uint256 v;
        assembly {
            v := iszero(iszero(data))
        }
        result = p(buffer, _single(v, 1));
    }

    function pAddress(DynamicBuffer memory buffer, address data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint160(data), 20));
    }

    function pUint8(DynamicBuffer memory buffer, uint8 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 1));
    }

    function pUint16(DynamicBuffer memory buffer, uint16 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 2));
    }

    function pUint24(DynamicBuffer memory buffer, uint24 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 3));
    }

    function pUint32(DynamicBuffer memory buffer, uint32 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 4));
    }

    function pUint40(DynamicBuffer memory buffer, uint40 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 5));
    }

    function pUint48(DynamicBuffer memory buffer, uint48 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 6));
    }

    function pUint56(DynamicBuffer memory buffer, uint56 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 7));
    }

    function pUint64(DynamicBuffer memory buffer, uint64 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 8));
    }

    function pUint72(DynamicBuffer memory buffer, uint72 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 9));
    }

    function pUint80(DynamicBuffer memory buffer, uint80 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 10));
    }

    function pUint88(DynamicBuffer memory buffer, uint88 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 11));
    }

    function pUint96(DynamicBuffer memory buffer, uint96 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 12));
    }

    function pUint104(DynamicBuffer memory buffer, uint104 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 13));
    }

    function pUint112(DynamicBuffer memory buffer, uint112 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 14));
    }

    function pUint120(DynamicBuffer memory buffer, uint120 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 15));
    }

    function pUint128(DynamicBuffer memory buffer, uint128 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 16));
    }

    function pUint136(DynamicBuffer memory buffer, uint136 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 17));
    }

    function pUint144(DynamicBuffer memory buffer, uint144 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 18));
    }

    function pUint152(DynamicBuffer memory buffer, uint152 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 19));
    }

    function pUint160(DynamicBuffer memory buffer, uint160 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 20));
    }

    function pUint168(DynamicBuffer memory buffer, uint168 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 21));
    }

    function pUint176(DynamicBuffer memory buffer, uint176 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 22));
    }

    function pUint184(DynamicBuffer memory buffer, uint184 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 23));
    }

    function pUint192(DynamicBuffer memory buffer, uint192 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 24));
    }

    function pUint200(DynamicBuffer memory buffer, uint200 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 25));
    }

    function pUint208(DynamicBuffer memory buffer, uint208 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 26));
    }

    function pUint216(DynamicBuffer memory buffer, uint216 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 27));
    }

    function pUint224(DynamicBuffer memory buffer, uint224 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 28));
    }

    function pUint232(DynamicBuffer memory buffer, uint232 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 29));
    }

    function pUint240(DynamicBuffer memory buffer, uint240 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 30));
    }

    function pUint248(DynamicBuffer memory buffer, uint248 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(data), 31));
    }

    function pUint256(DynamicBuffer memory buffer, uint256 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(data, 32));
    }

    function pBytes1(DynamicBuffer memory buffer, bytes1 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(uint256(uint8(data)), 1));
    }

    function pBytes2(DynamicBuffer memory buffer, bytes2 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 2));
    }

    function pBytes3(DynamicBuffer memory buffer, bytes3 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 3));
    }

    function pBytes4(DynamicBuffer memory buffer, bytes4 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 4));
    }

    function pBytes5(DynamicBuffer memory buffer, bytes5 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 5));
    }

    function pBytes6(DynamicBuffer memory buffer, bytes6 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 6));
    }

    function pBytes7(DynamicBuffer memory buffer, bytes7 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 7));
    }

    function pBytes8(DynamicBuffer memory buffer, bytes8 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 8));
    }

    function pBytes9(DynamicBuffer memory buffer, bytes9 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 9));
    }

    function pBytes10(DynamicBuffer memory buffer, bytes10 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 10));
    }

    function pBytes11(DynamicBuffer memory buffer, bytes11 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 11));
    }

    function pBytes12(DynamicBuffer memory buffer, bytes12 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 12));
    }

    function pBytes13(DynamicBuffer memory buffer, bytes13 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 13));
    }

    function pBytes14(DynamicBuffer memory buffer, bytes14 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 14));
    }

    function pBytes15(DynamicBuffer memory buffer, bytes15 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 15));
    }

    function pBytes16(DynamicBuffer memory buffer, bytes16 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 16));
    }

    function pBytes17(DynamicBuffer memory buffer, bytes17 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 17));
    }

    function pBytes18(DynamicBuffer memory buffer, bytes18 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 18));
    }

    function pBytes19(DynamicBuffer memory buffer, bytes19 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 19));
    }

    function pBytes20(DynamicBuffer memory buffer, bytes20 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 20));
    }

    function pBytes21(DynamicBuffer memory buffer, bytes21 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 21));
    }

    function pBytes22(DynamicBuffer memory buffer, bytes22 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 22));
    }

    function pBytes23(DynamicBuffer memory buffer, bytes23 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 23));
    }

    function pBytes24(DynamicBuffer memory buffer, bytes24 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 24));
    }

    function pBytes25(DynamicBuffer memory buffer, bytes25 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 25));
    }

    function pBytes26(DynamicBuffer memory buffer, bytes26 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 26));
    }

    function pBytes27(DynamicBuffer memory buffer, bytes27 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 27));
    }

    function pBytes28(DynamicBuffer memory buffer, bytes28 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 28));
    }

    function pBytes29(DynamicBuffer memory buffer, bytes29 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 29));
    }

    function pBytes30(DynamicBuffer memory buffer, bytes30 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 30));
    }

    function pBytes31(DynamicBuffer memory buffer, bytes31 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(bytes32(data), 31));
    }

    function pBytes32(DynamicBuffer memory buffer, bytes32 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p(buffer, _single(data, 32));
    }

    // -------------------------------------------------------------------------
    // Typed append (starting from empty buffer)
    // -------------------------------------------------------------------------

    function p() internal pure returns (DynamicBuffer memory result) {
        result.data = new bytes(0);
    }

    function p(bytes memory data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = p(result, data);
    }

    function p(bytes memory data0, bytes memory data1)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = p(result, data0, data1);
    }

    function p(bytes memory data0, bytes memory data1, bytes memory data2)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = p(result, data0, data1, data2);
    }

    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3
    ) internal pure returns (DynamicBuffer memory result) {
        result = p();
        result = p(result, data0, data1, data2, data3);
    }

    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4
    ) internal pure returns (DynamicBuffer memory result) {
        result = p();
        result = p(result, data0, data1, data2, data3, data4);
    }

    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5
    ) internal pure returns (DynamicBuffer memory result) {
        result = p();
        result = p(result, data0, data1, data2, data3, data4, data5);
    }

    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5,
        bytes memory data6
    ) internal pure returns (DynamicBuffer memory result) {
        result = p();
        result = p(result, data0, data1, data2, data3, data4, data5, data6);
    }

    function pBool(bool data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBool(result, data);
    }

    function pAddress(address data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pAddress(result, data);
    }

    function pUint8(uint8 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint8(result, data);
    }

    function pUint16(uint16 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint16(result, data);
    }

    function pUint24(uint24 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint24(result, data);
    }

    function pUint32(uint32 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint32(result, data);
    }

    function pUint40(uint40 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint40(result, data);
    }

    function pUint48(uint48 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint48(result, data);
    }

    function pUint56(uint56 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint56(result, data);
    }

    function pUint64(uint64 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint64(result, data);
    }

    function pUint72(uint72 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint72(result, data);
    }

    function pUint80(uint80 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint80(result, data);
    }

    function pUint88(uint88 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint88(result, data);
    }

    function pUint96(uint96 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint96(result, data);
    }

    function pUint104(uint104 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint104(result, data);
    }

    function pUint112(uint112 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint112(result, data);
    }

    function pUint120(uint120 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint120(result, data);
    }

    function pUint128(uint128 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint128(result, data);
    }

    function pUint136(uint136 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint136(result, data);
    }

    function pUint144(uint144 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint144(result, data);
    }

    function pUint152(uint152 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint152(result, data);
    }

    function pUint160(uint160 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint160(result, data);
    }

    function pUint168(uint168 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint168(result, data);
    }

    function pUint176(uint176 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint176(result, data);
    }

    function pUint184(uint184 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint184(result, data);
    }

    function pUint192(uint192 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint192(result, data);
    }

    function pUint200(uint200 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint200(result, data);
    }

    function pUint208(uint208 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint208(result, data);
    }

    function pUint216(uint216 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint216(result, data);
    }

    function pUint224(uint224 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint224(result, data);
    }

    function pUint232(uint232 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint232(result, data);
    }

    function pUint240(uint240 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint240(result, data);
    }

    function pUint248(uint248 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint248(result, data);
    }

    function pUint256(uint256 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pUint256(result, data);
    }

    function pBytes1(bytes1 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes1(result, data);
    }

    function pBytes2(bytes2 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes2(result, data);
    }

    function pBytes3(bytes3 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes3(result, data);
    }

    function pBytes4(bytes4 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes4(result, data);
    }

    function pBytes5(bytes5 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes5(result, data);
    }

    function pBytes6(bytes6 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes6(result, data);
    }

    function pBytes7(bytes7 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes7(result, data);
    }

    function pBytes8(bytes8 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes8(result, data);
    }

    function pBytes9(bytes9 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes9(result, data);
    }

    function pBytes10(bytes10 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes10(result, data);
    }

    function pBytes11(bytes11 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes11(result, data);
    }

    function pBytes12(bytes12 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes12(result, data);
    }

    function pBytes13(bytes13 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes13(result, data);
    }

    function pBytes14(bytes14 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes14(result, data);
    }

    function pBytes15(bytes15 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes15(result, data);
    }

    function pBytes16(bytes16 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes16(result, data);
    }

    function pBytes17(bytes17 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes17(result, data);
    }

    function pBytes18(bytes18 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes18(result, data);
    }

    function pBytes19(bytes19 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes19(result, data);
    }

    function pBytes20(bytes20 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes20(result, data);
    }

    function pBytes21(bytes21 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes21(result, data);
    }

    function pBytes22(bytes22 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes22(result, data);
    }

    function pBytes23(bytes23 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes23(result, data);
    }

    function pBytes24(bytes24 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes24(result, data);
    }

    function pBytes25(bytes25 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes25(result, data);
    }

    function pBytes26(bytes26 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes26(result, data);
    }

    function pBytes27(bytes27 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes27(result, data);
    }

    function pBytes28(bytes28 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes28(result, data);
    }

    function pBytes29(bytes29 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes29(result, data);
    }

    function pBytes30(bytes30 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes30(result, data);
    }

    function pBytes31(bytes31 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes31(result, data);
    }

    function pBytes32(bytes32 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        result = p();
        result = pBytes32(result, data);
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @notice Deallocates memory for a DynamicBuffer.
     */
    function _deallocate(DynamicBuffer memory result) private pure {
        // Best-effort: reset free memory pointer to current buffer if possible.
        assembly {
            if mload(result) {
                mstore(0x40, add(mload(result), 0x40))
            }
        }
    }

    /**
     * @notice Packs a uint256 `data` into a new bytes array of length `n`.
     */
    function _single(uint256 data, uint256 n)
        private
        pure
        returns (bytes memory result)
    {
        result = new bytes(n);
        assembly {
            let ptr := add(result, 0x20)
            // right-align the value in the last n bytes
            mstore(ptr, shl(mul(8, sub(0x20, n)), data))
        }
    }

    /**
     * @notice Packs a bytes32 `data` into a new bytes array of length `n`.
     */
    function _single(bytes32 data, uint256 n)
        private
        pure
        returns (bytes memory result)
    {
        result = new bytes(n);
        assembly {
            let ptr := add(result, 0x20)
            mstore(ptr, shl(mul(8, sub(0x20, n)), data))
        }
    }
}