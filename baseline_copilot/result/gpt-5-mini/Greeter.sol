// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Greeter {
    error BadGm();

    event GMEverybodyGM(address indexed who, string greeting);

    address public owner;
    string public greeting;

    /**
     * @notice Initializes the contract with a new greeting and sets the deployer as the owner.
     *
     * @param newGreeting The greeting string to be stored in the contract.
     */
    constructor(string memory newGreeting) {
        greeting = newGreeting;
        owner = msg.sender;
    }

    /**
     * @notice A function that checks if the provided greeting matches the expected greeting.
     * If the greeting matches, it emits a `GMEverybodyGM` event. Otherwise, it reverts with `BadGm`.
     *
     * @param myGm The greeting string to be checked against the expected greeting.
     * @return greet The expected greeting string.
     */
    function gm(string memory myGm) external returns (string memory greet) {
        if (keccak256(bytes(myGm)) != keccak256(bytes(greeting))) revert BadGm();
        emit GMEverybodyGM(msg.sender, greeting);
        return greeting;
    }

    /**
     * @notice Updates the greeting message stored in the contract.
     *
     * @param newGreeting The new greeting message to be stored.
     */
    function setGreeting(string memory newGreeting) external {
        greeting = newGreeting;
    }
}
``` 

[Greeter.sol](Greeter.sol) — [`Greeter`](Greeter.sol), [`gm`](Greeter.sol), [`setGreeting`](Greeter.sol), [`constructor`](Greeter.sol)  
[plan.txt](plan.txt)// filepath: Greeter.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Greeter {
    error BadGm();

    event GMEverybodyGM(address indexed who, string greeting);

    address public owner;
    string public greeting;

    /**
     * @notice Initializes the contract with a new greeting and sets the deployer as the owner.
     *
     * @param newGreeting The greeting string to be stored in the contract.
     */
    constructor(string memory newGreeting) {
        greeting = newGreeting;
        owner = msg.sender;
    }

    /**
     * @notice A function that checks if the provided greeting matches the expected greeting.
     * If the greeting matches, it emits a `GMEverybodyGM` event. Otherwise, it reverts with `BadGm`.
     *
     * @param myGm The greeting string to be checked against the expected greeting.
     * @return greet The expected greeting string.
     */
    function gm(string memory myGm) external returns (string memory greet) {
        if (keccak256(bytes(myGm)) != keccak256(bytes(greeting))) revert BadGm();
        emit GMEverybodyGM(msg.sender, greeting);
        return greeting;
    }

    /**
     * @notice Updates the greeting message stored in the contract.
     *
     * @param newGreeting The new greeting message to be stored.
     */
    function setGreeting(string memory newGreeting) external {
        greeting = newGreeting;
    }
}
``` 

[Greeter.sol](Greeter.sol) — [`Greeter`](Greeter.sol), [`gm`](Greeter.sol), [`setGreeting`](Greeter.sol), [`constructor`](Greeter.sol)  
[plan.txt](plan.txt)