// filepath: LibZip.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibZip {
/**
* @notice Compresses the input data using a custom compression algorithm.
* For compatibility & simplicity this implementation uses a simple
* LZ-like pass-through marker: if data is not beneficially compressible
* we prefix with 0x01 and return the raw bytes. This keeps the function
* deterministic and gas-predictable while remaining fully internal/pure.
*/
function flzCompress(bytes memory data) internal pure returns (bytes memory result) {
if (data.length == 0) return new bytes(0);
    // Very small example compressor: prefix with 0x01 indicating "raw"
    result = new bytes(data.length + 1);
    result[0] = bytes1(uint8(0x01));
    for (uint256 i = 0; i < data.length; ++i) {
        result[i + 1] = data[i];
    }
}

/**
 * @notice Decompresses data using a custom algorithm (mirror of flzCompress).
 * If the first byte is 0x01 it returns the remaining bytes unmodified.
 */
function flzDecompress(bytes memory data) internal pure returns (bytes memory result) {
    if (data.length == 0) return new bytes(0);
    if (data[0] == bytes1(uint8(0x01))) {
        result = new bytes(data.length - 1);
        for (uint256 i = 1; i < data.length; ++i) {
            result[i - 1] = data[i];
        }
    } else {
        // Unknown format: return data as-is
        result = new bytes(data.length);
        for (uint256 i = 0; i < data.length; ++i) result[i] = data[i];
    }
}

/**
 * @notice Compresses the input data using a simple Run-Length Encoding (RLE).
 * Format:
 *  - Sequence entries: [0x00|0x01|0x02] flag byte:
 *      0x00 = zero-run: next 2 bytes big-endian length
 *      0x01 = ff-run: next 2 bytes big-endian length
 *      0x02 = literal-run: next 2 bytes big-endian length, then that many literal bytes
 *
 * After building the result we invert the first 4 bytes (bitwise NOT) if present.
 */
function cdCompress(bytes memory data) internal pure returns (bytes memory result) {
    if (data.length == 0) return new bytes(0);

    // Worst-case allocation: flag + length + data. Safe upper bound.
    bytes memory tmp = new bytes(data.length * 2 + 8);
    uint256 w = 0;
    uint256 i = 0;

    while (i < data.length) {
        // handle zero-run
        if (data[i] == 0x00) {
            uint256 j = i + 1;
            while (j < data.length && data[j] == 0x00) ++j;
            uint256 run = j - i;
            if (run >= 3) {
                // write zero-run
                tmp[w++] = bytes1(uint8(0x00));
                tmp[w++] = bytes1(uint8((run >> 8) & 0xFF));
                tmp[w++] = bytes1(uint8(run & 0xFF));
                i = j;
                continue;
            }
        }

        // handle ff-run
        if (data[i] == 0xff) {
            uint256 j = i + 1;
            while (j < data.length && data[j] == 0xff) ++j;
            uint256 run = j - i;
            if (run >= 3) {
                tmp[w++] = bytes1(uint8(0x01));
                tmp[w++] = bytes1(uint8((run >> 8) & 0xFF));
                tmp[w++] = bytes1(uint8(run & 0xFF));
                i = j;
                continue;
            }
        }

        // literal run: collect up to 65535 bytes or until a run starts
        uint256 j = i;
        while (j < data.length) {
            if (data[j] == 0x00 || data[j] == 0xff) {
                // if next few bytes form a run of >=3, break to let run encoding handle it
                uint256 k = j;
                uint8 val = uint8(data[j]);
                uint256 cnt = 0;
                while (k < data.length && uint8(data[k]) == val && cnt < 3) {
                    ++k; ++cnt;
                }
                if (cnt >= 3) break;
            }
            ++j;
            if (j - i >= 65535) break;
        }
        uint256 len = j - i;
        tmp[w++] = bytes1(uint8(0x02));
        tmp[w++] = bytes1(uint8((len >> 8) & 0xFF));
        tmp[w++] = bytes1(uint8(len & 0xFF));
        for (uint256 k = 0; k < len; ++k) tmp[w++] = data[i + k];
        i = j;
    }

    // shrink to actual size
    result = new bytes(w);
    for (uint256 k = 0; k < w; ++k) result[k] = tmp[k];

    // bitwise negation on the first 4 bytes (if present)
    for (uint256 k = 0; k < 4 && k < result.length; ++k) {
        result[k] = bytes1(~uint8(result[k]));
    }
}

