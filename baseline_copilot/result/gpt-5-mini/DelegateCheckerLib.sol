// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DelegateCheckerLib {
    // Placeholder addresses for delegate registry contracts.
    // Replace these addresses with the actual deployed registry addresses when integrating.
    address internal constant DELEGATE_REGISTRY_V2 = address(0x0000000000000000000000000000000000000001);
    address internal constant DELEGATE_REGISTRY_V1 = address(0x0000000000000000000000000000000000000002);

    /// @notice Checks if a delegate has been granted full permissions (delegateForAll) for a specific address.
    /// @param to The address of the delegate being checked.
    /// @param from The address of the delegator (the one who granted permissions).
    /// @return isValid A boolean indicating whether the delegate has full permissions.
    function checkDelegateForAll(address to, address from) internal view returns (bool isValid) {
        return checkDelegateForAll(to, from, bytes32(0));
    }

    /// @notice Checks if a delegate has been granted full permissions (delegateForAll) for a specific address.
    /// @param to The address of the delegate being checked.
    /// @param from The address of the delegator (the one who granted permissions).
    /// @return isValid A boolean indicating whether the delegate has full permissions.
    function checkDelegateForAll(address to, address from, bytes32 rights) internal view returns (bool isValid) {
        bytes4 selV2 = bytes4(keccak256("checkDelegateForAll(address,address,bytes32)"));
        bytes memory callDataV2 = abi.encodeWithSelector(selV2, to, from, rights);

        (bool okV2, bytes memory retV2) = DELEGATE_REGISTRY_V2.staticcall(callDataV2);
        if (okV2 && retV2.length >= 32) {
            // expect a bool
            bool res = abi.decode(retV2, (bool));
            if (res) return true;
        }

        // Fallback to V1 with a different selector (no rights param)
        bytes4 selV1 = bytes4(keccak256("checkDelegateForAll(address,address)"));
        bytes memory callDataV1 = abi.encodeWithSelector(selV1, to, from);

        (bool okV1, bytes memory retV1) = DELEGATE_REGISTRY_V1.staticcall(callDataV1);
        if (okV1 && retV1.length >= 32) {
            bool res1 = abi.decode(retV1, (bool));
            if (res1) return true;
        }

        return false;
    }

    /// @notice Checks if a delegate is authorized for a specific contract on behalf of a delegator.
    /// @param to The address of the delegate to check.
    /// @param from The address of the delegator (the one who delegated the authority).
    /// @param contract_ The address of the contract for which the delegation is being checked.
    /// @return isValid A boolean indicating whether the delegate is authorized for the specified contract.
    function checkDelegateForContract(address to, address from, address contract_) internal view returns (bool isValid) {
        return checkDelegateForContract(to, from, contract_, bytes32(0));
    }

    /// @notice Checks if a delegate is authorized for a specific contract on behalf of a delegator.
    /// @param to The address of the delegate to check.
    /// @param from The address of the delegator (the one who delegated the authority).
    /// @param contract_ The address of the contract for which the delegation is being checked.
    /// @return isValid A boolean indicating whether the delegate is authorized for the specified contract.
    function checkDelegateForContract(address to, address from, address contract_, bytes32 rights) internal view returns (bool isValid) {
        bytes4 selV2 = bytes4(keccak256("checkDelegateForContract(address,address,address,bytes32)"));
        bytes memory callDataV2 = abi.encodeWithSelector(selV2, to, from, contract_, rights);

        (bool okV2, bytes memory retV2) = DELEGATE_REGISTRY_V2.staticcall(callDataV2);
        if (okV2 && retV2.length >= 32) {
            bool res = abi.decode(retV2, (bool));
            if (res) return true;
        }

        // Fallback to V1
        bytes4 selV1 = bytes4(keccak256("checkDelegateForContract(address,address,address)"));
        bytes memory callDataV1 = abi.encodeWithSelector(selV1, to, from, contract_);

        (bool okV1, bytes memory retV1) = DELEGATE_REGISTRY_V1.staticcall(callDataV1);
        if (okV1 && retV1.length >= 32) {
            bool res1 = abi.decode(retV1, (bool));
            if (res1) return true;
        }

        return false;
    }

    /// @notice Checks if a delegate is authorized for a specific ERC721 token.
    /// @param to The address of the delegate.
    /// @param from The address of the delegator.
    /// @param contract_ The address of the ERC721 contract.
    /// @param id The token ID to check.
    /// @return isValid A boolean indicating whether the delegate is authorized.
    function checkDelegateForERC721(address to, address from, address contract_, uint256 id) internal view returns (bool isValid) {
        return checkDelegateForERC721(to, from, contract_, id, bytes32(0));
    }

    /// @notice Checks if a delegate is authorized for a specific ERC721 token.
    /// @param to The address of the delegate.
    /// @param from The address of the delegator.
    /// @param contract_ The address of the ERC721 contract.
    /// @param id The token ID to check.
    /// @return isValid A boolean indicating whether the delegate is authorized.
    function checkDelegateForERC721(address to, address from, address contract_, uint256 id, bytes32 rights) internal view returns (bool isValid) {
        bytes4 selV2 = bytes4(keccak256("checkDelegateForERC721(address,address,address,uint256,bytes32)"));
        bytes memory callDataV2 = abi.encodeWithSelector(selV2, to, from, contract_, id, rights);

        (bool okV2, bytes memory retV2) = DELEGATE_REGISTRY_V2.staticcall(callDataV2);
        if (okV2 && retV2.length >= 32) {
            bool res = abi.decode(retV2, (bool));
            if (res) return true;
        }

        // Fallback to V1 - checkDelegateForToken(address,address,address,uint256)
        bytes4 selV1 = bytes4(keccak256("checkDelegateForToken(address,address,address,uint256)"));
        bytes memory callDataV1 = abi.encodeWithSelector(selV1, to, from, contract_, id);

        (bool okV1, bytes memory retV1) = DELEGATE_REGISTRY_V1.staticcall(callDataV1);
        if (okV1 && retV1.length >= 32) {
            bool res1 = abi.decode(retV1, (bool));
            if (res1) return true;
        }

        return false;
    }

    /// @notice Checks the delegated rights for ERC20 tokens between two addresses for a specific contract.
    /// @dev Returns an amount (uint256). If the V2 registry reports an amount, it's returned.
    ///      Otherwise, falls back to a boolean check in V1 and returns max uint256 if true (legacy full-delegation).
    /// @param to The address to check for delegated rights.
    /// @param from The address that delegated the rights.
    /// @param contract_ The contract address for which the rights are being checked.
    /// @return amount The amount of delegated rights found (0 if none).
    function checkDelegateForERC20(address to, address from, address contract_) internal view returns (uint256 amount) {
        return checkDelegateForERC20(to, from, contract_, bytes32(0));
    }

    /// @notice Checks the delegated rights for ERC20 tokens between two addresses for a specific contract.
    /// @dev Returns an amount (uint256). If the V2 registry reports an amount, it's returned.
    ///      Otherwise, falls back to a boolean check in V1 and returns max uint256 if true (legacy full-delegation).
    /// @param to The address to check for delegated rights.
    /// @param from The address that delegated the rights.
    /// @param contract_ The contract address for which the rights are being checked.
    /// @param rights The specific rights being checked.
    /// @return amount The amount of delegated rights found (0 if none).
    function checkDelegateForERC20(address to, address from, address contract_, bytes32 rights) internal view returns (uint256 amount) {
        bytes4 selV2 = bytes4(keccak256("checkDelegateForERC20(address,address,address,bytes32)"));
        bytes memory callDataV2 = abi.encodeWithSelector(selV2, to, from, contract_, rights);

        (bool okV2, bytes memory retV2) = DELEGATE_REGISTRY_V2.staticcall(callDataV2);
        if (okV2 && retV2.length >= 32) {
            uint256 amt = abi.decode(retV2, (uint256));
            if (amt > 0) return amt;
        }

        // Fallback: check V1 for boolean delegation to the contract
        bytes4 selV1 = bytes4(keccak256("checkDelegateForContract(address,address,address)"));
        bytes memory callDataV1 = abi.encodeWithSelector(selV1, to, from, contract_);

        (bool okV1, bytes memory retV1) = DELEGATE_REGISTRY_V1.staticcall(callDataV1);
        if (okV1 && retV1.length >= 32) {
            bool res1 = abi.decode(retV1, (bool));
            if (res1) {
                // Legacy full delegation - represent as "unbounded" amount
                return type(uint256).max;
            }
        }

        return 0;
    }

    /// @notice Checks the delegated rights for an ERC1155 token between two addresses.
    /// @param to The address to which the rights are delegated.
    /// @param from The address from which the rights are delegated.
    /// @param contract_ The address of the ERC1155 contract.
    /// @param id The ID of the ERC1155 token.
    /// @return amount The amount of delegated rights, if any.
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 id) internal view returns (uint256 amount) {
        return checkDelegateForERC1155(to, from, contract_, id, bytes32(0));
    }

    /// @notice Checks the delegated rights for an ERC1155 token between two addresses.
    /// @param to The address to which the rights are delegated.
    /// @param from The address from which the rights are delegated.
    /// @param contract_ The address of the ERC1155 contract.
    /// @param id The ID of the ERC1155 token.
    /// @param rights The specific rights being checked.
    /// @return amount The amount of delegated rights, if any.
    function checkDelegateForERC1155(address to, address from, address contract_, uint256 id, bytes32 rights) internal view returns (uint256 amount) {
        bytes4 selV2 = bytes4(keccak256("checkDelegateForERC1155(address,address,address,uint256,bytes32)"));
        bytes memory callDataV2 = abi.encodeWithSelector(selV2, to, from, contract_, id, rights);

        (bool okV2, bytes memory retV2) = DELEGATE_REGISTRY_V2.staticcall(callDataV2);
        if (okV2 && retV2.length >= 32) {
            uint256 amt = abi.decode(retV2, (uint256));
            if (amt > 0) return amt;
        }

        // Fallback to V1 token check (may be boolean or amount depending on implementation)
        bytes4 selV1Bool = bytes4(keccak256("checkDelegateForToken(address,address,address,uint256)"));
        bytes memory callDataV1Bool = abi.encodeWithSelector(selV1Bool, to, from, contract_, id);

        (bool okV1, bytes memory retV1) = DELEGATE_REGISTRY_V1.staticcall(callDataV1Bool);
        if (okV1 && retV1.length >= 32) {
            // Try decode as uint256 first
            uint256 maybeAmt = abi.decode(retV1, (uint256));
            if (maybeAmt > 0) return maybeAmt;

            // If decoding as uint256 yields 0, attempt bool decode fallback
            // Note: abi.decode can't change types dynamically; guard via length only.
            bool resBool = abi.decode(retV1, (bool));
            if (resBool) return type(uint256).max;
        }

        return 0;
    }
}