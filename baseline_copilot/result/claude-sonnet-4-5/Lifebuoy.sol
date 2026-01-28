```solidity: Lifebuoy.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

abstract contract Lifebuoy {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error Unauthorized();
    error RescueTransferFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 private _lifebuoyDeployerHash;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTANTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 private constant _RESCUE_LOCKED_FLAGS_SLOT = 0x8e94fed44239eb2314ab7a406345e6c5a8f0ccedf3b600de3d004e672c33abf4;

    uint256 private constant _LIFEBUOY_RESCUE_ETH_LOCK = 1 << 0;
    uint256 private constant _LIFEBUOY_RESCUE_ERC20_LOCK = 1 << 1;
    uint256 private constant _LIFEBUOY_RESCUE_ERC721_LOCK = 1 << 2;
    uint256 private constant _LIFEBUOY_RESCUE_ERC1155_LOCK = 1 << 3;
    uint256 private constant _LIFEBUOY_RESCUE_ERC6909_LOCK = 1 << 4;
    uint256 private constant _LIFEBUOY_LOCK_RESCUE_LOCK = 1 << 5;
    uint256 private constant _LIFEBUOY_DEPLOYER_ACCESS_LOCK = 1 << 6;
    uint256 private constant _LIFEBUOY_OWNER_ACCESS_LOCK = 1 << 7;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        assembly {
            mstore(0x00, address())
            mstore(0x20, deployer)
            sstore(_lifebuoyDeployerHash.slot, keccak256(0x00, 0x40))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the address of the transaction originator (tx.origin).
     * @dev This function is a placeholder and may be updated in the future to handle EIP7645 or include an `ecrecover` method.
     * @return The address of the transaction originator.
     */
    function _lifebuoyDefaultDeployer() internal view virtual returns (address) {
        return tx.origin;
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
    function _checkRescuer(uint256 modeLock) internal view virtual {
        uint256 locks = rescueLocked();
        assembly {
            if and(locks, modeLock) {
                locks := not(0)
            }
            
            for {} 1 {} {
                mstore(0x00, address())
                mstore(0x20, origin())
                let deployerHash := keccak256(0x00, 0x40)
                let storedHash := sload(_lifebuoyDeployerHash.slot)
                
                if and(eq(deployerHash, storedHash), iszero(and(locks, _LIFEBUOY_DEPLOYER_ACCESS_LOCK))) {
                    break
                }
                
                mstore(0x00, 0x8da5cb5b)
                if and(
                    and(
                        staticcall(gas(), address(), 0x1c, 0x04, 0x00, 0x20),
                        eq(caller(), mload(0x00))
                    ),
                    iszero(and(locks, _LIFEBUOY_OWNER_ACCESS_LOCK))
                ) {
                    break
                }
                
                mstore(0x00, 0x82b42900)
                revert(0x1c, 0x04)
            }
        }
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
            let slot := _RESCUE_LOCKED_FLAGS_SLOT
            sstore(slot, or(sload(slot), locksToSet))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PUBLIC FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
    function rescueETH(address to, uint256 amount) public payable virtual {
        _checkRescuer(_LIFEBUOY_RESCUE_ETH_LOCK);
        assembly {
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                mstore(0x00, 0x7939f424)
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
    function rescueERC20(address token, address to, uint256 amount) public payable virtual {
        _checkRescuer(_LIFEBUOY_RESCUE_ERC20_LOCK);
        assembly {
            let m := mload(0x40)
            mstore(0x14, to)
            mstore(0x34, amount)
            mstore(0x00, 0xa9059cbb000000000000000000000000)
            if iszero(
                and(
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0)
            mstore(0x40, m)
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
    function rescueERC721(address token, address to, uint256 id) public payable virtual {
        _checkRescuer(_LIFEBUOY_RESCUE_ERC721_LOCK);
        assembly {
            let m := mload(0x40)
            mstore(0x60, id)
            mstore(0x40, to)
            mstore(0x2c, address())
            mstore(0x0c, 0x23b872dd)
            if iszero(call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x00)) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0)
            mstore(0x40, m)
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
    function rescueERC1155(address token, address to, uint256 id, uint256 amount, bytes calldata data) public payable virtual {
        _checkRescuer(_LIFEBUOY_RESCUE_ERC1155_LOCK);
        assembly {
            let m := mload(0x40)
            let len := data.length
            mstore(0x20, address())
            mstore(0x40, to)
            mstore(0x60, id)
            mstore(0x80, amount)
            mstore(0xa0, 0xa0)
            mstore(0xc0, len)
            calldatacopy(0xe0, data.offset, len)
            if iszero(call(gas(), token, 0, 0x1c, add(0xc4, and(add(len, 0x1f), not(0x1f))), 0x00, 0x00)) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x40, m)
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
    function rescueERC6909(address token, address to, uint256 id, uint256 amount) public payable virtual {
        _checkRescuer(_LIFEBUOY_RESCUE_ERC6909_LOCK);
        assembly {
            let m := mload(0x40)
            mstore(0x14, to)
            mstore(0x34, id)
            mstore(0x54, amount)
            mstore(0x00, 0x095bcdb6)
            if iszero(
                and(
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x10, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x54, 0)
            mstore(0x40, m)
        }
    }

    /**
     * @notice Retrieves the locked flags for rescue operations.
     *
     * Steps:
     * 1. Use inline assembly to load the value stored at the `_RESCUE_LOCKED_FLAGS_SLOT` storage slot.
     * 2. Return the loaded value as the number of locks.
     */
    function rescueLocked() public view virtual returns (uint256 locks) {
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
    function lockRescue(uint256 locksToSet) public payable virtual {
        _checkRescuer(_LIFEBUOY_LOCK_RESCUE_LOCK);
        _lockRescue(locksToSet);
    }
}
```
