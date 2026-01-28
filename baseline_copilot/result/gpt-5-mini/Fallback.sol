// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fallback {
    address payable public owner;
    mapping(address => uint256) public contributions;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
     * @notice Initializes the contract by setting the deployer as the owner and assigning them an initial contribution.
     *
     * Steps:
     * 1. Assign the deployer's address (`msg.sender`) as the owner of the contract.
     * 2. Set the deployer's initial contribution to 1000 ether.
     */
    constructor() {
        owner = payable(msg.sender);
        contributions[msg.sender] = 1000 ether;
    }

    /**
     * @notice Allows users to contribute Ether to the contract, with a maximum contribution of less than 0.001 Ether per transaction.
     *         If a user's total contribution exceeds the current owner's contribution, the user becomes the new owner.
     *
     * Steps:
     * 1. Require that the sent Ether (`msg.value`) is less than 0.001 Ether.
     * 2. Add the sent Ether to the user's total contribution in the `contributions` mapping.
     * 3. Check if the user's total contribution now exceeds the current owner's contribution.
     * 4. If the user's contribution is greater, update the `owner` to the user's address (`msg.sender`).
     */
    function contribute() public payable {
        require(msg.value < 0.001 ether, "Contribution exceeds per-tx limit");
        contributions[msg.sender] += msg.value;
        if (contributions[msg.sender] > contributions[owner]) {
            owner = payable(msg.sender);
        }
    }

    /**
     * @notice Retrieves the contribution amount of the caller.
     *
     * @return The contribution amount of the caller.
     */
    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    /**
     * @notice Allows the contract owner to withdraw the entire balance of the contract.
     *
     * Requirements:
     * - Only the owner can call this function.
     *
     * Steps:
     * 1. Transfer the entire balance of the contract to the owner's address.
     */
    function withdraw() public onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance to withdraw");
        (bool success, ) = owner.call{value: bal}("");
        require(success, "Transfer failed");
    }
}