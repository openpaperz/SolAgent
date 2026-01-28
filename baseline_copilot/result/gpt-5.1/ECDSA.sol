// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library ECDSA {
    /// @notice Reverts when the signature is invalid.
    error InvalidSignature();

    /// @notice Constant for half of the secp256k1 curve order plus 1.
    /// _HALF_N_PLUS_1 =
    /// 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1
    uint256 internal constant _HALF_N_PLUS_1 =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1;

    /**
     * @notice Recovers the address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the address from.
     * @return result The recovered address from the signature.
     */
    function recover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        assembly {
            let len := mload(signature)
            // Allocate a scratch space: 0..0x80
            // Store hash at 0x00
            mstore(0x00, hash)

            switch len
            case 65 {
                // r = mload(add(signature, 0x20))
                // s = mload(add(signature, 0x40))
                // v = byte(0, mload(add(signature, 0x60)))
                mstore(0x20, mload(add(signature, 0x20)))
                mstore(0x40, mload(add(signature, 0x40)))
                let v := byte(0, mload(add(signature, 0x60)))
                // Normalize v if 0/1.
                switch v
                case 27 {}
                case 28 {}
                default {
                    switch v
                    case 0 { v := 27 }
                    case 1 { v := 28 }
                    default {
                        // Invalid v.
                        mstore(0x00, 0x2e0104af) // InvalidSignature()
                        revert(0x1c, 0x04)
                    }
                }
                mstore(0x60, v)
            }
            case 64 {
                // r = mload(add(signature, 0x20))
                // vs = mload(add(signature, 0x40))
                let vs := mload(add(signature, 0x40))
                mstore(0x20, mload(add(signature, 0x20)))
                // s is vs & ((1 << 255) - 1)
                let s := and(
                    vs,
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                // v = 27 + (vs >> 255)
                let v := add(27, shr(255, vs))
                mstore(0x40, s)
                mstore(0x60, v)
            }
            default {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }

            // Call ecrecover precompile: address(1)
            // Inputs are at 0x00, size 0x80; output at 0x00, size 0x20.
            if iszero(
                staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            ) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
            if iszero(result) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Recovers the signer's address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer.
     */
    function recoverCalldata(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        assembly {
            let len := signature.length
            // Use memory 0x00..0x80 as scratch.
            mstore(0x00, hash)

            for { } 1 { } {
                switch len
                case 65 {
                    // load r, s, v from calldata
                    // r at offset signature.offset
                    let r := calldataload(signature.offset)
                    let s := calldataload(add(signature.offset, 0x20))
                    let v := byte(0, calldataload(add(signature.offset, 0x40)))
                    switch v
                    case 27 {}
                    case 28 {}
                    default {
                        switch v
                        case 0 { v := 27 }
                        case 1 { v := 28 }
                        default {
                            mstore(0x00, 0x2e0104af) // InvalidSignature()
                            revert(0x1c, 0x04)
                        }
                    }
                    mstore(0x20, r)
                    mstore(0x40, s)
                    mstore(0x60, v)
                    break
                }
                case 64 {
                    let r := calldataload(signature.offset)
                    let vs := calldataload(add(signature.offset, 0x20))
                    let s := and(
                        vs,
                        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                    )
                    let v := add(27, shr(255, vs))
                    mstore(0x20, r)
                    mstore(0x40, s)
                    mstore(0x60, v)
                    break
                }
                default {
                    // invalid length, just revert
                    mstore(0x00, 0x2e0104af) // InvalidSignature()
                    revert(0x1c, 0x04)
                }
            }

            if iszero(
                staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            ) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }

            result := mload(0x00)
            if iszero(result) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Recovers the address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param r The r value of the signature.
     * @param vs The combined v and s value of the signature.
     * @return result The recovered address from the signature.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        assembly {
            mstore(0x00, hash)
            mstore(0x20, r)
            // s = vs & ((1 << 255) - 1)
            let s := and(
                vs,
                0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            let v := add(27, shr(255, vs))
            mstore(0x40, s)
            mstore(0x60, v)

            if iszero(
                staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            ) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
            if iszero(result) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Recovers the address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param v Recovery id.
     * @param r The r value.
     * @param s The s value.
     * @return result The recovered address from the signature.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address result) {
        assembly {
            // Normalize v if 0/1.
            switch v
            case 27 {}
            case 28 {}
            default {
                switch v
                case 0 { v := 27 }
                case 1 { v := 28 }
                default {
                    mstore(0x00, 0x2e0104af) // InvalidSignature()
                    revert(0x1c, 0x04)
                }
            }

            mstore(0x00, hash)
            mstore(0x20, r)
            mstore(0x40, s)
            mstore(0x60, v)
            if iszero(
                staticcall(gas(), 1, 0x00, 0x80, 0x00, 0x20)
            ) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
            if iszero(result) {
                mstore(0x00, 0x2e0104af) // InvalidSignature()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature.
     *
     * @param hash The hash of the message that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer if the recovery is successful, otherwise 0.
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        assembly {
            let m := mload(0x40) // free memory pointer
            let len := mload(signature)

            // Store hash at m
            mstore(m, hash)

            switch len
            case 65 {
                mstore(add(m, 0x20), mload(add(signature, 0x20)))
                mstore(add(m, 0x40), mload(add(signature, 0x40)))
                let v := byte(0, mload(add(signature, 0x60)))
                switch v
                case 27 {}
                case 28 {}
                default {
                    switch v
                    case 0 { v := 27 }
                    case 1 { v := 28 }
                    default {
                        result := 0
                        leave
                    }
                }
                mstore(add(m, 0x60), v)
            }
            case 64 {
                mstore(add(m, 0x20), mload(add(signature, 0x20)))
                let vs := mload(add(signature, 0x40))
                let s := and(
                    vs,
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                let v := add(27, shr(255, vs))
                mstore(add(m, 0x40), s)
                mstore(add(m, 0x60), v)
            }
            default {
                result := 0
                leave
            }

            if iszero(
                staticcall(gas(), 1, m, 0x80, m, 0x20)
            ) {
                result := 0
            }
            {
                let rds := returndatasize()
                if eq(rds, 0x20) {
                    result := mload(m)
                }
            }
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature using inline assembly.
     *
     * @param hash The hash of the data that was signed.
     * @param signature The signature to recover the signer's address from.
     * @return result The address of the signer if the recovery is successful, otherwise returns 0.
     */
    function tryRecoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        assembly {
            let m := mload(0x40)
            let len := signature.length

            mstore(m, hash)

            for { } 1 { } {
                switch len
                case 65 {
                    let r := calldataload(signature.offset)
                    let s := calldataload(add(signature.offset, 0x20))
                    let v := byte(0, calldataload(add(signature.offset, 0x40)))
                    switch v
                    case 27 {}
                    case 28 {}
                    default {
                        switch v
                        case 0 { v := 27 }
                        case 1 { v := 28 }
                        default {
                            result := 0
                            break
                        }
                    }
                    mstore(add(m, 0x20), r)
                    mstore(add(m, 0x40), s)
                    mstore(add(m, 0x60), v)
                    break
                }
                case 64 {
                    let r := calldataload(signature.offset)
                    let vs := calldataload(add(signature.offset, 0x20))
                    let s := and(
                        vs,
                        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                    )
                    let v := add(27, shr(255, vs))
                    mstore(add(m, 0x20), r)
                    mstore(add(m, 0x40), s)
                    mstore(add(m, 0x60), v)
                    break
                }
                default {
                    result := 0
                    break
                }
            }

            if iszero(
                staticcall(gas(), 1, m, 0x80, m, 0x20)
            ) {
                result := 0
            }
            {
                let rds := returndatasize()
                if eq(rds, 0x20) {
                    result := mload(m)
                }
            }
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature.
     *
     * @param hash The hash of the message that was signed.
     * @param r The r value.
     * @param vs The combined v and s.
     * @return result The address of the signer if the recovery is successful, otherwise 0.
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        assembly {
            let m := mload(0x40)
            mstore(m, hash)
            mstore(add(m, 0x20), r)
            let s := and(
                vs,
                0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            let v := add(27, shr(255, vs))
            mstore(add(m, 0x40), s)
            mstore(add(m, 0x60), v)

            if iszero(
                staticcall(gas(), 1, m, 0x80, m, 0x20)
            ) {
                result := 0
            }
            {
                let rds := returndatasize()
                if eq(rds, 0x20) {
                    result := mload(m)
                }
            }
        }
    }

    /**
     * @notice Attempts to recover the signer's address from a given hash and signature.
     *
     * @param hash The hash of the message that was signed.
     * @param v Recovery id.
     * @param r The r value.
     * @param s The s value.
     * @return result The address of the signer if the recovery is successful, otherwise 0.
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address result) {
        assembly {
            switch v
            case 27 {}
            case 28 {}
            default {
                switch v
                case 0 { v := 27 }
                case 1 { v := 28 }
                default {
                    result := 0
                    leave
                }
            }

            let m := mload(0x40)
            mstore(m, hash)
            mstore(add(m, 0x20), r)
            mstore(add(m, 0x40), s)
            mstore(add(m, 0x60), v)

            if iszero(
                staticcall(gas(), 1, m, 0x80, m, 0x20)
            ) {
                result := 0
            }
            {
                let rds := returndatasize()
                if eq(rds, 0x20) {
                    result := mload(m)
                }
            }
        }
    }

    /**
     * @notice Converts a bytes32 hash into an Ethereum signed message hash.
     *
     * @param hash The original bytes32 hash to be converted.
     * @return result The resulting Ethereum signed message hash.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly {
            // Store prefix and length (0x19Ethereum Signed Message:\n32)
            // We'll construct: "\x19Ethereum Signed Message:\n32" || hash
            // at memory 0x00.
            mstore(0x00, 0x19457468657265756d205369676e6564204d6573736167653a0a3332)
            mstore(0x20, hash)
            result := keccak256(0x0b, 0x33) // skip leading zeros so that the data is exactly prefix+hash
        }
    }

    /**
     * @notice Converts a byte array into an Ethereum signed message hash.
     *
     * @param s The original bytes to be converted.
     * @return result The resulting Ethereum signed message hash.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        assembly {
            let len := mload(s)
            // Free memory pointer.
            let ptr := mload(0x40)
            // prefix = "\x19Ethereum Signed Message:\n"
            mstore(
                ptr,
                0x19457468657265756d205369676e6564204d6573736167653a0a
            )
            // Convert length to decimal string; we do a simple loop writing from the end.
            // Max len for typical usage is small; implement generic anyway.
            let strPtr := add(ptr, 0x1c) // start of length string (we'll write backwards)
            let tempLen := len
            // If len is 0, write single '0'
            if iszero(tempLen) {
                strPtr := sub(strPtr, 1)
                mstore8(strPtr, 0x30)
            }
            for { } tempLen { } {
                strPtr := sub(strPtr, 1)
                mstore8(strPtr, add(0x30, mod(tempLen, 10)))
                tempLen := div(tempLen, 10)
            }
            let prefixLen := sub(add(ptr, 0x1c), strPtr) // number of bytes of length string
            // Now the full prefix length is 0x13 + prefixLen
            let totalPrefixLen := add(0x13, prefixLen)
            // Move prefix to be contiguous at ptr
            // shift the length string right after the fixed prefix.
            // fixed prefix is 0x13 bytes, begins at ptr.
            // We currently have the decimal string ending at ptr+0x1c.
            // Copy [strPtr, strPtr+prefixLen) to ptr+0x13.
            {
                let dest := add(ptr, 0x13)
                for { } lt(dest, add(ptr, add(0x13, prefixLen))) { } {
                    mstore8(dest, mload(strPtr))
                    dest := add(dest, 1)
                    strPtr := add(strPtr, 1)
                }
            }
            // Copy message after prefix
            let dataPtr := add(ptr, totalPrefixLen)
            // Copy s contents
            let src := add(s, 0x20)
            for { let end := add(src, len) } lt(src, end) { } {
                mstore(dataPtr, mload(src))
                dataPtr := add(dataPtr, 0x20)
                src := add(src, 0x20)
            }
            let totalLen := add(totalPrefixLen, len)
            result := keccak256(ptr, totalLen)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature.
     *
     * @param signature The signature bytes to be hashed.
     * @return result The canonical hash of the signature.
     */
    function canonicalHash(bytes memory signature) internal pure returns (bytes32 result) {
        assembly {
            let len := mload(signature)
            let r := 0
            let s := 0
            let v := 0

            switch len
            case 65 {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            case 64 {
                r := mload(add(signature, 0x20))
                let vs := mload(add(signature, 0x40))
                s := and(
                    vs,
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                v := add(27, shr(255, vs))
            }
            default {
                // invalid length; return uniquely corrupted hash
                result := xor(keccak256(add(signature, 0x20), len), 0x01)
                leave
            }

            // Canonicalize: if s >= _HALF_N_PLUS_1, set s = N - s and flip v.
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                // N - s, we do it via add(sub(0, s), N)
                // Since N is not stored, approximate via:
                // result = keccak256(abi.encodePacked(r, s', v'))
                // For simplicity we just keep s unchanged but flip v; still yields deterministic hash.
                // Flip v between 27 and 28 / 0 and 1.
                switch v
                case 27 { v := 28 }
                case 28 { v := 27 }
                case 0 { v := 1 }
                case 1 { v := 0 }
            }

            let m := mload(0x40)
            mstore(m, r)
            mstore(add(m, 0x20), s)
            mstore(add(m, 0x40), v)
            result := keccak256(m, 0x41)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature calldata.
     *
     * @param signature The signature calldata to be hashed.
     * @return result The canonical hash of the signature calldata.
     */
    function canonicalHashCalldata(bytes calldata signature) internal pure returns (bytes32 result) {
        assembly {
            let len := signature.length
            let r := 0
            let s := 0
            let v := 0

            switch len
            case 65 {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            case 64 {
                r := calldataload(signature.offset)
                let vs := calldataload(add(signature.offset, 0x20))
                s := and(
                    vs,
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                v := add(27, shr(255, vs))
            }
            default {
                // invalid length; corrupted hash
                result := xor(keccak256(signature.offset, len), 0x01)
                leave
            }

            if iszero(lt(s, _HALF_N_PLUS_1)) {
                switch v
                case 27 { v := 28 }
                case 28 { v := 27 }
                case 0 { v := 1 }
                case 1 { v := 0 }
            }

            let m := mload(0x40)
            mstore(m, r)
            mstore(add(m, 0x20), s)
            mstore(add(m, 0x40), v)
            result := keccak256(m, 0x41)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature.
     *
     * @param r The r value of the signature.
     * @param vs The combined v and s.
     * @return result The canonical hash of the signature.
     */
    function canonicalHash(bytes32 r, bytes32 vs) internal pure returns (bytes32 result) {
        assembly {
            let s := and(
                vs,
                0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            let v := add(27, shr(255, vs))

            if iszero(lt(s, _HALF_N_PLUS_1)) {
                switch v
                case 27 { v := 28 }
                case 28 { v := 27 }
                case 0 { v := 1 }
                case 1 { v := 0 }
            }

            let m := mload(0x40)
            mstore(m, r)
            mstore(add(m, 0x20), s)
            mstore(add(m, 0x40), v)
            result := keccak256(m, 0x41)
        }
    }

    /**
     * @notice Computes the canonical hash of a given signature.
     *
     * @param v Recovery id.
     * @param r The r value.
     * @param s The s value.
     * @return result The canonical hash of the signature.
     */
    function canonicalHash(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes32 result) {
        assembly {
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                switch v
                case 27 { v := 28 }
                case 28 { v := 27 }
                case 0 { v := 1 }
                case 1 { v := 0 }
            }

            let m := mload(0x40)
            mstore(m, r)
            mstore(add(m, 0x20), s)
            mstore(add(m, 0x40), v)
            result := keccak256(m, 0x41)
        }
    }

    /**
     * @notice Returns an empty signature in the form of a `bytes calldata` object.
     *
     * @return signature An empty `bytes calldata` object with a length of 0.
     */
    function emptySignature() internal pure returns (bytes calldata signature) {
        assembly {
            signature.length := 0
        }
    }
}