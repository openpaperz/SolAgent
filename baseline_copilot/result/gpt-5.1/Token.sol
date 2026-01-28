// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    /**
     * @notice Initializes the contract with an initial supply of tokens, assigning the entire supply to the deployer's address.
     *
     * @param _initialSupply The initial amount of tokens to be minted and assigned to the deployer's address.
     *
     * Steps:
     * 1. Assign the `_initialSupply` to both the `totalSupply` state variable and the balance of the deployer (`msg.sender`).
     */
    constructor (uint256 _initialSupply) public {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
    }

    /**
     * @notice Transfers tokens from the caller's address to the specified recipient.
     *
     * @param _to The address of the recipient to receive the tokens.
     * @param _value The amount of tokens to transfer.
     * @return A boolean indicating whether the transfer was successful.
     *
     * Steps:
     * 1. Ensure the caller has sufficient balance to transfer the specified amount.
     * 2. Deduct the transferred amount from the caller's balance.
     * 3. Add the transferred amount to the recipient's balance.
     * 4. Return `true` to indicate a successful transfer.
     *
     * @dev This function uses a simple balance check and does not handle underflow explicitly.
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        return true;
    }

    /**
     * @notice Retrieves the token balance of a specified address.
     *
     * @param _owner The address of the account whose balance is being queried.
     * @return balance The token balance of the specified address.
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balanceOf[_owner];
    }
}