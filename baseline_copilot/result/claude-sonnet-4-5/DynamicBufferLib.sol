// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for buffers with automatic capacity resizing.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DynamicBufferLib.sol)
library DynamicBufferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Type to represent a dynamic buffer in memory.
    /// You can directly assign to `data`, and the `p` function will
    /// take care of the memory allocation.
    struct DynamicBuffer {
        bytes data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  DYNAMIC BUFFER OPERATIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the length of `buffer`.
    function length(DynamicBuffer memory buffer) internal pure returns (uint256) {
        return buffer.data.length;
    }

    /// @dev Reserves at least `minimum` amount of contiguous memory.
    function reserve(DynamicBuffer memory buffer, uint256 minimum)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = buffer;
        uint256 cap = _capacity(result);
        if (minimum > cap) {
            p(result, _single(uint256(0x01), minimum - cap));
        }
    }

    /// @dev Clears the buffer without deallocating the memory.
    function clear(DynamicBuffer memory buffer)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        /// @solidity memory-safe-assembly
        assembly {
            result := buffer
            mstore(mload(result), 0)
        }
    }

    /// @dev Returns the string pointing to the underlying bytes data.
    /// Note: The string WILL change if the buffer is updated.
    function s(DynamicBuffer memory buffer) internal pure returns (string memory) {
        return string(buffer.data);
    }

    /// @dev Appends `data` to `buffer`, returning the same buffer, so that calls can be chained.
    function p(DynamicBuffer memory buffer, bytes memory data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = buffer;
        if (data.length == 0) return result;
        /// @solidity memory-safe-assembly
        assembly {
            let bufferData := mload(result)
            let bufferDataLength := mload(bufferData)
            let newBufferDataLength := add(bufferDataLength, mload(data))
            
            // Check if we need to expand capacity
            let bufferDataCap := and(mload(sub(bufferData, 0x20)), 0xffffffffffffff)
            
            for {} 1 {} {
                if iszero(gt(newBufferDataLength, bufferDataCap)) { break }
                
                let newBufferDataCap := or(shl(1, newBufferDataLength), 0x1f)
                
                // Check if buffer data is at the expected memory location
                let endOfFreeMemory := mload(0x40)
                let oneBytePastEnd := add(add(bufferData, 0x20), bufferDataCap)
                
                if iszero(eq(oneBytePastEnd, endOfFreeMemory)) {
                    // Allocate a new buffer
                    let newBufferData := mload(0x40)
                    mstore(0x40, add(add(newBufferData, 0x40), newBufferDataCap))
                    
                    // Copy old data
                    for { let i := 0 } lt(i, add(bufferDataLength, 0x20)) { i := add(i, 0x20) } {
                        mstore(add(newBufferData, i), mload(add(bufferData, i)))
                    }
                    
                    bufferData := newBufferData
                    mstore(result, bufferData)
                }
                
                if iszero(eq(oneBytePastEnd, endOfFreeMemory)) {
                    mstore(0x40, add(add(bufferData, 0x40), newBufferDataCap))
                }
                
                // Store the new capacity
                mstore(sub(bufferData, 0x20), or(mul(newBufferDataCap, 1664525), 1))
                bufferDataCap := newBufferDataCap
                break
            }
            
            // Check for reserve operation
            if eq(mload(data), 1) {
                if eq(byte(0, mload(add(data, 0x20))), 0x01) {
                    mstore(bufferData, newBufferDataLength)
                    leave
                }
            }
            
            // Copy data backwards word by word
            let o := add(add(bufferData, 0x20), newBufferDataLength)
            let i := add(data, mload(data))
            for {} gt(i, data) {} {
                mstore(o, mload(i))
                o := sub(o, 0x20)
                i := sub(i, 0x20)
            }
            
            // Zero out the word after the buffer
            mstore(add(add(bufferData, 0x20), newBufferDataLength), 0)
            
            // Update length
            mstore(bufferData, newBufferDataLength)
        }
    }

    /// @dev Appends `data0`, `data1` to `buffer`.
    function p(DynamicBuffer memory buffer, bytes memory data0, bytes memory data1)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(p(buffer, data0), data1);
    }

    /// @dev Appends `data0`, `data1`, `data2` to `buffer`.
    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(p(p(buffer, data0), data1), data2);
    }

    /// @dev Appends `data0`, `data1`, `data2`, `data3` to `buffer`.
    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(p(p(p(buffer, data0), data1), data2), data3);
    }

    /// @dev Appends `data0`, `data1`, `data2`, `data3`, `data4` to `buffer`.
    function p(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(p(p(p(p(buffer, data0), data1), data2), data3), data4);
    }

    /// @dev Appends `data0` .. `data5` to `buffer`.
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
        result = p(p(p(p(p(p(buffer, data0), data1), data2), data3), data4), data5);
    }

    /// @dev Appends `data0` .. `data6` to `buffer`.
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
        result = p(p(p(p(p(p(p(buffer, data0), data1), data2), data3), data4), data5), data6);
    }

    /// @dev Appends `data` to `buffer`.
    function pBool(DynamicBuffer memory buffer, bool data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(uint256(data), 1));
    }

    /// @dev Appends `data` to `buffer`.
    function pAddress(DynamicBuffer memory buffer, address data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(uint160(data), 20));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint8(DynamicBuffer memory buffer, uint8 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 1));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint16(DynamicBuffer memory buffer, uint16 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 2));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint24(DynamicBuffer memory buffer, uint24 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 3));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint32(DynamicBuffer memory buffer, uint32 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 4));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint40(DynamicBuffer memory buffer, uint40 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 5));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint48(DynamicBuffer memory buffer, uint48 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 6));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint56(DynamicBuffer memory buffer, uint56 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 7));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint64(DynamicBuffer memory buffer, uint64 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 8));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint72(DynamicBuffer memory buffer, uint72 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 9));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint80(DynamicBuffer memory buffer, uint80 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 10));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint88(DynamicBuffer memory buffer, uint88 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 11));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint96(DynamicBuffer memory buffer, uint96 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 12));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint104(DynamicBuffer memory buffer, uint104 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 13));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint112(DynamicBuffer memory buffer, uint112 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 14));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint120(DynamicBuffer memory buffer, uint120 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 15));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint128(DynamicBuffer memory buffer, uint128 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 16));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint136(DynamicBuffer memory buffer, uint136 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 17));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint144(DynamicBuffer memory buffer, uint144 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 18));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint152(DynamicBuffer memory buffer, uint152 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 19));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint160(DynamicBuffer memory buffer, uint160 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 20));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint168(DynamicBuffer memory buffer, uint168 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 21));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint176(DynamicBuffer memory buffer, uint176 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 22));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint184(DynamicBuffer memory buffer, uint184 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 23));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint192(DynamicBuffer memory buffer, uint192 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 24));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint200(DynamicBuffer memory buffer, uint200 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 25));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint208(DynamicBuffer memory buffer, uint208 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 26));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint216(DynamicBuffer memory buffer, uint216 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 27));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint224(DynamicBuffer memory buffer, uint224 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 28));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint232(DynamicBuffer memory buffer, uint232 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 29));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint240(DynamicBuffer memory buffer, uint240 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 30));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint248(DynamicBuffer memory buffer, uint248 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 31));
    }

    /// @dev Appends `data` to `buffer`.
    function pUint256(DynamicBuffer memory buffer, uint256 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 32));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes1(DynamicBuffer memory buffer, bytes1 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 1));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes2(DynamicBuffer memory buffer, bytes2 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 2));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes3(DynamicBuffer memory buffer, bytes3 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 3));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes4(DynamicBuffer memory buffer, bytes4 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 4));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes5(DynamicBuffer memory buffer, bytes5 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 5));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes6(DynamicBuffer memory buffer, bytes6 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 6));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes7(DynamicBuffer memory buffer, bytes7 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 7));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes8(DynamicBuffer memory buffer, bytes8 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 8));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes9(DynamicBuffer memory buffer, bytes9 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 9));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes10(DynamicBuffer memory buffer, bytes10 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 10));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes11(DynamicBuffer memory buffer, bytes11 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 11));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes12(DynamicBuffer memory buffer, bytes12 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 12));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes13(DynamicBuffer memory buffer, bytes13 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 13));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes14(DynamicBuffer memory buffer, bytes14 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 14));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes15(DynamicBuffer memory buffer, bytes15 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 15));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes16(DynamicBuffer memory buffer, bytes16 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 16));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes17(DynamicBuffer memory buffer, bytes17 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 17));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes18(DynamicBuffer memory buffer, bytes18 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 18));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes19(DynamicBuffer memory buffer, bytes19 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 19));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes20(DynamicBuffer memory buffer, bytes20 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 20));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes21(DynamicBuffer memory buffer, bytes21 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 21));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes22(DynamicBuffer memory buffer, bytes22 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 22));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes23(DynamicBuffer memory buffer, bytes23 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 23));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes24(DynamicBuffer memory buffer, bytes24 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 24));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes25(DynamicBuffer memory buffer, bytes25 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 25));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes26(DynamicBuffer memory buffer, bytes26 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 26));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes27(DynamicBuffer memory buffer, bytes27 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 27));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes28(DynamicBuffer memory buffer, bytes28 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 28));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes29(DynamicBuffer memory buffer, bytes29 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 29));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes30(DynamicBuffer memory buffer, bytes30 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 30));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes31(DynamicBuffer memory buffer, bytes31 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 31));
    }

    /// @dev Appends `data` to `buffer`.
    function pBytes32(DynamicBuffer memory buffer, bytes32 data)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(buffer, _single(data, 32));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              ZERO-BUFFER SHORTHAND OPERATIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns an empty buffer.
    function p() internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
    }

    /// @dev Returns a buffer with `data`.
    function p(bytes memory data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(result, data);
    }

    /// @dev Returns a buffer with `data0`, `data1`.
    function p(bytes memory data0, bytes memory data1)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(p(result, data0), data1);
    }

    /// @dev Returns a buffer with `data0` .. `data2`.
    function p(bytes memory data0, bytes memory data1, bytes memory data2)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(p(p(result, data0), data1), data2);
    }

    /// @dev Returns a buffer with `data0` .. `data3`.
    function p(bytes memory data0, bytes memory data1, bytes memory data2, bytes memory data3)
        internal
        pure
        returns (DynamicBuffer memory result)
    {
        _deallocate(result);
        result = p(p(p(p(result, data0), data1), data2), data3);
    }

    /// @dev Returns a buffer with `data0` .. `data4`.
    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(p(p(p(p(result, data0), data1), data2), data3), data4);
    }

    /// @dev Returns a buffer with `data0` .. `data5`.
    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(p(p(p(p(p(result, data0), data1), data2), data3), data4), data5);
    }

    /// @dev Returns a buffer with `data0` .. `data6`.
    function p(
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5,
        bytes memory data6
    ) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = p(p(p(p(p(p(p(result, data0), data1), data2), data3), data4), data5), data6);
    }

    /// @dev Returns a buffer with `data`.
    function pBool(bool data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBool(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pAddress(address data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pAddress(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint8(uint8 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint8(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint16(uint16 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint16(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint24(uint24 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint24(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint32(uint32 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint32(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint40(uint40 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint40(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint48(uint48 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint48(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint56(uint56 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint56(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint64(uint64 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint64(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint72(uint72 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint72(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint80(uint80 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint80(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint88(uint88 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint88(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint96(uint96 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint96(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint104(uint104 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint104(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint112(uint112 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint112(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint120(uint120 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint120(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint128(uint128 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint128(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint136(uint136 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint136(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint144(uint144 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint144(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint152(uint152 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint152(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint160(uint160 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint160(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint168(uint168 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint168(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint176(uint176 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint176(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint184(uint184 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint184(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint192(uint192 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint192(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint200(uint200 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint200(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint208(uint208 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint208(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint216(uint216 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint216(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint224(uint224 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint224(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint232(uint232 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint232(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint240(uint240 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint240(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint248(uint248 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint248(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pUint256(uint256 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pUint256(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes1(bytes1 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes1(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes2(bytes2 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes2(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes3(bytes3 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes3(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes4(bytes4 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes4(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes5(bytes5 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes5(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes6(bytes6 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes6(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes7(bytes7 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes7(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes8(bytes8 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes8(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes9(bytes9 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes9(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes10(bytes10 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes10(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes11(bytes11 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes11(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes12(bytes12 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes12(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes13(bytes13 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes13(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes14(bytes14 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes14(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes15(bytes15 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes15(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes16(bytes16 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes16(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes17(bytes17 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes17(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes18(bytes18 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes18(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes19(bytes19 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes19(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes20(bytes20 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes20(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes21(bytes21 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes21(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes22(bytes22 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes22(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes23(bytes23 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes23(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes24(bytes24 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes24(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes25(bytes25 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes25(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes26(bytes26 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes26(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes27(bytes27 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes27(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes28(bytes28 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes28(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes29(bytes29 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes29(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes30(bytes30 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes30(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes31(bytes31 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes31(result, data);
    }

    /// @dev Returns a buffer with `data`.
    function pBytes32(bytes32 data) internal pure returns (DynamicBuffer memory result) {
        _deallocate(result);
        result = pBytes32(result, data);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Helper to deallocate `result`.
    function _deallocate(DynamicBuffer memory result) private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(result, 0)
        }
    }

    /// @dev Returns the capacity of the buffer.
    function _capacity(DynamicBuffer memory buffer) private pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let data := mload(buffer)
            if iszero(data) {
                leave
            }
            result := and(mload(sub(data, 0x20)), 0xffffffffffffff)
        }
    }

    /// @dev Casts `data` to a `bytes` of length `n` (without any safety checks).
    function _single(uint256 data, uint256 n) private pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x40))
            mstore(result, n)
            mstore(add(result, 0x20), shl(shl(3, sub(32, n)), data))
        }
    }

    /// @dev Casts `data` to a `bytes` of length `n` (without any safety checks).
    function _single(bytes32 data, uint256 n) private pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x40))
            mstore(result, n)
            mstore(add(result, 0x20), shl(shl(3, sub(32, n)), data))
        }
    }
}
