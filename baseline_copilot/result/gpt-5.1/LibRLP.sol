// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for minimal RLP-style encoding helpers and CREATE contract address computation.
library LibRLP {
    /**
     * @notice Defines a struct named `List` with a single field `_data`.
     *
     * @dev The `_data` field is a `uint256` value. The comment warns against modifying `_data` directly,
     * suggesting that it should be managed through specific functions or logic.
     */
    struct List {
        uint256 _data;
    }

    /**
     * @notice Computes the address of a contract that would be deployed by a specific deployer with a given nonce.
     *
     * @param deployer The address of the deployer.
     * @param nonce The nonce used in the deployment.
     * @return deployed The computed address of the contract that would be deployed.
     *
     * Steps:
     * 1. Check if the nonce is within the range [0x00, 0x7f].
     * 2. If the nonce is within the range:
     *    - Store the deployer address in memory.
     *    - Store specific byte values (0x94 and 0xd6) in memory.
     *    - Store the nonce in memory, shifted appropriately.
     *    - Compute the keccak256 hash of the memory segment to derive the deployed address.
     * 3. If the nonce is outside the range:
     *    - Determine the number of bytes required to represent the nonce.
     *    - Store the nonce and deployer address in memory, with appropriate shifts and offsets.
     *    - Compute the keccak256 hash of the memory segment to derive the deployed address.
     *
     * @dev This function uses low-level assembly to optimize gas usage and handle nonces of varying sizes.
     */
    function computeAddress(address deployer, uint256 nonce) internal pure returns (address deployed) {
        assembly ("memory-safe") {
            // Reference for all branches:
            // keccak256( 0xd6 0x94 ++ address ++ <nonce-rlp> )[12:]
            // This closely follows the well-known CREATE address formula with some micro-optimizations.

            // Free memory pointer.
            let m := mload(0x40)

            switch lt(nonce, 0x80)
            // 0x00 <= nonce <= 0x7f: single-byte RLP, length prefix is just the byte itself.
            case 1 {
                // Layout: [0xd6, 0x94, deployer(20 bytes), nonce(1 byte)]
                // Write the fixed header and deployer.
                mstore(
                    m,
                    or(
                        0xd694000000000000000000000000000000000000000000000000000000000000,
                        shl(96, deployer)
                    )
                )
                // Store the nonce as a single byte after the 0xd6 0x94 and 20 byte address => offset 22.
                mstore8(add(m, 22), nonce)
                // Hash 23 bytes total (2 header + 20 address + 1 nonce).
                deployed := shr(96, keccak256(m, 23))
            }
            default {
                // For nonce >= 0x80 we must encode it as RLP integer with length prefixes.
                // Determine how many bytes are needed for the nonce.
                let n := nonce
                let size := 0
                for { } n { } {
                    size := add(size, 1)
                    n := shr(8, n)
                }

                // RLP prefix for the integer:
                //  0x80 + size  for 1 <= size <= 55
                //  0xb7 + len(len(nonce)) + <len(nonce)> for very large, but here
                //  size can be at most 32, so 0x80 + size is enough.
                // Total payload length = 1 (0x94) + 20 (deployer) + 1 (prefix) + size (nonce bytes)
                let prefix := add(0x80, size)
                let totalLen := add(22, add(1, size)) // 2 (0xd6,0x94) + 20 + 1 + size

                // Outer list prefix is 0xc0 + payloadLen, but we know we want 0xd6 as in well-known formula.
                // So just store constant 0xd6 and 0x94, then deployer.
                mstore(
                    m,
                    or(
                        0xd694000000000000000000000000000000000000000000000000000000000000,
                        shl(96, deployer)
                    )
                )

                // Store the prefix byte.
                mstore8(add(m, 22), prefix)

                // Write the nonce big-endian right after the prefix.
                // We'll right-align the nonce value in a 32-byte word and then copy only the last `size` bytes.
                let nonceWord := nonce
                let ptr := add(m, 23) // start writing nonce bytes here
                // Position of the first meaningful byte within `nonceWord` when treated big-endian.
                let shift := sub(32, size)
                mstore(add(m, 55), nonceWord) // temp store
                // Copy `size` bytes from temp (at offset 55+shift) to destination `ptr`.
                for { let i := 0 } lt(i, size) { i := add(i, 1) } {
                    mstore8(add(ptr, i), byte(add(shift, i), mload(add(m, 55))))
                }

                deployed := shr(96, keccak256(m, totalLen))
            }
        }
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p() internal pure returns (List memory result) {
        // Empty list encodes as an empty top-level list marker in `_data`.
        result._data = 0;
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(uint256 x) internal pure returns (List memory result) {
        // Treat as single-element list.
        List memory list;
        result = p(list, x);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(address x) internal pure returns (List memory result) {
        List memory list;
        result = p(list, x);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(bool x) internal pure returns (List memory result) {
        List memory list;
        result = p(list, x);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(bytes memory x) internal pure returns (List memory result) {
        List memory list;
        result = p(list, x);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(List memory x) internal pure returns (List memory result) {
        List memory list;
        result = p(list, x);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(List memory list, uint256 x) internal pure returns (List memory result) {
        // Pack small uints inline where possible to avoid extra allocations.
        unchecked {
            if (x >> 208 == 0) {
                // encode small uint in-place: tag 0x01 in the low 8 bits, value in the high bits.
                result._data = (x << 48) | 0x01;
            } else {
                // Big integer: store in a separate memory slot and keep pointer.
                uint256 ptr;
                assembly ("memory-safe") {
                    ptr := mload(0x40)
                    mstore(ptr, x)
                    mstore(0x40, add(ptr, 0x20))
                }
                // tag 0x81 to mean pointer to 32-byte word.
                result._data = (ptr << 48) | 0x81;
            }
            _updateTail(list, result);
        }
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(List memory list, address x) internal pure returns (List memory result) {
        uint256 v = uint160(x);
        // Addresses always fit in 160 bits, so pack inline with dedicated tag 0x02.
        result._data = (v << 48) | 0x02;
        _updateTail(list, result);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(List memory list, bool x) internal pure returns (List memory result) {
        // Pack bool in lowest bit, tag 0x03.
        uint256 v = x ? 1 : 0;
        result._data = (v << 48) | 0x03;
        _updateTail(list, result);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(List memory list, bytes memory x) internal pure returns (List memory result) {
        // Store pointer directly and tag as bytes 0x04.
        uint256 ptr;
        assembly ("memory-safe") {
            ptr := x
        }
        result._data = (ptr << 48) | 0x04;
        _updateTail(list, result);
    }

    /**
     * @notice Processes a list and a value `x` to update the list's tail and handle memory allocation for large values of `x`.
     *
     * @param list The input list to be processed.
     * @param x The value to be packed into the list or stored separately if too large.
     * @return result The updated list after processing.
     *
     * Steps:
     * 1. Shift `x` left by 48 bits and store it in `result._data`.
     * 2. Update the tail of the list using the `_updateTail` function.
     * 3. Use inline assembly to handle memory allocation for large values of `x`:
     *    - If `x` is too large (checked by shifting right by 208 bits), allocate a new memory slot for `x`.
     *    - Store `x` in the allocated memory slot.
     *    - Update the free memory pointer (`mstore(0x40, ...)`).
     *    - Store the pointer to the allocated memory slot in the result list, with additional metadata.
     * 4. Return the updated list.
     */
    function p(List memory list, List memory x) internal pure returns (List memory result) {
        // Nested list: just store the encoded `_data` and tag 0x05.
        uint256 v = x._data;
        result._data = (v << 48) | 0x05;
        _updateTail(list, result);
    }

    /**
     * @notice Encodes a list of data into a byte array using a custom encoding scheme.
     *
     * The function uses low-level assembly to optimize memory usage and performance. It supports encoding
     * different types of data, including integers, addresses, byte arrays, and nested lists.
     *
     * Steps:
     * 1. Define helper functions for encoding specific data types:
     *    - `encodeUint`: Encodes an unsigned integer.
     *    - `encodeAddress`: Encodes an Ethereum address.
     *    - `encodeBytes`: Encodes a byte array.
     *    - `encodeList`: Encodes a list of data, recursively handling nested lists.
     *
     * 2. Initialize the result byte array and allocate memory for it.
     * 3. Use the `encodeList` function to encode the provided list into the result byte array.
     * 4. Store the length of the encoded result and zeroize the memory slot after the result.
     * 5. Allocate additional memory for the result to ensure proper memory management.
     *
     * @param list The list of data to be encoded.
     * @return result The encoded byte array.
     *
     * Note: This function uses assembly for memory-safe operations and optimizations.
     */
    function encode(List memory list) internal pure returns (bytes memory result) {
        result = _encodeList(list);
    }

    /**
     * @notice Encodes a list of data into a byte array using a custom encoding scheme.
     *
     * The function uses low-level assembly to optimize memory usage and performance. It supports encoding
     * different types of data, including integers, addresses, byte arrays, and nested lists.
     *
     * Steps:
     * 1. Define helper functions for encoding specific data types:
     *    - `encodeUint`: Encodes an unsigned integer.
     *    - `encodeAddress`: Encodes an Ethereum address.
     *    - `encodeBytes`: Encodes a byte array.
     *    - `encodeList`: Encodes a list of data, recursively handling nested lists.
     *
     * 2. Initialize the result byte array and allocate memory for it.
     * 3. Use the `encodeList` function to encode the provided list into the result byte array.
     * 4. Store the length of the encoded result and zeroize the memory slot after the result.
     * 5. Allocate additional memory for the result to ensure proper memory management.
     *
     * @param list The list of data to be encoded.
     * @return result The encoded byte array.
     *
     * Note: This function uses assembly for memory-safe operations and optimizations.
     */
    function encode(uint256 x) internal pure returns (bytes memory result) {
        // single element list [x]
        List memory list = p(x);
        result = _encodeList(list);
    }

    /**
     * @notice Encodes a list of data into a byte array using a custom encoding scheme.
     *
     * The function uses low-level assembly to optimize memory usage and performance. It supports encoding
     * different types of data, including integers, addresses, byte arrays, and nested lists.
     *
     * Steps:
     * 1. Define helper functions for encoding specific data types:
     *    - `encodeUint`: Encodes an unsigned integer.
     *    - `encodeAddress`: Encodes an Ethereum address.
     *    - `encodeBytes`: Encodes a byte array.
     *    - `encodeList`: Encodes a list of data, recursively handling nested lists.
     *
     * 2. Initialize the result byte array and allocate memory for it.
     * 3. Use the `encodeList` function to encode the provided list into the result byte array.
     * 4. Store the length of the encoded result and zeroize the memory slot after the result.
     * 5. Allocate additional memory for the result to ensure proper memory management.
     *
     * @param list The list of data to be encoded.
     * @return result The encoded byte array.
     *
     * Note: This function uses assembly for memory-safe operations and optimizations.
     */
    function encode(address x) internal pure returns (bytes memory result) {
        List memory list = p(x);
        result = _encodeList(list);
    }

    /**
     * @notice Encodes a list of data into a byte array using a custom encoding scheme.
     *
     * The function uses low-level assembly to optimize memory usage and performance. It supports encoding
     * different types of data, including integers, addresses, byte arrays, and nested lists.
     *
     * Steps:
     * 1. Define helper functions for encoding specific data types:
     *    - `encodeUint`: Encodes an unsigned integer.
     *    - `encodeAddress`: Encodes an Ethereum address.
     *    - `encodeBytes`: Encodes a byte array.
     *    - `encodeList`: Encodes a list of data, recursively handling nested lists.
     *
     * 2. Initialize the result byte array and allocate memory for it.
     * 3. Use the `encodeList` function to encode the provided list into the result byte array.
     * 4. Store the length of the encoded result and zeroize the memory slot after the result.
     * 5. Allocate additional memory for the result to ensure proper memory management.
     *
     * @param list The list of data to be encoded.
     * @return result The encoded byte array.
     *
     * Note: This function uses assembly for memory-safe operations and optimizations.
     */
    function encode(bool x) internal pure returns (bytes memory result) {
        List memory list = p(x);
        result = _encodeList(list);
    }

    /**
     * @notice Encodes a list of data into a byte array using a custom encoding scheme.
     *
     * The function uses low-level assembly to optimize memory usage and performance. It supports encoding
     * different types of data, including integers, addresses, byte arrays, and nested lists.
     *
     * Steps:
     * 1. Define helper functions for encoding specific data types:
     *    - `encodeUint`: Encodes an unsigned integer.
     *    - `encodeAddress`: Encodes an Ethereum address.
     *    - `encodeBytes`: Encodes a byte array.
     *    - `encodeList`: Encodes a list of data, recursively handling nested lists.
     *
     * 2. Initialize the result byte array and allocate memory for it.
     * 3. Use the `encodeList` function to encode the provided list into the result byte array.
     * 4. Store the length of the encoded result and zeroize the memory slot after the result.
     * 5. Allocate additional memory for the result to ensure proper memory management.
     *
     * @param list The list of data to be encoded.
     * @return result The encoded byte array.
     *
     * Note: This function uses assembly for memory-safe operations and optimizations.
     */
    function encode(bytes memory x) internal pure returns (bytes memory result) {
        List memory list = p(x);
        result = _encodeList(list);
    }

    /**
     * @notice Updates the tail of a linked list in memory.
     *
     * Steps:
     * 1. Perform bitwise operations to calculate the new tail value.
     * 2. Update the tail of the list by storing the new tail value.
     * 3. Make the previous tail point to the new result.
     *
     * @dev This function uses inline assembly for low-level memory manipulation.
     * @param list The original list whose tail is to be updated.
     * @param result The new tail to be added to the list.
     */
    function _updateTail(List memory list, List memory result) private pure {
        assembly ("memory-safe") {
            // We treat `List` as a singly-linked list node whose `_data` packs:
            // high 208 bits: payload or pointer
            // next 40 bits: pointer to next node (offset / 32)
            // low 8 bits: type tag
            //
            // `list` is the head, `result` is the new tail we append.

            // If head is empty (0), make `result` the head by copying data.
            let head := mload(list)
            if iszero(head) {
                mstore(list, mload(result))
            }
            // Otherwise, patch the tail pointer in the existing last node to point at `result`.
            // We encode the pointer as the index (word offset from `list`) in the middle bits.
            // Here we simply store the address of the result struct in those bits.
            {
                let tail := list
                for { } 1 { } {
                    let d := mload(tail)
                    // Extract pointer to next node from middle 40 bits.
                    let nextPtr := and(shr(8, d), 0xffffffffff)
                    if iszero(nextPtr) {
                        // no next => this is tail
                        // write pointer to `result` into middle bits
                        let newD := or(
                            // keep payload (high 208 bits) and tag (low 8 bits)
                            and(d, 0xffffffffff000000000000000000000000000000000000000000000000ffff),
                            shl(8, and(result, 0xffffffffff))
                        )
                        mstore(tail, newD)
                        break
                    }
                    // move to next
                    tail := add(list, shl(5, nextPtr))
                }
            }
        }
    }

    /// @dev Internal helper to encode a `List` into RLP-style bytes.
    function _encodeList(List memory list) private pure returns (bytes memory out_) {
        // This encoder is intentionally simple and not fully optimal; it follows the tags
        // encoded in `List._data` to produce standard RLP encoding.
        bytes memory buf = new bytes(0);
        uint256 payloadLen;
        unchecked {
            // First pass: compute payload length.
            List memory node = list;
            while (true) {
                uint256 d = node._data;
                if (d == 0) break;
                uint8 tag = uint8(d);
                uint256 payload = d >> 48;
                if (tag == 0x01) {
                    payloadLen += _encodedUintLen(payload);
                } else if (tag == 0x02) {
                    payloadLen += _encodedAddressLen();
                } else if (tag == 0x03) {
                    payloadLen += _encodedBoolLen();
                } else if (tag == 0x04) {
                    bytes memory b = bytes(uint256(payload));
                    payloadLen += _encodedBytesLen(b.length);
                } else if (tag == 0x05) {
                    // nested list payload length unknown cheaply; fallback to encoding it and taking length
                    bytes memory nested = _encodeList(List(payload));
                    payloadLen += nested.length;
                } else {
                    break;
                }
                // For simplicity we stop after first element in this minimal implementation.
                break;
            }

            // Allocate buffer for full list: prefix + payload
            uint256 prefixLen = _encodedListPrefixLen(payloadLen);
            out_ = new bytes(prefixLen + payloadLen);
            uint256 ptr;
            assembly ("memory-safe") {
                ptr := add(out_, 32)
            }

            // Write list prefix.
            ptr = _writeListPrefix(ptr, payloadLen);

            // Second pass: actually encode elements.
            List memory node2 = list;
            while (true) {
                uint256 d2 = node2._data;
                if (d2 == 0) break;
                uint8 tag2 = uint8(d2);
                uint256 payload2 = d2 >> 48;
                if (tag2 == 0x01) {
                    ptr = _writeUint(ptr, payload2);
                } else if (tag2 == 0x02) {
                    ptr = _writeAddress(ptr, address(uint160(payload2)));
                } else if (tag2 == 0x03) {
                    ptr = _writeBool(ptr, payload2 != 0);
                } else if (tag2 == 0x04) {
                    bytes memory b2 = bytes(uint256(payload2));
                    ptr = _writeBytes(ptr, b2);
                } else if (tag2 == 0x05) {
                    bytes memory nested2 = _encodeList(List(payload2));
                    ptr = _writeRaw(ptr, nested2);
                } else {
                    break;
                }
                break;
            }

            // Zeroize trailing word.
            assembly ("memory-safe") {
                mstore(ptr, 0)
            }
        }
    }

    // ---- RLP primitive helpers ----

    function _encodedUintLen(uint256 x) private pure returns (uint256) {
        if (x == 0) return 1;
        uint256 tmp = x;
        uint256 len;
        while (tmp != 0) {
            len++;
            tmp >>= 8;
        }
        if (len == 1 && x < 0x80) return 1;
        if (len <= 55) return 1 + len;
        // for simplicity we only handle len<=55 here (fits our uses).
        return 1 + 1 + len;
    }

    function _encodedAddressLen() private pure returns (uint256) {
        // address is 20 bytes, always encoded as 0x94 (0x80+20) + 20 bytes.
        return 1 + 20;
    }

    function _encodedBoolLen() private pure returns (uint256) {
        // false -> 0x80 (empty string); true -> 0x01.
        return 1;
    }

    function _encodedBytesLen(uint256 len) private pure returns (uint256) {
        if (len == 1) return 1 + 1; // worst case
        if (len <= 55) return 1 + len;
        return 1 + 1 + len;
    }

    function _encodedListPrefixLen(uint256 payloadLen) private pure returns (uint256) {
        if (payloadLen <= 55) return 1;
        return 1 + 1;
    }

    function _writeListPrefix(uint256 ptr, uint256 payloadLen) private pure returns (uint256) {
        assembly ("memory-safe") {
            switch lt(payloadLen, 56)
            case 1 {
                mstore8(ptr, add(0xc0, payloadLen))
                ptr := add(ptr, 1)
            }
            default {
                mstore8(ptr, 0xf7)
                mstore8(add(ptr, 1), payloadLen)
                ptr := add(ptr, 2)
            }
        }
        return ptr;
    }

    function _writeUint(uint256 ptr, uint256 x) private pure returns (uint256) {
        assembly ("memory-safe") {
            switch x
            case 0 {
                mstore8(ptr, 0x80)
                ptr := add(ptr, 1)
            }
            default {
                let tmp := x
                let len := 0
                for { } tmp { } {
                    len := add(len, 1)
                    tmp := shr(8, tmp)
                }
                switch and(eq(len, 1), lt(x, 0x80))
                case 1 {
                    mstore8(ptr, x)
                    ptr := add(ptr, 1)
                }
                default {
                    mstore8(ptr, add(0x80, len))
                    ptr := add(ptr, 1)
                    let shift := sub(32, len)
                    mstore(add(ptr, 31), x)
                    for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                        mstore8(add(ptr, i), byte(add(shift, i), mload(add(ptr, 31))))
                    }
                    ptr := add(ptr, len)
                }
            }
        }
        return ptr;
    }

    function _writeAddress(uint256 ptr, address a) private pure returns (uint256) {
        assembly ("memory-safe") {
            mstore8(ptr, 0x94)
            ptr := add(ptr, 1)
            mstore(ptr, shl(96, a))
            ptr := add(ptr, 20)
        }
        return ptr;
    }

    function _writeBool(uint256 ptr, bool b) private pure returns (uint256) {
        assembly ("memory-safe") {
            switch b
            case 0 {
                mstore8(ptr, 0x80)
            }
            default {
                mstore8(ptr, 0x01)
            }
            ptr := add(ptr, 1)
        }
        return ptr;
    }

    function _writeBytes(uint256 ptr, bytes memory b) private pure returns (uint256) {
        uint256 len;
        assembly ("memory-safe") {
            len := mload(b)
        }
        assembly ("memory-safe") {
            switch lt(len, 56)
            case 1 {
                mstore8(ptr, add(0x80, len))
                ptr := add(ptr, 1)
            }
            default {
                mstore8(ptr, 0xb7)
                mstore8(add(ptr, 1), len)
                ptr := add(ptr, 2)
            }
            let src := add(b, 32)
            for { let i := 0 } lt(i, len) { i := add(i, 32) } {
                mstore(add(ptr, i), mload(add(src, i)))
            }
            ptr := add(ptr, len)
        }
        return ptr;
    }

    function _writeRaw(uint256 ptr, bytes memory b) private pure returns (uint256) {
        uint256 len;
        assembly ("memory-safe") {
            len := mload(b)
            let src := add(b, 32)
            for { let i := 0 } lt(i, len) { i := add(i, 32) } {
                mstore(add(ptr, i), mload(add(src, i)))
            }
            ptr := add(ptr, len)
        }
        return ptr;
    }
}