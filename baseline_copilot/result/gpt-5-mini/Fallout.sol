// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Fallout {
    address payable public owner;
    mapping(address => uint256) public allocations;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice A function that allows the caller to claim ownership by sending Ether.
     *
     * Steps:
     * 1. Assign the caller's address (`msg.sender`) as the owner.
     * 2. Record the amount of Ether sent (`msg.value`) in the `allocations` mapping under the owner's address.
     *
     * @dev This function is payable, meaning it can receive Ether when called.
     */
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[owner] += msg.value;
    }

    /**
     * @notice Allocates funds to the caller's address.
     *
     * Steps:
     * 1. Adds the sent value (msg.value) to the caller's (msg.sender) allocation balance.
     */
    function allocate() public payable {
        allocations[msg.sender] += msg.value;
    }

    /**
     * @notice Sends the allocated amount to the specified allocator.
     *
     * Steps:
     * 1. Checks if the allocator has a positive allocation.
     * 2. Transfers the allocated amount to the allocator's address.
     */
    function sendAllocation(address payable allocator) public {
        uint256 amount = allocations[allocator];
        require(amount > 0, "No allocation to send");
        allocations[allocator] = 0;
        allocator.transfer(amount);
    }

    /**
     * @notice Allows the owner to collect all allocated funds from the contract.
     *
     * Steps:
     * 1. Checks that the caller is the owner (via the `onlyOwner` modifier).
     * 2. Transfers the entire contract balance to the owner's address.
     */
    function collectAllocations() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    /**
     * @notice Retrieves the balance allocated to a specific allocator.
     * 
     * @param allocator The address of the allocator whose balance is being queried.
     * @return uint256 The balance allocated to the specified allocator.
     */
    function allocatorBalance(address allocator) public view returns (uint256) {
        return allocations[allocator];
    }
}