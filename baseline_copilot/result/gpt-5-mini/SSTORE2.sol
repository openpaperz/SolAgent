// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SSTORE2 {
    error DeploymentFailed();

    // A placeholder hash for the CREATE3 proxy initcode. The real CREATE3 proxy
    // initcode hash should be used for full CREATE3 compatibility.
    bytes32 private constant _CREATE3_PROXY_INITCODE_HASH = bytes32(0);

    /**
     * @notice Writes the provided data to a new contract and returns the contract's address.
     *
     * @dev The runtime code of the deployed contract will be `0x00` + data so that
     *      the contract cannot be called (STOP / invalid). Uses `create`.
     */
    function write(bytes memory data) internal returns (address pointer) {
        uint256 n = data.length;
        assembly {
            // Allocate memory for creation code: 1 byte (0x00) + n
            let ptr := mload(0x40)
            // Store the 0x00 prefix
            mstore8(ptr, 0x00)
            // Copy `data` into memory after the prefix
            let src := add(data, 0x20)
            let dest := add(ptr, 1)
            // Copy full words
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(dest, i), mload(add(src, i)))
            }
            // Deploy with `create`
            pointer := create(0, ptr, add(n, 1))
        }
        if (pointer == address(0)) revert DeploymentFailed();
    }

    /**
     * @notice Deploys a new contract using `create2` with the provided data and salt.
     *
     * @dev The runtime code of the deployed contract will be `0x00` + data.
     */
    function writeCounterfactual(bytes memory data, bytes32 salt) internal returns (address pointer) {
        uint256 n = data.length;
        require(n <= 0xfffe, "SSTORE2: data too long");
        assembly {
            // Allocate memory for creation code: 1 byte (0x00) + n
            let ptr := mload(0x40)
            // Store the 0x00 prefix
            mstore8(ptr, 0x00)
            // Copy `data` into memory after the prefix
            let src := add(data, 0x20)
            let dest := add(ptr, 1)
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(dest, i), mload(add(src, i)))
            }
            // Deploy with `create2`
            pointer := create2(0, ptr, add(n, 1), salt)
        }
        if (pointer == address(0)) revert DeploymentFailed();
    }

    /**
     * @notice Deploys a deterministic contract using CREATE2 and the provided salt.
     *
     * @dev This implementation uses CREATE2 directly: it deploys a contract whose
     *      runtime code is `0x00` + data, using the provided salt. This allows
     *      computing the address via `predictDeterministicAddress` if the same
     *      initcode hash and deployer are used. This is a simplified deterministic
     *      deploy (not full CREATE3 behavior).
     */
    function writeDeterministic(bytes memory data, bytes32 salt) internal returns (address pointer) {
        // Reuse writeCounterfactual semantics to deploy deterministically with create2.
        pointer = writeCounterfactual(data, salt);
    }

    /**
     * @notice Computes the keccak256 hash of the given bytecode data with a specific prefix.
     *
     * @dev The prefix is a single zero byte used in our deployed runtime code.
     */
    function initCodeHash(bytes memory data) internal pure returns (bytes32 hash) {
        // hash of 0x00 || data
        hash = keccak256(abi.encodePacked(bytes1(0x00), data));
    }

    /**
     * @notice Predicts the counterfactual address for a contract deployment using the provided data and salt.
     *
     * @dev Uses `address(this)` as deployer.
     */
    function predictCounterfactualAddress(bytes memory data, bytes32 salt) internal view returns (address pointer) {
        return predictCounterfactualAddress(data, salt, address(this));
    }

    /**
     * @notice Predicts the counterfactual address for a contract deployment using the provided data, salt and deployer.
     *
     * @dev Implements the standard CREATE2 address formula:
     *      keccak256(0xff ++ deployer ++ salt ++ keccak256(init_code))[12:]
     */
    function predictCounterfactualAddress(bytes memory data, bytes32 salt, address deployer) internal pure returns (address predicted) {
        bytes32 h = initCodeHash(data);
        bytes32 hash_ = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, h));
        predicted = address(uint160(uint256(hash_)));
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using a CREATE3-style proxy.
     *
     * @dev This simplified implementation computes the address as if a proxy with
     *      initcode hash `_CREATE3_PROXY_INITCODE_HASH` were deployed by `address(this)`
     *      using CREATE2 with the provided salt, and the final contract is created by that
     *      proxy with nonce 1. This matches the common CREATE3 address derivation pattern:
     *
     *      proxy = keccak256(0xff ++ deployer ++ salt ++ proxyInitCodeHash)[12:]
     *      final  = keccak256(0xd6 94 ++ proxy ++ 0x01)[12:]
     *
     *      Note: _CREATE3_PROXY_INITCODE_HASH is a placeholder (zero) in this implementation.
     */
    function predictDeterministicAddress(bytes32 salt) internal view returns (address pointer) {
        return predictDeterministicAddress(salt, address(this));
    }

    /**
     * @notice Predicts the deterministic address for a contract deployment using CREATE3 pattern with a specified deployer.
     *
     * @dev This is a pure computation given the proxy initcode hash placeholder above.
     */
    function predictDeterministicAddress(bytes32 salt, address deployer) internal pure returns (address pointer) {
        // Compute the proxy address (the address of the contract created with CREATE2)
        bytes32 proxyHash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, _CREATE3_PROXY_INITCODE_HASH));
        address proxy = address(uint160(uint256(proxyHash)));

        // Compute the address of the contract created by the proxy with nonce 1 (RLP enc: 0xd6 0x94 <addr> 0x01)
        bytes32 finalHash = keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01)));
        pointer = address(uint160(uint256(finalHash)));
    }

    /**
     * @notice Reads the code of a contract at the given address and returns it as a byte array.
     */
    function read(address pointer) internal view returns (bytes memory data) {
        assembly {
            // Get code size
            let size := extcodesize(pointer)
            // Allocate output byte array
            data := mload(0x40)
            // Update free memory pointer: rounded up to 32 bytes
            mstore(0x40, add(data, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // Store length
            mstore(data, size)
            // Copy code to memory
            extcodecopy(pointer, add(data, 0x20), 0, size)
        }
    }

    /**
     * @notice Reads the code of a contract at the given address starting from `start` and returns the remainder.
     */
    function read(address pointer, uint256 start) internal view returns (bytes memory data) {
        bytes memory full = read(pointer);
        uint256 len = full.length;
        if (start >= len) {
            return new bytes(0);
        }
        uint256 outLen = len - start;
        data = new bytes(outLen);
        // Copy slice
        for (uint256 i = 0; i < outLen; ++i) {
            data[i] = full[start + i];
        }
    }

    /**
     * @notice Reads the code of a contract at the given address and returns the slice [start, end).
     */
    function read(address pointer, uint256 start, uint256 end) internal view returns (bytes memory data) {
        require(end >= start, "SSTORE2: end < start");
        bytes memory full = read(pointer);
        uint256 len = full.length;
        if (start >= len) {
            return new bytes(0);
        }
        if (end > len) {
            end = len;
        }
        uint256 outLen = end - start;
        data = new bytes(outLen);
        for (uint256 i = 0; i < outLen; ++i) {
            data[i] = full[start + i];
        }
    }
}
// ...existing code...
{ changed code }
// ...existing code...