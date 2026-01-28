// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice A small library to deploy contracts deterministically using a CREATE2-deployed proxy
/// that then uses CREATE to deploy the actual contract. This enables deterministic addresses
/// that do not depend on the initCode hash of the deployed contract.
library CREATE3 {
    /**
     * @notice Deploys a contract deterministically using the provided initialization code and salt.
     *
     * @param initCode The bytecode of the contract to be deployed, including the constructor arguments.
     * @param salt A unique value used to ensure deterministic deployment.
     * @return deployed The address of the deployed contract.
     *
     * Steps:
     * 1. Calls the `deployDeterministic` function with a value of 0, the provided `initCode`, and `salt`.
     * 2. Returns the address of the deployed contract.
     */
    function deployDeterministic(bytes memory initCode, bytes32 salt) internal returns (address deployed) {
        return deployDeterministic(0, initCode, salt);
    }

    /**
     * @notice Deploys a contract deterministically using the provided initialization code and salt.
     *
     * @param value Amount of wei to send to the created contract during CREATE.
     * @param initCode The bytecode of the contract to be deployed, including the constructor arguments.
     * @param salt A unique value used to ensure deterministic deployment.
     * @return deployed The address of the deployed contract.
     *
     * Steps:
     * 1. Deploys a small proxy (CREATE3Proxy) using CREATE2 at a deterministic address derived
     *    from the current address, supplied salt and the proxy creation code hash.
     * 2. Calls the proxy, passing `initCode` as calldata and `value` as call value. The proxy's
     *    fallback will execute CREATE with that calldata and return the created address.
     */
    function deployDeterministic(uint256 value, bytes memory initCode, bytes32 salt) internal returns (address deployed) {
        address proxy = predictDeterministicAddress(salt);

        // Try to deploy the proxy via CREATE2. If it already exists, create2 will return zero.
        bytes memory creationCode = type(CREATE3Proxy).creationCode;
        address created;
        assembly {
            created := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }

        // If creation returned zero, ensure the proxy already exists.
        if (created == address(0)) {
            uint256 size;
            assembly { size := extcodesize(proxy) }
            require(size != 0, "CREATE3: deploy failed");
        }

        // Call the proxy with the initCode as calldata to perform the CREATE.
        (bool ok, bytes memory result) = proxy.call{value: value}(initCode);
        require(ok && result.length >= 32, "CREATE3: deployment failed");

        deployed = abi.decode(result, (address));
        require(deployed != address(0), "CREATE3: zero address");
    }

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using CREATE2.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @return deployed The predicted address of the contract to be deployed.
     *
     * Steps:
     * 1. Delegates to [`predictDeterministicAddress(bytes32,address)`](#) using the current contract as deployer.
     */
    function predictDeterministicAddress(bytes32 salt) internal view returns (address deployed) {
        return predictDeterministicAddress(salt, address(this));
    }

    /**
     * @notice Predicts the deterministic address of a contract to be deployed using CREATE2.
     *
     * @param salt A unique salt value used to generate the deterministic address.
     * @param deployer The address of the deployer who will deploy the contract.
     * @return deployed The predicted address of the contract to be deployed.
     *
     * Steps:
     * 1. Compute the address where the proxy will be deployed using CREATE2:
     *      keccak256(0xff ++ deployer ++ salt ++ keccak256(proxyCreationCode))
     * 2. Compute the address of the final contract created by that proxy (nonce = 1):
     *      keccak256( rlp([proxy, 1]) ) -> represented here as keccak256(0xd6,0x94, proxy, 0x01)
     */
    function predictDeterministicAddress(bytes32 salt, address deployer) internal pure returns (address deployed) {
        bytes32 proxyCodeHash = keccak256(type(CREATE3Proxy).creationCode);
        address proxy = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, proxyCodeHash)))));

        // RLP encoding for [address, 0x01] where address is 20 bytes:
        // 0xd6 0x94 <20 bytes address> 0x01
        deployed = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01))))));
    }
}

/// @dev Minimal helper contract used as a proxy. Deployed via CREATE2. When called, the fallback
/// reads calldata and performs CREATE with that calldata as the init code and returns the created address.
contract CREATE3Proxy {
    fallback() external payable {
        assembly {
            // copy calldata to memory
            let len := calldatasize()
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, len)

            // create the new contract with provided value
            let newContract := create(callvalue(), ptr, len)
            if iszero(newContract) {
                // bubble up the failure
                revert(0, 0)
            }

            // store the created address at ptr and return it
            mstore(ptr, newContract)
            return(ptr, 32)
        }
    }
}