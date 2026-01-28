// Links:
// [plan.txt](plan.txt)
// [MetadataReaderLib.sol](MetadataReaderLib.sol)
// Referenced symbols:
// [`MetadataReaderLib.readName`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readSymbol`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readString`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readDecimals`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readUint`](MetadataReaderLib.sol)
// [`MetadataReaderLib._string`](MetadataReaderLib.sol)
// [`MetadataReaderLib._uint`](MetadataReaderLib.sol)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title MetadataReaderLib
/// @notice Utility library for reading ERC20/ERC721 style metadata (name, symbol, decimals) and arbitrary strings/uints
library MetadataReaderLib {
    uint256 private constant DEFAULT_LIMIT = 256;
    uint256 private constant DEFAULT_GAS_STIPEND = 30000;

    /// @notice Reads the name() of a target contract.
    function readName(address target) internal view returns (string memory) {
        return readName(target, DEFAULT_LIMIT, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the name() of a target contract with a byte limit.
    function readName(address target, uint256 limit) internal view returns (string memory) {
        return readName(target, limit, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the name() of a target contract with a byte limit and gas stipend.
    function readName(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        // selector for name(): 0x06fdde03
        return _string(target, _ptr(uint256(0x06fdde03)), limit, gasStipend);
    }

    /// @notice Reads the symbol() of a target contract.
    function readSymbol(address target) internal view returns (string memory) {
        return readSymbol(target, DEFAULT_LIMIT, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the symbol() of a target contract with a byte limit.
    function readSymbol(address target, uint256 limit) internal view returns (string memory) {
        return readSymbol(target, limit, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the symbol() of a target contract with a byte limit and gas stipend.
    function readSymbol(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        // selector for symbol(): 0x95d89b41
        return _string(target, _ptr(uint256(0x95d89b41)), limit, gasStipend);
    }

    /// @notice Reads arbitrary string result by passing `data` to target.
    function readString(address target, bytes memory data) internal view returns (string memory) {
        return readString(target, data, DEFAULT_LIMIT, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads arbitrary string result by passing `data` to target with a byte limit.
    function readString(address target, bytes memory data, uint256 limit) internal view returns (string memory) {
        return readString(target, data, limit, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads arbitrary string result by passing `data` to target with a byte limit and gas stipend.
    function readString(address target, bytes memory data, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(data), limit, gasStipend);
    }

    /// @notice Reads decimals() and returns as uint8.
    function readDecimals(address target) internal view returns (uint8) {
        return readDecimals(target, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads decimals() with custom gas stipend.
    function readDecimals(address target, uint256 gasStipend) internal view returns (uint8) {
        // selector for decimals(): 0x313ce567
        uint256 val = _uint(target, _ptr(uint256(0x313ce567)), gasStipend);
        return uint8(val);
    }

    /// @notice Read a uint256 by passing ABI-encoded `data`.
    function readUint(address target, bytes memory data) internal view returns (uint256) {
        return readUint(target, data, DEFAULT_GAS_STIPEND);
    }

    /// @notice Read a uint256 by passing ABI-encoded `data` with gas stipend.
    function readUint(address target, bytes memory data, uint256 gasStipend) internal view returns (uint256) {
        return _uint(target, _ptr(data), gasStipend);
    }

    /// @dev Internal helper: treat `ptr` either as a small selector (<= 0xffff) packed into bytes32
    ///      or as an in-memory pointer to a bytes payload (when ptr is a memory address).
    function _string(address target, bytes32 ptr, uint256 limit, uint256 gasStipend) private view returns (string memory result) {
        assembly {
            let ptrVal := shr(0, ptr) // numeric value of ptr
            let success := 0
            let returndatasz := 0

            // Determine if ptrVal is a memory pointer (large) or a selector (small)
            // We treat values > 0xffff as memory pointers.
            if gt(ptrVal, 0xffff) {
                // ptrVal points to the first byte of calldata payload in memory.
                let dataPtr := ptrVal
                let dataLen := mload(sub(dataPtr, 0x20)) // bytes length is stored just before data pointer

                // perform staticcall with limited gas
                success := staticcall(gasStipend, target, dataPtr, dataLen, 0, 0)
                returndatasz := returndatasize()
                // if no returndata, return empty string
                if iszero(returndatasz) {
                    result := mload(0x40)
                    mstore(result, 0)
                    mstore(0x40, add(result, 0x20))
                    leave
                }

                // copy returndata to memory at free pointer
                let out := mload(0x40)
                returndatacopy(out, 0, returndatasz)

                // If returndata is standard ABI (offset + len + data) minimum 64
                if lt(returndatasz, 0x40) {
                    // treat as null-terminated or raw bytes
                    let maxScan := returndatasz
                    if gt(maxScan, limit) { maxScan := limit }
                    let i := 0
                    for { } lt(i, maxScan) { i := add(i, 1) } {
                        if iszero(byte(0, mload(add(out, i)))) { } else { break }
                    }
                    let len := i
                    if gt(len, limit) { len := limit }
                    // allocate result
                    result := mload(0x40)
                    mstore(result, len)
                    // copy bytes in 32-byte chunks
                    let src := out
                    let dst := add(result, 0x20)
                    let copied := 0
                    for { } lt(copied, len) { copied := add(copied, 0x20) } {
                        mstore(add(dst, copied), mload(add(src, copied)))
                    }
                    mstore(0x40, add(add(result, 0x20), and(add(len, 0x1f), not(0x1f))))
                    leave
                }

                // try to ABI decode: offset at out, typically 32, then length at out+32
                let offset := mload(out)
                // we expect offset == 32 in typical ABI-encoded string
                if eq(offset, 0x20) {
                    let strLen := mload(add(out, 0x20))
                    // safety: ensure entire string bytes are present
                    // string bytes start at out + 64, total required = 64 + padded(strLen)
                    if gt(add(0x40, strLen), returndatasz) {
                        // fallback: treat remaining bytes after 64 as available data
                        if gt(sub(returndatasz, 0x40), 0) {
                            strLen := sub(returndatasz, 0x40)
                        } else {
                            strLen := 0
                        }
                    }
                    if gt(strLen, limit) { strLen := limit }
                    result := mload(0x40)
                    mstore(result, strLen)
                    let src := add(out, 0x40)
                    let dst := add(result, 0x20)
                    let copied := 0
                    for { } lt(copied, strLen) { copied := add(copied, 0x20) } {
                        mstore(add(dst, copied), mload(add(src, copied)))
                    }
                    mstore(0x40, add(add(result, 0x20), and(add(strLen, 0x1f), not(0x1f))))
                    leave
                } else {
                    // fallback to raw bytes scanning for null
                    let maxScan := sub(returndatasz, 0x0)
                    if gt(maxScan, limit) { maxScan := limit }
                    let i := 0
                    for { } lt(i, maxScan) { i := add(i, 1) } {
                        if iszero(byte(0, mload(add(out, i)))) { } else { break }
                    }
                    let len := i
                    if gt(len, limit) { len := limit }
                    result := mload(0x40)
                    mstore(result, len)
                    let src := out
                    let dst := add(result, 0x20)
                    let copied := 0
                    for { } lt(copied, len) { copied := add(copied, 0x20) } {
                        mstore(add(dst, copied), mload(add(src, copied)))
                    }
                    mstore(0x40, add(add(result, 0x20), and(add(len, 0x1f), not(0x1f))))
                    leave
                }
            } // end if memory-pointer branch

            // Else: ptrVal is small => treat as 4-byte selector packed into low bits
            let sel := shl(224, and(ptrVal, 0xffffffff))
            // prepare calldata in memory at scratch
            let memPtr := mload(0x40)
            mstore(memPtr, sel) // 32 bytes; selector is high 4 bytes
            let dataPtr := memPtr
            let dataLen := 4
            success := staticcall(gasStipend, target, dataPtr, dataLen, 0, 0)
            returndatasz := returndatasize()
            if iszero(returndatasz) {
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x20))
                leave
            }
            // copy returndata
            let out2 := add(memPtr, 0x20) // reuse memory after calldata
            returndatacopy(out2, 0, returndatasz)

            if lt(returndatasz, 0x40) {
                // null-terminated or raw bytes
                let maxScan := returndatasz
                if gt(maxScan, limit) { maxScan := limit }
                let i := 0
                for { } lt(i, maxScan) { i := add(i, 1) } {
                    if iszero(byte(0, mload(add(out2, i)))) { } else { break }
                }
                let len := i
                if gt(len, limit) { len := limit }
                result := mload(0x40)
                mstore(result, len)
                let src := out2
                let dst := add(result, 0x20)
                let copied := 0
                for { } lt(copied, len) { copied := add(copied, 0x20) } {
                    mstore(add(dst, copied), mload(add(src, copied)))
                }
                mstore(0x40, add(add(result, 0x20), and(add(len, 0x1f), not(0x1f))))
                leave
            }

            // try ABI decode
            let offset2 := mload(out2)
            if eq(offset2, 0x20) {
                let strLen2 := mload(add(out2, 0x20))
                if gt(add(0x40, strLen2), returndatasz) {
                    if gt(sub(returndatasz, 0x40), 0) {
                        strLen2 := sub(returndatasz, 0x40)
                    } else {
                        strLen2 := 0
                    }
                }
                if gt(strLen2, limit) { strLen2 := limit }
                result := mload(0x40)
                mstore(result, strLen2)
                let src2 := add(out2, 0x40)
                let dst2 := add(result, 0x20)
                let copied2 := 0
                for { } lt(copied2, strLen2) { copied2 := add(copied2, 0x20) } {
                    mstore(add(dst2, copied2), mload(add(src2, copied2)))
                }
                mstore(0x40, add(add(result, 0x20), and(add(strLen2, 0x1f), not(0x1f))))
                leave
            }

            // final fallback
            let maxScan2 := returndatasz
            if gt(maxScan2, limit) { maxScan2 := limit }
            let j := 0
            for { } lt(j, maxScan2) { j := add(j, 1) } {
                if iszero(byte(0, mload(add(out2, j)))) { } else { break }
            }
            let l := j
            if gt(l, limit) { l := limit }
            result := mload(0x40)
            mstore(result, l)
            let s := out2
            let d := add(result, 0x20)
            let c := 0
            for { } lt(c, l) { c := add(c, 0x20) } {
                mstore(add(d, c), mload(add(s, c)))
            }
            mstore(0x40, add(add(result, 0x20), and(add(l, 0x1f), not(0x1f))))
        } // end assembly
    }

    /// @dev Perform a staticcall and interpret the first 32 bytes of returndata as uint256.
    function _uint(address target, bytes32 ptr, uint256 gasStipend) private view returns (uint256 result) {
        assembly {
            let ptrVal := shr(0, ptr)
            let success := 0
            let returndatasz := 0

            if gt(ptrVal, 0xffff) {
                // ptrVal is memory pointer to bytes payload
                let dataPtr := ptrVal
                let dataLen := mload(sub(dataPtr, 0x20))
                success := staticcall(gasStipend, target, dataPtr, dataLen, 0, 0)
            } else {
                // ptrVal is selector
                let sel := shl(224, and(ptrVal, 0xffffffff))
                let memPtr := mload(0x40)
                mstore(memPtr, sel)
                success := staticcall(gasStipend, target, memPtr, 4, 0, 0)
            }

            returndatasz := returndatasize()
            if lt(returndatasz, 0x20) {
                result := 0
            } else {
                // copy first 32 bytes of returndata to memory and read
                let out := mload(0x40)
                returndatacopy(out, 0, 0x20)
                result := mload(out)
            }
        }
    }

    /// @dev Pack a selector (uint256) into bytes32 for use as a small ptr.
    function _ptr(uint256 s) private pure returns (bytes32 result) {
        // store selector integer directly in bytes32 (low-order)
        result = bytes32(s);
    }

    /// @dev Return pointer to data payload (memory address of first data byte).
    function _ptr(bytes memory data) private pure returns (bytes32 result) {
        assembly {
            // return pointer to the first data byte
            result := add(data, 0x20)
        }
    }
}
```// filepath: MetadataReaderLib.sol
// Links:
// [plan.txt](plan.txt)
// [MetadataReaderLib.sol](MetadataReaderLib.sol)
// Referenced symbols:
// [`MetadataReaderLib.readName`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readSymbol`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readString`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readDecimals`](MetadataReaderLib.sol)
// [`MetadataReaderLib.readUint`](MetadataReaderLib.sol)
// [`MetadataReaderLib._string`](MetadataReaderLib.sol)
// [`MetadataReaderLib._uint`](MetadataReaderLib.sol)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title MetadataReaderLib
/// @notice Utility library for reading ERC20/ERC721 style metadata (name, symbol, decimals) and arbitrary strings/uints
library MetadataReaderLib {
    uint256 private constant DEFAULT_LIMIT = 256;
    uint256 private constant DEFAULT_GAS_STIPEND = 30000;

    /// @notice Reads the name() of a target contract.
    function readName(address target) internal view returns (string memory) {
        return readName(target, DEFAULT_LIMIT, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the name() of a target contract with a byte limit.
    function readName(address target, uint256 limit) internal view returns (string memory) {
        return readName(target, limit, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the name() of a target contract with a byte limit and gas stipend.
    function readName(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        // selector for name(): 0x06fdde03
        return _string(target, _ptr(uint256(0x06fdde03)), limit, gasStipend);
    }

    /// @notice Reads the symbol() of a target contract.
    function readSymbol(address target) internal view returns (string memory) {
        return readSymbol(target, DEFAULT_LIMIT, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the symbol() of a target contract with a byte limit.
    function readSymbol(address target, uint256 limit) internal view returns (string memory) {
        return readSymbol(target, limit, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads the symbol() of a target contract with a byte limit and gas stipend.
    function readSymbol(address target, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        // selector for symbol(): 0x95d89b41
        return _string(target, _ptr(uint256(0x95d89b41)), limit, gasStipend);
    }

    /// @notice Reads arbitrary string result by passing `data` to target.
    function readString(address target, bytes memory data) internal view returns (string memory) {
        return readString(target, data, DEFAULT_LIMIT, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads arbitrary string result by passing `data` to target with a byte limit.
    function readString(address target, bytes memory data, uint256 limit) internal view returns (string memory) {
        return readString(target, data, limit, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads arbitrary string result by passing `data` to target with a byte limit and gas stipend.
    function readString(address target, bytes memory data, uint256 limit, uint256 gasStipend) internal view returns (string memory) {
        return _string(target, _ptr(data), limit, gasStipend);
    }

    /// @notice Reads decimals() and returns as uint8.
    function readDecimals(address target) internal view returns (uint8) {
        return readDecimals(target, DEFAULT_GAS_STIPEND);
    }

    /// @notice Reads decimals() with custom gas stipend.
    function readDecimals(address target, uint256 gasStipend) internal view returns (uint8) {
        // selector for decimals(): 0x313ce567
        uint256 val = _uint(target, _ptr(uint256(0x313ce567)), gasStipend);
        return uint8(val);
    }

    /// @notice Read a uint256 by passing ABI-encoded `data`.
    function readUint(address target, bytes memory data) internal view returns (uint256) {
        return readUint(target, data, DEFAULT_GAS_STIPEND);
    }

    /// @notice Read a uint256 by passing ABI-encoded `data` with gas stipend.
    function readUint(address target, bytes memory data, uint256 gasStipend) internal view returns (uint256) {
        return _uint(target, _ptr(data), gasStipend);
    }

    /// @dev Internal helper: treat `ptr` either as a small selector (<= 0xffff) packed into bytes32
    ///      or as an in-memory pointer to a bytes payload (when ptr is a memory address).
    function _string(address target, bytes32 ptr, uint256 limit, uint256 gasStipend) private view returns (string memory result) {
        assembly {
            let ptrVal := shr(0, ptr) // numeric value of ptr
            let success := 0
            let returndatasz := 0

            // Determine if ptrVal is a memory pointer (large) or a selector (small)
            // We treat values > 0xffff as memory pointers.
            if gt(ptrVal, 0xffff) {
                // ptrVal points to the first byte of calldata payload in memory.
                let dataPtr := ptrVal
                let dataLen := mload(sub(dataPtr, 0x20)) // bytes length is stored just before data pointer

                // perform staticcall with limited gas
                success := staticcall(gasStipend, target, dataPtr, dataLen, 0, 0)
                returndatasz := returndatasize()
                // if no returndata, return empty string
                if iszero(returndatasz) {
                    result := mload(0x40)
                    mstore(result, 0)
                    mstore(0x40, add(result, 0x20))
                    leave
                }

                // copy returndata to memory at free pointer
                let out := mload(0x40)
                returndatacopy(out, 0, returndatasz)

                // If returndata is standard ABI (offset + len + data) minimum 64
                if lt(returndatasz, 0x40) {
                    // treat as null-terminated or raw bytes
                    let maxScan := returndatasz
                    if gt(maxScan, limit) { maxScan := limit }
                    let i := 0
                    for { } lt(i, maxScan) { i := add(i, 1) } {
                        if iszero(byte(0, mload(add(out, i)))) { } else { break }
                    }
                    let len := i
                    if gt(len, limit) { len := limit }
                    // allocate result
                    result := mload(0x40)
                    mstore(result, len)
                    // copy bytes in 32-byte chunks
                    let src := out
                    let dst := add(result, 0x20)
                    let copied := 0
                    for { } lt(copied, len) { copied := add(copied, 0x20) } {
                        mstore(add(dst, copied), mload(add(src, copied)))
                    }
                    mstore(0x40, add(add(result, 0x20), and(add(len, 0x1f), not(0x1f))))
                    leave
                }

                // try to ABI decode: offset at out, typically 32, then length at out+32
                let offset := mload(out)
                // we expect offset == 32 in typical ABI-encoded string
                if eq(offset, 0x20) {
                    let strLen := mload(add(out, 0x20))
                    // safety: ensure entire string bytes are present
                    // string bytes start at out + 64, total required = 64 + padded(strLen)
                    if gt(add(0x40, strLen), returndatasz) {
                        // fallback: treat remaining bytes after 64 as available data
                        if gt(sub(returndatasz, 0x40), 0) {
                            strLen := sub(returndatasz, 0x40)
                        } else {
                            strLen := 0
                        }
                    }
                    if gt(strLen, limit) { strLen := limit }
                    result := mload(0x40)
                    mstore(result, strLen)
                    let src := add(out, 0x40)
                    let dst := add(result, 0x20)
                    let copied := 0
                    for { } lt(copied, strLen) { copied := add(copied, 0x20) } {
                        mstore(add(dst, copied), mload(add(src, copied)))
                    }
                    mstore(0x40, add(add(result, 0x20), and(add(strLen, 0x1f), not(0x1f))))
                    leave
                } else {
                    // fallback to raw bytes scanning for null
                    let maxScan := sub(returndatasz, 0x0)
                    if gt(maxScan, limit) { maxScan := limit }
                    let i := 0
                    for { } lt(i, maxScan) { i := add(i, 1) } {
                        if iszero(byte(0, mload(add(out, i)))) { } else { break }
                    }
                    let len := i
                    if gt(len, limit) { len := limit }
                    result := mload(0x40)
                    mstore(result, len)
                    let src := out
                    let dst := add(result, 0x20)
                    let copied := 0
                    for { } lt(copied, len) { copied := add(copied, 0x20) } {
                        mstore(add(dst, copied), mload(add(src, copied)))
                    }
                    mstore(0x40, add(add(result, 0x20), and(add(len, 0x1f), not(0x1f))))
                    leave
                }
            } // end if memory-pointer branch

            // Else: ptrVal is small => treat as 4-byte selector packed into low bits
            let sel := shl(224, and(ptrVal, 0xffffffff))
            // prepare calldata in memory at scratch
            let memPtr := mload(0x40)
            mstore(memPtr, sel) // 32 bytes; selector is high 4 bytes
            let dataPtr := memPtr
            let dataLen := 4
            success := staticcall(gasStipend, target, dataPtr, dataLen, 0, 0)
            returndatasz := returndatasize()
            if iszero(returndatasz) {
                result := mload(0x40)
                mstore(result, 0)
                mstore(0x40, add(result, 0x20))
                leave
            }
            // copy returndata
            let out2 := add(memPtr, 0x20) // reuse memory after calldata
            returndatacopy(out2, 0, returndatasz)

            if lt(returndatasz, 0x40) {
                // null-terminated or raw bytes
                let maxScan := returndatasz
                if gt(maxScan, limit) { maxScan := limit }
                let i := 0
                for { } lt(i, maxScan) { i := add(i, 1) } {
                    if iszero(byte(0, mload(add(out2, i)))) { } else { break }
                }
                let len := i
                if gt(len, limit) { len := limit }
                result := mload(0x40)
                mstore(result, len)
                let src := out2
                let dst := add(result, 0x20)
                let copied := 0
                for { } lt(copied, len) { copied := add(copied, 0x20) } {
                    mstore(add(dst, copied), mload(add(src, copied)))
                }
                mstore(0x40, add(add(result, 0x20), and(add(len, 0x1f), not(0x1f))))
                leave
            }

            // try ABI decode
            let offset2 := mload(out2)
            if eq(offset2, 0x20) {
                let strLen2 := mload(add(out2, 0x20))
                if gt(add(0x40, strLen2), returndatasz) {
                    if gt(sub(returndatasz, 0x40), 0) {
                        strLen2 := sub(returndatasz, 0x40)
                    } else {
                        strLen2 := 0
                    }
                }
                if gt(strLen2, limit) { strLen2 := limit }
                result := mload(0x40)
                mstore(result, strLen2)
                let src2 := add(out2, 0x40)
                let dst2 := add(result, 0x20)
                let copied2 := 0
                for { } lt(copied2, strLen2) { copied2 := add(copied2, 0x20) } {
                    mstore(add(dst2, copied2), mload(add(src2, copied2)))
                }
                mstore(0x40, add(add(result, 0x20), and(add(strLen2, 0x1f), not(0x1f))))
                leave
            }

            // final fallback
            let maxScan2 := returndatasz
            if gt(maxScan2, limit) { maxScan2 := limit }
            let j := 0
            for { } lt(j, maxScan2) { j := add(j, 1) } {
                if iszero(byte(0, mload(add(out2, j)))) { } else { break }
            }
            let l := j
            if gt(l, limit) { l := limit }
            result := mload(0x40)
            mstore(result, l)
            let s := out2
            let d := add(result, 0x20)
            let c := 0
            for { } lt(c, l) { c := add(c, 0x20) } {
                mstore(add(d, c), mload(add(s, c)))
            }
            mstore(0x40, add(add(result, 0x20), and(add(l, 0x1f), not(0x1f))))
        } // end assembly
    }

    /// @dev Perform a staticcall and interpret the first 32 bytes of returndata as uint256.
    function _uint(address target, bytes32 ptr, uint256 gasStipend) private view returns (uint256 result) {
        assembly {
            let ptrVal := shr(0, ptr)
            let success := 0
            let returndatasz := 0

            if gt(ptrVal, 0xffff) {
                // ptrVal is memory pointer to bytes payload
                let dataPtr := ptrVal
                let dataLen := mload(sub(dataPtr, 0x20))
                success := staticcall(gasStipend, target, dataPtr, dataLen, 0, 0)
            } else {
                // ptrVal is selector
                let sel := shl(224, and(ptrVal, 0xffffffff))
                let memPtr := mload(0x40)
                mstore(memPtr, sel)
                success := staticcall(gasStipend, target, memPtr, 4, 0, 0)
            }

            returndatasz := returndatasize()
            if lt(returndatasz, 0x20) {
                result := 0
            } else {
                // copy first 32 bytes of returndata to memory and read
                let out := mload(0x40)
                returndatacopy(out, 0, 0x20)
                result := mload(out)
            }
        }
    }

    /// @dev Pack a selector (uint256) into bytes32 for use as a small ptr.
    function _ptr(uint256 s) private pure returns (bytes32 result) {
        // store selector integer directly in bytes32 (low-order)
        result = bytes32(s);
    }

    /// @dev Return pointer to data payload (memory address of first data byte).
    function _ptr(bytes memory data) private pure returns (bytes32 result) {
        assembly {
            // return pointer to the first data byte
            result := add(data, 0x20)
        }
    }
}