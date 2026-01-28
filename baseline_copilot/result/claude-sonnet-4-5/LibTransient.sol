// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for transient storage operations with compatibility support.
library LibTransient {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice A simple struct containing a single uint256 variable.
    /// @dev This struct is used as a placeholder or spacer, typically to align storage or for testing purposes.
    /// It contains a single uint256 variable named `_spacer`.
    struct TUint256 {
        uint256 _spacer;
    }

    /// @notice Defines a struct named `TInt256` with a single field `_spacer` of type `uint256`.
    /// This struct is likely used as a placeholder or for alignment purposes in the contract.
    struct TInt256 {
        uint256 _spacer;
    }

    /// @notice Defines a struct named `TBytes32` with a single field `_spacer` of type `uint256`.
    /// This struct is likely used as a placeholder or spacer in memory or storage to align data structures.
    struct TBytes32 {
        uint256 _spacer;
    }

    /// @notice Defines a simple struct named `TAddress` with a single field `_spacer` of type `uint256`.
    /// This struct is likely used as a placeholder or for alignment purposes in the contract.
    struct TAddress {
        uint256 _spacer;
    }

    /// @notice A struct representing a boolean value with a spacer to align storage.
    /// @dev The `_spacer` field is used to ensure proper alignment in storage, which can be important for gas optimization and avoiding storage collisions.
    struct TBool {
        uint256 _spacer;
    }

    /// @notice A struct named `TBytes` with a single field `_spacer` of type `uint256`.
    /// This struct is likely used as a placeholder or spacer in a contract to align data or reserve space.
    struct TBytes {
        uint256 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The transient compatibility slot seed.
    uint256 private constant _COMPAT_SLOT_SEED = 0x8b4e1f3fb191b94ec8c4c5cfedb1b9f3bf5b5e5e;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    TUINT256 OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns a reference to a `TUint256` storage variable located at the specified slot.
    function tUint256(bytes32 tSlot) internal pure returns (TUint256 storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Returns a reference to a `TUint256` storage variable located at the specified slot.
    function tUint256(uint256 tSlot) internal pure returns (TUint256 storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves the value stored at the given `TUint256` pointer.
    function get(TUint256 storage ptr) internal view returns (uint256 result) {
        assembly ("memory-safe") {
            result := tload(ptr.slot)
        }
    }

    /// @notice Retrieves the compatibility-adjusted value from storage based on the current chain ID.
    function getCompat(TUint256 storage ptr) internal view returns (uint256 result) {
        if (block.chainid == 1) return get(ptr);
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            result := sload(keccak256(0x00, 0x24))
        }
    }

    /// @notice Sets the value of a TUint256 storage pointer to a specified value.
    function set(TUint256 storage ptr, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, value)
        }
    }

    /// @notice Sets the value of a TUint256 storage pointer, with compatibility handling for different chains.
    function setCompat(TUint256 storage ptr, uint256 value) internal {
        if (block.chainid == 1) {
            set(ptr, value);
        } else {
            _compat(ptr)._spacer = value;
        }
    }

    /// @notice Clears the value stored at the given storage pointer.
    function clear(TUint256 storage ptr) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, 0)
        }
    }

    /// @notice Clears the storage pointer `ptr` in a way that is compatible with different chain IDs.
    function clearCompat(TUint256 storage ptr) internal {
        if (block.chainid == 1) {
            clear(ptr);
        } else {
            _compat(ptr)._spacer = 0;
        }
    }

    /// @notice Increments the value stored at the given pointer by 1 and returns the new value.
    function inc(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = get(ptr) + 1;
        set(ptr, newValue);
    }

    /// @notice Increments the value stored at the given pointer by 1 and returns the new value.
    function incCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) + 1;
        setCompat(ptr, newValue);
    }

    /// @notice Increments the value stored at the given pointer by delta and returns the new value.
    function inc(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = get(ptr) + delta;
        set(ptr, newValue);
    }

    /// @notice Increments the value stored at the given pointer by delta and returns the new value.
    function incCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) + delta;
        setCompat(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by 1 and returns the new value.
    function dec(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = get(ptr) - 1;
        set(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by 1 and returns the new value.
    function decCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) - 1;
        setCompat(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by delta and returns the new value.
    function dec(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = get(ptr) - delta;
        set(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by delta and returns the new value.
    function decCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) - delta;
        setCompat(ptr, newValue);
    }

    /// @notice Increments a signed integer value stored in a `TUint256` storage pointer by a specified delta.
    function incSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        assembly ("memory-safe") {
            let currentValue := tload(ptr.slot)
            newValue := add(currentValue, delta)
            if or(and(lt(newValue, currentValue), sgt(delta, 0)), and(gt(newValue, currentValue), slt(delta, 0))) {
                mstore(0x00, 0x4e487b71)
                mstore(0x04, 0x11)
                revert(0x1c, 0x24)
            }
            tstore(ptr.slot, newValue)
        }
    }

    /// @notice Increments a signed integer value stored at a given storage pointer by a specified delta.
    function incSignedCompat(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        if (block.chainid == 1) return incSigned(ptr, delta);
        TUint256 storage c = _compat(ptr);
        assembly ("memory-safe") {
            let currentValue := sload(c.slot)
            newValue := add(currentValue, delta)
            if or(and(lt(newValue, currentValue), sgt(delta, 0)), and(gt(newValue, currentValue), slt(delta, 0))) {
                mstore(0x00, 0x4e487b71)
                mstore(0x04, 0x11)
                revert(0x1c, 0x24)
            }
            sstore(c.slot, newValue)
        }
    }

    /// @notice Decrements a signed integer value from a storage pointer and returns the new value.
    function decSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        assembly ("memory-safe") {
            let currentValue := tload(ptr.slot)
            newValue := sub(currentValue, delta)
            if or(and(lt(newValue, currentValue), sgt(delta, 0)), and(gt(newValue, currentValue), slt(delta, 0))) {
                mstore(0x00, 0x4e487b71)
                mstore(0x04, 0x11)
                revert(0x1c, 0x24)
            }
            tstore(ptr.slot, newValue)
        }
    }

    /// @notice Decreases the value stored at the given pointer by a signed delta, with compatibility checks.
    function decSignedCompat(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        if (block.chainid == 1) return decSigned(ptr, delta);
        TUint256 storage c = _compat(ptr);
        assembly ("memory-safe") {
            let currentValue := sload(c.slot)
            newValue := sub(currentValue, delta)
            if or(and(lt(newValue, currentValue), sgt(delta, 0)), and(gt(newValue, currentValue), slt(delta, 0))) {
                mstore(0x00, 0x4e487b71)
                mstore(0x04, 0x11)
                revert(0x1c, 0x24)
            }
            sstore(c.slot, newValue)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    TINT256 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns a storage pointer to a `TInt256` type located at the specified storage slot.
    function tInt256(bytes32 tSlot) internal pure returns (TInt256 storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Returns a storage pointer to a `TInt256` type located at the specified storage slot.
    function tInt256(uint256 tSlot) internal pure returns (TInt256 storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves the value stored at the given `TInt256` pointer.
    function get(TInt256 storage ptr) internal view returns (int256 result) {
        assembly ("memory-safe") {
            result := tload(ptr.slot)
        }
    }

    /// @notice Retrieves the compatibility-adjusted value from storage based on the current chain ID.
    function getCompat(TInt256 storage ptr) internal view returns (int256 result) {
        if (block.chainid == 1) return get(ptr);
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            result := sload(keccak256(0x00, 0x24))
        }
    }

    /// @notice Sets the value of a TInt256 storage pointer to a specified value.
    function set(TInt256 storage ptr, int256 value) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, value)
        }
    }

    /// @notice Sets the value of a TInt256 storage pointer, with compatibility handling for different chains.
    function setCompat(TInt256 storage ptr, int256 value) internal {
        if (block.chainid == 1) {
            set(ptr, value);
        } else {
            _compat(ptr)._spacer = uint256(value);
        }
    }

    /// @notice Clears the value stored at the given storage pointer.
    function clear(TInt256 storage ptr) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, 0)
        }
    }

    /// @notice Clears the storage pointer `ptr` in a way that is compatible with different chain IDs.
    function clearCompat(TInt256 storage ptr) internal {
        if (block.chainid == 1) {
            clear(ptr);
        } else {
            _compat(ptr)._spacer = 0;
        }
    }

    /// @notice Increments the value stored at the given pointer by 1 and returns the new value.
    function inc(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = get(ptr) + 1;
        set(ptr, newValue);
    }

    /// @notice Increments the value stored at the given pointer by 1 and returns the new value.
    function incCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = getCompat(ptr) + 1;
        setCompat(ptr, newValue);
    }

    /// @notice Increments the value stored at the given pointer by delta and returns the new value.
    function inc(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = get(ptr) + delta;
        set(ptr, newValue);
    }

    /// @notice Increments the value stored at the given pointer by delta and returns the new value.
    function incCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = getCompat(ptr) + delta;
        setCompat(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by 1 and returns the new value.
    function dec(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = get(ptr) - 1;
        set(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by 1 and returns the new value.
    function decCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = getCompat(ptr) - 1;
        setCompat(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by delta and returns the new value.
    function dec(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = get(ptr) - delta;
        set(ptr, newValue);
    }

    /// @notice Decrements the value stored at the given pointer by delta and returns the new value.
    function decCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = getCompat(ptr) - delta;
        setCompat(ptr, newValue);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   TBYTES32 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns a storage pointer to a `TBytes32` struct located at the specified storage slot.
    function tBytes32(bytes32 tSlot) internal pure returns (TBytes32 storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Returns a storage pointer to a `TBytes32` struct located at the specified storage slot.
    function tBytes32(uint256 tSlot) internal pure returns (TBytes32 storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves the value stored at the given `TBytes32` pointer.
    function get(TBytes32 storage ptr) internal view returns (bytes32 result) {
        assembly ("memory-safe") {
            result := tload(ptr.slot)
        }
    }

    /// @notice Retrieves the compatibility-adjusted value from storage based on the current chain ID.
    function getCompat(TBytes32 storage ptr) internal view returns (bytes32 result) {
        if (block.chainid == 1) return get(ptr);
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            result := sload(keccak256(0x00, 0x24))
        }
    }

    /// @notice Sets the value of a TBytes32 storage pointer to a specified value.
    function set(TBytes32 storage ptr, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, value)
        }
    }

    /// @notice Sets the value of a TBytes32 storage pointer, with compatibility handling for different chains.
    function setCompat(TBytes32 storage ptr, bytes32 value) internal {
        if (block.chainid == 1) {
            set(ptr, value);
        } else {
            _compat(ptr)._spacer = uint256(value);
        }
    }

    /// @notice Clears the value stored at the given storage pointer.
    function clear(TBytes32 storage ptr) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, 0)
        }
    }

    /// @notice Clears the storage pointer `ptr` in a way that is compatible with different chain IDs.
    function clearCompat(TBytes32 storage ptr) internal {
        if (block.chainid == 1) {
            clear(ptr);
        } else {
            _compat(ptr)._spacer = 0;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   TADDRESS OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Retrieves a storage pointer to a `TAddress` struct located at a specific storage slot.
    function tAddress(bytes32 tSlot) internal pure returns (TAddress storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves a storage pointer to a `TAddress` struct located at a specific storage slot.
    function tAddress(uint256 tSlot) internal pure returns (TAddress storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves the value stored at the given `TAddress` pointer.
    function get(TAddress storage ptr) internal view returns (address result) {
        assembly ("memory-safe") {
            result := tload(ptr.slot)
        }
    }

    /// @notice Retrieves the compatibility-adjusted value from storage based on the current chain ID.
    function getCompat(TAddress storage ptr) internal view returns (address result) {
        if (block.chainid == 1) return get(ptr);
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            result := sload(keccak256(0x00, 0x24))
        }
    }

    /// @notice Sets the value of a TAddress storage pointer to a specified value.
    function set(TAddress storage ptr, address value) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, value)
        }
    }

    /// @notice Sets the value of a TAddress storage pointer, with compatibility handling for different chains.
    function setCompat(TAddress storage ptr, address value) internal {
        if (block.chainid == 1) {
            set(ptr, value);
        } else {
            _compat(ptr)._spacer = uint256(uint160(value));
        }
    }

    /// @notice Clears the value stored at the given storage pointer.
    function clear(TAddress storage ptr) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, 0)
        }
    }

    /// @notice Clears the storage pointer `ptr` in a way that is compatible with different chain IDs.
    function clearCompat(TAddress storage ptr) internal {
        if (block.chainid == 1) {
            clear(ptr);
        } else {
            _compat(ptr)._spacer = 0;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     TBOOL OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Retrieves a `TBool` storage pointer from a given storage slot.
    function tBool(bytes32 tSlot) internal pure returns (TBool storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves a `TBool` storage pointer from a given storage slot.
    function tBool(uint256 tSlot) internal pure returns (TBool storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Retrieves the value stored at the given `TBool` pointer.
    function get(TBool storage ptr) internal view returns (bool result) {
        assembly ("memory-safe") {
            result := tload(ptr.slot)
        }
    }

    /// @notice Retrieves the compatibility-adjusted value from storage based on the current chain ID.
    function getCompat(TBool storage ptr) internal view returns (bool result) {
        if (block.chainid == 1) return get(ptr);
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            result := sload(keccak256(0x00, 0x24))
        }
    }

    /// @notice Sets the value of a TBool storage pointer to a specified value.
    function set(TBool storage ptr, bool value) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, value)
        }
    }

    /// @notice Sets the value of a TBool storage pointer, with compatibility handling for different chains.
    function setCompat(TBool storage ptr, bool value) internal {
        if (block.chainid == 1) {
            set(ptr, value);
        } else {
            _compat(ptr)._spacer = value ? 1 : 0;
        }
    }

    /// @notice Clears the value stored at the given storage pointer.
    function clear(TBool storage ptr) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, 0)
        }
    }

    /// @notice Clears the storage pointer `ptr` in a way that is compatible with different chain IDs.
    function clearCompat(TBool storage ptr) internal {
        if (block.chainid == 1) {
            clear(ptr);
        } else {
            _compat(ptr)._spacer = 0;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    TBYTES OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns a storage pointer to a `TBytes` struct located at the specified storage slot.
    function tBytes(bytes32 tSlot) internal pure returns (TBytes storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Returns a storage pointer to a `TBytes` struct located at the specified storage slot.
    function tBytes(uint256 tSlot) internal pure returns (TBytes storage ptr) {
        assembly ("memory-safe") {
            ptr.slot := tSlot
        }
    }

    /// @notice Returns the length of the byte array stored in the given storage pointer.
    function length(TBytes storage ptr) internal view returns (uint256 result) {
        assembly ("memory-safe") {
            result := shr(224, tload(ptr.slot))
        }
    }

    /// @notice Returns the length of a byte array stored in a `TBytes` struct, with compatibility handling for different chains.
    function lengthCompat(TBytes storage ptr) internal view returns (uint256 result) {
        if (block.chainid == 1) return length(ptr);
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            result := shr(224, sload(keccak256(0x00, 0x24)))
        }
    }

    /// @notice Retrieves the value stored at the given `TBytes` pointer.
    function get(TBytes storage ptr) internal view returns (bytes memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            let data := tload(ptr.slot)
            let len := shr(224, data)
            mstore(result, len)
            mstore(add(result, 0x20), shl(32, data))
            let end := add(add(result, 0x20), len)
            if iszero(lt(len, 0x1d)) {
                let dataSlot := add(ptr.slot, 1)
                for { let i := add(result, 0x3c) } lt(i, end) { i := add(i, 0x20) } {
                    mstore(i, tload(dataSlot))
                    dataSlot := add(dataSlot, 1)
                }
            }
            mstore(end, 0)
            mstore(0x40, and(add(end, 0x3f), not(0x1f)))
        }
    }

    /// @notice Retrieves the compatibility-adjusted bytes from storage based on the current chain ID.
    function getCompat(TBytes storage ptr) internal view returns (bytes memory result) {
        if (block.chainid == 1) return get(ptr);
        TBytes storage c = _compat(ptr);
        assembly ("memory-safe") {
            result := mload(0x40)
            let data := sload(c.slot)
            let len := shr(224, data)
            mstore(result, len)
            mstore(add(result, 0x20), shl(32, data))
            let end := add(add(result, 0x20), len)
            if iszero(lt(len, 0x1d)) {
                let dataSlot := add(c.slot, 1)
                for { let i := add(result, 0x3c) } lt(i, end) { i := add(i, 0x20) } {
                    mstore(i, sload(dataSlot))
                    dataSlot := add(dataSlot, 1)
                }
            }
            mstore(end, 0)
            mstore(0x40, and(add(end, 0x3f), not(0x1f)))
        }
    }

    /// @notice Sets the value of a TBytes storage pointer to a specified value.
    function set(TBytes storage ptr, bytes memory value) internal {
        assembly ("memory-safe") {
            let len := mload(value)
            let data := mload(add(value, 0x20))
            tstore(ptr.slot, or(shl(224, len), shr(32, data)))
            if iszero(lt(len, 0x1d)) {
                let dataSlot := add(ptr.slot, 1)
                let end := add(add(value, 0x20), len)
                for { let i := add(value, 0x3c) } lt(i, end) { i := add(i, 0x20) } {
                    tstore(dataSlot, mload(i))
                    dataSlot := add(dataSlot, 1)
                }
            }
        }
    }

    /// @notice Sets the value of a TBytes storage pointer, with compatibility handling for different chains.
    function setCompat(TBytes storage ptr, bytes memory value) internal {
        if (block.chainid == 1) {
            set(ptr, value);
        } else {
            TBytes storage c = _compat(ptr);
            assembly ("memory-safe") {
                let len := mload(value)
                let data := mload(add(value, 0x20))
                sstore(c.slot, or(shl(224, len), shr(32, data)))
                if iszero(lt(len, 0x1d)) {
                    let dataSlot := add(c.slot, 1)
                    let end := add(add(value, 0x20), len)
                    for { let i := add(value, 0x3c) } lt(i, end) { i := add(i, 0x20) } {
                        sstore(dataSlot, mload(i))
                        dataSlot := add(dataSlot, 1)
                    }
                }
            }
        }
    }

    /// @notice Sets the calldata for a TBytes storage pointer.
    function setCalldata(TBytes storage ptr, bytes calldata value) internal {
        assembly ("memory-safe") {
            let len := value.length
            tstore(ptr.slot, or(shl(224, len), shr(32, calldataload(value.offset))))
            if iszero(lt(len, 0x1d)) {
                let dataSlot := add(ptr.slot, 1)
                let end := add(value.offset, len)
                for { let i := add(value.offset, 0x1c) } lt(i, end) { i := add(i, 0x20) } {
                    tstore(dataSlot, calldataload(i))
                    dataSlot := add(dataSlot, 1)
                }
            }
        }
    }

    /// @notice Sets the calldata compatibility for a given TBytes storage pointer.
    function setCalldataCompat(TBytes storage ptr, bytes calldata value) internal {
        if (block.chainid == 1) {
            setCalldata(ptr, value);
        } else {
            TBytes storage c = _compat(ptr);
            assembly ("memory-safe") {
                let len := value.length
                sstore(c.slot, or(shl(224, len), shr(32, calldataload(value.offset))))
                if iszero(lt(len, 0x1d)) {
                    let dataSlot := add(c.slot, 1)
                    let end := add(value.offset, len)
                    for { let i := add(value.offset, 0x1c) } lt(i, end) { i := add(i, 0x20) } {
                        sstore(dataSlot, calldataload(i))
                        dataSlot := add(dataSlot, 1)
                    }
                }
            }
        }
    }

    /// @notice Clears the value stored at the given storage pointer.
    function clear(TBytes storage ptr) internal {
        assembly ("memory-safe") {
            tstore(ptr.slot, 0)
        }
    }

    /// @notice Clears the storage pointer `ptr` in a way that is compatible with different chain IDs.
    function clearCompat(TBytes storage ptr) internal {
        if (block.chainid == 1) {
            clear(ptr);
        } else {
            _compat(ptr)._spacer = 0;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   COMPATIBILITY HELPERS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Converts a TUint256 storage pointer to a compatible format using inline assembly.
    function _compat(TUint256 storage ptr) private pure returns (TUint256 storage c) {
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @notice Converts a TInt256 storage pointer to a compatible format using inline assembly.
    function _compat(TInt256 storage ptr) private pure returns (TInt256 storage c) {
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @notice Converts a TBytes32 storage pointer to a compatible format using inline assembly.
    function _compat(TBytes32 storage ptr) private pure returns (TBytes32 storage c) {
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @notice Converts a TAddress storage pointer to a compatible format using inline assembly.
    function _compat(TAddress storage ptr) private pure returns (TAddress storage c) {
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @notice Converts a TBool storage pointer to a compatible format using inline assembly.
    function _compat(TBool storage ptr) private pure returns (TBool storage c) {
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @notice Converts a TBytes storage pointer to a compatible format using inline assembly.
    function _compat(TBytes storage ptr) private pure returns (TBytes storage c) {
        assembly ("memory-safe") {
            mstore(0x04, _COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }
}