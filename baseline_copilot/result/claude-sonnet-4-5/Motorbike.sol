// SPDX-License-Identifier: MIT
pragma solidity <0.7.0;

contract Motorbike {
    /**
     * @notice A struct representing a storage slot for an address value.
     * @dev This struct is used to store a single address value in a storage slot.
     */
    struct AddressSlot {
        address value;
    }

    // ERC1967 implementation slot: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @notice Initializes the contract by setting the logic implementation and initializing it.
     *
     * @param _logic The address of the logic contract to be used as the implementation.
     *
     * Steps:
     * 1. Ensure that the provided `_logic` address is a valid contract.
     * 2. Store the `_logic` address in the implementation slot.
     * 3. Delegatecall the `initialize()` function on the `_logic` contract.
     * 4. Ensure that the delegatecall was successful.
     *
     * Reverts:
     * - If `_logic` is not a contract, reverts with "ERC1967: new implementation is not a contract".
     * - If the delegatecall to `initialize()` fails, reverts with "Call failed".
     */
    constructor(address _logic) public {
        require(Address.isContract(_logic), "ERC1967: new implementation is not a contract");
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = _logic;
        (bool success,) = _logic.delegatecall(abi.encodeWithSignature("initialize()"));
        require(success, "Call failed");
    }

    /**
     * @notice Delegates the current call to an implementation address.
     *
     * Steps:
     * 1. Copies the calldata to memory.
     * 2. Performs a delegatecall to the implementation address with the copied calldata.
     * 3. Copies the returned data to memory.
     * 4. Checks the result of the delegatecall:
     *    - If the result is 0, reverts with the returned data.
     *    - Otherwise, returns the returned data.
     *
     * @dev This function uses inline assembly to perform low-level operations.
     * @param implementation The address of the contract to delegate the call to.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice Retrieves the storage slot for an address based on the provided slot identifier.
     *
     * @param slot The bytes32 identifier for the storage slot.
     * @return r The AddressSlot storage reference corresponding to the provided slot.
     *
     * Steps:
     * 1. Use inline assembly to assign the provided slot to the storage reference.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r_slot := slot
        }
    }

    fallback() external payable {
        _delegate(_getAddressSlot(_IMPLEMENTATION_SLOT).value);
    }

    receive() external payable {
        _delegate(_getAddressSlot(_IMPLEMENTATION_SLOT).value);
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

    // ERC1967 implementation slot
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public upgrader;
    uint256 public horsePower;

    // Initializer state tracking
    bool private initialized;

    modifier initializer() {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
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
     * Steps:
     * 1. Authorize the upgrade by calling `_authorizeUpgrade()`.
     * 2. Perform the upgrade to the new implementation address and delegate to it with the provided data.
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
     * This function is called during the upgrade process to verify that only the
     * authorized upgrader address can perform contract upgrades.
     *
     * Requirements:
     * - The caller (msg.sender) must match the stored upgrader address.
     *
     * Emits:
     * - Reverts with "Can't upgrade" error if authorization fails.
     */
    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Can't upgrade");
    }

    /**
     * @notice Upgrades the implementation contract and optionally calls a function on the new implementation.
     *
     * Steps:
     * 1. Set the new implementation contract address.
     * 2. If there is data provided, delegate call the data to the new implementation.
     * 3. Revert if the delegate call fails.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Call failed");
        }
    }

    /**
     * @notice Sets the implementation address for a proxy contract.
     *
     * Steps:
     * 1. Validate that the new implementation address is a contract.
     * 2. Access the implementation storage slot using inline assembly.
     * 3. Store the new implementation address in the designated storage slot.
     *
     * Requirements:
     * - The new implementation must be a valid contract address.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        AddressSlot storage slot;
        assembly {
            slot_slot := _IMPLEMENTATION_SLOT
        }
        slot.value = newImplementation;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
