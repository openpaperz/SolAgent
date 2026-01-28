// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library ECDSA {
    // secp256k1 curve order
    uint256 private constant _SECP256K1N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint256 private constant _HALF_N_PLUS_1 = (_SECP256K1N / 2) + 1;

    /// @notice Recovers the address from a given hash and signature.
    function recover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        result = tryRecover(hash, signature);
        require(result != address(0), "InvalidSignature");
    }

    /// @notice Recovers the signer's address from a given hash and calldata signature.
    function recoverCalldata(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        result = tryRecoverCalldata(hash, signature);
        require(result != address(0), "InvalidSignature");
    }

    /// @notice Recover from r,vs (EIP-2098 short signatures)
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        result = tryRecover(hash, r, vs);
        require(result != address(0), "InvalidSignature");
    }

    /// @notice Recover from explicit v,r,s
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address result) {
        result = tryRecover(hash, v, r, s);
        require(result != address(0), "InvalidSignature");
    }

    /// @notice Attempts to recover the signer's address from a signature (memory).
    function tryRecover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            result = tryRecover(hash, v, r, s);
            return result;
        } else if (signature.length == 64) {
            // EIP-2098 short signature (r, vs)
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            result = tryRecover(hash, r, vs);
            return result;
        }
        return address(0);
    }

    /// @notice Attempts to recover the signer's address from a signature (calldata).
    function tryRecoverCalldata(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                // calldata layout: offset points to data, but calldataload needs offset in calldata.
                // skip 0x20 length prefix for bytes calldata in memory ABI, but for calldata we access directly:
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            result = tryRecover(hash, v, r, s);
            return result;
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(signature.offset)
                vs := calldataload(add(signature.offset, 0x20))
            }
            result = tryRecover(hash, r, vs);
            return result;
        }
        return address(0);
    }

    /// @notice Attempts to recover the signer's address from r,vs (EIP-2098)
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        // vs: highest bit is v parity, remaining is s
        uint8 v;
        bytes32 s;
        unchecked {
            uint256 vsUint = uint256(vs);
            v = uint8((vsUint >> 255) + 27); // 27 or 28
            s = bytes32(vsUint & (~(uint256(1) << 255)));
        }
        result = tryRecover(hash, v, r, s);
    }

    /// @notice Attempts to recover the signer's address from explicit v,r,s
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address result) {
        // Validate v
        if (v != 27 && v != 28) return address(0);
        // Validate s is in lower half order
        if (uint256(s) >= _HALF_N_PLUS_1) return address(0);
        // ecrecover returns address(0) on failure
        address addr = ecrecover(hash, v, r, s);
        return addr;
    }

    /// @notice Converts a bytes32 hash into an Ethereum signed message hash.
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        // Equivalent to: keccak256("\x19Ethereum Signed Message:\n32" + hash)
        result = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /// @notice Converts arbitrary bytes into an Ethereum signed message hash.
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        result = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _uintToString(s.length), s));
    }

    /// @notice Computes the canonical hash of a signature (memory).
    function canonicalHash(bytes memory signature) internal pure returns (bytes32 result) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return canonicalHash(v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return canonicalHash(r, vs);
        }
        // invalid length -> corrupted hash
        return keccak256(signature) ^ bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    }

    /// @notice Computes the canonical hash of a signature (calldata).
    function canonicalHashCalldata(bytes calldata signature) internal pure returns (bytes32 result) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            return canonicalHash(v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(signature.offset)
                vs := calldataload(add(signature.offset, 0x20))
            }
            return canonicalHash(r, vs);
        }
        // invalid length -> corrupted hash
        // XOR with an error code to indicate corruption similarly to memory variant
        return keccak256(signature) ^ bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    }

    /// @notice Computes canonical hash from r,vs
    function canonicalHash(bytes32 r, bytes32 vs) internal pure returns (bytes32 result) {
        uint8 v;
        bytes32 s;
        unchecked {
            uint256 vsUint = uint256(vs);
            v = uint8((vsUint >> 255) + 27);
            s = bytes32(vsUint & (~(uint256(1) << 255)));
        }
        return canonicalHash(v, r, s);
    }

    /// @notice Computes canonical hash from v,r,s ensuring canonical s and v.
    function canonicalHash(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes32 result) {
        // Normalize v to 27/28
        if (v != 27 && v != 28) {
            // corrupt
            return keccak256(abi.encodePacked(r, s, v)) ^ bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
        }
        uint256 sUint = uint256(s);
        if (sUint >= _HALF_N_PLUS_1) {
            // flip s to n - s and toggle v
            sUint = _SECP256K1N - sUint;
            v = (v == 27) ? 28 : 27;
        }
        return keccak256(abi.encodePacked(r, bytes32(sUint), v));
    }

    /// @notice Returns an empty signature (calldata).
    function emptySignature() internal pure returns (bytes calldata signature) {
        // Return a zero-length calldata slice. We craft a pointer with length 0.
        assembly {
            // For internal pure returning bytes calldata, set to 0 offset and 0 length.
            // A valid zero-length calldata view can be represented with offset 0 and length 0.
            signature := 0
        }
    }

    /* ========== Internal helpers ========== */

    function _uintToString(uint256 v) private pure returns (string memory str) {
        if (v == 0) return "0";
        uint256 digits;
        uint256 tmp = v;
        while (tmp != 0) {
            digits++;
            tmp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (v != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(v % 10)));
            v /= 10;
        }
        return string(buffer);
    }
}