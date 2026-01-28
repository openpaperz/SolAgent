// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for working with transient storage slots using
/// the experimental `TLOAD` / `TSTORE` opcodes (EIP-1153 style).
library LibTransient {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /**
     * @notice A simple struct containing a single uint256 variable.
     *
     * @dev This struct is used as a placeholder or spacer, typically to align
     * storage or for testing purposes. It contains a single uint256 variable
     * named `_spacer`.
     */
    struct TUint256 {
        uint256 _spacer;
    }

    /**
     * @notice Defines a struct named `TInt256` with a single field `_spacer`
     * of type `uint256`.
     *
     * This struct is likely used as a placeholder or for alignment purposes in
     * the contract.
     */
    struct TInt256 {
        uint256 _spacer;
    }

    /**
     * @notice Defines a struct named `TBytes32` with a single field `_spacer`
     * of type `uint256`.
     *
     * This struct is likely used as a placeholder or spacer in memory or
     * storage to align data structures.
     */
    struct TBytes32 {
        uint256 _spacer;
    }

    /**
     * @notice Defines a simple struct named `TAddress` with a single field
     * `_spacer` of type `uint256`. This struct is likely used as a placeholder
     * or for alignment purposes in the contract.
     */
    struct TAddress {
        uint256 _spacer;
    }

    /**
     * @notice A struct representing a boolean value with a spacer to align
     * storage.
     *
     * @dev The `_spacer` field is used to ensure proper alignment in storage,
     * which can be important for gas optimization and avoiding storage
     * collisions.
     */
    struct TBool {
        uint256 _spacer;
    }

    /**
     * @notice A struct named `TBytes` with a single field `_spacer` of type
     * `uint256`.
     *
     * This struct is likely used as a placeholder or spacer in a contract to
     * align data or reserve space.
     */
    struct TBytes {
        uint256 _spacer;
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @dev Seed used for computing the compatibility slots.
    bytes32 private constant _TRANSIENT_COMPAT_SEED =
        0x8f2f5c41d632fc6be1f7d3a2e1b4c7a93e9b6d02fb3dfc4b5a96e2f90bdc001;

    // -------------------------------------------------------------------------
    // TUint256
    // -------------------------------------------------------------------------

    /**
     * @notice Returns a reference to a `TUint256` storage variable located at
     * the specified slot.
     */
    function tUint256(bytes32 tSlot) internal pure returns (TUint256 storage ptr) {
        assembly {
            sstore(ptr.slot, 0) // Silence unused slot warning.
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Returns a reference to a `TUint256` storage variable located at
     * the specified slot.
     */
    function tUint256(uint256 tSlot) internal pure returns (TUint256 storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves the value stored at the given `TUint256` pointer.
     */
    function get(TUint256 storage ptr) internal view returns (uint256 result) {
        assembly {
            result := tload(ptr.slot)
        }
    }

    /**
     * @notice Retrieves the compatibility-adjusted uint256 from transient
     * storage based on the current chain ID.
     */
    function getCompat(TUint256 storage ptr) internal view returns (uint256 result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return get(ptr);
        }
        TUint256 storage c = _compat(ptr);
        assembly {
            result := tload(c.slot)
        }
    }

    /**
     * @notice Sets the value of a TUint256 storage pointer to a specified value.
     */
    function set(TUint256 storage ptr, uint256 value) internal {
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /**
     * @notice Sets the value of a TUint256 storage pointer, with compatibility
     * handling for different chains.
     */
    function setCompat(TUint256 storage ptr, uint256 value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            set(ptr, value);
        } else {
            TUint256 storage c = _compat(ptr);
            assembly {
                tstore(c.slot, value)
            }
        }
    }

    /**
     * @notice Clears the value stored at the given storage pointer.
     */
    function clear(TUint256 storage ptr) internal {
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /**
     * @notice Clears the storage pointer `ptr` in a way that is compatible
     * with different chain IDs.
     */
    function clearCompat(TUint256 storage ptr) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            clear(ptr);
        } else {
            TUint256 storage c = _compat(ptr);
            assembly {
                tstore(c.slot, 0)
            }
        }
    }

    /**
     * @notice Increments the value stored at the given pointer by 1 and
     * returns the new value.
     */
    function inc(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = get(ptr) + 1;
        set(ptr, newValue);
    }

    /**
     * @notice Increments the value stored at the given pointer by 1 and
     * returns the new value (compat version).
     */
    function incCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) + 1;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Increments the value stored at the given pointer by `delta`
     * and returns the new value.
     */
    function inc(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = get(ptr) + delta;
        set(ptr, newValue);
    }

    /**
     * @notice Increments the value stored at the given pointer by `delta`
     * and returns the new value (compat version).
     */
    function incCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) + delta;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by 1 and
     * returns the new value.
     */
    function dec(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = get(ptr) - 1;
        set(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by 1 and
     * returns the new value (compat version).
     */
    function decCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) - 1;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by `delta`
     * and returns the new value.
     */
    function dec(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = get(ptr) - delta;
        set(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by `delta`
     * and returns the new value (compat version).
     */
    function decCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) - delta;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Increments a signed integer value stored in a `TUint256` storage
     * pointer by a specified delta.
     */
    function incSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        uint256 oldValue;
        assembly {
            oldValue := tload(ptr.slot)
        }
        unchecked {
            if (delta >= 0) {
                newValue = oldValue + uint256(delta);
                if (newValue < oldValue) _panic();
            } else {
                uint256 abs = uint256(-delta);
                newValue = oldValue - abs;
                if (newValue > oldValue) _panic();
            }
        }
        assembly {
            tstore(ptr.slot, newValue)
        }
    }

    /**
     * @notice Increments a signed integer value stored at a given storage
     * pointer by a specified delta (compat version).
     */
    function incSignedCompat(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return incSigned(ptr, delta);
        }
        TUint256 storage c = _compat(ptr);
        uint256 oldValue;
        assembly {
            oldValue := tload(c.slot)
        }
        unchecked {
            if (delta >= 0) {
                newValue = oldValue + uint256(delta);
                if (newValue < oldValue) _panic();
            } else {
                uint256 abs = uint256(-delta);
                newValue = oldValue - abs;
                if (newValue > oldValue) _panic();
            }
        }
        assembly {
            tstore(c.slot, newValue)
        }
    }

    /**
     * @notice Decrements a signed integer value from a storage pointer and
     * returns the new value.
     */
    function decSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        uint256 oldValue;
        assembly {
            oldValue := tload(ptr.slot)
        }
        unchecked {
            if (delta >= 0) {
                uint256 abs = uint256(delta);
                newValue = oldValue - abs;
                if (newValue > oldValue) _panic();
            } else {
                uint256 abs = uint256(-delta);
                newValue = oldValue + abs;
                if (newValue < oldValue) _panic();
            }
        }
        assembly {
            tstore(ptr.slot, newValue)
        }
    }

    /**
     * @notice Decreases the value stored at the given pointer by a signed
     * delta, with compatibility checks.
     */
    function decSignedCompat(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return decSigned(ptr, delta);
        }
        TUint256 storage c = _compat(ptr);
        uint256 oldValue;
        assembly {
            oldValue := tload(c.slot)
        }
        unchecked {
            if (delta >= 0) {
                uint256 abs = uint256(delta);
                newValue = oldValue - abs;
                if (newValue > oldValue) _panic();
            } else {
                uint256 abs = uint256(-delta);
                newValue = oldValue + abs;
                if (newValue < oldValue) _panic();
            }
        }
        assembly {
            tstore(c.slot, newValue)
        }
    }

    // -------------------------------------------------------------------------
    // TInt256
    // -------------------------------------------------------------------------

    /**
     * @notice Returns a storage pointer to a `TInt256` type located at the
     * specified storage slot.
     */
    function tInt256(bytes32 tSlot) internal pure returns (TInt256 storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Returns a storage pointer to a `TInt256` type located at the
     * specified storage slot.
     */
    function tInt256(uint256 tSlot) internal pure returns (TInt256 storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves the value stored at the given `TInt256` pointer.
     */
    function get(TInt256 storage ptr) internal view returns (int256 result) {
        assembly {
            result := tload(ptr.slot)
        }
    }

    /**
     * @notice Retrieves the compatibility-adjusted int256 from storage based
     * on the current chain ID.
     */
    function getCompat(TInt256 storage ptr) internal view returns (int256 result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return get(ptr);
        }
        TInt256 storage c = _compat(ptr);
        assembly {
            result := tload(c.slot)
        }
    }

    /**
     * @notice Sets the value of a TInt256 storage pointer to a specified value.
     */
    function set(TInt256 storage ptr, int256 value) internal {
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /**
     * @notice Sets the value of a TInt256 storage pointer, with compatibility
     * handling for different chains.
     */
    function setCompat(TInt256 storage ptr, int256 value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            set(ptr, value);
        } else {
            TInt256 storage c = _compat(ptr);
            assembly {
                tstore(c.slot, value)
            }
        }
    }

    /**
     * @notice Clears the value stored at the given TInt256 storage pointer.
     */
    function clear(TInt256 storage ptr) internal {
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /**
     * @notice Clears the storage pointer `ptr` in a way that is compatible
     * with different chain IDs.
     */
    function clearCompat(TInt256 storage ptr) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            clear(ptr);
        } else {
            TInt256 storage c = _compat(ptr);
            assembly {
                tstore(c.slot, 0)
            }
        }
    }

    /**
     * @notice Increments the value stored at the given pointer by 1 and
     * returns the new value.
     */
    function inc(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = get(ptr) + 1;
        set(ptr, newValue);
    }

    /**
     * @notice Increments the value stored at the given pointer by 1 and
     * returns the new value (compat version).
     */
    function incCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = getCompat(ptr) + 1;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Increments the value stored at the given pointer by `delta`
     * and returns the new value.
     */
    function inc(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = get(ptr) + delta;
        set(ptr, newValue);
    }

    /**
     * @notice Increments the value stored at the given pointer by `delta`
     * and returns the new value (compat version).
     */
    function incCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = getCompat(ptr) + delta;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by 1 and
     * returns the new value.
     */
    function dec(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = get(ptr) - 1;
        set(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by 1 and
     * returns the new value (compat version).
     */
    function decCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = getCompat(ptr) - 1;
        setCompat(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by `delta`
     * and returns the new value.
     */
    function dec(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = get(ptr) - delta;
        set(ptr, newValue);
    }

    /**
     * @notice Decrements the value stored at the given pointer by `delta`
     * and returns the new value (compat version).
     */
    function decCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = getCompat(ptr) - delta;
        setCompat(ptr, newValue);
    }

    // -------------------------------------------------------------------------
    // TBytes32
    // -------------------------------------------------------------------------

    /**
     * @notice Returns a storage pointer to a `TBytes32` struct located at the
     * specified storage slot.
     */
    function tBytes32(bytes32 tSlot) internal pure returns (TBytes32 storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Returns a storage pointer to a `TBytes32` struct located at the
     * specified storage slot.
     */
    function tBytes32(uint256 tSlot) internal pure returns (TBytes32 storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves the value stored at the given `TBytes32` pointer.
     */
    function get(TBytes32 storage ptr) internal view returns (bytes32 result) {
        assembly {
            result := tload(ptr.slot)
        }
    }

    /**
     * @notice Retrieves the compatibility-adjusted bytes32 from storage based
     * on the current chain ID.
     */
    function getCompat(TBytes32 storage ptr) internal view returns (bytes32 result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return get(ptr);
        }
        TBytes32 storage c = _compat(ptr);
        assembly {
            result := tload(c.slot)
        }
    }

    /**
     * @notice Sets the value of a TBytes32 storage pointer to a specified
     * value.
     */
    function set(TBytes32 storage ptr, bytes32 value) internal {
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /**
     * @notice Sets the value of a TBytes32 storage pointer, with compatibility
     * handling for different chains.
     */
    function setCompat(TBytes32 storage ptr, bytes32 value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            set(ptr, value);
        } else {
            TBytes32 storage c = _compat(ptr);
            assembly {
                tstore(c.slot, value)
            }
        }
    }

    /**
     * @notice Clears the value stored at the given TBytes32 storage pointer.
     */
    function clear(TBytes32 storage ptr) internal {
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /**
     * @notice Clears the storage pointer `ptr` for TBytes32, compat version.
     */
    function clearCompat(TBytes32 storage ptr) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            clear(ptr);
        } else {
            TBytes32 storage c = _compat(ptr);
            assembly {
                tstore(c.slot, 0)
            }
        }
    }

    // -------------------------------------------------------------------------
    // TAddress
    // -------------------------------------------------------------------------

    /**
     * @notice Retrieves a storage pointer to a `TAddress` struct located at a
     * specific storage slot.
     */
    function tAddress(bytes32 tSlot) internal pure returns (TAddress storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves a storage pointer to a `TAddress` struct located at a
     * specific storage slot.
     */
    function tAddress(uint256 tSlot) internal pure returns (TAddress storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves the value stored at the given `TAddress` pointer.
     */
    function get(TAddress storage ptr) internal view returns (address result) {
        assembly {
            result := tload(ptr.slot)
        }
    }

    /**
     * @notice Retrieves the compatibility-adjusted address from storage based
     * on the current chain ID.
     */
    function getCompat(TAddress storage ptr) internal view returns (address result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return get(ptr);
        }
        TAddress storage c = _compat(ptr);
        assembly {
            result := tload(c.slot)
        }
    }

    /**
     * @notice Sets the value of a TAddress storage pointer to a specified
     * value.
     */
    function set(TAddress storage ptr, address value) internal {
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /**
     * @notice Sets the value of a TAddress storage pointer, with
     * compatibility handling for different chains.
     */
    function setCompat(TAddress storage ptr, address value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            set(ptr, value);
        } else {
            TAddress storage c = _compat(ptr);
            assembly {
                tstore(c.slot, value)
            }
        }
    }

    /**
     * @notice Clears the value stored at the given TAddress storage pointer.
     */
    function clear(TAddress storage ptr) internal {
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /**
     * @notice Clears the storage pointer `ptr` for TAddress, compat version.
     */
    function clearCompat(TAddress storage ptr) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            clear(ptr);
        } else {
            TAddress storage c = _compat(ptr);
            assembly {
                tstore(c.slot, 0)
            }
        }
    }

    // -------------------------------------------------------------------------
    // TBool
    // -------------------------------------------------------------------------

    /**
     * @notice Retrieves a `TBool` storage pointer from a given storage slot.
     */
    function tBool(bytes32 tSlot) internal pure returns (TBool storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves a `TBool` storage pointer from a given storage slot.
     */
    function tBool(uint256 tSlot) internal pure returns (TBool storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Retrieves the value stored at the given `TBool` pointer.
     */
    function get(TBool storage ptr) internal view returns (bool result) {
        assembly {
            result := iszero(iszero(tload(ptr.slot)))
        }
    }

    /**
     * @notice Retrieves the compatibility-adjusted bool from storage based on
     * the current chain ID.
     */
    function getCompat(TBool storage ptr) internal view returns (bool result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return get(ptr);
        }
        TBool storage c = _compat(ptr);
        assembly {
            result := iszero(iszero(tload(c.slot)))
        }
    }

    /**
     * @notice Sets the value of a TBool storage pointer to a specified value.
     */
    function set(TBool storage ptr, bool value) internal {
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /**
     * @notice Sets the value of a TBool storage pointer, with compatibility
     * handling for different chains.
     */
    function setCompat(TBool storage ptr, bool value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            set(ptr, value);
        } else {
            TBool storage c = _compat(ptr);
            assembly {
                tstore(c.slot, value)
            }
        }
    }

    /**
     * @notice Clears the value stored at the given TBool storage pointer.
     */
    function clear(TBool storage ptr) internal {
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /**
     * @notice Clears the storage pointer `ptr` for TBool, compat version.
     */
    function clearCompat(TBool storage ptr) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            clear(ptr);
        } else {
            TBool storage c = _compat(ptr);
            assembly {
                tstore(c.slot, 0)
            }
        }
    }

    // -------------------------------------------------------------------------
    // TBytes
    // -------------------------------------------------------------------------

    /**
     * @notice Returns a storage pointer to a `TBytes` struct located at the
     * specified storage slot.
     */
    function tBytes(bytes32 tSlot) internal pure returns (TBytes storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Returns a storage pointer to a `TBytes` struct located at the
     * specified storage slot.
     */
    function tBytes(uint256 tSlot) internal pure returns (TBytes storage ptr) {
        assembly {
            sstore(ptr.slot, 0)
            ptr.slot := tSlot
        }
    }

    /**
     * @notice Returns the length of the byte array stored in the given
     * storage pointer.
     */
    function length(TBytes storage ptr) internal view returns (uint256 result) {
        assembly {
            let packed := tload(ptr.slot)
            result := shr(224, packed)
        }
    }

    /**
     * @notice Returns the length of a byte array stored in a `TBytes` struct,
     * with compatibility handling for different chains.
     */
    function lengthCompat(TBytes storage ptr) internal view returns (uint256 result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return length(ptr);
        }
        TBytes storage c = _compat(ptr);
        assembly {
            let packed := tload(c.slot)
            result := shr(224, packed)
        }
    }

    /**
     * @notice Retrieves the value stored at the given `TBytes` pointer.
     *
     * Layout (packed in first word):
     * - upper 32 bits: length (uint32)
     * - lower 224 bits: first up to 29 bytes of data
     * - if length >= 29, remaining bytes are stored in subsequent words:
     *   data word offset = keccak256(slot) + i
     */
    function get(TBytes storage ptr) internal view returns (bytes memory result) {
        assembly {
            let head := tload(ptr.slot)
            let len := shr(224, head)
            result := mload(0x40)
            mstore(result, len)

            let dataPtr := add(result, 0x20)
            // Copy first 29 bytes from head (lower 232 bits, but we use 224).
            // We shift left so that the least significant 29 bytes end up
            // left-aligned then stored; consumers read as usual.
            if lt(len, 0x1d) {
                // len < 29, everything is in head
                // shift left to align
                let first := shl(32, head)
                mstore(dataPtr, first)
            }
            if iszero(lt(len, 0x1d)) {
                // len >= 29
                let first := shl(32, head)
                mstore(dataPtr, first)
                let offset := add(dataPtr, 0x1d)
                let end := add(dataPtr, len)
                // load tail from subsequent slots
                let h := keccak256(ptr.slot, 0x20)
                for { } lt(offset, end) { } {
                    let word := tload(h)
                    mstore(offset, word)
                    offset := add(offset, 0x20)
                    h := add(h, 1)
                }
            }
            // update free memory pointer
            mstore(0x40, add(dataPtr, and(add(len, 0x3f), not(0x1f))))
        }
    }

    /**
     * @notice Retrieves the compatibility-adjusted bytes from storage based on
     * the current chain ID.
     */
    function getCompat(TBytes storage ptr) internal view returns (bytes memory result) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            return get(ptr);
        }
        TBytes storage c = _compat(ptr);
        assembly {
            let head := tload(c.slot)
            let len := shr(224, head)
            result := mload(0x40)
            mstore(result, len)

            let dataPtr := add(result, 0x20)
            if lt(len, 0x1d) {
                let first := shl(32, head)
                mstore(dataPtr, first)
            }
            if iszero(lt(len, 0x1d)) {
                let first := shl(32, head)
                mstore(dataPtr, first)
                let offset := add(dataPtr, 0x1d)
                let end := add(dataPtr, len)
                let h := keccak256(c.slot, 0x20)
                for { } lt(offset, end) { } {
                    let word := tload(h)
                    mstore(offset, word)
                    offset := add(offset, 0x20)
                    h := add(h, 1)
                }
            }
            mstore(0x40, add(dataPtr, and(add(len, 0x3f), not(0x1f))))
        }
    }

    /**
     * @notice Sets the value of a TBytes storage pointer to a specified value.
     */
    function set(TBytes storage ptr, bytes memory value) internal {
        assembly {
            let len := mload(value)
            // first word to store: len in upper 32 bits, first up to 29 bytes in lower bits
            let dataPtr := add(value, 0x20)
            let first := mload(dataPtr)

            // pack len in upper 32 bits
            let packed := or(shl(224, len), shr(32, first))
            tstore(ptr.slot, packed)

            // store tail if len >= 29
            if iszero(lt(len, 0x1d)) {
                let offset := add(dataPtr, 0x1d)
                let end := add(dataPtr, len)
                let h := keccak256(ptr.slot, 0x20)
                for { } lt(offset, end) { } {
                    let word := mload(offset)
                    tstore(h, word)
                    offset := add(offset, 0x20)
                    h := add(h, 1)
                }
            }
        }
    }

    /**
     * @notice Sets the value of a TBytes storage pointer, with compatibility
     * handling for different chains.
     */
    function setCompat(TBytes storage ptr, bytes memory value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            set(ptr, value);
            return;
        }
        TBytes storage c = _compat(ptr);
        assembly {
            let len := mload(value)
            let dataPtr := add(value, 0x20)
            let first := mload(dataPtr)
            let packed := or(shl(224, len), shr(32, first))
            tstore(c.slot, packed)
            if iszero(lt(len, 0x1d)) {
                let offset := add(dataPtr, 0x1d)
                let end := add(dataPtr, len)
                let h := keccak256(c.slot, 0x20)
                for { } lt(offset, end) { } {
                    let word := mload(offset)
                    tstore(h, word)
                    offset := add(offset, 0x20)
                    h := add(h, 1)
                }
            }
        }
    }

    /**
     * @notice Sets the calldata for a TBytes storage pointer.
     */
    function setCalldata(TBytes storage ptr, bytes calldata value) internal {
        assembly {
            let len := value.length
            let dataPtr := value.offset
            let first := calldataload(dataPtr)
            let packed := or(shl(224, len), shr(32, first))
            tstore(ptr.slot, packed)
            if iszero(lt(len, 0x1d)) {
                let offset := add(dataPtr, 0x1d)
                let end := add(dataPtr, len)
                let h := keccak256(ptr.slot, 0x20)
                for { } lt(offset, end) { } {
                    let word := calldataload(offset)
                    tstore(h, word)
                    offset := add(offset, 0x20)
                    h := add(h, 1)
                }
            }
        }
    }

    /**
     * @notice Sets the calldata compatibility for a given TBytes storage
     * pointer.
     */
    function setCalldataCompat(TBytes storage ptr, bytes calldata value) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            setCalldata(ptr, value);
            return;
        }
        TBytes storage c = _compat(ptr);
        assembly {
            let len := value.length
            let dataPtr := value.offset
            let first := calldataload(dataPtr)
            let packed := or(shl(224, len), shr(32, first))
            tstore(c.slot, packed)
            if iszero(lt(len, 0x1d)) {
                let offset := add(dataPtr, 0x1d)
                let end := add(dataPtr, len)
                let h := keccak256(c.slot, 0x20)
                for { } lt(offset, end) { } {
                    let word := calldataload(offset)
                    tstore(h, word)
                    offset := add(offset, 0x20)
                    h := add(h, 1)
                }
            }
        }
    }

    /**
     * @notice Clears the value stored at the given TBytes storage pointer.
     */
    function clear(TBytes storage ptr) internal {
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /**
     * @notice Clears the storage pointer `ptr` in a way that is compatible
     * with different chain IDs.
     */
    function clearCompat(TBytes storage ptr) internal {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 1) {
            clear(ptr);
        } else {
            TBytes storage c = _compat(ptr);
            assembly {
                tstore(c.slot, 0)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Compat slot mapping helpers
    // -------------------------------------------------------------------------

    /**
     * @notice Converts a TUint256 storage pointer to a compatible format
     * using inline assembly.
     */
    function _compat(TUint256 storage ptr) private pure returns (TUint256 storage c) {
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, _TRANSIENT_COMPAT_SEED)
            c.slot := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Converts a TInt256 storage pointer to a compatible format
     * using inline assembly.
     */
    function _compat(TInt256 storage ptr) private pure returns (TInt256 storage c) {
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, _TRANSIENT_COMPAT_SEED)
            c.slot := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Converts a TBytes32 storage pointer to a compatible format
     * using inline assembly.
     */
    function _compat(TBytes32 storage ptr) private pure returns (TBytes32 storage c) {
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, _TRANSIENT_COMPAT_SEED)
            c.slot := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Converts a TAddress storage pointer to a compatible format
     * using inline assembly.
     */
    function _compat(TAddress storage ptr) private pure returns (TAddress storage c) {
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, _TRANSIENT_COMPAT_SEED)
            c.slot := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Converts a TBool storage pointer to a compatible format using
     * inline assembly.
     */
    function _compat(TBool storage ptr) private pure returns (TBool storage c) {
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, _TRANSIENT_COMPAT_SEED)
            c.slot := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Converts a TBytes storage pointer to a compatible format using
     * inline assembly.
     */
    function _compat(TBytes storage ptr) private pure returns (TBytes storage c) {
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, _TRANSIENT_COMPAT_SEED)
            c.slot := keccak256(0x00, 0x40)
        }
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /// @dev Revert with a panic code 0x11 (arithmetic overflow/underflow).
    function _panic() private pure {
        assembly {
            mstore(0x00, 0x4e487b71) // Panic selector.
            mstore(0x04, 0x11)      // Overflow/underflow.
            revert(0x00, 0x24)
        }
    }
}