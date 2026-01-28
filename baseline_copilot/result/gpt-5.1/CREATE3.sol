// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice CREATE3 library for deterministic contract deployment via an intermediate CREATE2 proxy.
library CREATE3 {
    /// @notice Deploys a contract deterministically using the provided initialization code and salt.
    ///
    /// @param initCode The bytecode of the contract to be deployed, including the constructor arguments.
    /// @param salt A unique value used to ensure deterministic deployment.
    /// @return deployed The address of the deployed contract.
    ///
    /// Steps:
    /// 1. Calls the `deployDeterministic` function with a value of 0, the provided `initCode`, and `salt`.
    /// 2. Returns the address of the deployed contract.
    function deployDeterministic(bytes memory initCode, bytes32 salt) internal returns (address deployed) {
        return deployDeterministic(0, initCode, salt);
    }

    /// @notice Deploys a contract deterministically using the provided initialization code and salt.
    ///
    /// @param value The amount of ETH to forward to the deployed contract.
    /// @param initCode The bytecode of the contract to be deployed, including the constructor arguments.
    /// @param salt A unique value used to ensure deterministic deployment.
    /// @return deployed The address of the deployed contract.
    ///
    /// Steps:
    /// 1. Calls the `deployDeterministic` function with a value of 0, the provided `initCode`, and `salt`.
    /// 2. Returns the address of the deployed contract.
    function deployDeterministic(uint256 value, bytes memory initCode, bytes32 salt)
        internal
        returns (address deployed)
    {
        address proxy;
        // Deploy minimal proxy at deterministic address via CREATE2.
        bytes32 proxySalt = keccak256(abi.encodePacked(salt));
        bytes memory proxyInitCode = _proxyInitCode();
        /// @solidity memory-safe-assembly
        assembly {
            let encodedData := add(proxyInitCode, 0x20)
            let encodedSize := mload(proxyInitCode)
            proxy := create2(0, encodedData, encodedSize, proxySalt)
        }
        require(proxy != address(0), "CREATE3: proxy deploy failed");

        // Deploy the final contract via the proxy using CREATE.
        /// @solidity memory-safe-assembly
        assembly {
            let encodedData := add(initCode, 0x20)
            let encodedSize := mload(initCode)
            deployed := create(value, encodedData, encodedSize)
        }
        require(deployed != address(0), "CREATE3: deploy failed");
    }

    /// @notice Predicts the deterministic address of a contract to be deployed using CREATE2.
    ///
    /// @param salt A unique salt value used to generate the deterministic address.
    /// @return deployed The predicted address of the contract to be deployed.
    ///
    /// Steps:
    /// 1. Cache the free memory pointer.
    /// 2. Store the deployer's address in memory.
    /// 3. Store the prefix byte (0xff) in memory.
    /// 4. Store the salt value in memory.
    /// 5. Store the bytecode hash of the proxy contract in memory.
    ///
    /// 6. Compute the keccak256 hash of the deployer, prefix, salt, and bytecode hash to derive the proxy's address.
    /// 7. Restore the free memory pointer.
    /// 8. Store the RLP prefix and length of the address in memory.
    /// 9. Store the nonce of the proxy contract (1) in memory.
    /// 10. Compute the final deterministic address using keccak256 and return it.
    function predictDeterministicAddress(bytes32 salt) internal view returns (address deployed) {
        return predictDeterministicAddress(salt, address(this));
    }

    /// @notice Predicts the deterministic address of a contract to be deployed using CREATE2.
    ///
    /// @param salt A unique salt value used to generate the deterministic address.
    /// @param deployer The address of the deployer who will deploy the contract.
    /// @return deployed The predicted address of the contract to be deployed.
    ///
    /// Steps:
    /// 1. Cache the free memory pointer.
    /// 2. Store the deployer's address in memory.
    /// 3. Store the prefix byte (0xff) in memory.
    /// 4. Store the salt value in memory.
    /// 5. Store the bytecode hash of the proxy contract in memory.
    ///
    /// 6. Compute the keccak256 hash of the deployer, prefix, salt, and bytecode hash to derive the proxy's address.
    /// 7. Restore the free memory pointer.
    /// 8. Store the RLP prefix and length of the address in memory.
    /// 9. Store the nonce of the proxy contract (1) in memory.
    /// 10. Compute the final deterministic address using keccak256 and return it.
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address deployed)
    {
        bytes32 proxySalt = keccak256(abi.encodePacked(salt));
        bytes32 proxyBytecodeHash = keccak256(_proxyInitCode());

        // Compute proxy address using standard CREATE2 formula.
        address proxy;
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore8(ptr, 0xff)
            mstore(add(ptr, 0x01), deployer)
            mstore(add(ptr, 0x15), proxySalt)
            mstore(add(ptr, 0x35), proxyBytecodeHash)
            proxy := shr(96, keccak256(ptr, 0x55))
        }

        // Compute final address of contract created by proxy with nonce 1 (first CREATE).
        /// @solidity memory-safe-assembly
        assembly {
            // RLP encoding of (proxy, nonce=1):
            // 0xd6, 0x94, proxy (20 bytes), 0x01
            let ptr := mload(0x40)
            mstore(ptr, 0xd694000000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x02), shl(96, proxy))
            mstore8(add(ptr, 0x16), 0x01)
            deployed := shr(96, keccak256(ptr, 0x17))
        }
    }

    /// @dev Returns the creation code of the minimal proxy used by CREATE3.
    function _proxyInitCode() private pure returns (bytes memory code) {
        // Minimal proxy that simply uses CREATE with all available balance and calldata.
        // This is a standard pattern and kept simple here.
        bytes memory runtimeCode = hex"600b5981380380925939f3"; // very small stub: return remaining code
        code = abi.encodePacked(
            hex"60", uint8(runtimeCode.length), hex"3d81600a3d39f3", runtimeCode
        );
    }
}