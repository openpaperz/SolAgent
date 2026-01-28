// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DelegateCheckerLib {
    /// @dev Delegate Cash V2 registry.
    address internal constant DELEGATE_REGISTRY_V2 =
        0x00000000000000447e69651d841bD8D104Bed493;

    /// @dev Delegate Cash V1 registry.
    address internal constant DELEGATE_REGISTRY_V1 =
        0x00000000000076A84fEf008CDAbe6409d2FE638B;

    // -------------------------------------------------------------------------
    // checkDelegateForAll
    // -------------------------------------------------------------------------

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
    function checkDelegateForAll(address to, address from)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            let m := mload(0x40)

            // Layout:
            // [0x00..0x04) selector
            // [0x04..0x24) to
            // [0x24..0x44) from
            // [0x44..0x64) rights (bytes32, zero for "all")
            mstore(m, 0x9f1b4d6e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), 0) // rights = bytes32(0) for "all"

            // Staticcall V2: checkDelegateForAll(address,address,bytes32)
            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0x64,
                m,
                0x20
            )

            if and(ok, eq(mload(m), 1)) {
                isValid := 1
            }
            if iszero(isValid) {
                // Fallback to V1: checkDelegateForAll(address,address)
                // selector: bytes4(keccak256("checkDelegateForAll(address,address)"))
                mstore(m, 0x7ecebe00000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x44,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    isValid := 1
                }
            }
        }
    }

    /**
     * @notice Checks if a delegate has been granted full permissions (delegateForAll) for a specific address.
     *
     * @param to The address of the delegate being checked.
     * @param from The address of the delegator (the one who granted permissions).
     * @param rights The rights key in Delegate Cash V2.
     * @return isValid A boolean indicating whether the delegate has full permissions.
     *
     * Steps are the same as above, but using the provided `rights`.
     */
    function checkDelegateForAll(address to, address from, bytes32 rights)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            let m := mload(0x40)

            mstore(m, 0x9f1b4d6e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), rights)

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0x64,
                m,
                0x20
            )

            if and(ok, eq(mload(m), 1)) {
                isValid := 1
            }
            if iszero(isValid) {
                mstore(m, 0x7ecebe00000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x44,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    isValid := 1
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // checkDelegateForContract
    // -------------------------------------------------------------------------

    /**
     * @notice Checks if a delegate is authorized for a specific contract on behalf of a delegator.
     *
     * @param to The address of the delegate to check.
     * @param from The address of the delegator (the one who delegated the authority).
     * @param contract_ The address of the contract for which the delegation is being checked.
     * @return isValid A boolean indicating whether the delegate is authorized for the specified contract.
     *
     * @dev This function uses inline assembly to optimize gas usage and memory allocation.
     */
    function checkDelegateForContract(address to, address from, address contract_)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            let m := mload(0x40)

            // V2: checkDelegateForContract(address,address,address,bytes32)
            mstore(m, 0x49b9f7f400000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), 0) // rights = 0

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0x84,
                m,
                0x20
            )

            if and(ok, eq(mload(m), 1)) {
                isValid := 1
            }
            if iszero(isValid) {
                // V1: checkDelegateForContract(address,address,address)
                mstore(m, 0x9b64e1a600000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x64,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    isValid := 1
                }
            }
        }
    }

    /**
     * @notice Checks if a delegate is authorized for a specific contract on behalf of a delegator.
     *
     * @param to The address of the delegate to check.
     * @param from The address of the delegator (the one who delegated the authority).
     * @param contract_ The address of the contract for which the delegation is being checked.
     * @param rights The rights key in Delegate Cash V2.
     * @return isValid A boolean indicating whether the delegate is authorized for the specified contract.
     *
     * @dev This function uses inline assembly to optimize gas usage and memory allocation.
     */
    function checkDelegateForContract(
        address to,
        address from,
        address contract_,
        bytes32 rights
    ) internal view returns (bool isValid) {
        assembly {
            let m := mload(0x40)

            // V2
            mstore(m, 0x49b9f7f400000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), rights)

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0x84,
                m,
                0x20
            )

            if and(ok, eq(mload(m), 1)) {
                isValid := 1
            }
            if iszero(isValid) {
                // V1
                mstore(m, 0x9b64e1a600000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x64,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    isValid := 1
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // checkDelegateForERC721
    // -------------------------------------------------------------------------

    /**
     * @notice Checks if a delegate is authorized for a specific ERC721 token.
     *
     * @param to The address of the delegate.
     * @param from The address of the delegator.
     * @param contract_ The address of the ERC721 contract.
     * @param id The token ID to check.
     * @return isValid A boolean indicating whether the delegate is authorized.
     */
    function checkDelegateForERC721(
        address to,
        address from,
        address contract_,
        uint256 id
    ) internal view returns (bool isValid) {
        assembly {
            let m := mload(0x40)

            // V2: checkDelegateForERC721(address,address,address,uint256,bytes32)
            mstore(m, 0x3bb85d2600000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), id)
            mstore(add(m, 0x84), 0) // rights = 0

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0xa4,
                m,
                0x20
            )

            if and(ok, eq(mload(m), 1)) {
                isValid := 1
            }
            if iszero(isValid) {
                // V1: checkDelegateForToken(address,address,address,uint256)
                mstore(m, 0x8e9f13a200000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)
                mstore(add(m, 0x64), id)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x84,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    isValid := 1
                }
            }
        }
    }

    /**
     * @notice Checks if a delegate is authorized for a specific ERC721 token.
     *
     * @param to The address of the delegate.
     * @param from The address of the delegator.
     * @param contract_ The address of the ERC721 contract.
     * @param id The token ID to check.
     * @param rights The rights key in Delegate Cash V2.
     * @return isValid A boolean indicating whether the delegate is authorized.
     */
    function checkDelegateForERC721(
        address to,
        address from,
        address contract_,
        uint256 id,
        bytes32 rights
    ) internal view returns (bool isValid) {
        assembly {
            let m := mload(0x40)

            // V2
            mstore(m, 0x3bb85d2600000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), id)
            mstore(add(m, 0x84), rights)

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0xa4,
                m,
                0x20
            )

            if and(ok, eq(mload(m), 1)) {
                isValid := 1
            }
            if iszero(isValid) {
                // V1
                mstore(m, 0x8e9f13a200000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)
                mstore(add(m, 0x64), id)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x84,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    isValid := 1
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // checkDelegateForERC20
    // -------------------------------------------------------------------------

    /**
     * @notice Checks the delegated rights for ERC20 tokens between two addresses for a specific contract.
     *
     * @param to The address to check for delegated rights.
     * @param from The address that delegated the rights.
     * @param contract_ The contract address for which the rights are being checked.
     * @return amount The amount of delegated rights found (0 if none).
     */
    function checkDelegateForERC20(address to, address from, address contract_)
        internal
        view
        returns (uint256 amount)
    {
        assembly {
            let m := mload(0x40)

            // V2: checkDelegateForERC20(address,address,address,bytes32)
            mstore(m, 0x0c6a4f8e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), 0) // rights = 0

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0x84,
                m,
                0x40
            )

            // V2 returns (bool, uint256) but we only care about the amount
            if and(ok, gt(mload(add(m, 0x20)), 0)) {
                amount := mload(add(m, 0x20))
            }
            if iszero(amount) {
                // Fallback V1: checkDelegateForContract(address,address,address)
                mstore(m, 0x9b64e1a600000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x64,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    amount := 1
                }
            }
        }
    }

    /**
     * @notice Checks the delegated rights for ERC20 tokens between two addresses for a specific contract.
     *
     * @param to The address to check for delegated rights.
     * @param from The address that delegated the rights.
     * @param contract_ The contract address for which the rights are being checked.
     * @param rights The specific rights being checked.
     * @return amount The amount of delegated rights found (0 if none).
     */
    function checkDelegateForERC20(
        address to,
        address from,
        address contract_,
        bytes32 rights
    ) internal view returns (uint256 amount) {
        assembly {
            let m := mload(0x40)

            // V2
            mstore(m, 0x0c6a4f8e00000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), rights)

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0x84,
                m,
                0x40
            )

            if and(ok, gt(mload(add(m, 0x20)), 0)) {
                amount := mload(add(m, 0x20))
            }
            if iszero(amount) {
                // V1 fallback as boolean
                mstore(m, 0x9b64e1a600000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x64,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    amount := 1
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // checkDelegateForERC1155
    // -------------------------------------------------------------------------

    /**
     * @notice Checks the delegated rights for an ERC1155 token between two addresses.
     *
     * @param to The address to which the rights are delegated.
     * @param from The address from which the rights are delegated.
     * @param contract_ The address of the ERC1155 contract.
     * @param id The ID of the ERC1155 token.
     *
     * @return amount The amount of delegated rights, if any.
     */
    function checkDelegateForERC1155(
        address to,
        address from,
        address contract_,
        uint256 id
    ) internal view returns (uint256 amount) {
        assembly {
            let m := mload(0x40)

            // V2: checkDelegateForERC1155(address,address,address,uint256,bytes32)
            mstore(m, 0x19d898b000000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), id)
            mstore(add(m, 0x84), 0) // rights = 0

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0xa4,
                m,
                0x40
            )

            if and(ok, gt(mload(add(m, 0x20)), 0)) {
                amount := mload(add(m, 0x20))
            }
            if iszero(amount) {
                // Fallback V1: checkDelegateForToken(address,address,address,uint256)
                mstore(m, 0x8e9f13a200000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)
                mstore(add(m, 0x64), id)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x84,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    amount := 1
                }
            }
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
     */
    function checkDelegateForERC1155(
        address to,
        address from,
        address contract_,
        uint256 id,
        bytes32 rights
    ) internal view returns (uint256 amount) {
        assembly {
            let m := mload(0x40)

            // V2
            mstore(m, 0x19d898b000000000000000000000000000000000000000000000000000000000)
            mstore(add(m, 0x04), to)
            mstore(add(m, 0x24), from)
            mstore(add(m, 0x44), contract_)
            mstore(add(m, 0x64), id)
            mstore(add(m, 0x84), rights)

            let ok := staticcall(
                gas(),
                DELEGATE_REGISTRY_V2,
                m,
                0xa4,
                m,
                0x40
            )

            if and(ok, gt(mload(add(m, 0x20)), 0)) {
                amount := mload(add(m, 0x20))
            }
            if iszero(amount) {
                // V1 fallback
                mstore(m, 0x8e9f13a200000000000000000000000000000000000000000000000000000000)
                mstore(add(m, 0x04), to)
                mstore(add(m, 0x24), from)
                mstore(add(m, 0x44), contract_)
                mstore(add(m, 0x64), id)

                ok := staticcall(
                    gas(),
                    DELEGATE_REGISTRY_V1,
                    m,
                    0x84,
                    m,
                    0x20
                )

                if and(ok, eq(mload(m), 1)) {
                    amount := 1
                }
            }
        }
    }
}