// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Minimal ERC1967-style UUPS upgradeability contract.
contract UUPSUpgradeable {
    /// @dev Emitted when the implementation is upgraded.
    event Upgraded(address indexed implementation);

    /// @dev Error thrown when the proxiableUUID check fails.
    error UpgradeFailed();

    /// @dev Storage slot with the address of the current implementation, as per EIP-1967.
    /// bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 internal constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The UUID for this proxiable implementation, equal to `_ERC1967_IMPLEMENTATION_SLOT`.
    bytes32 internal constant _PROXIABLE_UUID = _ERC1967_IMPLEMENTATION_SLOT;

    /// @dev Ensures that the call is made through delegatecall via a proxy.
    modifier onlyProxy() {
        // We are in proxy if address(this) is different from implementation stored in the slot.
        // A simple implementation check: in a proxy call, `address(this)` is the proxy,
        // while the implementation address is stored in the slot.
        address impl;
        bytes32 slot = _ERC1967_IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
        require(address(this) != impl && impl != address(0), "UUPSUpgradeable: not called via proxy");
        _;
    }

    /// @dev Ensures that the function cannot be called through delegatecall.
    modifier notDelegated() {
        // If called via proxy (delegatecall), implementation slot holds a different address.
        address impl;
        bytes32 slot = _ERC1967_IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
        require(address(this) == impl || impl == address(0), "UUPSUpgradeable: must not be delegated");
        _;
    }

    /**
     * @notice A function to authorize an upgrade to a new implementation.
     * @dev This function is virtual and should be overridden by derived contracts to provide specific authorization logic.
     * @param newImplementation The address of the new implementation contract to which the upgrade is being authorized.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual {
        // Intended to be overridden in child contracts, e.g. onlyOwner, onlyRole, etc.
        // Silence compiler warning about unused parameter.
        newImplementation;
        revert("UUPSUpgradeable: authorization not implemented");
    }

    /**
     * @notice Returns the UUID (slot) for the ERC1967 implementation. This function is used to comply with the ERC1967 standard.
     *
     * @dev This function must always return `_ERC1967_IMPLEMENTATION_SLOT` to ensure compatibility with the ERC1967 proxy pattern.
     * It is marked as `virtual` to allow overriding in derived contracts, and `notDelegated` to prevent delegation calls.
     *
     * @return bytes32 The storage slot for the ERC1967 implementation.
     */
    function proxiableUUID() public virtual notDelegated returns (bytes32) {
        return _PROXIABLE_UUID;
    }

    /**
     * @notice Upgrades the contract's implementation to a new address and optionally performs a delegatecall with provided data.
     * @dev This function is restricted to be called only by the proxy contract (`onlyProxy` modifier).
     * 
     * Steps:
     * 1. Authorize the upgrade by calling `_authorizeUpgrade` with the new implementation address.
     * 2. Use inline assembly to:
     *    a. Clear the upper 96 bits of the `newImplementation` address.
     *    b. Check if the `newImplementation` correctly implements the `proxiableUUID` function by comparing the returned value with the expected slot.
     *    c. If the check fails, revert with the `UpgradeFailed` error.
     *    d. Emit the `Upgraded` event with the new implementation address.
     *    e. Update the implementation slot in storage with the new address.
     * 3. If `data` is provided, perform a delegatecall to the new implementation with the provided data:
     *    a. Copy the `data` into memory.
     *    b. Execute the delegatecall to the new implementation.
     *    c. If the delegatecall fails, revert with the returned data.
     *
     * @param newImplementation The address of the new implementation contract.
     * @param data Optional data to be passed to the new implementation via delegatecall.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) public virtual onlyProxy {
        _authorizeUpgrade(newImplementation);

        bytes32 slot = _ERC1967_IMPLEMENTATION_SLOT;
        bytes32 expectedUUID = _PROXIABLE_UUID;

        assembly {
            // 2.a. Clear upper 96 bits of newImplementation
            newImplementation := and(newImplementation, 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)

            // Prepare calldata for proxiableUUID() -> 0x52d1902d
            mstore(0x00, 0x52d1902d00000000000000000000000000000000000000000000000000000000)
            let success := staticcall(gas(), newImplementation, 0x00, 0x04, 0x00, 0x20)

            // If the call failed or returned wrong UUID, revert with UpgradeFailed
            if iszero(success) {
                mstore(0x00, 0x3f0d4f0f) // selector for UpgradeFailed()
                revert(0x1c, 0x04)
            }

            let returnedUUID := mload(0x00)
            if iszero(eq(returnedUUID, expectedUUID)) {
                mstore(0x00, 0x3f0d4f0f) // selector for UpgradeFailed()
                revert(0x1c, 0x04)
            }

            // 2.d. Emit Upgraded(newImplementation)
            // keccak256("Upgraded(address)") = 0x5f6e74d... (compute topic)
            mstore(0x00, 0x5f6e74d000000000000000000000000000000000000000000000000000000000)
            log1(0x1c, 0x20, keccak256(0x00, 0x04))

            // 2.e. Store new implementation in EIP-1967 slot
            sstore(slot, newImplementation)
        }

        // 3. Optional delegatecall with data
        if (data.length > 0) {
            (bool ok, bytes memory returndata) = newImplementation.delegatecall(data);
            if (!ok) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
        }
    }
}