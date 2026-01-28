// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external returns (bool);
}

contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

error ERC721InvalidOwner();
error ERC721NonexistentToken();
error ERC721InsufficientApproval();
error ERC721InvalidOperator();
error ERC721InvalidReceiver();
error ERC721IncorrectOwner();

contract ERC721 is ERC165, IERC721, IERC721Metadata {
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count (using uint128 as requested in helpers)
    mapping(address => uint128) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public virtual override(ERC165, IERC165) returns (bool) {
        if (interfaceId == type(IERC721).interfaceId) return true;
        if (interfaceId == type(IERC721Metadata).interfaceId) return true;
        return ERC165.supportsInterface(interfaceId);
    }

    function balanceOf(address owner) public virtual view returns (uint256) {
        if (owner == address(0)) revert ERC721InvalidOwner();
        return uint256(_balances[owner]);
    }

    function ownerOf(uint256 tokenId) public virtual view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken();
        return owner;
    }

    function name() public virtual view returns (string memory) {
        return _name;
    }

    function symbol() public virtual view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public virtual view returns (string memory) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken();
        if (msg.sender != owner) revert ERC721InsufficientApproval();
        string memory base = _baseURI();
        if (bytes(base).length == 0) {
            return "";
        }
        return string(abi.encodePacked(base, _toString(tokenId)));
    }

    function _baseURI() internal virtual view returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken();
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) revert ERC721InsufficientApproval();
        _approve(to, tokenId, msg.sender, true);
    }

    function getApproved(uint256 tokenId) public virtual view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public virtual view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) revert ERC721InvalidReceiver();
        address prev = _owners[tokenId];
        if (prev == address(0)) revert ERC721NonexistentToken();
        if (!_isAuthorized(prev, msg.sender, tokenId)) revert ERC721InsufficientApproval();
        if (prev != from) revert ERC721IncorrectOwner();
        _update(to, tokenId, msg.sender);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        _safeTransfer(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        _safeTransfer(from, to, tokenId, data);
    }

    /* INTERNAL VIEW HELPERS */
    function _ownerOf(uint256 tokenId) internal virtual view returns (address) {
        return _owners[tokenId];
    }

    function _getApproved(uint256 tokenId) internal virtual view returns (address) {
        return _tokenApprovals[tokenId];
    }

    function _isAuthorized(address owner, address spender, uint256 tokenId) internal virtual view returns (bool) {
        if (spender == address(0)) return false;
        if (owner == spender) return true;
        if (_operatorApprovals[owner][spender]) return true;
        if (_tokenApprovals[tokenId] == spender) return true;
        return false;
    }

    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal virtual view {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) revert ERC721NonexistentToken();
            revert ERC721InsufficientApproval();
        }
    }

    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] = _balances[account] + value;
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address previousOwner = _owners[tokenId];
        if (auth != address(0)) {
            _checkAuthorized(previousOwner, auth, tokenId);
        }
        if (previousOwner != address(0)) {
            // clear previous approval
            delete _tokenApprovals[tokenId];
            unchecked { _balances[previousOwner] -= 1; }
        }
        if (to != address(0)) {
            _increaseBalance(to, 1);
            _owners[tokenId] = to;
        } else {
            // burning
            delete _owners[tokenId];
        }
        emit Transfer(previousOwner, to, tokenId);
        return previousOwner;
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ERC721InvalidReceiver();
        address previousOwner = _owners[tokenId];
        if (previousOwner != address(0)) revert ERC721InvalidOwner();
        _owners[tokenId] = to;
        _increaseBalance(to, 1);
        emit Transfer(address(0), to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        if (!_checkOnERC721Received(address(0), to, tokenId, data)) revert ERC721InvalidReceiver();
    }

    function _burn(uint256 tokenId) internal {
        address previousOwner = _owners[tokenId];
        if (previousOwner == address(0)) revert ERC721NonexistentToken();
        _update(address(0), tokenId, address(0));
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ERC721InvalidReceiver();
        address prev = _owners[tokenId];
        if (prev == address(0)) revert ERC721NonexistentToken();
        if (prev != from) revert ERC721IncorrectOwner();
        _update(to, tokenId, msg.sender);
    }

    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, data)) revert ERC721InvalidReceiver();
    }

    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken();
        if (auth != owner && !_operatorApprovals[owner][auth]) revert ERC721InsufficientApproval();
        _tokenApprovals[tokenId] = to;
        if (emitEvent) emit Approval(owner, to, tokenId);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) revert ERC721InvalidOperator();
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken();
        return owner;
    }

    /* INTERNAL RECEIVER CHECK */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (isContract(to)) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        }
        return true;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /* small uint -> string helper */
    function _toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OpenZeppelin's toString
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
