// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Minimal IERC1822 interface required for UUPS checks.
interface IERC1822Proxiable {
    function proxiableUUID() external returns (bytes32);
}

error UpgradeFailed();
error Unauthorized();

contract UUPSUpgradeable {
    // Emitted when the implementation is upgraded.
    event Upgraded(address indexed implementation);

    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 internal constant _ERC1967_IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    // Storage slot sentinel for this implementation's own address to detect delegatecalls.
    address private immutable __self;

    constructor() {
        __self = address(this);
    }

    /**
     * @notice A function to authorize an upgrade to a new implementation.
     * @dev This function is virtual and should be overridden by derived contracts to provide specific authorization logic.
     * @param newImplementation The address of the new implementation contract to which the upgrade is being authorized.
     */
    function _authorizeUpgrade(address /* newImplementation */) internal virtual {
        revert Unauthorized();
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
    function upgradeToAndCall(address newImplementation, bytes calldata data) public virtual onlyProxy {
        _authorizeUpgrade(newImplementation);

        // Clear upper bits and verify proxiableUUID via a staticcall (assembly used for the call).
        address cleanImpl = address(uint160(newImplementation));
        bytes32 slot = _ERC1967_IMPLEMENTATION_SLOT;
        bytes4 selector = IERC1822Proxiable.proxiableUUID.selector;
        bool ok;
        bytes32 returned;

        assembly {
            // prepare calldata for proxiableUUID() selector (4 bytes)
            let ptr := mload(0x40)
            mstore(ptr, shl(224, selector))
            // staticcall to the implementation
            ok := staticcall(gas(), cleanImpl, ptr, 0x04, ptr, 0x20)
            returned := mload(ptr)
        }

        if (!ok || returned != slot) revert UpgradeFailed();

        // Emit event and update implementation slot
        emit Upgraded(cleanImpl);
        _setImplementation(cleanImpl);

        // If data provided, delegatecall into the new implementation and bubble up revert if any.
        if (data.length > 0) {
            (bool success, bytes memory returndata) = cleanImpl.delegatecall(data);
            if (!success) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
        }
    }

    // --- Internal helpers ---

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = _ERC1967_IMPLEMENTATION_SLOT;
        uint256 v;
        assembly {
            v := sload(slot)
        }
        impl = address(uint160(uint256(v)));
    }

    function _setImplementation(address newImpl) private {
        bytes32 slot = _ERC1967_IMPLEMENTATION_SLOT;
        uint256 v = uint256(uint160(newImpl));
        assembly {
            sstore(slot, v)
        }
    }

    // --- Modifiers ---

    /**
     * @dev Ensures the function is not being called through a delegatecall.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Ensures the function is called through the proxy (delegatecall) and that the proxy's implementation points to this contract.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "UUPSUpgradeable: must be called through delegatecall");
        require(_getImplementation() == __self, "UUPSUpgradeable: must be called through active proxy");
        _;
    }
}