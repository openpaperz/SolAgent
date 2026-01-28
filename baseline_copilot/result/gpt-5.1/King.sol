// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address private owner;
    address private king;
    uint256 private prize;

    /**
     * @notice Initializes the contract with the deployer as the owner and king, and sets the initial prize amount.
     *
     * Steps:
     * 1. Assign the deployer's address (`msg.sender`) as the owner.
     * 2. Assign the deployer's address (`msg.sender`) as the king.
     * 3. Set the initial prize amount to the value sent with the transaction (`msg.value`).
     */
    constructor() payable {
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

    /**
     * @notice Returns the owner of the contract.
     * @return The address of the contract owner.
     */
    function ownerAddress() public view returns (address) {
        return owner;
    }

    /**
     * @notice Returns the current prize amount required to become the king.
     * @return The current prize in wei.
     */
    function currentPrize() public view returns (uint256) {
        return prize;
    }

    /**
     * @notice Allows a user to claim kingship by sending more Ether than the current prize.
     *         The previous king is paid the current prize, and the caller becomes the new king.
     */
    function claimThrone() external payable {
        require(msg.value > prize, "Need to pay more than current prize");

        address previousKing = king;
        uint256 previousPrize = prize;

        king = msg.sender;
        prize = msg.value;

        (bool sent, ) = payable(previousKing).call{value: previousPrize}("");
        require(sent, "Failed to pay previous king");
    }

    /**
     * @notice Fallback to allow direct payments for claiming kingship.
     *         Behaves like claimThrone().
     */
    receive() external payable {
        require(msg.value > prize, "Need to pay more than current prize");

        address previousKing = king;
        uint256 previousPrize = prize;

        king = msg.sender;
        prize = msg.value;

        (bool sent, ) = payable(previousKing).call{value: previousPrize}("");
        require(sent, "Failed to pay previous king");
    }
}