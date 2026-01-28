// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DexTwo is Ownable {
    address public token1;
    address public token2;

    /**
     * @notice An empty constructor.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Sets the addresses of two tokens.
     * @dev This function can only be called by the owner.
     * @param _token1 The address of the first token.
     * @param _token2 The address of the second token.
     */
    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    /**
     * @notice Adds liquidity by transferring tokens from the caller to the contract.
     * 
     * Steps:
     * 1. The function is restricted to the contract owner using the `onlyOwner` modifier.
     * 2. Transfers the specified `amount` of tokens from the caller (`msg.sender`) to the contract.
     * 3. The token address is specified by `token_address`.
     */
    function add_liquidity(address token_address, uint256 amount) public onlyOwner {
        IERC20(token_address).transferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Swaps tokens from one address to another.
     *
     * @param from The address of the token to swap from.
     * @param to The address of the token to swap to.
     * @param amount The amount of tokens to swap.
     *
     * Steps:
     * 1. Check if the sender has enough tokens to swap (revert if not).
     * 2. Calculate the swap amount using the `getSwapAmount` function.
     * 3. Transfer the `amount` of tokens from the sender to this contract.
     * 4. Approve the contract to spend the `swapAmount` of the target token.
     * 5. Transfer the `swapAmount` of the target token from the contract to the sender.
     *
     * Reverts:
     * - If the sender does not have enough tokens to swap.
     */
    function swap(address from, address to, uint256 amount) public {
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        uint256 swapAmount = getSwapAmount(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
    }

    /**
     * @notice Calculates the swap amount based on the balance of tokens in the contract.
     *
     * @param from The address of the token to swap from.
     * @param to The address of the token to swap to.
     * @param amount The amount of tokens to swap.
     *
     * @return The calculated swap amount, derived from the ratio of the balances of the two tokens in the contract.
     */
    function getSwapAmount(address from, address to, uint256 amount) public view returns (uint256) {
        return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
    }

    /**
     * @notice Approves a spender to spend a specified amount of tokens on behalf of the caller.
     *
     * Steps:
     * 1. Calls the `approve` function on `token1` to approve the spender for the specified amount.
     * 2. Calls the `approve` function on `token2` to approve the spender for the specified amount.
     *
     * @param spender The address of the spender to be approved.
     * @param amount The amount of tokens the spender is allowed to spend.
     */
    function approve(address spender, uint256 amount) public {
        SwappableTokenTwo(token1).approve(msg.sender, spender, amount);
        SwappableTokenTwo(token2).approve(msg.sender, spender, amount);
    }

    /**
     * @notice Retrieves the token balance of a specified account for a given ERC20 token.
     * 
     * @param token The address of the ERC20 token contract.
     * @param account The address of the account to query the balance for.
     * @return uint256 The token balance of the specified account.
     */
    function balanceOf(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}

contract SwappableTokenTwo is ERC20 {
    address private _dex;

    /**
     * @notice A constructor that initializes an ERC20 token with a specified name, symbol, and initial supply.
     *
     * Steps:
     * 1. Initialize the ERC20 token with the provided name and symbol.
     * 2. Mint the initial supply of tokens to the message sender's address.
     * 3. Set the DEX instance address for future interactions.
     */
    constructor(address dexInstance, string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
    }

    /**
     * @notice Approves an address to spend a specified amount of tokens on behalf of the owner.
     *
     * Steps:
     * 1. Validate that the owner is not the DEX address (to prevent invalid approvals).
     * 2. Call the parent's _approve function to set the spending allowance.
     */
    function approve(address owner, address spender, uint256 amount) public {
        require(owner != _dex, "InvalidApprover");
        _approve(owner, spender, amount);
    }
}
