```solidity: Dex.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Dex is Ownable {
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
     * 1. Transfers the specified amount of tokens from the caller to the contract.
     * 
     * Requirements:
     * - The caller must be the owner of the contract.
     * - The token address must be valid.
     * - The amount must be greater than zero.
     */
    function addLiquidity(address token_address, uint256 amount) public onlyOwner {
        IERC20(token_address).transferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Swaps tokens between two supported token pairs.
     *
     * @param from The address of the token to swap from.
     * @param to The address of the token to swap to.
     * @param amount The amount of tokens to swap.
     *
     * Requirements:
     * 1. The `from` and `to` tokens must be one of the supported pairs (`token1` and `token2`).
     * 2. The caller must have a sufficient balance of the `from` token to perform the swap.
     *
     * Steps:
     * 1. Calculate the swap amount using the `getSwapPrice` function.
     * 2. Transfer the `amount` of `from` tokens from the caller to this contract.
     * 3. Approve the contract to transfer the calculated `swapAmount` of `to` tokens.
     * 4. Transfer the `swapAmount` of `to` tokens from the contract to the caller.
     *
     * Reverts:
     * - If the `from` and `to` tokens are not a valid pair, with the message "Invalid tokens".
     * - If the caller does not have enough `from` tokens, with the message "Not enough to swap".
     */
    function swap(address from, address to, uint256 amount) public {
        require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        
        uint256 swapAmount = getSwapPrice(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transfer(msg.sender, swapAmount);
    }

    /**
     * @notice Calculates the swap price between two tokens based on their balances in the contract.
     *
     * @param from The address of the token to swap from.
     * @param to The address of the token to swap to.
     * @param amount The amount of the `from` token to calculate the swap price for.
     *
     * @return The calculated swap price in terms of the `to` token.
     *
     * Formula:
     * Swap Price = (amount * balance of `to` token in contract) / balance of `from` token in contract
     */
    function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
        return (amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this));
    }

    /**
     * @notice Approves a spender to spend a specified amount of tokens on behalf of the caller for both token1 and token2.
     *
     * @param spender The address of the spender to be approved.
     * @param amount The amount of tokens the spender is allowed to spend.
     *
     * Steps:
     * 1. Call the `approve` function of `SwappableToken` for `token1`, approving the spender to spend the specified amount on behalf of the caller (`msg.sender`).
     * 2. Call the `approve` function of `SwappableToken` for `token2`, approving the spender to spend the specified amount on behalf of the caller (`msg.sender`).
     */
    function approve(address spender, uint256 amount) public {
        SwappableToken(token1).approve(msg.sender, spender, amount);
        SwappableToken(token2).approve(msg.sender, spender, amount);
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

contract SwappableToken is ERC20 {
    address private _dex;

    /**
     * @notice Initializes the token contract with a DEX instance, name, symbol, and initial supply.
     *
     * Steps:
     * 1. Call the parent ERC20 constructor with the provided name and symbol.
     * 2. Mint the initial supply of tokens to the message sender.
     * 3. Store the DEX instance address in the private _dex state variable.
     */
    constructor(address dexInstance, string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
    }

    /**
     * @notice Approves an address to spend a specific amount of tokens on behalf of the owner.
     *
     * Steps:
     * 1. Check that the owner is not the DEX contract itself (to prevent invalid approvals).
     * 2. Call the parent's _approve function to set the spending allowance.
     */
    function approve(address owner, address spender, uint256 amount) public {
        require(owner != _dex, "InvalidApprover");
        _approve(owner, spender, amount);
    }
}
```
