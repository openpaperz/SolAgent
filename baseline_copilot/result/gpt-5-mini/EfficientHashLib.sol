// ...existing code...
pragma solidity ^0.8.4;

library EfficientHashLib {
    /* ------------- Fixed-arity keccak hash helpers ------------- */

    function hash(bytes32 v0) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = v0;
        return hash(arr);
    }

    function hash(uint256 v0) internal pure returns (bytes32 result) {
        return hash(bytes32(v0));
    }

    function hash(bytes32 v0, bytes32 v1) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](2);
        arr[0] = v0;
        arr[1] = v1;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](3);
        arr[0] = v0;
        arr[1] = v1;
        arr[2] = v2;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](4);
        arr[0] = v0;
        arr[1] = v1;
        arr[2] = v2;
        arr[3] = v3;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](5);
        arr[0] = v0;
        arr[1] = v1;
        arr[2] = v2;
        arr[3] = v3;
        arr[4] = v4;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](6);
        arr[0] = v0;
        arr[1] = v1;
        arr[2] = v2;
        arr[3] = v3;
        arr[4] = v4;
        arr[5] = v5;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](7);
        arr[0] = v0;
        arr[1] = v1;
        arr[2] = v2;
        arr[3] = v3;
        arr[4] = v4;
        arr[5] = v5;
        arr[6] = v6;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](8);
        arr[0] = v0; arr[1] = v1; arr[2] = v2; arr[3] = v3;
        arr[4] = v4; arr[5] = v5; arr[6] = v6; arr[7] = v7;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6), bytes32(v7));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](9);
        arr[0]=v0; arr[1]=v1; arr[2]=v2; arr[3]=v3; arr[4]=v4; arr[5]=v5; arr[6]=v6; arr[7]=v7; arr[8]=v8;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6), bytes32(v7), bytes32(v8));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](10);
        arr[0]=v0; arr[1]=v1; arr[2]=v2; arr[3]=v3; arr[4]=v4; arr[5]=v5; arr[6]=v6; arr[7]=v7; arr[8]=v8; arr[9]=v9;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6), bytes32(v7), bytes32(v8), bytes32(v9));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](11);
        arr[0]=v0; arr[1]=v1; arr[2]=v2; arr[3]=v3; arr[4]=v4; arr[5]=v5; arr[6]=v6; arr[7]=v7; arr[8]=v8; arr[9]=v9; arr[10]=v10;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6), bytes32(v7), bytes32(v8), bytes32(v9), bytes32(v10));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](12);
        arr[0]=v0; arr[1]=v1; arr[2]=v2; arr[3]=v3; arr[4]=v4; arr[5]=v5; arr[6]=v6; arr[7]=v7; arr[8]=v8; arr[9]=v9; arr[10]=v10; arr[11]=v11;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6), bytes32(v7), bytes32(v8), bytes32(v9), bytes32(v10), bytes32(v11));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11, bytes32 v12) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](13);
        arr[0]=v0; arr[1]=v1; arr[2]=v2; arr[3]=v3; arr[4]=v4; arr[5]=v5; arr[6]=v6; arr[7]=v7; arr[8]=v8; arr[9]=v9; arr[10]=v10; arr[11]=v11; arr[12]=v12;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11, uint256 v12) internal pure returns (bytes32 result) {
        return hash(bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6), bytes32(v7), bytes32(v8), bytes32(v9), bytes32(v10), bytes32(v11), bytes32(v12));
    }

    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5, bytes32 v6, bytes32 v7, bytes32 v8, bytes32 v9, bytes32 v10, bytes32 v11, bytes32 v12, bytes32 v13) internal pure returns (bytes32 result) {
        bytes32[] memory arr = new bytes32[](14);
        arr[0]=v0; arr[1]=v1; arr[2]=v2; arr[3]=v3; arr[4]=v4; arr[5]=v5; arr[6]=v6; arr[7]=v7; arr[8]=v8; arr[9]=v9; arr[10]=v10; arr[11]=v11; arr[12]=v12; arr[13]=v13;
        return hash(arr);
    }

    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5, uint256 v6, uint256 v7, uint256 v8, uint256 v9, uint256 v10, uint256 v11, uint256 v12, uint256 v13) internal pure returns (bytes32 result) {
        return hash(
            bytes32(v0), bytes32(v1), bytes32(v2), bytes32(v3), bytes32(v4), bytes32(v5), bytes32(v6),
            bytes32(v7), bytes32(v8), bytes32(v9), bytes32(v10), bytes32(v11), bytes32(v12), bytes32(v13)
        );
    }

    /* ------------- Dynamic array & memory helpers ------------- */

    /// @dev Compute keccak256 over a bytes32[] memory buffer (concatenation of elements).
    function hash(bytes32[] memory buffer) internal pure returns (bytes32 result) {
        assembly {
            // data starts at buffer + 0x20, length in words = mload(buffer)
            result := keccak256(add(buffer, 0x20), mul(mload(buffer), 0x20))
        }
    }

    /// @notice Sets a bytes32 value into buffer at index i.
    function set(bytes32[] memory buffer, uint256 i, bytes32 value) internal pure returns (bytes32[] memory) {
        require(i < buffer.length, "Index OOB");
        buffer[i] = value;
        return buffer;
    }

    /// @notice Sets a uint256 value (stored as bytes32) into buffer at index i.
    function set(bytes32[] memory buffer, uint256 i, uint256 value) internal pure returns (bytes32[] memory) {
        require(i < buffer.length, "Index OOB");
        buffer[i] = bytes32(value);
        return buffer;
    }

    /// @notice Allocate a bytes32[] memory buffer of length n, returns the typed pointer.
    function malloc(uint256 n) internal pure returns (bytes32[] memory buffer) {
        assembly {
            let ptr := mload(0x40)
            // store length
            mstore(ptr, n)
            // new free pointer = ptr + 0x20 (length slot) + n*0x20
            let size := mul(add(n, 1), 0x20)
            mstore(0x40, add(ptr, size))
            buffer := ptr
        }
    }

    /// @notice Free memory allocated for the dynamic bytes32 array if it's the most recent allocation.
    function free(bytes32[] memory buffer) internal pure {
        assembly {
            let len := mload(buffer)
            // if zero length, nothing to free
            if iszero(len) { leave }
            let dataEnd := add(add(buffer, 0x20), mul(len, 0x20))
            let freePtr := mload(0x40)
            // if this allocation is at the top of memory, roll back the free pointer
            if eq(dataEnd, freePtr) {
                mstore(0x40, buffer)
            }
        }
    }

    /* ------------- Equality helpers ------------- */

    /// @notice Compare bytes32 with bytes memory (true if bytes length == 32 and contents equal).
    function eq(bytes32 a, bytes memory b) internal pure returns (bool result) {
        if (b.length != 32) return false;
        bytes32 b0;
        assembly { b0 := mload(add(b, 0x20)) }
        return a == b0;
    }

    /// @notice Compare bytes memory with bytes32 (same as above, reversed args).
    function eq(bytes memory a, bytes32 b) internal pure returns (bool result) {
        return eq(b, a);
    }

    /* ------------- Bytes memory keccak helpers ------------- */

    function hash(bytes memory b, uint256 start, uint256 end) internal pure returns (bytes32 result) {
        uint256 len = b.length;
        if (end > len) end = len;
        if (start > len) start = len;
        uint256 n = end - start;
        if (n == 0) {
            // keccak256 of empty
            assembly { result := keccak256(0x0, 0x0) }
            return result;
        }
        uint256 ptr;
        assembly { ptr := add(add(b, 0x20), start) }
        assembly { result := keccak256(ptr, n) }
    }

    function hash(bytes memory b, uint256 start) internal pure returns (bytes32 result) {
        return hash(b, start, b.length);
    }

    function hash(bytes memory b) internal pure returns (bytes32 result) {
        assembly { result := keccak256(add(b, 0x20), mload(b)) }
    }

    /* ------------- Calldata keccak helpers ------------- */

    function hashCalldata(bytes calldata b, uint256 start, uint256 end) internal pure returns (bytes32 result) {
        uint256 len = b.length;
        if (end > len) end = len;
        if (start > len) start = len;
        uint256 n = end - start;
        if (n == 0) {
            assembly { result := keccak256(0x0, 0x0) }
            return result;
        }
        bytes memory tmp = new bytes(n);
        for (uint256 i = 0; i < n; ++i) tmp[i] = b[start + i];
        assembly { result := keccak256(add(tmp, 0x20), mload(tmp)) }
    }

    function hashCalldata(bytes calldata b, uint256 start) internal pure returns (bytes32 result) {
        return hashCalldata(b, start, b.length);
    }

    function hashCalldata(bytes calldata b) internal pure returns (bytes32 result) {
        // direct keccak on calldata bytes is allowed
        return keccak256(b);
    }

    /* ------------- SHA-2 (sha256) helpers using precompile at address 0x02 ------------- */

    function sha2(bytes32 b) internal view returns (bytes32 result) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, b)
            let success := staticcall(gas(), 0x02, ptr, 0x20, ptr, 0x20)
            if iszero(success) { revert(0, 0) }
            result := mload(ptr)
        }
    }

    function sha2(bytes memory b, uint256 start, uint256 end) internal view returns (bytes32 result) {
        uint256 len = b.length;
        if (end > len) end = len;
        if (start > len) start = len;
        uint256 n = end - start;
        if (n == 0) {
            // sha256 of empty -> call precompile with zero-length input
            assembly {
                let ptr := mload(0x40)
                let success := staticcall(gas(), 0x02, ptr, 0x0, ptr, 0x20)
                if iszero(success) { revert(0,0) }
                result := mload(ptr)
            }
            return result;
        }
        bytes memory tmp = new bytes(n);
        for (uint256 i = 0; i < n; ++i) tmp[i] = b[start + i];
        assembly {
            let ptr := add(tmp, 0x20)
            let success := staticcall(gas(), 0x02, ptr, mload(tmp), ptr, 0x20)
            if iszero(success) { revert(0,0) }
            result := mload(ptr)
        }
    }

    function sha2(bytes memory b, uint256 start) internal view returns (bytes32 result) {
        return sha2(b, start, b.length);
    }

    function sha2(bytes memory b) internal view returns (bytes32 result) {
        assembly {
            let ptr := add(b, 0x20)
            let success := staticcall(gas(), 0x02, ptr, mload(b), ptr, 0x20)
            if iszero(success) { revert(0,0) }
            result := mload(ptr)
        }
    }

    function sha2Calldata(bytes calldata b, uint256 start, uint256 end) internal view returns (bytes32 result) {
        uint256 len = b.length;
        if (end > len) end = len;
        if (start > len) start = len;
        uint256 n = end - start;
        if (n == 0) {
            assembly {
                let ptr := mload(0x40)
                let success := staticcall(gas(), 0x02, ptr, 0x0, ptr, 0x20)
                if iszero(success) { revert(0,0) }
                result := mload(ptr)
            }
            return result;
        }
        bytes memory tmp = new bytes(n);
        for (uint256 i = 0; i < n; ++i) tmp[i] = b[start + i];
        assembly {
            let ptr := add(tmp, 0x20)
            let success := staticcall(gas(), 0x02, ptr, mload(tmp), ptr, 0x20)
            if iszero(success) { revert(0,0) }
            result := mload(ptr)
        }
    }

    function sha2Calldata(bytes calldata b, uint256 start) internal view returns (bytes32 result) {
        return sha2Calldata(b, start, b.length);
    }

    function sha2Calldata(bytes calldata b) internal view returns (bytes32 result) {
        bytes memory tmp = new bytes(b.length);
        for (uint256 i = 0; i < b.length; ++i) tmp[i] = b[i];
        assembly {
            let ptr := add(tmp, 0x20)
            let success := staticcall(gas(), 0x02, ptr, mload(tmp), ptr, 0x20)
            if iszero(success) { revert(0,0) }
            result := mload(ptr)
        }
    }
}
// ...existing code...