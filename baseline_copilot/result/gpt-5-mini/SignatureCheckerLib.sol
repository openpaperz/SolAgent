// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SignatureCheckerLib {
    bytes4 internal constant ERC1271_SELECTOR = 0x1626ba7e;

    /// @notice Validates if a given signature is valid for a specific signer and hash.
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature) internal view returns (bool isValid) {
        if (signer == address(0)) return false;

        // Try EOA signatures first (64 or 65 bytes)
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            address recovered = ecrecover(hash, v, r, s);
            if (recovered == signer) return true;
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            bytes32 s = bytes32(uint256(vs) & ((1 << 255) - 1));
            address recovered = ecrecover(hash, v, r, s);
            if (recovered == signer) return true;
        }

        // Fallback to ERC1271 (contract) verifier
        return isValidERC1271SignatureNow(signer, hash, signature);
    }

    /// @notice Validates a signature for a given hash using the provided signer and signature (calldata).
    function isValidSignatureNowCalldata(address signer, bytes32 hash, bytes calldata signature) internal view returns (bool isValid) {
        if (signer == address(0)) return false;

        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                // calldata layout: sig.data starts at signature.offset
                let dataPtr := add(signature.offset, 0)
                r := calldataload(add(dataPtr, 0x20))
                s := calldataload(add(dataPtr, 0x40))
                v := byte(0, calldataload(add(dataPtr, 0x60)))
            }
            address recovered = ecrecover(hash, v, r, s);
            if (recovered == signer) return true;
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                let dataPtr := add(signature.offset, 0)
                r := calldataload(add(dataPtr, 0x20))
                vs := calldataload(add(dataPtr, 0x40))
            }
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            bytes32 s = bytes32(uint256(vs) & ((1 << 255) - 1));
            address recovered = ecrecover(hash, v, r, s);
            if (recovered == signer) return true;
        }

        return isValidERC1271SignatureNowCalldata(signer, hash, signature);
    }

    /// @notice Validates if a given signature is valid for a specific signer and hash (r, vs).
    function isValidSignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs) internal view returns (bool isValid) {
        if (signer == address(0)) return false;
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        bytes32 s = bytes32(uint256(vs) & ((1 << 255) - 1));
        address recovered = ecrecover(hash, v, r, s);
        if (recovered == signer) return true;

        // construct compact signature (r || vs)
        bytes memory sig = new bytes(64);
        assembly {
            mstore(add(sig, 0x20), r)
            mstore(add(sig, 0x40), vs)
        }
        return isValidERC1271SignatureNow(signer, hash, sig);
    }

    /// @notice Validates if a given signature is valid for a specific signer and hash (v, r, s).
    function isValidSignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (bool isValid) {
        if (signer == address(0)) return false;
        address recovered = ecrecover(hash, v, r, s);
        if (recovered == signer) return true;

        // construct full signature (r || s || v)
        bytes memory sig = new bytes(65);
        assembly {
            mstore(add(sig, 0x20), r)
            mstore(add(sig, 0x40), s)
            mstore8(add(sig, 0x60), v)
        }
        return isValidERC1271SignatureNow(signer, hash, sig);
    }

    /// @notice Checks if a given signature is valid for a specific signer and hash according to ERC1271 (memory).
    function isValidERC1271SignatureNow(address signer, bytes32 hash, bytes memory signature) internal view returns (bool isValid) {
        if (signer == address(0)) return false;
        bytes memory data = abi.encodeWithSelector(ERC1271_SELECTOR, hash, signature);
        (bool success, bytes memory returndata) = signer.staticcall(data);
        if (!success || returndata.length < 4) return false;
        bytes4 returned;
        assembly { returned := mload(add(returndata, 0x20)) }
        return returned == ERC1271_SELECTOR;
    }

    /// @notice Validates an ERC1271 signature using calldata.
    function isValidERC1271SignatureNowCalldata(address signer, bytes32 hash, bytes calldata signature) internal view returns (bool isValid) {
        if (signer == address(0)) return false;
        // Build calldata: selector + hash + offset + length + signature-data
        // Use memory to build the head, then append signature from calldata.
        bytes memory head = abi.encodeWithSelector(ERC1271_SELECTOR, hash, bytes(""));
        // head currently encodes selector, hash, offset(0x40), length(0) - we need to replace length and insert calldata
        // Simpler: perform staticcall with ABI encoding built manually in memory.

        uint256 sigLen = signature.length;
        uint256 total = 4 + 32 + 32 + 32 + sigLen; // sel + hash + offset + len + data
        bytes memory buf = new bytes(total);
        assembly {
            let bptr := add(buf, 0x20)
            // selector
            mstore(bptr, shl(224, ERC1271_SELECTOR))
            // hash
            mstore(add(bptr, 0x04), hash)
            // offset to bytes (0x40)
            mstore(add(bptr, 0x24), 0x40)
            // length
            mstore(add(bptr, 0x44), sigLen)
        }
        // copy signature calldata into buf
        if (sigLen > 0) {
            // copy signature bytes from calldata to memory
            uint256 dest;
            assembly { dest := add(add(buf, 0x20), 0x64) } // 4 + 32 + 32 + 32 = 100 (0x64)
            assembly {
                let src := add(signature.offset, 0x20)
                // copy loop
                for { let i := 0 } lt(i, sigLen) { i := add(i, 0x20) } {
                    mstore(add(dest, i), calldataload(add(src, i)))
                }
            }
        }
        (bool success, bytes memory returndata) = signer.staticcall(buf);
        if (!success || returndata.length < 4) return false;
        bytes4 returned;
        assembly { returned := mload(add(returndata, 0x20)) }
        return returned == ERC1271_SELECTOR;
    }

    /// @notice Checks if a given signature is valid for a specific signer and hash according to ERC1271 (r, vs).
    function isValidERC1271SignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs) internal view returns (bool isValid) {
        // Construct compact signature r||vs
        bytes memory sig = new bytes(64);
        assembly {
            mstore(add(sig, 0x20), r)
            mstore(add(sig, 0x40), vs)
        }
        return isValidERC1271SignatureNow(signer, hash, sig);
    }

    /// @notice Checks if a given signature is valid for a specific signer and hash according to ERC1271 (v, r, s).
    function isValidERC1271SignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (bool isValid) {
        // construct full signature (r || s || v)
        bytes memory sig = new bytes(65);
        assembly {
            mstore(add(sig, 0x20), r)
            mstore(add(sig, 0x40), s)
            mstore8(add(sig, 0x60), v)
        }
        return isValidERC1271SignatureNow(signer, hash, sig);
    }

    /// @notice Validates an ERC6492 signature with side effects allowed (uses call).
    function isValidERC6492SignatureNowAllowSideEffects(address signer, bytes32 hash, bytes memory signature) internal returns (bool isValid) {
        if (signer == address(0)) return false;

        // If signer is a contract, attempt to call isValidSignature (allow side effects)
        uint256 codeSize;
        assembly { codeSize := extcodesize(signer) }
        if (codeSize > 0) {
            bytes memory data = abi.encodeWithSelector(ERC1271_SELECTOR, hash, signature);
            (bool success, bytes memory returndata) = signer.call(data);
            if (success && returndata.length >= 4) {
                bytes4 returned;
                assembly { returned := mload(add(returndata, 0x20)) }
                if (returned == ERC1271_SELECTOR) return true;
            }
            // If contract check fails or reverts, do not revert; fallthrough to EOA attempt.
        }

        // EOA fallback: attempt ecrecover
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            address recovered = ecrecover(hash, v, r, s);
            return recovered == signer;
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            bytes32 s = bytes32(uint256(vs) & ((1 << 255) - 1));
            address recovered = ecrecover(hash, v, r, s);
            return recovered == signer;
        }

        return false;
    }

    /// @notice Validates an ERC6492 signature (no side effects allowed - staticcall for contract verifiers).
    function isValidERC6492SignatureNow(address signer, bytes32 hash, bytes memory signature) internal returns (bool isValid) {
        if (signer == address(0)) return false;
        uint256 codeSize;
        assembly { codeSize := extcodesize(signer) }
        if (codeSize > 0) {
            bytes memory data = abi.encodeWithSelector(ERC1271_SELECTOR, hash, signature);
            (bool success, bytes memory returndata) = signer.staticcall(data);
            if (success && returndata.length >= 4) {
                bytes4 returned;
                assembly { returned := mload(add(returndata, 0x20)) }
                if (returned == ERC1271_SELECTOR) return true;
            }
            // If contract verifier fails, fallthrough to EOA
        }

        // EOA fallback (same as above)
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            address recovered = ecrecover(hash, v, r, s);
            return recovered == signer;
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            bytes32 s = bytes32(uint256(vs) & ((1 << 255) - 1));
            address recovered = ecrecover(hash, v, r, s);
            return recovered == signer;
        }

        return false;
    }

    /// @notice Converts a bytes32 hash into an Ethereum signed message hash.
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        // Standard: "\x19Ethereum Signed Message:\n32"
        result = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /// @notice Converts arbitrary bytes into an Ethereum signed message hash.
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        // Build prefix "\x19Ethereum Signed Message:\n" + decimal length
        result = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _toString(s.length), s));
    }

    /// @notice Returns an empty signature as `bytes calldata`
    function emptySignature() internal pure returns (bytes calldata signature) {
        // Returning memory bytes as calldata is acceptable via an implicit conversion for internal calls.
        bytes memory empty = "";
        return abi.decode(abi.encodePacked(empty), (bytes));
    }

    /* ============================
       Internal helpers
       ============================ */

    function _toString(uint256 value) internal pure returns (string memory str) {
        // Inspired by OpenZeppelin's toString
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        str = string(buffer);
    }
}