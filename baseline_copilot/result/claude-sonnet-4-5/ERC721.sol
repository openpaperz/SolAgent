// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "./IERC721.sol";
import {IERC721Metadata} from "./IERC721Metadata.sol";
import {IERC721Receiver} from "./IERC721Receiver.sol";
import {ERC165} from "./ERC165.sol";
import {IERC165} from "./IERC165.sol";
import {Strings} from "./Strings.sol";
import {IERC721Errors} from "./IERC721Errors.sol";

/**
 * @dev Implementation of the {IERC721} interface.
 */
contract ERC721 is ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 tokenId => address) private _owners;

    // Mapping owner address to token count
    mapping(address owner => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 tokenId => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    /**
     * @notice Initializes the contract with a name and symbol.
     *
     * @param name_ The name of the contract or token.
     * @param symbol_ The symbol representing the contract or token.
     *
     * Steps:
     * 1. Assign the provided name to the `_name` state variable.
     * 2. Assign the provided symbol to the `_symbol` state variable.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @notice Checks if this contract supports a given interface ID.
     *
     * This function overrides the supportsInterface function from both ERC165 and IERC165
     * to ensure compatibility with ERC721 and ERC721Metadata interfaces.
     *
     * Steps:
     * 1. Check if the provided interface ID matches the ERC721 interface ID.
     * 2. Check if the provided interface ID matches the ERC721Metadata interface ID.
     * 3. Fall back to the parent implementation for any other interface IDs.
     *
     * Returns true if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the number of NFTs owned by a specific address.
     *
     * Steps:
     * 1. Check if the provided owner address is the zero address.
     * 2. If it is the zero address, revert with ERC721InvalidOwner error.
     * 3. Otherwise, return the balance of NFTs for the given owner from the internal balances mapping.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    /**
     * @notice Returns the owner of a given token ID.
     *
     * @param tokenId The ID of the token to query.
     * @return The address of the owner of the specified token.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /**
     * @notice Returns the name of the token.
     *
     * This is a virtual view function that returns the internal `_name` variable.
     * It allows derived contracts to override this behavior while providing a default implementation.
     *
     * @return The name of the token as a string.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token.
     *
     * This is a view function that retrieves and returns the token symbol
     * stored in the internal `_symbol` variable.
     *
     * @return string memory The symbol of the token
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the URI for a given token ID.
     *
     * Steps:
     * 1. Require that the caller owns the specified token ID.
     * 2. Retrieve the base URI from the contract.
     * 3. If the base URI is not empty, concatenate it with the token ID as a string.
     * 4. Return the complete URI, or an empty string if the base URI is empty.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @notice Returns the base URI for token metadata.
     * 
     * @return string memory The base URI string, which is empty in this implementation.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @notice Approves another address to transfer a specific NFT token.
     *
     * Steps:
     * 1. Calls the internal _approve function with the target address, token ID, and the sender of the transaction.
     * 2. This allows the specified address to transfer the token on behalf of the sender.
     */
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, msg.sender);
    }

    /**
     * @notice Retrieves the approved address for a given token ID.
     *
     * Steps:
     * 1. Require that the token ID is owned by some address.
     * 2. Return the approved address for the specified token ID.
     *
     * @param tokenId The ID of the token to query approval for.
     * @return The address that is approved to manage the specified token.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);
        return _getApproved(tokenId);
    }

    /**
     * @notice Sets or removes approval for a operator to manage all of the caller's tokens.
     *
     * Steps:
     * 1. Calls the internal function `_setApprovalForAll` with the sender as the owner,
     *    the provided operator, and the approval status.
     *
     * This function is virtual, allowing derived contracts to override its behavior.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @notice Checks if a given operator is approved to manage all of the owner's tokens.
     *
     * @param owner The address of the token owner.
     * @param operator The address of the operator being checked.
     * @return bool True if the operator is approved for all tokens of the owner, false otherwise.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @notice Transfers ownership of an NFT from one address to another.
     *
     * Steps:
     * 1. Check if the recipient address is valid (not zero address).
     * 2. Update the token's ownership to the new address.
     * 3. Verify that the previous owner matches the expected sender.
     *
     * Notes:
     * - The `_isAuthorized` check ensures the token exists and the sender is authorized.
     * - The `_update` function handles the actual transfer logic and returns the previous owner.
     * - Reverts if the recipient is the zero address or if the sender is not the current owner.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, msg.sender);
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @notice Safely transfers a token from one address to another.
     *
     * This function transfers a token with the specified tokenId from the 'from' address to the 'to' address.
     * It includes additional data in the transfer call, which can be used for additional processing or validation.
     * The function ensures that the transfer is safe, typically checking that the recipient can handle tokens.
     *
     * Parameters:
     * - from: The address to transfer the token from.
     * - to: The address to transfer the token to.
     * - tokenId: The identifier of the token to be transferred.
     * - data: Additional data to be passed along with the transfer.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @notice Safely transfers a token from one address to another.
     *
     * This function transfers a token with the specified tokenId from the 'from' address to the 'to' address.
     * It includes additional data in the transfer call, which can be used for additional processing or validation.
     * The function ensures that the transfer is safe, typically checking that the recipient can handle tokens.
     *
     * Parameters:
     * - from: The address to transfer the token from.
     * - to: The address to transfer the token to.
     * - tokenId: The identifier of the token to be transferred.
     * - data: Additional data to be passed along with the transfer.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @notice Internal view function that retrieves the owner of a given token ID.
     *
     * @param tokenId The ID of the token to query the owner for.
     * @return The address of the owner of the specified token.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @notice Internal view function that retrieves the approved address for a given token ID.
     *
     * @param tokenId The ID of the token to query the approval status for.
     * @return The address that is approved to manage the specified token.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @notice Checks if an address is authorized to manage a specific token.
     *
     * This function verifies authorization through one of three conditions:
     * 1. The spender is not the zero address.
     * 2. The owner is the spender (owner has direct control).
     * 3. The owner has approved the spender for all tokens (isApprovedForAll).
     * 4. The spender has been specifically approved for this token (_getApproved).
     *
     * @param owner The owner of the token.
     * @param spender The address attempting to manage the token.
     * @param tokenId The ID of the token being checked.
     * @return bool True if the spender is authorized to manage the token, false otherwise.
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @notice Internal virtual function that checks if a spender is authorized to manage a specific token.
     *
     * Steps:
     * 1. Check if the spender is authorized for the given token ID.
     * 2. If not authorized:
     *    a. If the token does not exist (owner is zero), revert with ERC721NonexistentToken.
     *    b. Otherwise, revert with ERC721InsufficientApproval.
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @notice Increases the balance of a given account by a specified value.
     *
     * Steps:
     * 1. Accepts an account address and a value to increase the balance by.
     * 2. Uses unchecked arithmetic to add the value to the current balance of the account.
     * 3. The balance update is performed in place within the internal balances mapping.
     *
     * Note: This function is virtual, allowing derived contracts to override its behavior.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    }

    /**
     * @notice Updates the ownership of a token from one address to another.
     *
     * Steps:
     * 1. Retrieve the current owner of the token.
     *
     * 2. If an authorized address is provided, verify that it is authorized to perform the transfer.
     *
     * 3. If the token was previously owned, remove the previous owner's balance and clear any approvals.
     *
     * 4. If the new owner is not zero, increment the new owner's balance.
     *
     * 5. Update the token's owner in storage.
     *
     * 6. Emit a Transfer event to log the ownership change.
     *
     * Returns:
     * - The previous owner of the token.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        if (from != address(0)) {
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
     * @notice Mints a new ERC721 token to the specified address.
     *
     * @param to The address to which the token will be minted.
     * @param tokenId The ID of the token to be minted.
     *
     * Steps:
     * 1. Check if the `to` address is the zero address. If so, revert with an error indicating an invalid receiver.
     * 2. Update the token's ownership by calling `_update` with the `to` address, `tokenId`, and the zero address as the previous owner.
     * 3. If the `previousOwner` is not the zero address, revert with an error indicating an invalid sender.
     *
     * @dev This function is internal and can only be called within the contract or derived contracts.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**
     * @notice Mints a new token to the specified address.
     *
     * This function calls the internal _safeMint function with an empty data parameter,
     * ensuring the token is safely minted to the given address without any additional data.
     *
     * @param to The address that will receive the minted token.
     * @param tokenId The unique identifier for the new token.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @notice Mints a new token to the specified address.
     *
     * This function calls the internal _safeMint function with an empty data parameter,
     * ensuring the token is safely minted to the given address without any additional data.
     *
     * @param to The address that will receive the minted token.
     * @param tokenId The unique identifier for the new token.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /**
     * @notice Internal function to burn (destroy) a specific token.
     *
     * @param tokenId The ID of the token to be burned.
     *
     * Steps:
     * 1. Call `_update` to set the owner of the token to `address(0)` (indicating it is burned).
     * 2. If the token did not exist (i.e., `previousOwner` is `address(0)`), revert with an error indicating the token does not exist.
     *
     * Reverts:
     * - If the token does not exist, reverts with `ERC721NonexistentToken`.
     */
    function _burn(uint256 tokenId) internal virtual {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @notice Internal function to transfer an ERC721 token from one address to another.
     *
     * Steps:
     * 1. Check if the recipient address is the zero address and revert if so.
     * 2. Update the token's ownership to the new address and store the previous owner.
     * 3. If no previous owner existed, revert with "Nonexistent Token" error.
     * 4. If the previous owner does not match the sender, revert with "Incorrect Owner" error.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @notice Internal function to safely transfer a token from one address to another.
     *
     * This function delegates to the full _safeTransfer implementation with an empty data parameter.
     * It ensures that the token transfer is performed safely, typically checking that the recipient
     * is either a valid contract that implements the ERC721 receiver interface or an EOA.
     *
     * Parameters:
     * - from: The address to transfer the token from
     * - to: The address to transfer the token to
     * - tokenId: The ID of the token being transferred
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal virtual {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @notice Internal function to safely transfer a token from one address to another.
     *
     * This function delegates to the full _safeTransfer implementation with an empty data parameter.
     * It ensures that the token transfer is performed safely, typically checking that the recipient
     * is either a valid contract that implements the ERC721 receiver interface or an EOA.
     *
     * Parameters:
     * - from: The address to transfer the token from
     * - to: The address to transfer the token to
     * - tokenId: The ID of the token being transferred
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @notice Internal function that approves a address to transfer a token.
     *
     * This function calls the internal _approve function with the forceUpdate parameter set to true.
     *
     * Parameters:
     * - to: The address to approve for transferring the token.
     * - tokenId: The ID of the token to approve.
     * - auth: The address authorized to perform the approval.
     */
    function _approve(address to, uint256 tokenId, address auth) internal virtual {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @notice Internal function that approves a address to transfer a token.
     *
     * This function calls the internal _approve function with the forceUpdate parameter set to true.
     *
     * Parameters:
     * - to: The address to approve for transferring the token.
     * - tokenId: The ID of the token to approve.
     * - auth: The address authorized to perform the approval.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     * @notice Sets or removes approval for a third party ("operator") to manage all of the caller's tokens.
     *
     * Steps:
     * 1. Check if the operator address is zero, and revert if so with ERC721InvalidOperator error.
     * 2. Set the approval status for the operator on behalf of the owner in the operator approvals mapping.
     * 3. Emit an ApprovalForAll event to notify of the change in approval status.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @notice Internal function that checks if a token exists and returns its owner.
     *
     * Steps:
     * 1. Retrieve the owner address of the given token ID.
     * 2. If the owner is the zero address, revert with ERC721NonexistentToken error.
     * 3. Return the owner address.
     */
    function _requireOwned(uint256 tokenId) internal view virtual returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    /**
     * @notice Internal function that checks if a contract implements ERC721Receiver.
     *
     * @param from The address sending the token.
     * @param to The address receiving the token.
     * @param tokenId The ID of the token being transferred.
     * @param data Additional data with no specified format.
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
}