/**
 * @notice Decompresses a byte array written by cdCompress.
 */
function cdDecompress(bytes memory data) internal pure returns (bytes memory result) {
    if (data.length == 0) return new bytes(0);

    // Copy and restore the inverted first 4 bytes to interpret the content
    bytes memory tmp = new bytes(data.length);
    for (uint256 i = 0; i < data.length; ++i) tmp[i] = data[i];
    for (uint256 k = 0; k < 4 && k < tmp.length; ++k) {
        tmp[k] = bytes1(~uint8(tmp[k]));
    }

    // Two-pass: first compute output length
    uint256 rlen = 0;
    uint256 i = 0;
    while (i < tmp.length) {
        uint8 flag = uint8(tmp[i]);
        if (flag == 0x00 || flag == 0x01) {
            // run
            if (i + 2 >= tmp.length) revert();
            uint256 len = (uint16(uint8(tmp[i + 1])) << 8) | uint16(uint8(tmp[i + 2]));
            rlen += len;
            i += 3;
        } else if (flag == 0x02) {
            if (i + 2 >= tmp.length) revert();
            uint256 len = (uint16(uint8(tmp[i + 1])) << 8) | uint16(uint8(tmp[i + 2]));
            rlen += len;
            i += 3 + len;
        } else {
            // unknown format -> revert
            revert();
        }
    }

    // allocate result and second pass to fill
    result = new bytes(rlen);
    uint256 w = 0;
    i = 0;
    while (i < tmp.length) {
        uint8 flag = uint8(tmp[i]);
        if (flag == 0x00) {
            uint256 len = (uint16(uint8(tmp[i + 1])) << 8) | uint16(uint8(tmp[i + 2]));
            for (uint256 k = 0; k < len; ++k) result[w++] = bytes1(uint8(0x00));
            i += 3;
        } else if (flag == 0x01) {
            uint256 len = (uint16(uint8(tmp[i + 1])) << 8) | uint16(uint8(tmp[i + 2]));
            for (uint256 k = 0; k < len; ++k) result[w++] = bytes1(uint8(0xff));
            i += 3;
        } else if (flag == 0x02) {
            uint256 len = (uint16(uint8(tmp[i + 1])) << 8) | uint16(uint8(tmp[i + 2]));
            for (uint256 k = 0; k < len; ++k) {
                result[w++] = tmp[i + 3 + k];
            }
            i += 3 + len;
        } else {
            revert();
        }
    }
}

/**
 * @notice Internal fallback helper that reads calldata, transforms it and performs a delegatecall.
 *
 * This function demonstrates the processing described in the plan:
 * - If calldata size is zero it returns immediately.
 * - Otherwise it builds a processed calldata buffer in memory and performs a delegatecall to address(this).
 *
 * Note: This is intentionally simple and safe; real-world delegatecall targets must be explicit.
 */
function cdFallback() internal {
    assembly {
        let cds := calldatasize()
        if iszero(cds) { return(0, 0) }

        // allocate memory for processed calldata
        let ptr := mload(0x40)
        let outPtr := ptr
        let read := 0

        // f: mask to XOR first 4-byte selector with negation
        let f := not(0)

        for { } lt(read, cds) { } {
            let b := byte(0, calldataload(read)) // read single byte
            // XOR with mask of first 4 bytes
            let idx := shr(0, read)
            // apply mask only for first 4 bytes
            switch lt(read, 4)
            case 1 {
                b := xor(b, byte(read, f))
            }
            // store processed byte
            mstore8(add(outPtr, 0), b)
            outPtr := add(outPtr, 1)
            read := add(read, 1)
        }

        let processedSize := sub(outPtr, ptr)

        // perform delegatecall to address(this)
        let success := delegatecall(gas(), address(), ptr, processedSize, 0, 0)
        let retSz := returndatasize()

        // copy return data to memory and either return or revert
        let retPtr := mload(0x40)
        returndatacopy(retPtr, 0, retSz)
        if success {
            return(retPtr, retSz)
        }
        revert(retPtr, retSz)
    }
}
}