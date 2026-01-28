// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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
     */
    function reserve(DynamicBuffer memory buffer, uint256 minimum) internal pure returns (DynamicBuffer memory result) {
        result = buffer;
        if (result.data.length < minimum) {
            bytes memory newData = new bytes(minimum);
            uint256 srcLen = buffer.data.length;
            for (uint256 i = 0; i < srcLen; ++i) {
                newData[i] = buffer.data[i];
            }
            result.data = newData;
        }
    }

    /**
     * @notice Clears the contents of a DynamicBuffer by deallocating its memory and resetting its length.
     */
    function clear(DynamicBuffer memory /*buffer*/) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result.data = new bytes(0);
    }

    /**
     * @notice Converts a DynamicBuffer to a string.
     */
    function s(DynamicBuffer memory buffer) internal pure returns (string memory) {
        return string(buffer.data);
    }

    /* ---------------------------
       Core append helpers
       --------------------------- */

    /// Append `part` to `buffer` (returns updated buffer).
    function _append(DynamicBuffer memory buffer, bytes memory part) private pure returns (DynamicBuffer memory result) {
        result = buffer;
        if (part.length == 0) {
            return result;
        }
        bytes memory combined = new bytes(result.data.length + part.length);
        uint256 i = 0;
        uint256 n = result.data.length;
        for (; i < n; ++i) combined[i] = result.data[i];
        uint256 j = 0;
        uint256 m = part.length;
        for (; j < m; ++j) combined[i + j] = part[j];
        result.data = combined;
    }

    /// Append multiple parts to `buffer`.
    function _appendMany(DynamicBuffer memory buffer, bytes[] memory parts) private pure returns (DynamicBuffer memory result) {
        result = buffer;
        uint256 total = 0;
        for (uint256 i = 0; i < parts.length; ++i) total += parts[i].length;
        if (total == 0) return result;
        bytes memory combined = new bytes(result.data.length + total);
        uint256 offset = 0;
        uint256 n = result.data.length;
        for (uint256 i = 0; i < n; ++i) combined[offset++] = result.data[i];
        for (uint256 p = 0; p < parts.length; ++p) {
            bytes memory part = parts[p];
            for (uint256 q = 0; q < part.length; ++q) combined[offset++] = part[q];
        }
        result.data = combined;
    }

    /* ---------------------------
       Primary `p` functions (buffer + bytes)
       --------------------------- */

    function p(DynamicBuffer memory buffer, bytes memory data) internal pure returns (DynamicBuffer memory result) {
        // Deallocate result buffer then assign input
        _deallocate(result);
        result = buffer;
        if (data.length == 0) return result;
        return _append(result, data);
    }

    function p(DynamicBuffer memory buffer, bytes memory data0, bytes memory data1) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = buffer;
        bytes[] memory parts = new bytes[](2);
        parts[0] = data0;
        parts[1] = data1;
        return _appendMany(result, parts);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = buffer;
        bytes[] memory parts = new bytes[](3);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        return _appendMany(result, parts);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = buffer;
        bytes[] memory parts = new bytes[](4);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        return _appendMany(result, parts);
    }

    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = buffer;
        bytes[] memory parts = new bytes[](5);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        parts[4] = data4;
        return _appendMany(result, parts);
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
        _deallocate(result);
        result = buffer;
        bytes[] memory parts = new bytes[](6);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        parts[4] = data4;
        parts[5] = data5;
        return _appendMany(result, parts);
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
        _deallocate(result);
        result = buffer;
        bytes[] memory parts = new bytes[](7);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        parts[4] = data4;
        parts[5] = data5;
        parts[6] = data6;
        return _appendMany(result, parts);
    }

    /* ---------------------------
       `p` variants with no buffer param (create new buffer)
       --------------------------- */

    function p() internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result.data = new bytes(0);
    }

    function p(bytes memory data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result.data = new bytes(data.length);
        for (uint256 i = 0; i < data.length; ++i) result.data[i] = data[i];
    }

    function p(bytes memory data0, bytes memory data1) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        bytes[] memory parts = new bytes[](2);
        parts[0] = data0;
        parts[1] = data1;
        result.data = new bytes(_totalLength(parts));
        uint256 off = 0;
        for (uint256 i = 0; i < parts.length; ++i) {
            bytes memory part = parts[i];
            for (uint256 j = 0; j < part.length; ++j) result.data[off++] = part[j];
        }
    }

    function p(bytes memory data0, bytes memory data1, bytes memory data2) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        bytes[] memory parts = new bytes[](3);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        result.data = new bytes(_totalLength(parts));
        uint256 off = 0;
        for (uint256 i = 0; i < parts.length; ++i) {
            bytes memory part = parts[i];
            for (uint256 j = 0; j < part.length; ++j) result.data[off++] = part[j];
        }
    }

    function p(bytes memory data0, bytes memory data1, bytes memory data2, bytes memory data3) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        bytes[] memory parts = new bytes[](4);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        result.data = new bytes(_totalLength(parts));
        uint256 off = 0;
        for (uint256 i = 0; i < parts.length; ++i) {
            bytes memory part = parts[i];
            for (uint256 j = 0; j < part.length; ++j) result.data[off++] = part[j];
        }
    }

    function p(bytes memory data0, bytes memory data1, bytes memory data2, bytes memory data3, bytes memory data4) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        bytes[] memory parts = new bytes[](5);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        parts[4] = data4;
        result.data = new bytes(_totalLength(parts));
        uint256 off = 0;
        for (uint256 i = 0; i < parts.length; ++i) {
            bytes memory part = parts[i];
            for (uint256 j = 0; j < part.length; ++j) result.data[off++] = part[j];
        }
    }

    function p(bytes memory data0, bytes memory data1, bytes memory data2, bytes memory data3, bytes memory data4, bytes memory data5) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        bytes[] memory parts = new bytes[](6);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        parts[4] = data4;
        parts[5] = data5;
        result.data = new bytes(_totalLength(parts));
        uint256 off = 0;
        for (uint256 i = 0; i < parts.length; ++i) {
            bytes memory part = parts[i];
            for (uint256 j = 0; j < part.length; ++j) result.data[off++] = part[j];
        }
    }

    function p(bytes memory data0, bytes memory data1, bytes memory data2, bytes memory data3, bytes memory data4, bytes memory data5, bytes memory data6) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        bytes[] memory parts = new bytes[](7);
        parts[0] = data0;
        parts[1] = data1;
        parts[2] = data2;
        parts[3] = data3;
        parts[4] = data4;
        parts[5] = data5;
        parts[6] = data6;
        result.data = new bytes(_totalLength(parts));
        uint256 off = 0;
        for (uint256 i = 0; i < parts.length; ++i) {
            bytes memory part = parts[i];
            for (uint256 j = 0; j < part.length; ++j) result.data[off++] = part[j];
        }
    }

    /* ---------------------------
       Boolean / address helpers
       --------------------------- */

    function pBool(DynamicBuffer memory buffer, bool data) internal pure returns (DynamicBuffer memory result) {
        bytes memory b = new bytes(1);
        b[0] = data ? bytes1(0x01) : bytes1(0x00);
        return p(buffer, b);
    }

    function pBool(bool data) internal pure returns (DynamicBuffer memory result) {
        bytes memory b = new bytes(1);
        b[0] = data ? bytes1(0x01) : bytes1(0x00);
        return p(b);
    }

    function pAddress(DynamicBuffer memory buffer, address data) internal pure returns (DynamicBuffer memory result) {
        bytes memory packed = abi.encodePacked(data);
        return p(buffer, packed);
    }

    function pAddress(address data) internal pure returns (DynamicBuffer memory result) {
        bytes memory packed = abi.encodePacked(data);
        return p(packed);
    }

    /* ---------------------------
       Unsigned integer packers (many sizes)
       --------------------------- */

    function pUint8(DynamicBuffer memory buffer, uint8 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pUint8(uint8 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pUint16(DynamicBuffer memory buffer, uint16 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pUint16(uint16 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pUint24(DynamicBuffer memory buffer, uint24 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pUint24(uint24 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pUint32(DynamicBuffer memory buffer, uint32 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 4));
    }

    function pUint32(uint32 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 4));
    }

    function pUint40(DynamicBuffer memory buffer, uint40 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 5));
    }

    function pUint40(uint40 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 5));
    }

    function pUint48(DynamicBuffer memory buffer, uint48 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 6));
    }

    function pUint48(uint48 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 6));
    }

    function pUint56(DynamicBuffer memory buffer, uint56 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 7));
    }

    function pUint56(uint56 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 7));
    }

    function pUint64(DynamicBuffer memory buffer, uint64 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 8));
    }

    function pUint64(uint64 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 8));
    }

    function pUint72(DynamicBuffer memory buffer, uint72 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 9));
    }

    function pUint72(uint72 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 9));
    }

    function pUint80(DynamicBuffer memory buffer, uint80 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 10));
    }

    function pUint80(uint80 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 10));
    }

    function pUint88(DynamicBuffer memory buffer, uint88 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 11));
    }

    function pUint88(uint88 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 11));
    }

    function pUint96(DynamicBuffer memory buffer, uint96 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 12));
    }

    function pUint96(uint96 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 12));
    }

    function pUint104(DynamicBuffer memory buffer, uint104 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 13));
    }

    function pUint104(uint104 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 13));
    }

    function pUint112(DynamicBuffer memory buffer, uint112 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 14));
    }

    function pUint112(uint112 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 14));
    }

    function pUint120(DynamicBuffer memory buffer, uint120 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 15));
    }

    function pUint120(uint120 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 15));
    }

    function pUint128(DynamicBuffer memory buffer, uint128 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 16));
    }

    function pUint128(uint128 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 16));
    }

    function pUint136(DynamicBuffer memory buffer, uint136 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 17));
    }

    function pUint136(uint136 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 17));
    }

    function pUint144(DynamicBuffer memory buffer, uint144 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 18));
    }

    function pUint144(uint144 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 18));
    }

    function pUint152(DynamicBuffer memory buffer, uint152 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 19));
    }

    function pUint152(uint152 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 19));
    }

    function pUint160(DynamicBuffer memory buffer, uint160 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 20));
    }

    function pUint160(uint160 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 20));
    }

    function pUint168(DynamicBuffer memory buffer, uint168 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 21));
    }

    function pUint168(uint168 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 21));
    }

    function pUint176(DynamicBuffer memory buffer, uint176 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 22));
    }

    function pUint176(uint176 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 22));
    }

    function pUint184(DynamicBuffer memory buffer, uint184 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 23));
    }

    function pUint184(uint184 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 23));
    }

    function pUint192(DynamicBuffer memory buffer, uint192 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 24));
    }

    function pUint192(uint192 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 24));
    }

    function pUint200(DynamicBuffer memory buffer, uint200 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 25));
    }

    function pUint200(uint200 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 25));
    }

    function pUint208(DynamicBuffer memory buffer, uint208 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 26));
    }

    function pUint208(uint208 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 26));
    }

    function pUint216(DynamicBuffer memory buffer, uint216 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 27));
    }

    function pUint216(uint216 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 27));
    }

    function pUint224(DynamicBuffer memory buffer, uint224 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 28));
    }

    function pUint224(uint224 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 28));
    }

    function pUint232(DynamicBuffer memory buffer, uint232 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 29));
    }

    function pUint232(uint232 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 29));
    }

    function pUint240(DynamicBuffer memory buffer, uint240 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 30));
    }

    function pUint240(uint240 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 30));
    }

    function pUint248(DynamicBuffer memory buffer, uint248 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(uint256(data)), 31));
    }

    function pUint248(uint248 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(uint256(data)), 31));
    }

    function pUint256(DynamicBuffer memory buffer, uint256 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, _single(bytes32(data), 32));
    }

    function pUint256(uint256 data) internal pure returns (DynamicBuffer memory result) {
        return p(_single(bytes32(data), 32));
    }

    /* ---------------------------
       Fixed-bytes packers helpers (bytes1..bytes32)
       --------------------------- */

    function pBytes1(DynamicBuffer memory buffer, bytes1 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes1(bytes1 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes2(DynamicBuffer memory buffer, bytes2 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes2(bytes2 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes3(DynamicBuffer memory buffer, bytes3 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes3(bytes3 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes4(DynamicBuffer memory buffer, bytes4 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes4(bytes4 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes5(DynamicBuffer memory buffer, bytes5 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes5(bytes5 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes6(DynamicBuffer memory buffer, bytes6 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes6(bytes6 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes7(DynamicBuffer memory buffer, bytes7 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes7(bytes7 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes8(DynamicBuffer memory buffer, bytes8 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes8(bytes8 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes9(DynamicBuffer memory buffer, bytes9 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes9(bytes9 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes10(DynamicBuffer memory buffer, bytes10 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes10(bytes10 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes11(DynamicBuffer memory buffer, bytes11 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes11(bytes11 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes12(DynamicBuffer memory buffer, bytes12 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes12(bytes12 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes13(DynamicBuffer memory buffer, bytes13 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes13(bytes13 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes14(DynamicBuffer memory buffer, bytes14 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes14(bytes14 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes15(DynamicBuffer memory buffer, bytes15 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes15(bytes15 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes16(DynamicBuffer memory buffer, bytes16 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes16(bytes16 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes17(DynamicBuffer memory buffer, bytes17 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes17(bytes17 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes18(DynamicBuffer memory buffer, bytes18 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes18(bytes18 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes19(DynamicBuffer memory buffer, bytes19 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes19(bytes19 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes20(DynamicBuffer memory buffer, bytes20 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes20(bytes20 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes21(DynamicBuffer memory buffer, bytes21 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes21(bytes21 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes22(DynamicBuffer memory buffer, bytes22 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes22(bytes22 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes23(DynamicBuffer memory buffer, bytes23 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes23(bytes23 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes24(DynamicBuffer memory buffer, bytes24 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes24(bytes24 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes25(DynamicBuffer memory buffer, bytes25 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes25(bytes25 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes26(DynamicBuffer memory buffer, bytes26 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes26(bytes26 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes27(DynamicBuffer memory buffer, bytes27 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes27(bytes27 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes28(DynamicBuffer memory buffer, bytes28 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes28(bytes28 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes29(DynamicBuffer memory buffer, bytes29 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes29(bytes29 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes30(DynamicBuffer memory buffer, bytes30 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes30(bytes30 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes31(DynamicBuffer memory buffer, bytes31 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes31(bytes31 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    function pBytes32(DynamicBuffer memory buffer, bytes32 data) internal pure returns (DynamicBuffer memory result) {
        return p(buffer, abi.encodePacked(data));
    }

    function pBytes32(bytes32 data) internal pure returns (DynamicBuffer memory result) {
        return p(abi.encodePacked(data));
    }

    /* ---------------------------
       Private helpers
       --------------------------- */

    /**
     * @notice Deallocates memory for a DynamicBuffer.
     */
    function _deallocate(DynamicBuffer memory result) private pure {
        // Reset the bytes array to zero length to allow GC-like behavior in memory usage
        result.data = new bytes(0);
    }

    /**
     * @notice A private pure function that manipulates memory to store data and a number.
     *
     * @param data The bytes32 data to be stored in memory.
     * @param n The uint256 number of bytes to keep from `data` (prefix).
     * @return result The memory bytes containing the stored data truncated to `n` bytes.
     */
    function _single(bytes32 data, uint256 n) private pure returns (bytes memory result) {
        if (n == 0) {
            result = new bytes(0);
            return result;
        }
        require(n <= 32, "n>32");
        result = new bytes(n);
        // copy the high-order bytes of data into result[0..n-1]
        for (uint256 i = 0; i < n; ++i) {
            // take byte at position (32 - n + i) from the 32-byte word so that small numbers are right-aligned
            result[i] = bytes1(uint8(uint256(data) >> (8 * (32 - n + i))));
        }
    }

    /**
     * @notice A private pure function that manipulates a uint256 as bytes32 and truncates.
     */
    function _single(uint256 data, uint256 n) private pure returns (bytes memory result) {
        return _single(bytes32(data), n);
    }

    function _totalLength(bytes[] memory parts) private pure returns (uint256 total) {
        total = 0;
        for (uint256 i = 0; i < parts.length; ++i) total += parts[i].length;
    }
}