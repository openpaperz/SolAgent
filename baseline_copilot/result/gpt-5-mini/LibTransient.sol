// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibTransient {
    // Transient compat seed (arbitrary constant)
    bytes32 private constant TRANSIENT_COMPAT_SEED = bytes32(uint256(0x0102030405060708010203040506070801020304050607080102030405060708));

    // --- Structs ---
    struct TUint256 { uint256 _spacer; }
    struct TInt256 { int256 _spacer; }
    struct TBytes32 { bytes32 _spacer; }
    struct TAddress { address _spacer; }
    struct TBool { uint256 _spacer; }
    struct TBytes { uint256 _spacer; }

    // --- TUint256 ---
    function tUint256(bytes32 tSlot) internal pure returns (TUint256 storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function tUint256(uint256 tSlot) internal pure returns (TUint256 storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function get(TUint256 storage ptr) internal view returns (uint256 result) {
        assembly { result := sload(ptr.slot) }
    }

    function getCompat(TUint256 storage ptr) internal view returns (uint256 result) {
        if (block.chainid == 1) return get(ptr);
        TUint256 storage c = _compat(ptr);
        return get(c);
    }

    function set(TUint256 storage ptr, uint256 value) internal {
        assembly { sstore(ptr.slot, value) }
    }

    function setCompat(TUint256 storage ptr, uint256 value) internal {
        if (block.chainid == 1) { set(ptr, value); return; }
        TUint256 storage c = _compat(ptr);
        set(c, value);
    }

    function clear(TUint256 storage ptr) internal {
        set(ptr, 0);
    }

    function clearCompat(TUint256 storage ptr) internal {
        if (block.chainid == 1) { clear(ptr); return; }
        TUint256 storage c = _compat(ptr);
        set(c, 0);
    }

    function inc(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = get(ptr) + 1;
        set(ptr, newValue);
    }

    function incCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) + 1;
        setCompat(ptr, newValue);
    }

    function inc(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = get(ptr) + delta;
        set(ptr, newValue);
    }

    function incCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) + delta;
        setCompat(ptr, newValue);
    }

    function dec(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = get(ptr) - 1;
        set(ptr, newValue);
    }

    function decCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) - 1;
        setCompat(ptr, newValue);
    }

    function dec(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = get(ptr) - delta;
        set(ptr, newValue);
    }

    function decCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        newValue = getCompat(ptr) - delta;
        setCompat(ptr, newValue);
    }

    function incSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        uint256 raw = get(ptr);
        int256 cur = int256(int256(uint256(raw)));
        int256 res = cur + delta;
        // Overflow/underflow checks
        if (delta > 0) {
            require(res >= cur, "LibTransient: signed overflow");
        } else if (delta < 0) {
            require(res <= cur, "LibTransient: signed underflow");
        }
        newValue = uint256(int256(res));
        set(ptr, newValue);
    }

    function incSignedCompat(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        if (block.chainid == 1) return incSigned(ptr, delta);
        TUint256 storage c = _compat(ptr);
        return incSigned(c, delta);
    }

    function decSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        // decSigned is simply incSigned with negative delta
        return incSigned(ptr, -delta);
    }

    function decSignedCompat(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        if (block.chainid == 1) return decSigned(ptr, delta);
        TUint256 storage c = _compat(ptr);
        return decSigned(c, delta);
    }

    // --- TInt256 ---
    function tInt256(bytes32 tSlot) internal pure returns (TInt256 storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function tInt256(uint256 tSlot) internal pure returns (TInt256 storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function get(TInt256 storage ptr) internal view returns (int256 result) {
        uint256 raw;
        assembly { raw := sload(ptr.slot) }
        result = int256(int256(uint256(raw)));
    }

    function getCompat(TInt256 storage ptr) internal view returns (int256 result) {
        if (block.chainid == 1) return get(ptr);
        TInt256 storage c = _compat(ptr);
        return get(c);
    }

    function set(TInt256 storage ptr, int256 value) internal {
        assembly { sstore(ptr.slot, value) }
    }

    function setCompat(TInt256 storage ptr, int256 value) internal {
        if (block.chainid == 1) { set(ptr, value); return; }
        TInt256 storage c = _compat(ptr);
        set(c, value);
    }

    function clear(TInt256 storage ptr) internal {
        set(ptr, 0);
    }

    function clearCompat(TInt256 storage ptr) internal {
        if (block.chainid == 1) { clear(ptr); return; }
        TInt256 storage c = _compat(ptr);
        set(c, 0);
    }

    function inc(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = get(ptr) + int256(1);
        set(ptr, newValue);
    }

    function incCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = getCompat(ptr) + int256(1);
        setCompat(ptr, newValue);
    }

    function inc(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = get(ptr) + delta;
        set(ptr, newValue);
    }

    function incCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = getCompat(ptr) + delta;
        setCompat(ptr, newValue);
    }

    function dec(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = get(ptr) - int256(1);
        set(ptr, newValue);
    }

    function decCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        newValue = getCompat(ptr) - int256(1);
        setCompat(ptr, newValue);
    }

    function dec(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = get(ptr) - delta;
        set(ptr, newValue);
    }

    function decCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        newValue = getCompat(ptr) - delta;
        setCompat(ptr, newValue);
    }

    // --- TBytes32 ---
    function tBytes32(bytes32 tSlot) internal pure returns (TBytes32 storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function tBytes32(uint256 tSlot) internal pure returns (TBytes32 storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function get(TBytes32 storage ptr) internal view returns (bytes32 result) {
        assembly { result := sload(ptr.slot) }
    }

    function getCompat(TBytes32 storage ptr) internal view returns (bytes32 result) {
        if (block.chainid == 1) return get(ptr);
        TBytes32 storage c = _compat(ptr);
        return get(c);
    }

    function set(TBytes32 storage ptr, bytes32 value) internal {
        assembly { sstore(ptr.slot, value) }
    }

    function setCompat(TBytes32 storage ptr, bytes32 value) internal {
        if (block.chainid == 1) { set(ptr, value); return; }
        TBytes32 storage c = _compat(ptr);
        set(c, value);
    }

    function clear(TBytes32 storage ptr) internal {
        set(ptr, bytes32(0));
    }

    function clearCompat(TBytes32 storage ptr) internal {
        if (block.chainid == 1) { clear(ptr); return; }
        TBytes32 storage c = _compat(ptr);
        set(c, bytes32(0));
    }

    // --- TAddress ---
    function tAddress(bytes32 tSlot) internal pure returns (TAddress storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function tAddress(uint256 tSlot) internal pure returns (TAddress storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function get(TAddress storage ptr) internal view returns (address result) {
        uint256 raw;
        assembly { raw := sload(ptr.slot) }
        result = address(uint160(raw));
    }

    function getCompat(TAddress storage ptr) internal view returns (address result) {
        if (block.chainid == 1) return get(ptr);
        TAddress storage c = _compat(ptr);
        return get(c);
    }

    function set(TAddress storage ptr, address value) internal {
        assembly { sstore(ptr.slot, value) }
    }

    function setCompat(TAddress storage ptr, address value) internal {
        if (block.chainid == 1) { set(ptr, value); return; }
        TAddress storage c = _compat(ptr);
        set(c, value);
    }

    function clear(TAddress storage ptr) internal {
        set(ptr, address(0));
    }

    function clearCompat(TAddress storage ptr) internal {
        if (block.chainid == 1) { clear(ptr); return; }
        TAddress storage c = _compat(ptr);
        set(c, address(0));
    }

    // --- TBool ---
    function tBool(bytes32 tSlot) internal pure returns (TBool storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function tBool(uint256 tSlot) internal pure returns (TBool storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function get(TBool storage ptr) internal view returns (bool result) {
        uint256 raw;
        assembly { raw := sload(ptr.slot) }
        result = (raw != 0);
    }

    function getCompat(TBool storage ptr) internal view returns (bool result) {
        if (block.chainid == 1) return get(ptr);
        TBool storage c = _compat(ptr);
        return get(c);
    }

    function set(TBool storage ptr, bool value) internal {
        assembly { sstore(ptr.slot, value) }
    }

    function setCompat(TBool storage ptr, bool value) internal {
        if (block.chainid == 1) { set(ptr, value); return; }
        TBool storage c = _compat(ptr);
        set(c, value);
    }

    function clear(TBool storage ptr) internal {
        set(ptr, false);
    }

    function clearCompat(TBool storage ptr) internal {
        if (block.chainid == 1) { clear(ptr); return; }
        TBool storage c = _compat(ptr);
        set(c, false);
    }

    // --- TBytes (dynamic) ---
    function tBytes(bytes32 tSlot) internal pure returns (TBytes storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function tBytes(uint256 tSlot) internal pure returns (TBytes storage ptr) {
        assembly { ptr.slot := tSlot }
    }

    function length(TBytes storage ptr) internal view returns (uint256 result) {
        assembly { result := sload(ptr.slot) }
    }

    function lengthCompat(TBytes storage ptr) internal view returns (uint256 result) {
        if (block.chainid == 1) return length(ptr);
        TBytes storage c = _compat(ptr);
        return length(c);
    }

    function get(TBytes storage ptr) internal view returns (bytes memory result) {
        uint256 len;
        assembly { len := sload(ptr.slot) }
        result = new bytes(len);
        if (len == 0) return result;

        // dataSlot = keccak256(ptr.slot)
        bytes32 dataLocation;
        assembly {
            mstore(0x0, ptr.slot)
            dataLocation := keccak256(0x0, 0x20)
        }

        uint256 words = (len + 31) / 32;
        assembly {
            let memPtr := add(result, 0x20)
            // copy each storage slot
            for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                mstore(memPtr, sload(add(dataLocation, i)))
                memPtr := add(memPtr, 0x20)
            }
        }
    }

    function getCompat(TBytes storage ptr) internal view returns (bytes memory result) {
        if (block.chainid == 1) return get(ptr);
        TBytes storage c = _compat(ptr);
        return get(c);
    }

    function set(TBytes storage ptr, bytes memory value) internal {
        uint256 len = value.length;
        assembly { sstore(ptr.slot, len) }
        // compute data slot
        bytes32 dataLocation;
        assembly {
            mstore(0x0, ptr.slot)
            dataLocation := keccak256(0x0, 0x20)
        }
        uint256 words = (len + 31) / 32;
        assembly {
            let memPtr := add(value, 0x20)
            for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                sstore(add(dataLocation, i), mload(memPtr))
                memPtr := add(memPtr, 0x20)
            }
        }
    }

    function setCompat(TBytes storage ptr, bytes memory value) internal {
        if (block.chainid == 1) { set(ptr, value); return; }
        TBytes storage c = _compat(ptr);
        set(c, value);
    }

    function setCalldata(TBytes storage ptr, bytes calldata value) internal {
        // calldata -> memory conversion then set
        set(ptr, bytes(value));
    }

    function setCalldataCompat(TBytes storage ptr, bytes calldata value) internal {
        if (block.chainid == 1) { setCalldata(ptr, value); return; }
        TBytes storage c = _compat(ptr);
        setCalldata(c, value);
    }

    function clear(TBytes storage ptr) internal {
        // set length to 0 (do not clear underlying storage slots aggressively)
        assembly { sstore(ptr.slot, 0) }
    }

    function clearCompat(TBytes storage ptr) internal {
        if (block.chainid == 1) { clear(ptr); return; }
        TBytes storage c = _compat(ptr);
        clear(c);
    }

    // --- _compat helpers for each struct type ---
    function _compat(TUint256 storage ptr) private pure returns (TUint256 storage c) {
        bytes32 seed = TRANSIENT_COMPAT_SEED;
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, seed)
            let h := keccak256(0x00, 0x40)
            c.slot := h
        }
    }

    function _compat(TInt256 storage ptr) private pure returns (TInt256 storage c) {
        bytes32 seed = TRANSIENT_COMPAT_SEED;
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, seed)
            let h := keccak256(0x00, 0x40)
            c.slot := h
        }
    }

    function _compat(TBytes32 storage ptr) private pure returns (TBytes32 storage c) {
        bytes32 seed = TRANSIENT_COMPAT_SEED;
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, seed)
            let h := keccak256(0x00, 0x40)
            c.slot := h
        }
    }

    function _compat(TAddress storage ptr) private pure returns (TAddress storage c) {
        bytes32 seed = TRANSIENT_COMPAT_SEED;
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, seed)
            let h := keccak256(0x00, 0x40)
            c.slot := h
        }
    }

    function _compat(TBool storage ptr) private pure returns (TBool storage c) {
        bytes32 seed = TRANSIENT_COMPAT_SEED;
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, seed)
            let h := keccak256(0x00, 0x40)
            c.slot := h
        }
    }

    function _compat(TBytes storage ptr) private pure returns (TBytes storage c) {
        bytes32 seed = TRANSIENT_COMPAT_SEED;
        assembly {
            mstore(0x00, ptr.slot)
            mstore(0x20, seed)
            let h := keccak256(0x00, 0x40)
            c.slot := h
        }
    }
}