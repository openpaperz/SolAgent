// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for checking delegate permissions across V1 and V2 of the delegate registry.
library DelegateCheckerLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONSTANTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The address of the Delegate Registry V2 contract.
    address internal constant DELEGATE_REGISTRY_V2 = 0x00000000000000447e69651d841bD8D104Bed493;

    /// @dev The address of the Delegate Registry V1 contract.
    address internal constant DELEGATE_REGISTRY_V1 = 0x00000000000076A84feF008CDAbe6409d2FE638B;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   DELEGATE FOR ALL CHECKS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Checks if a delegate has been granted full permissions (delegateForAll) for a specific address.
     *
     * @param to The address of the delegate being checked.
     * @param from The address of the delegator (the one who granted permissions).
     * @return isValid A boolean indicating whether the delegate has full permissions.
     *
     * Steps:
     * 1. Load the free memory pointer (`0x40`) into `m`.
     * 2. Store the `from` address in memory at `0x40`.
     * 3. Store the `to` address (shifted left by 96 bits) in memory at `0x2c`.
     * 4. Store the function selector for `checkDelegateForAll(address,address,bytes32)` in memory at `0x0c`.
     * 5. Perform a static call to `DELEGATE_REGISTRY_V2` to check if the delegate has full permissions.
     *    - If the result is `1`, set `isValid` to `true`.
     * 6. If the result from `DELEGATE_REGISTRY_V2` is invalid, perform a static call to `DELEGATE_REGISTRY_V1` with a different function selector.
     *    - If the result is `1`, set `isValid` to `true`.
     * 7. Restore the free memory pointer to its original value.
     */
    function checkDelegateForAll(address to, address from) internal view returns (bool isValid) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0x9c395bc2) // Store the function selector for `checkDelegateForAll(address,address,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0x64, 0x00, 0x20) {
                isValid := eq(mload(0x00), 1) // Check if the result is 1.
            }
            // If the result from V2 is invalid, fallback to V1.
            if iszero(isValid) {
                mstore(0x0c, 0xeabba580) // Store the function selector for V1's `checkDelegateForAll(address,address)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x44, 0x00, 0x20) {
                    isValid := eq(mload(0x00), 1) // Check if the result is 1.
                }
            }
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /**
     * @notice Checks if a delegate has been granted full permissions (delegateForAll) for a specific address.
     *
     * @param to The address of the delegate being checked.
     * @param from The address of the delegator (the one who granted permissions).
     * @return isValid A boolean indicating whether the delegate has full permissions.
     *
     * Steps:
     * 1. Load the free memory pointer (`0x40`) into `m`.
     * 2. Store the `from` address in memory at `0x40`.
     * 3. Store the `to` address (shifted left by 96 bits) in memory at `0x2c`.
     * 4. Store the function selector for `checkDelegateForAll(address,address,bytes32)` in memory at `0x0c`.
     * 5. Perform a static call to `DELEGATE_REGISTRY_V2` to check if the delegate has full permissions.
     *    - If the result is `1`, set `isValid` to `true`.
     * 6. If the result from `DELEGATE_REGISTRY_V2` is invalid, perform a static call to `DELEGATE_REGISTRY_V1` with a different function selector.
     *    - If the result is `1`, set `isValid` to `true`.
     * 7. Restore the free memory pointer to its original value.
     */
    function checkDelegateForAll(address to, address from, bytes32 rights)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x60, rights) // Store `rights` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0x9c395bc2) // Store the function selector for `checkDelegateForAll(address,address,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0x64, 0x00, 0x20) {
                isValid := eq(mload(0x00), 1) // Check if the result is 1.
            }
            // If the result from V2 is invalid, fallback to V1.
            if iszero(isValid) {
                mstore(0x0c, 0xeabba580) // Store the function selector for V1's `checkDelegateForAll(address,address)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x44, 0x00, 0x20) {
                    isValid := eq(mload(0x00), 1) // Check if the result is 1.
                }
            }
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                DELEGATE FOR CONTRACT CHECKS                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Checks if a delegate is authorized for a specific contract on behalf of a delegator.
     *
     * @param to The address of the delegate to check.
     * @param from The address of the delegator (the one who delegated the authority).
     * @param contract_ The address of the contract for which the delegation is being checked.
     * @return isValid A boolean indicating whether the delegate is authorized for the specified contract.
     *
     * Steps:
     * 1. Allocate memory for the function call.
     * 2. Prepare the function call data for `checkDelegateForContract` in both V2 and V1 of the DelegateRegistry.
     * 3. Perform a static call to the DelegateRegistry V2 contract to check delegation.
     * 4. If the V2 check fails, perform a static call to the DelegateRegistry V1 contract as a fallback.
     * 5. Return `true` if the delegate is authorized, otherwise `false`.
     *
     * @dev This function uses inline assembly to optimize gas usage and memory allocation.
     */
    function checkDelegateForContract(address to, address from, address contract_)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0x90c9a2d0) // Store the function selector for `checkDelegateForContract(address,address,address,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0x84, 0x00, 0x20) {
                isValid := eq(mload(0x00), 1) // Check if the result is 1.
            }
            // If the result from V2 is invalid, fallback to V1.
            if iszero(isValid) {
                mstore(0x0c, 0xa3f4df7e) // Store the function selector for V1's `checkDelegateForContract(address,address,address)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x64, 0x00, 0x20) {
                    isValid := eq(mload(0x00), 1) // Check if the result is 1.
                }
            }
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /**
     * @notice Checks if a delegate is authorized for a specific contract on behalf of a delegator.
     *
     * @param to The address of the delegate to check.
     * @param from The address of the delegator (the one who delegated the authority).
     * @param contract_ The address of the contract for which the delegation is being checked.
     * @return isValid A boolean indicating whether the delegate is authorized for the specified contract.
     *
     * Steps:
     * 1. Allocate memory for the function call.
     * 2. Prepare the function call data for `checkDelegateForContract` in both V2 and V1 of the DelegateRegistry.
     * 3. Perform a static call to the DelegateRegistry V2 contract to check delegation.
     * 4. If the V2 check fails, perform a static call to the DelegateRegistry V1 contract as a fallback.
     * 5. Return `true` if the delegate is authorized, otherwise `false`.
     *
     * @dev This function uses inline assembly to optimize gas usage and memory allocation.
     */
    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x80, rights) // Store `rights` at 0x80.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0x90c9a2d0) // Store the function selector for `checkDelegateForContract(address,address,address,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0x84, 0x00, 0x20) {
                isValid := eq(mload(0x00), 1) // Check if the result is 1.
            }
            // If the result from V2 is invalid, fallback to V1.
            if iszero(isValid) {
                mstore(0x0c, 0xa3f4df7e) // Store the function selector for V1's `checkDelegateForContract(address,address,address)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x64, 0x00, 0x20) {
                    isValid := eq(mload(0x00), 1) // Check if the result is 1.
                }
            }
            mstore(0x80, 0) // Clear the scratch space.
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 DELEGATE FOR ERC721 CHECKS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Checks if a delegate is authorized for a specific ERC721 token.
     *
     * @param to The address of the delegate.
     * @param from The address of the delegator.
     * @param contract_ The address of the ERC721 contract.
     * @param id The token ID to check.
     * @return isValid A boolean indicating whether the delegate is authorized.
     *
     * Steps:
     * 1. Load memory pointer and prepare memory layout for the delegate check.
     * 2. Store the token ID, contract address, delegator, and delegate addresses in memory.
     * 3. Call the `checkDelegateForERC721` function in the DELEGATE_REGISTRY_V2 contract.
     * 4. If the delegate is not valid, fallback to calling `checkDelegateForToken` in the DELEGATE_REGISTRY_V1 contract.
     * 5. Return the validity of the delegate.
     */
    function checkDelegateForERC721(address to, address from, address contract_, uint256 id)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x80, id) // Store `id` at 0x80.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0xf4b2bcb4) // Store the function selector for `checkDelegateForERC721(address,address,address,uint256,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0xa4, 0x00, 0x20) {
                isValid := eq(mload(0x00), 1) // Check if the result is 1.
            }
            // If the result from V2 is invalid, fallback to V1.
            if iszero(isValid) {
                mstore(0x0c, 0xaba69cf8) // Store the function selector for V1's `checkDelegateForToken(address,address,address,uint256)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x84, 0x00, 0x20) {
                    isValid := eq(mload(0x00), 1) // Check if the result is 1.
                }
            }
            mstore(0x80, 0) // Clear the scratch space.
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /**
     * @notice Checks if a delegate is authorized for a specific ERC721 token.
     *
     * @param to The address of the delegate.
     * @param from The address of the delegator.
     * @param contract_ The address of the ERC721 contract.
     * @param id The token ID to check.
     * @return isValid A boolean indicating whether the delegate is authorized.
     *
     * Steps:
     * 1. Load memory pointer and prepare memory layout for the delegate check.
     * 2. Store the token ID, contract address, delegator, and delegate addresses in memory.
     * 3. Call the `checkDelegateForERC721` function in the DELEGATE_REGISTRY_V2 contract.
     * 4. If the delegate is not valid, fallback to calling `checkDelegateForToken` in the DELEGATE_REGISTRY_V1 contract.
     * 5. Return the validity of the delegate.
     */
    function checkDelegateForERC721(address to, address from, address contract_, uint256 id, bytes32 rights)
        internal
        view
        returns (bool isValid)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0xa0, rights) // Store `rights` at 0xa0.
            mstore(0x80, id) // Store `id` at 0x80.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0xf4b2bcb4) // Store the function selector for `checkDelegateForERC721(address,address,address,uint256,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0xa4, 0x00, 0x20) {
                isValid := eq(mload(0x00), 1) // Check if the result is 1.
            }
            // If the result from V2 is invalid, fallback to V1.
            if iszero(isValid) {
                mstore(0x0c, 0xaba69cf8) // Store the function selector for V1's `checkDelegateForToken(address,address,address,uint256)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x84, 0x00, 0x20) {
                    isValid := eq(mload(0x00), 1) // Check if the result is 1.
                }
            }
            mstore(0xa0, 0) // Clear the scratch space.
            mstore(0x80, 0) // Clear the scratch space.
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 DELEGATE FOR ERC20 CHECKS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Checks the delegated rights for ERC20 tokens between two addresses for a specific contract.
     * @dev This function uses low-level assembly to interact with the delegate registry contracts (V1 and V2).
     * It checks if the `to` address has the specified `rights` delegated from the `from` address for the `contract_`.
     * If the rights are not found in V2, it falls back to checking V1.
     *
     * Steps:
     * 1. Load memory pointer `m` at 0x40.
     * 2. Store the function selector and parameters in memory for the `checkDelegateForERC20` call.
     * 3. Perform a static call to the DELEGATE_REGISTRY_V2 contract to check for delegated rights.
     * 4. Multiply the result by the amount returned to ensure correctness.
     * 5. If no rights are found in V2, fall back to checking DELEGATE_REGISTRY_V1 using the `checkDelegateForContract` function.
     * 6. Return the amount of delegated rights found.
     *
     * @param to The address to check for delegated rights.
     * @param from The address that delegated the rights.
     * @param contract_ The contract address for which the rights are being checked.
     * @param rights The specific rights being checked.
     * @return amount The amount of delegated rights found (0 if none).
     */
    function checkDelegateForERC20(address to, address from, address contract_)
        internal
        view
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0x49e43966) // Store the function selector for `checkDelegateForERC20(address,address,address,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0x84, 0x00, 0x40) {
                // Multiply the result by the amount returned.
                amount := mul(eq(mload(0x00), 1), mload(0x20))
            }
            // If no rights are found in V2, fallback to V1.
            if iszero(amount) {
                mstore(0x0c, 0xa3f4df7e) // Store the function selector for V1's `checkDelegateForContract(address,address,address)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x64, 0x00, 0x20) {
                    // If valid, set amount to max uint256.
                    amount := mul(eq(mload(0x00), 1), not(0))
                }
            }
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /**
     * @notice Checks the delegated rights for ERC20 tokens between two addresses for a specific contract.
     * @dev This function uses low-level assembly to interact with the delegate registry contracts (V1 and V2).
     * It checks if the `to` address has the specified `rights` delegated from the `from` address for the `contract_`.
     * If the rights are not found in V2, it falls back to checking V1.
     *
     * Steps:
     * 1. Load memory pointer `m` at 0x40.
     * 2. Store the function selector and parameters in memory for the `checkDelegateForERC20` call.
     * 3. Perform a static call to the DELEGATE_REGISTRY_V2 contract to check for delegated rights.
     * 4. Multiply the result by the amount returned to ensure correctness.
     * 5. If no rights are found in V2, fall back to checking DELEGATE_REGISTRY_V1 using the `checkDelegateForContract` function.
     * 6. Return the amount of delegated rights found.
     *
     * @param to The address to check for delegated rights.
     * @param from The address that delegated the rights.
     * @param contract_ The contract address for which the rights are being checked.
     * @param rights The specific rights being checked.
     * @return amount The amount of delegated rights found (0 if none).
     */
    function checkDelegateForERC20(address to, address from, address contract_, bytes32 rights)
        internal
        view
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x80, rights) // Store `rights` at 0x80.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0x49e43966) // Store the function selector for `checkDelegateForERC20(address,address,address,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0x84, 0x00, 0x40) {
                // Multiply the result by the amount returned.
                amount := mul(eq(mload(0x00), 1), mload(0x20))
            }
            // If no rights are found in V2, fallback to V1.
            if iszero(amount) {
                mstore(0x0c, 0xa3f4df7e) // Store the function selector for V1's `checkDelegateForContract(address,address,address)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x64, 0x00, 0x20) {
                    // If valid, set amount to max uint256.
                    amount := mul(eq(mload(0x00), 1), not(0))
                }
            }
            mstore(0x80, 0) // Clear the scratch space.
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                DELEGATE FOR ERC1155 CHECKS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Checks the delegated rights for an ERC1155 token between two addresses.
     *
     * @param to The address to which the rights are delegated.
     * @param from The address from which the rights are delegated.
     * @param contract_ The address of the ERC1155 contract.
     * @param id The ID of the ERC1155 token.
     * @param rights The specific rights being checked.
     *
     * @return amount The amount of delegated rights, if any.
     *
     * Steps:
     * 1. Load memory pointer and prepare memory layout for the delegate check.
     * 2. Store the parameters in memory for the delegate check.
     * 3. Perform a static call to the DELEGATE_REGISTRY_V2 contract to check for ERC1155 delegation.
     * 4. Calculate the amount of delegated rights based on the result.
     * 5. If no rights are found or if the rights are invalid, fallback to checking the DELEGATE_REGISTRY_V1 contract.
     * 6. Return the amount of delegated rights.
     */
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 id)
        internal
        view
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0x80, id) // Store `id` at 0x80.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0xe00cd27e) // Store the function selector for `checkDelegateForERC1155(address,address,address,uint256,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0xa4, 0x00, 0x40) {
                // Calculate the amount based on the result.
                amount := mul(eq(mload(0x00), 1), mload(0x20))
            }
            // If no rights are found in V2, fallback to V1.
            if iszero(amount) {
                mstore(0x0c, 0xaba69cf8) // Store the function selector for V1's `checkDelegateForToken(address,address,address,uint256)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x84, 0x00, 0x20) {
                    // If valid, set amount to max uint256.
                    amount := mul(eq(mload(0x00), 1), not(0))
                }
            }
            mstore(0x80, 0) // Clear the scratch space.
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /**
     * @notice Checks the delegated rights for an ERC1155 token between two addresses.
     *
     * @param to The address to which the rights are delegated.
     * @param from The address from which the rights are delegated.
     * @param contract_ The address of the ERC1155 contract.
     * @param id The ID of the ERC1155 token.
     * @param rights The specific rights being checked.
     *
     * @return amount The amount of delegated rights, if any.
     *
     * Steps:
     * 1. Load memory pointer and prepare memory layout for the delegate check.
     * 2. Store the parameters in memory for the delegate check.
     * 3. Perform a static call to the DELEGATE_REGISTRY_V2 contract to check for ERC1155 delegation.
     * 4. Calculate the amount of delegated rights based on the result.
     * 5. If no rights are found or if the rights are invalid, fallback to checking the DELEGATE_REGISTRY_V1 contract.
     * 6. Return the amount of delegated rights.
     */
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 id, bytes32 rights)
        internal
        view
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(0xa0, rights) // Store `rights` at 0xa0.
            mstore(0x80, id) // Store `id` at 0x80.
            mstore(0x60, contract_) // Store `contract_` at 0x60.
            mstore(0x40, from) // Store `from` at 0x40.
            mstore(0x2c, shl(96, to)) // Store `to` (shifted left by 96 bits) at 0x2c.
            mstore(0x0c, 0xe00cd27e) // Store the function selector for `checkDelegateForERC1155(address,address,address,uint256,bytes32)` at 0x0c.
            // Perform a static call to DELEGATE_REGISTRY_V2.
            if staticcall(gas(), DELEGATE_REGISTRY_V2, 0x1c, 0xa4, 0x00, 0x40) {
                // Calculate the amount based on the result.
                amount := mul(eq(mload(0x00), 1), mload(0x20))
            }
            // If no rights are found in V2, fallback to V1.
            if iszero(amount) {
                mstore(0x0c, 0xaba69cf8) // Store the function selector for V1's `checkDelegateForToken(address,address,address,uint256)` at 0x0c.
                if staticcall(gas(), DELEGATE_REGISTRY_V1, 0x1c, 0x84, 0x00, 0x20) {
                    // If valid, set amount to max uint256.
                    amount := mul(eq(mload(0x00), 1), not(0))
                }
            }
            mstore(0xa0, 0) // Clear the scratch space.
            mstore(0x80, 0) // Clear the scratch space.
            mstore(0x60, 0) // Clear the scratch space.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }
}
