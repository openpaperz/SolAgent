// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address public owner;
    address private king;
    uint256 public prize;

    /**
     * @notice Initializes the contract with the deployer as the owner and king, and sets the initial prize amount.
     *
     * Steps:
     * 1. Assign the deployer's address (`msg.sender`) as the owner.
     * 2. Assign the deployer's address (`msg.sender`) as the king.
     * 3. Set the initial prize amount to the value sent with the transaction (`msg.value`).
     */
    constructor () {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    /**
     * @notice Returns the current king address.
     * @return The address of the current king.
     */
    function _king() public view returns (address) {
        return king;
    }
}