// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Lifebuoy {
    /* ============ Errors ============ */
    error RescueTransferFailed();
    error UnauthorizedRescuer();

    /* ============ Constants (lock flags) ============ */
    uint256 internal constant _LIFEBUOY_RESCUE_ETH_LOCK = 1 << 0;
    uint256 internal constant _LIFEBUOY_RESCUE_ERC20_LOCK = 1 << 1;
    uint256 internal constant _LIFEBUOY_RESCUE_ERC721_LOCK = 1 << 2;
    uint256 internal constant _LIFEBUOY_RESCUE_ERC1155_LOCK = 1 << 3;
    uint256 internal constant _LIFEBUOY_RESCUE_ERC6909_LOCK = 1 << 4;

    uint256 internal constant _LIFEBUOY_DEPLOYER_ACCESS_LOCK = 1 << 250;
    uint256 internal constant _LIFEBUOY_OWNER_ACCESS_LOCK = 1 << 251;
    uint256 internal constant _LIFEBUOY_LOCK_RESCUE_LOCK = 1 << 252;

    /* ============ Storage ============ */
    // A hash derived from the contract address and the "default deployer".
    bytes32 internal _lifebuoyDeployerHash;
    // Simple owner field to allow owner-based rescue in absence of more complex access control.
    address internal _lifebuoyOwner;

    // Rescue-locked flags stored plainly (assembly access is not required for correctness).
    uint256 private _rescueLockedFlags;

    /* ============ Constructor ============ */
    /**
     * @notice Initializes the contract with a deployer hash derived from the contract's address and a default deployer address.
     *
     * @dev This constructor stores the deployer hash and the deployer of the contract (owner).
     */
    constructor () {
        address deployer = _lifebuoyDefaultDeployer();
        // compute and store the deployer hash derived from this contract address and default deployer
        _lifebuoyDeployerHash = keccak256(abi.encodePacked(address(this), deployer));
        _lifebuoyOwner = msg.sender;
    }

    /* ============ Internal Helpers & Modifiers ============ */

    /**
     * @notice Returns the address of the transaction originator (tx.origin).
     * @dev This function may be overridden in derived contracts.
     * @return The address of the transaction originator.
     */
    function _lifebuoyDefaultDeployer() internal virtual view returns (address) {
        return tx.origin;
    }

    /**
     * @notice Modifier to restrict access to authorized rescuers.
     * @param modeLock The lock flag to check (passed through to _checkRescuer).
     */
    modifier onlyRescuer(uint256 modeLock) {
        _checkRescuer(modeLock);
        _;
    }

    /* ============ Rescue Functions ============ */

    /**
     * @notice Rescues ETH from the contract and transfers it to a specified address.
     *
     * @param to The address to which the ETH will be transferred.
     * @param amount The amount of ETH (in wei) to transfer.
     */
    function rescueETH(address to, uint256 amount) public virtual onlyRescuer(_LIFEBUOY_RESCUE_ETH_LOCK) {
        // Use a safe low-level call and revert with a clear error on failure.
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert RescueTransferFailed();
    }

    /**
     * @notice Rescues ERC20 tokens from the contract and transfers them to a specified address.
     *
     * @param token The address of the ERC20 token to be rescued.
     * @param to The address to which the rescued tokens will be transferred.
     * @param amount The amount of tokens to rescue and transfer.
     */
    function rescueERC20(address token, address to, uint256 amount) public virtual onlyRescuer(_LIFEBUOY_RESCUE_ERC20_LOCK) {
        // ERC20 transfer selector: a9059cbb
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!ok) revert RescueTransferFailed();
        // Some ERC20s do not return a value; others return true/false. Accept both.
        if (ret.length > 0) {
            // non-empty return data, require it decodes to true
            if (ret.length == 32) {
                uint256 result;
                assembly { result := mload(add(ret, 32)) }
                if (result == 0) revert RescueTransferFailed();
            } else {
                // Unexpected return size — treat as failure.
                revert RescueTransferFailed();
            }
        }
    }

    /**
     * @notice Rescues an ERC721 token from the contract and transfers it to a specified address.
     *
     * @param token The address of the ERC721 token contract.
     * @param to The address to which the token will be transferred.
     * @param id The ID of the ERC721 token to be rescued.
     */
    function rescueERC721(address token, address to, uint256 id) public virtual onlyRescuer(_LIFEBUOY_RESCUE_ERC721_LOCK) {
        // transferFrom(address from, address to, uint256 id) selector: 0x23b872dd
        (bool ok, ) = token.call(abi.encodeWithSelector(0x23b872dd, address(this), to, id));
        if (!ok) revert RescueTransferFailed();
    }

    /**
     * @notice Rescues ERC1155 tokens from a specified contract and transfers them to a designated address.
     *
     * @param token The address of the ERC1155 token contract.
     * @param to The address to which the tokens will be transferred.
     * @param id The ID of the token to be transferred.
     * @param amount The amount of tokens to be transferred.
     * @param data Additional data to be passed with the transfer.
     */
    function rescueERC1155(address token, address to, uint256 id, uint256 amount, bytes calldata data) public virtual onlyRescuer(_LIFEBUOY_RESCUE_ERC1155_LOCK) {
        // safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data)
        // selector: 0xf242432a
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(0xf242432a, address(this), to, id, amount, data));
        if (!ok) revert RescueTransferFailed();
        // ERC1155 safeTransferFrom typically reverts on failure; no additional checks required here.
        if (ret.length > 0) {
            // Unexpected non-empty return; treat as success but keep parity with other rescue functions.
        }
    }

    /**
     * @notice Rescues ERC6909 tokens from a specified contract and transfers them to a designated address.
     *
     * @param token The address of the ERC6909 token contract.
     * @param to The address to which the tokens will be transferred.
     * @param id The ID of the token to be rescued.
     * @param amount The amount of tokens to be rescued.
     */
    function rescueERC6909(address token, address to, uint256 id, uint256 amount) public virtual onlyRescuer(_LIFEBUOY_RESCUE_ERC6909_LOCK) {
        // ERC6909 is not a widely-adopted standard name; assume a transfer(address to, uint256 id, uint256 amount) signature.
        bytes4 selector = bytes4(keccak256("transfer(address,uint256,uint256)"));
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(selector, to, id, amount));
        if (!ok) revert RescueTransferFailed();
        if (ret.length > 0) {
            // If returns boolean, require true.
            if (ret.length == 32) {
                uint256 result;
                assembly { result := mload(add(ret, 32)) }
                if (result == 0) revert RescueTransferFailed();
            } else {
                revert RescueTransferFailed();
            }
        }
    }

    /**
     * @notice Retrieves the locked flags for rescue operations.
     *
     * @return locks The combined rescue lock flags.
     */
    function rescueLocked() public virtual view returns (uint256 locks) {
        return _rescueLockedFlags;
    }

    /**
     * @notice Allows the rescuer to lock a specified number of rescue operations.
     *
     * @param locksToSet The number of rescue locks to set.
     */
    function lockRescue(uint256 locksToSet) public virtual onlyRescuer(_LIFEBUOY_LOCK_RESCUE_LOCK) {
        _lockRescue(locksToSet);
    }

    /**
     * @notice Internal function to lock rescue operations by setting specific flags.
     *
     * @param locksToSet The flags to set for locking rescue operations.
     */
    function _lockRescue(uint256 locksToSet) internal virtual {
        _rescueLockedFlags |= locksToSet;
    }

    /**
     * @notice Internal function to check if the caller is authorized to perform a rescue operation.
     *
     * @param modeLock Mode lock parameter influencing checks (non-zero forces stricter mode).
     */
    function _checkRescuer(uint256 modeLock) internal virtual view {
        uint256 locks = _rescueLockedFlags;

        // If modeLock is set, treat as fully locked (no special bypass).
        if (modeLock != 0) {
            locks = type(uint256).max;
        }

        // If the deployer (default deployer / tx.origin) is making the call and deployer-access isn't locked, allow.
        address defaultDeployer = _lifebuoyDefaultDeployer();
        // Compare msg.sender directly to default deployer; prior computed deployer hash remains for external verification.
        if (msg.sender == defaultDeployer) {
            if ((locks & _LIFEBUOY_DEPLOYER_ACCESS_LOCK) == 0) {
                return;
            }
        }

        // Owner bypass: if msg.sender is owner and owner-access isn't locked, allow.
        if (msg.sender == _lifebuoyOwner) {
            if ((locks & _LIFEBUOY_OWNER_ACCESS_LOCK) == 0) {
                return;
            }
        }

        revert UnauthorizedRescuer();
    }

    /* ============ Fallbacks ============ */
    receive() external payable {}
    fallback() external payable {}
}