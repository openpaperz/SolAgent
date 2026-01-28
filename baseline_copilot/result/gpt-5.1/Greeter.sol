// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

error BadGm();

contract Greeter {
    string public greeting;
    address public owner;

    /**
     * @notice Initializes the contract with a new greeting and sets the deployer as the owner.
     *
     * @param newGreeting The greeting string to be stored in the contract.
     *
     * Steps:
     * 1. Assign the provided `newGreeting` to the `greeting` state variable.
     * 2. Set the deployer's address (`msg.sender`) as the owner of the contract.
     */
    constructor(string memory newGreeting) {
        greeting = newGreeting;
        owner = msg.sender;
    }

    event GMEverybodyGM(address indexed from, string greeting);

    /**
     * @notice A function that checks if the provided greeting matches the expected greeting.
     * If the greeting matches, it emits a `GMEverybodyGM` event. Otherwise, it reverts with `BadGm`.
     *
     * @param myGm The greeting string to be checked against the expected greeting.
     * @return greet The expected greeting string.
     *
     * Steps:
     * 1. Compare the provided greeting (`myGm`) with the expected greeting (`greeting`) using keccak256 hashing.
     * 2. If the greetings do not match, revert with the error `BadGm`.
     * 3. If the greetings match, emit the `GMEverybodyGM` event.
     * 4. Return the expected greeting string.
     */
    function gm(string memory myGm) external returns (string memory greet) {
        if (keccak256(abi.encodePacked(myGm)) != keccak256(abi.encodePacked(greeting))) {
            revert BadGm();
        }

        emit GMEverybodyGM(msg.sender, greeting);
        return greeting;
    }

    /**
     * @notice Updates the greeting message stored in the contract.
     *
     * @param newGreeting The new greeting message to be stored.
     *
     * Steps:
     * 1. Assign the provided `newGreeting` string to the `greeting` state variable.
     */
    function setGreeting(string memory newGreeting) external {
        greeting = newGreeting;
    }
}