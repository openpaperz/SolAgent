```solidity: LibRLP.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for RLP (Recursive Length Prefix) encoding.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibRLP.sol)
library LibRLP {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Defines a struct named `List` with a single field `_data`.
     *
     * @dev The `_data` field is a `uint256` value. The comment warns against modifying `_data` directly,
     * suggesting that it should be managed through specific functions or logic.
     */
    struct List {
        /// @dev Do not modify this directly.
        uint256 _data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ADDRESS COMPUTATION                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        /// @solidity memory-safe-assembly
        assembly {
            // If the nonce is in [0x00..0x7f].
            if iszero(gt(nonce, 0x7f)) {
                mstore(0x00, deployer)
                mstore8(0x0b, 0x94)
                mstore8(0x0a, 0xd6)
                mstore8(0x20, nonce)
                deployed := keccak256(0x0a, 0x17)
                leave
            }
            // For nonces greater than 0x7f, we need to encode the length.
            let i := 8
            for {} shr(i, nonce) { i := add(i, 8) } {}
            mstore(0x00, nonce)
            i := shr(3, i)
            mstore8(i, add(0x80, i))
            mstore(0x00, deployer)
            mstore8(0x0b, add(0x94, i))
            mstore8(0x0a, add(0xd6, i))
            deployed := keccak256(0x0a, add(0x16, i))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      LIST CONSTRUCTION                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
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
    function p(uint256 x) internal pure returns (List memory result) {
        result._data = x << 48;
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
            if shr(208, x) {
                let m := mload(0x40)
                mstore(m, x)
                mstore(0x40, add(m, 0x20))
                mstore(result, or(shl(208, 1), m))
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
    function p(address x) internal pure returns (List memory result) {
        result._data = uint256(uint160(x)) << 48;
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
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
    function p(bool x) internal pure returns (List memory result) {
        result._data = _boolToUint256(x) << 48;
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
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
    function p(bytes memory x) internal pure returns (List memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
            mstore(result, or(shl(208, 2), x))
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
    function p(List memory x) internal pure returns (List memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
            mstore(result, or(shl(208, 3), x))
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
    function p(List memory list, uint256 x) internal pure returns (List memory result) {
        result._data = x << 48;
        _updateTail(list, result);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
            if shr(208, x) {
                let m := mload(0x40)
                mstore(m, x)
                mstore(0x40, add(m, 0x20))
                mstore(result, or(shl(208, 1), m))
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
    function p(List memory list, address x) internal pure returns (List memory result) {
        result._data = uint256(uint160(x)) << 48;
        _updateTail(list, result);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
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
    function p(List memory list, bool x) internal pure returns (List memory result) {
        result._data = _boolToUint256(x) << 48;
        _updateTail(list, result);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
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
    function p(List memory list, bytes memory x) internal pure returns (List memory result) {
        _updateTail(list, result);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
            mstore(result, or(shl(208, 2), x))
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
    function p(List memory list, List memory x) internal pure returns (List memory result) {
        _updateTail(list, result);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x20))
            mstore(result, or(shl(208, 3), x))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         ENCODING                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        /// @solidity memory-safe-assembly
        assembly {
            function encodeUint(x_, o_) -> _o {
                _o := add(o_, 1)
                let n_ := iszero(x_)
                if iszero(or(gt(x_, 0x7f), n_)) {
                    mstore8(o_, x_)
                    leave
                }
                for { let i_ := 0xf8 } 1 { i_ := add(i_, 0xf8) } {
                    if iszero(shr(i_, x_)) {
                        i_ := shr(3, i_)
                        _o := add(o_, add(i_, 1))
                        mstore8(o_, add(0x80, i_))
                        mstore(add(o_, 1), shl(shl(3, sub(0x1f, i_)), x_))
                        break
                    }
                }
            }
            function encodeAddress(x_, o_) -> _o {
                _o := add(o_, 21)
                mstore8(o_, 0x94)
                mstore(add(o_, 1), shl(96, x_))
            }
            function encodeBytes(x_, o_) -> _o {
                let n_ := mload(x_)
                if iszero(gt(n_, 1)) {
                    if iszero(n_) {
                        mstore8(o_, 0x80)
                        _o := add(o_, 1)
                        leave
                    }
                    let b_ := byte(0, mload(add(x_, 0x20)))
                    if iszero(gt(b_, 0x7f)) {
                        mstore8(o_, b_)
                        _o := add(o_, 1)
                        leave
                    }
                }
                if iszero(gt(n_, 55)) {
                    mstore8(o_, add(0x80, n_))
                    mcopy(add(o_, 1), add(x_, 0x20), n_)
                    _o := add(add(o_, 1), n_)
                    leave
                }
                let i_ := 0xf8
                for {} 1 { i_ := add(i_, 0xf8) } {
                    if iszero(shr(i_, n_)) {
                        i_ := shr(3, i_)
                        mstore8(o_, add(0xb7, i_))
                        mstore(add(o_, 1), shl(shl(3, sub(0x1f, i_)), n_))
                        mcopy(add(add(o_, 1), i_), add(x_, 0x20), n_)
                        _o := add(add(add(o_, 1), i_), n_)
                        break
                    }
                }
            }
            function encodeList(l_, o_) -> _o {
                let c_ := l_
                for {} iszero(iszero(c_)) {} {
                    let t_ := shr(208, mload(c_))
                    let v_ := shr(48, shl(48, mload(c_)))
                    if iszero(t_) {
                        o_ := encodeUint(v_, o_)
                        c_ := mload(add(c_, 0x20))
                        continue
                    }
                    if eq(t_, 1) {
                        v_ := mload(v_)
                        o_ := encodeUint(v_, o_)
                        c_ := mload(add(c_, 0x20))
                        continue
                    }
                    if eq(t_, 2) {
                        o_ := encodeBytes(v_, o_)
                        c_ := mload(add(c_, 0x20))
                        continue
                    }
                    if eq(t_, 3) {
                        let m_ := mload(0x40)
                        mstore(0x40, add(m_, 0x40))
                        mstore(m_, o_)
                        mstore(add(m_, 0x20), c_)
                        o_ := encodeList(v_, add(o_, 1))
                        c_ := mload(add(m_, 0x20))
                        let n_ := sub(o_, mload(m_))
                        o_ := mload(m_)
                        mstore(0x40, m_)
                        if iszero(gt(n_, 55)) {
                            mstore8(o_, add(0xc0, n_))
                            o_ := add(o_, add(n_, 1))
                            c_ := mload(add(c_, 0x20))
                            continue
                        }
                        let d_ := add(o_, 1)
                        let x_ := n_
                        let i_ := 0xf8
                        for {} 1 { i_ := add(i_, 0xf8) } {
                            if iszero(shr(i_, x_)) {
                                i_ := shr(3, i_)
                                mstore8(o_, add(0xf7, i_))
                                mstore(add(o_, 1), shl(shl(3, sub(0x1f, i_)), x_))
                                d_ := add(d_, i_)
                                n_ := add(n_, add(i_, 1))
                                break
                            }
                        }
                        mcopy(d_, add(o_, 1), sub(o_, d_))
                        o_ := add(o_, n_)
                        c_ := mload(add(c_, 0x20))
                        continue
                    }
                    break
                }
                _o := o_
            }
            result := mload(0x40)
            let o_ := add(result, 0x20)
            o_ := encodeList(list, o_)
            let n_ := sub(o_, add(result, 0x20))
            mstore(result, n_)
            mstore(o_, 0)
            mstore(0x40, add(o_, 0x20))
        }
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
        return encode(p(x));
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
        return encode(p(x));
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
        return encode(p(x));
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
        return encode(p(x));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        /// @solidity memory-safe-assembly
        assembly {
            let t_ := list
            for {} iszero(iszero(mload(add(t_, 0x20)))) {} {
                t_ := mload(add(t_, 0x20))
            }
            mstore(add(t_, 0x20), result)
        }
    }

    /// @dev Helper function to convert bool to uint256.
    function _boolToUint256(bool x) private pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := x
        }
    }
}
```
