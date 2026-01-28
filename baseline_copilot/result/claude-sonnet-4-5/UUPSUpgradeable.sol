```solidity: UUPSUpgradeable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice UUPS proxy mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/UUPSUpgradeable.sol)
/// @author Modified from OpenZeppelin
/// (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/utils/UUPSUpgradeable.sol)
///
/// Note:
/// - This implementation is intended to be used with ERC1967 proxies.
/// See: `LibClone.deployERC1967` and related functions.
/// - This implementation is NOT compatible with legacy OpenZeppelin proxies
/// which do not store the implementation at `_ERC1967_IMPLEMENTATION_SLOT`.
abstract contract UUPSUpgradeable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The upgrade failed.
    error UpgradeFailed();

    /// @dev The call is from an unauthorized call context.
    error UnauthorizedCallContext();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when the proxy's implementation is upgraded.
    event Upgraded(address indexed implementation);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          IMMUTABLES                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev For checking if the context is a delegate call.
    uint256 private immutable __self = uint256(uint160(address(this)));

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          MODIFIERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Requires that the execution is performed through a proxy.
    modifier onlyProxy() {
        uint256 s = __self;
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller's address is the same as the immutable `__self`,
            // we are not being called via delegatecall from the proxy.
            if eq(s, address()) {
                mstore(0x00, 0x9f03a026) // `UnauthorizedCallContext()`.
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    /// @dev Requires that the execution is NOT performed via delegatecall.
    /// This is the opposite of `onlyProxy`.
    modifier notDelegated() {
        uint256 s = __self;
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller's address is different from the immutable `__self`,
            // we are being called via delegatecall.
            if iszero(eq(s, address())) {
                mstore(0x00, 0x9f03a026) // `UnauthorizedCallContext()`.
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INTERNAL CONSTANTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ERC-1967 storage slot for the implementation in the proxy.
    /// `uint256(keccak256("eip1967.proxy.implementation")) - 1`.
    bytes32 internal constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL / PRIVATE HELPERS                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice A function to authorize an upgrade to a new implementation.
     * @dev This function is virtual and should be overridden by derived contracts to provide specific authorization logic.
     * @param newImplementation The address of the new implementation contract to which the upgrade is being authorized.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PUBLIC FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the UUID (slot) for the ERC1967 implementation. This function is used to comply with the ERC1967 standard.
     *
     * @dev This function must always return `_ERC1967_IMPLEMENTATION_SLOT` to ensure compatibility with the ERC1967 proxy pattern.
     * It is marked as `virtual` to allow overriding in derived contracts, and `notDelegated` to prevent delegation calls.
     *
     * @return bytes32 The storage slot for the ERC1967 implementation.
     */
    function proxiableUUID() public view virtual notDelegated returns (bytes32) {
        return _ERC1967_IMPLEMENTATION_SLOT;
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
    function upgradeToAndCall(address newImplementation, bytes calldata data)
        public
        payable
        virtual
        onlyProxy
    {
        _authorizeUpgrade(newImplementation);
        /// @solidity memory-safe-assembly
        assembly {
            // Clear the upper 96 bits of the `newImplementation` address.
            newImplementation := shr(96, shl(96, newImplementation))
            
            // Store the function selector of `proxiableUUID()` in memory.
            mstore(0x00, 0x52d1902d) // `proxiableUUID()` selector.
            
            // Check if the new implementation correctly implements `proxiableUUID()`.
            // We perform a staticcall and check if it returns the expected slot.
            if iszero(
                and(
                    // Check that the staticcall succeeded.
                    staticcall(gas(), newImplementation, 0x1c, 0x04, 0x00, 0x20),
                    // Check that exactly 32 bytes were returned.
                    eq(returndatasize(), 0x20)
                )
            ) {
                mstore(0x00, 0x55299b49) // `UpgradeFailed()`.
                revert(0x1c, 0x04)
            }
            
            // Load the returned slot value.
            let returnedSlot := mload(0x00)
            
            // Check if the returned value matches the expected implementation slot.
            if iszero(eq(returnedSlot, _ERC1967_IMPLEMENTATION_SLOT)) {
                mstore(0x00, 0x55299b49) // `UpgradeFailed()`.
                revert(0x1c, 0x04)
            }
            
            // Emit the `Upgraded` event.
            log2(0x00, 0x00, 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b, newImplementation)
            
            // Update the implementation slot in storage.
            sstore(_ERC1967_IMPLEMENTATION_SLOT, newImplementation)
        }
        
        // If data is provided, perform a delegatecall to the new implementation.
        if (data.length != 0) {
            /// @solidity memory-safe-assembly
            assembly {
                // Copy the `data` into memory.
                calldatacopy(0x00, data.offset, data.length)
                
                // Execute the delegatecall to the new implementation.
                if iszero(delegatecall(gas(), newImplementation, 0x00, data.length, 0x00, 0x00)) {
                    // If the delegatecall fails, revert with the returned data.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
            }
        }
    }
}
```