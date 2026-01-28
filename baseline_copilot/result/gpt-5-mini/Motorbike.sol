pragma solidity <0.7.0;

/**
 * @title Motorbike Proxy + Engine (implementation)
 * @dev Implements the proxy (Motorbike) that delegates to an Engine implementation.
 */

// Shared implementation slot (EIP-1967: keccak256("eip1967.proxy.implementation") - 1)
bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

contract Motorbike {
    /**
     * @notice A struct representing a storage slot for an address value.
     * @dev This struct is used to store a single address value in a storage slot.
     */
    struct AddressSlot {
        address value;
    }

    constructor(address _logic) public {
        require(isContract(_logic), "ERC1967: new implementation is not a contract");

        // Store implementation address in the EIP-1967 implementation slot
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, _logic)
        }

        // Initialize the implementation via delegatecall to initialize()
        (bool ok, ) = _logic.delegatecall(abi.encodeWithSignature("initialize()"));
        require(ok, "Call failed");
    }

    /**
     * @notice Delegates the current call to an implementation address.
     *
     * @dev This function uses inline assembly to perform low-level operations.
     * @param implementation The address of the contract to delegate the call to.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // copy calldata
            calldatacopy(0, 0, calldatasize())

            // delegatecall(gas, to, in_ptr, in_size, out_ptr, out_size)
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // copy returned data
            returndatacopy(0, 0, returndatasize())

            // handle result
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @notice Retrieves the storage slot for an address based on the provided slot identifier.
     *
     * @param slot The bytes32 identifier for the storage slot.
     * @return r The AddressSlot storage reference corresponding to the provided slot.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r_slot := slot
        }
    }

    // Proxy fallback - forward all calls to implementation
    fallback () external payable {
        AddressSlot storage slotRef = _getAddressSlot(IMPLEMENTATION_SLOT);
        _delegate(slotRef.value);
    }

    receive () external payable {
        AddressSlot storage slotRef = _getAddressSlot(IMPLEMENTATION_SLOT);
        _delegate(slotRef.value);
    }

    // Helper: check if an address is a contract
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

contract Engine {
    /**
     * @notice A struct representing a storage slot for an address value.
     * @dev This struct is used to store a single address value in a storage slot.
     */
    struct AddressSlot {
        address value;
    }

    // State variables (storage layout expected for proxied logic)
    uint256 public horsePower;
    address public upgrader;
    bool private _initialized;

    // Reuse the same implementation slot constant (declared at file level)
    // bytes32 constant IMPLEMENTATION_SLOT = ... (shared)

    // initializer modifier (preserves signature in plan)
    modifier initializer() {
        require(!_initialized, "already initialized");
        _initialized = true;
        _;
    }

    /**
     * @notice Initializes the contract with default values.
     *
     * Sets the initial horse power to 1000 and assigns the caller as the upgrader.
     */
    function initialize() external initializer {
        horsePower = 1000;
        upgrader = msg.sender;
    }

    /**
     * @notice Upgrades the contract implementation and calls a function on the new implementation.
     *
     * @param newImplementation The address of the new implementation contract.
     * @param data The encoded calldata to be sent to the new implementation during the upgrade.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade();
        _upgradeToAndCall(newImplementation, data);
    }

    /**
     * @notice Authorizes contract upgrades by checking if the caller is the designated upgrader.
     *
     * Reverts with "Can't upgrade" if authorization fails.
     */
    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Can't upgrade");
    }

    /**
     * @notice Upgrades the implementation contract and optionally calls a function on the new implementation.
     *
     * @param newImplementation The address of the new implementation contract.
     * @param data The encoded calldata to be sent to the new implementation during the upgrade.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);

        if (data.length > 0) {
            // Delegatecall into the new implementation with provided data
            (bool ok, ) = newImplementation.delegatecall(data);
            require(ok, "Call failed");
        }
    }

    /**
     * @notice Sets the implementation address for a proxy contract.
     *
     * Steps:
     * 1. Validate that the new implementation address is a contract.
     * 2. Access the implementation storage slot using inline assembly.
     * 3. Store the new implementation address in the designated storage slot.
     */
    function _setImplementation(address newImplementation) private {
        require(isContract(newImplementation), "ERC1967: new implementation is not a contract");
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    // Helper: check if an address is a contract
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}