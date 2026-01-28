// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Lifebuoy rescue helper contract.
contract Lifebuoy {
    /// @dev Storage slot for rescue locked flags.
    /// Using a specific slot keeps layout stable for inheritance / proxies.
    uint256 private constant _RESCUE_LOCKED_FLAGS_SLOT =
        uint256(keccak256("solady.lifebuoy.rescue.locked.flags"));

    /// @dev Lock bit for generic ETH rescue.
    uint256 internal constant _LIFEBUOY_RESCUE_ETH_LOCK = 1 << 0;

    /// @dev Lock bit for ERC20 rescue.
    uint256 internal constant _LIFEBUOY_RESCUE_ERC20_LOCK = 1 << 1;

    /// @dev Lock bit for ERC721 rescue.
    uint256 internal constant _LIFEBUOY_RESCUE_ERC721_LOCK = 1 << 2;

    /// @dev Lock bit for ERC1155 rescue.
    uint256 internal constant _LIFEBUOY_RESCUE_ERC1155_LOCK = 1 << 3;

    /// @dev Lock bit for ERC6909 rescue.
    uint256 internal constant _LIFEBUOY_RESCUE_ERC6909_LOCK = 1 << 4;

    /// @dev Lock bit that controls ability to change rescue locks.
    uint256 internal constant _LIFEBUOY_LOCK_RESCUE_LOCK = 1 << 5;

    /// @dev Lock bit that allows deployer access even if other locks exist.
    uint256 internal constant _LIFEBUOY_DEPLOYER_ACCESS_LOCK = 1 << 6;

    /// @dev Lock bit that allows owner access.
    uint256 internal constant _LIFEBUOY_OWNER_ACCESS_LOCK = 1 << 7;

    /// @dev Special mode where all locks are considered enabled.
    uint256 internal constant _LIFEBUOY_MODE_LOCK_ALL = 1 << 255;

    /// @dev Hash tying this deployment to its default deployer.
    bytes32 internal immutable _lifebuoyDeployerHash;

    /// @dev Optional owner address for rescue access.
    address public owner;

    error RescueTransferFailed();
    error RescueNotAuthorized();
    error ZeroAddress();

    /**
     * @notice Initializes the contract with a deployer hash derived from the contract's address and a default deployer address.
     *
     * Steps:
     * 1. Retrieve the default deployer address using `_lifebuoyDefaultDeployer()`.
     * 2. Use inline assembly to:
     *    - Store the contract's address in memory at position 0x00.
     *    - Store the deployer address in memory at position 0x20.
     *    - Compute the keccak256 hash of the concatenated data (0x00 to 0x40).
     * 3. Assign the computed hash to the `_lifebuoyDeployerHash` state variable.
     *
     * @dev This constructor is payable, allowing it to receive Ether during deployment.
     */
    constructor() payable {
        address deployer = _lifebuoyDefaultDeployer();
        owner = deployer;

        bytes32 hash_;
        assembly {
            mstore(0x00, address())
            mstore(0x20, deployer)
            hash_ := keccak256(0x00, 0x40)
        }
        _lifebuoyDeployerHash = hash_;
    }

    /**
     * @notice Returns the address of the transaction originator (tx.origin).
     * @dev This function is a placeholder and may be updated in the future to handle EIP7645 or include an `ecrecover` method.
     * @return The address of the transaction originator.
     */
    function _lifebuoyDefaultDeployer() internal virtual view returns (address) {
        return tx.origin;
    }

    modifier onlyRescuer(uint256 modeLock) {
        _checkRescuer(modeLock);
        _;
    }

    /**
     * @notice Rescues ETH from the contract and transfers it to a specified address.
     * @dev This function is only callable by a designated rescuer, and it uses low-level assembly for gas efficiency.
     *
     * @param to The address to which the ETH will be transferred.
     * @param amount The amount of ETH (in wei) to transfer.
     *
     * Steps:
     * 1. Check if the caller is authorized as a rescuer using the `onlyRescuer` modifier.
     * 2. Use low-level assembly to perform the ETH transfer:
     *    - Attempt to call the `to` address with the specified `amount` of ETH.
     *    - If the transfer fails, revert with the error `RescueTransferFailed()`.
     *
     * @dev The function is marked as `payable` to allow ETH transfers, and it is `virtual` to allow overriding in derived contracts.
     */
    function rescueETH(address to, uint256 amount)
        public
        virtual
        onlyRescuer(_LIFEBUOY_RESCUE_ETH_LOCK)
    {
        if (to == address(0)) revert ZeroAddress();
        assembly {
            let success := call(gas(), to, amount, 0, 0, 0, 0)
            if iszero(success) {
                mstore(0x00, 0x1dd5e6e9) // RescueTransferFailed()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Rescues ERC20 tokens from the contract and transfers them to a specified address.
     *
     * @param token The address of the ERC20 token to be rescued.
     * @param to The address to which the rescued tokens will be transferred.
     * @param amount The amount of tokens to rescue and transfer.
     *
     * Requirements:
     * - The caller must have the `onlyRescuer` modifier, which ensures that only authorized addresses can perform this operation.
     *
     * Steps:
     * 1. Store the `to` and `amount` arguments in memory.
     * 2. Use inline assembly to perform a low-level call to the ERC20 token's `transfer` function.
     * 3. If the call fails, revert with an error indicating that the transfer failed.
     * 4. Restore the overwritten part of the free memory pointer.
     *
     * @dev This function uses inline assembly for gas efficiency and memory safety.
     */
    function rescueERC20(address token, address to, uint256 amount)
        public
        virtual
        onlyRescuer(_LIFEBUOY_RESCUE_ERC20_LOCK)
    {
        if (to == address(0)) revert ZeroAddress();
        assembly {
            let ptr := mload(0x40)
            // function selector: transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), to)
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), token, 0, ptr, 0x44, 0x00, 0x20)

            // Basic success check: either no return data or boolean true.
            let ok := and(success, or(iszero(returndatasize()), eq(mload(0x00), 1)))
            if iszero(ok) {
                mstore(0x00, 0x1dd5e6e9) // RescueTransferFailed()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Rescues an ERC721 token from the contract and transfers it to a specified address.
     *
     * @dev This function is marked as `payable` and can only be called by an address with the `onlyRescuer` modifier.
     * It uses low-level assembly to interact with the ERC721 token contract.
     *
     * @param token The address of the ERC721 token contract.
     * @param to The address to which the token will be transferred.
     * @param id The ID of the ERC721 token to be rescued.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Store the `id` argument in memory.
     * 3. Store the `to` argument in memory.
     * 4. Store the `from` argument (the current contract's address) in memory.
     * 5. Prepare the function selector for `transferFrom(address,address,uint256)`.
     * 6. Execute a low-level call to the ERC721 token contract to transfer the token.
     * 7. If the call fails, revert with an error.
     * 8. Restore the zero slot and free memory pointer to their original states.
     */
    function rescueERC721(address token, address to, uint256 id)
        public
        virtual
        onlyRescuer(_LIFEBUOY_RESCUE_ERC721_LOCK)
    {
        if (to == address(0)) revert ZeroAddress();
        assembly {
            let ptr := mload(0x40)
            // selector: transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), address())
            mstore(add(ptr, 0x24), to)
            mstore(add(ptr, 0x44), id)

            let success := call(gas(), token, 0, ptr, 0x64, 0x00, 0x00)
            if iszero(success) {
                mstore(0x00, 0x1dd5e6e9) // RescueTransferFailed()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Rescues ERC1155 tokens from a specified contract and transfers them to a designated address.
     *
     * @param token The address of the ERC1155 token contract.
     * @param to The address to which the tokens will be transferred.
     * @param id The ID of the token to be transferred.
     * @param amount The amount of tokens to be transferred.
     * @param data Additional data to be passed with the transfer.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Prepare the function selector and arguments for the `safeTransferFrom` call.
     * 3. Store the `from` argument (current contract address).
     * 4. Store the `to` argument (recipient address).
     * 5. Store the `id` argument (token ID).
     * 6. Store the `amount` argument (amount of tokens).
     * 7. Store the offset to `data` and the length of `data`.
     * 8. Copy the `data` from calldata to memory.
     * 9. Execute the `safeTransferFrom` call on the ERC1155 token contract.
     * 10. If the call fails, revert with the error message "RescueTransferFailed".
     *
     * @dev This function is restricted to the `onlyRescuer` modifier, which ensures that only authorized addresses can execute it.
     */
    function rescueERC1155(
        address token,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual onlyRescuer(_LIFEBUOY_RESCUE_ERC1155_LOCK) {
        if (to == address(0)) revert ZeroAddress();
        assembly {
            let ptr := mload(0x40)
            // selector: safeTransferFrom(address,address,uint256,uint256,bytes)
            mstore(ptr, 0xf242432a00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), address()) // from
            mstore(add(ptr, 0x24), to) // to
            mstore(add(ptr, 0x44), id) // id
            mstore(add(ptr, 0x64), amount) // amount
            mstore(add(ptr, 0x84), 0xa0) // offset to data (160 bytes)

            let dataLen := data.length
            mstore(add(ptr, 0xa4), dataLen)

            // copy calldata `data` to memory
            calldatacopy(add(ptr, 0xc4), data.offset, dataLen)

            let totalLen := add(0xc4, dataLen)
            let success := call(gas(), token, 0, ptr, totalLen, 0x00, 0x00)
            if iszero(success) {
                mstore(0x00, 0x1dd5e6e9) // RescueTransferFailed()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Rescues ERC6909 tokens from a specified contract and transfers them to a designated address.
     * @dev This function is marked as `payable` and can only be called by an authorized rescuer.
     *      It uses low-level assembly to interact with the token contract directly.
     *
     * @param token The address of the ERC6909 token contract.
     * @param to The address to which the tokens will be transferred.
     * @param id The ID of the token to be rescued.
     * @param amount The amount of tokens to be rescued.
     *
     * Steps:
     * 1. Cache the free memory pointer.
     * 2. Store the `to`, `id`, and `amount` arguments in memory.
     * 3. Prepare the function selector for the `transfer` function of the ERC6909 token contract.
     * 4. Execute a low-level call to the token contract to transfer the tokens.
     * 5. If the call fails, revert with an error message.
     * 6. Restore the zero slot and free memory pointer to their original states.
     */
    function rescueERC6909(address token, address to, uint256 id, uint256 amount)
        public
        virtual
        onlyRescuer(_LIFEBUOY_RESCUE_ERC6909_LOCK)
    {
        if (to == address(0)) revert ZeroAddress();
        assembly {
            let ptr := mload(0x40)
            // selector: transfer(address,uint256,uint256)
            // keccak256("transfer(address,uint256,uint256)") = 0x84bd6d29...
            mstore(ptr, 0x84bd6d2900000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), to)
            mstore(add(ptr, 0x24), id)
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), token, 0, ptr, 0x64, 0x00, 0x20)
            let ok := and(success, or(iszero(returndatasize()), eq(mload(0x00), 1)))
            if iszero(ok) {
                mstore(0x00, 0x1dd5e6e9) // RescueTransferFailed()
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Retrieves the locked flags for rescue operations.
     *
     * Steps:
     * 1. Use inline assembly to load the value stored at the `_RESCUE_LOCKED_FLAGS_SLOT` storage slot.
     * 2. Return the loaded value as the number of locks.
     */
    function rescueLocked() public virtual view returns (uint256 locks) {
        assembly {
            locks := sload(_RESCUE_LOCKED_FLAGS_SLOT)
        }
    }

    /**
     * @notice Allows the rescuer to lock a specified number of rescue operations.
     *
     * @param locksToSet The number of rescue locks to set.
     *
     * Requirements:
     * - The caller must have the `_LIFEBUOY_LOCK_RESCUE_LOCK` role.
     *
     * Steps:
     * 1. Calls the internal `_lockRescue` function to set the specified number of rescue locks.
     */
    function lockRescue(uint256 locksToSet)
        public
        virtual
        onlyRescuer(_LIFEBUOY_LOCK_RESCUE_LOCK)
    {
        _lockRescue(locksToSet);
    }

    /**
     * @notice Internal function to lock rescue operations by setting specific flags.
     * 
     * @param locksToSet The flags to set for locking rescue operations.
     * 
     * Steps:
     * 1. Use inline assembly to safely interact with storage.
     * 2. Load the current value from the storage slot `_RESCUE_LOCKED_FLAGS_SLOT`.
     * 3. Perform a bitwise OR operation with `locksToSet` to set the new flags.
     * 4. Store the updated value back into the storage slot.
     */
    function _lockRescue(uint256 locksToSet) internal virtual {
        assembly {
            let current := sload(_RESCUE_LOCKED_FLAGS_SLOT)
            sstore(_RESCUE_LOCKED_FLAGS_SLOT, or(current, locksToSet))
        }
    }

    /**
     * @notice Internal function to check if the caller is authorized to perform a rescue operation.
     * 
     * Steps:
     * 1. Retrieve the current rescue locks.
     * 2. Use assembly to perform low-level checks:
     *    - If `modeLock` flag is true, set all bits in `locks` to true.
     *    - Check if the caller is the deployer and the contract is not a proxy.
     *    - If the caller is the deployer and the contract is not a proxy, and the `locks & _LIFEBUOY_DEPLOYER_ACCESS_LOCK` is false, break the loop.
     *    - If the caller is the owner and `locks & _LIFEBUOY_OWNER_ACCESS_LOCK` is false, break the loop.
     * 3. If none of the conditions are met, revert with an error.
     */
    function _checkRescuer(uint256 modeLock) internal virtual view {
        uint256 locks = rescueLocked();

        assembly {
            // If modeLock has the global lock-all bit, treat all bits as locked.
            if and(modeLock, _LIFEBUOY_MODE_LOCK_ALL) {
                locks := not(0)
            }
        }

        address sender = msg.sender;

        // If corresponding operation lock bit is set in `locks`, operation is disabled.
        if ((locks & modeLock) != 0) revert RescueNotAuthorized();

        bool allowed = false;

        // Deployer access: verify hash to ensure same deployer and not proxied.
        if ((locks & _LIFEBUOY_DEPLOYER_ACCESS_LOCK) == 0) {
            address deployer = _lifebuoyDefaultDeployer();
            bytes32 expected;
            assembly {
                mstore(0x00, address())
                mstore(0x20, deployer)
                expected := keccak256(0x00, 0x40)
            }
            if (expected == _lifebuoyDeployerHash && sender == deployer) {
                allowed = true;
            }
        }

        // Owner access.
        if (!allowed && (locks & _LIFEBUOY_OWNER_ACCESS_LOCK) == 0) {
            if (sender == owner && sender != address(0)) {
                allowed = true;
            }
        }

        if (!allowed) revert RescueNotAuthorized();
    }
}