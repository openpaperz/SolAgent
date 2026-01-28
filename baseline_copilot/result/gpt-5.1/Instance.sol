// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Instance {
    string private password;
    bool private cleared;

    /**
     * @notice Initializes the contract with a password.
     *
     * @param _password The password to be stored in the contract.
     *
     * Steps:
     * 1. Assign the provided password to the `password` state variable.
     */
    constructor(string memory _password) {
        password = _password;
        cleared = false;
    }

    /**
     * @notice Returns a string message directing the user to another function for more information.
     * @return A string message indicating that the required information can be found in `info1()`.
     */
    function info() public pure returns (string memory) {
        return "You will find what you need in info1().";
    }

    /**
     * @notice Returns a string instructing the user to call `info2()` with the parameter "hello".
     *
     * @return A string message suggesting to call `info2()` with "hello" as the parameter.
     */
    function info1() public pure returns (string memory) {
        return "Try calling info2(\"hello\").";
    }

    /**
     * @notice Returns a specific message based on the input parameter.
     *
     * Steps:
     * 1. Checks if the input parameter is "hello" by comparing the keccak256 hash of the encoded parameter.
     * 2. If the parameter is "hello", returns a message indicating that the property infoNum holds the number of the next info method to call.
     * 3. If the parameter is not "hello", returns "Wrong parameter".
     */
    function info2(string memory param) public pure returns (string memory) {
        if (keccak256(abi.encodePacked(param)) == keccak256(abi.encodePacked("hello"))) {
            return "The property infoNum holds the number of the next info method to call.";
        } else {
            return "Wrong parameter";
        }
    }

    /**
     * @notice Returns a string indicating that the next method's name should be called.
     *
     * @return A string message suggesting the caller to use the name of the next method.
     */
    function info42() public pure returns (string memory) {
        return "theMethodName is method7123949.";
    }

    /**
     * @notice A public pure function that returns a string message.
     *
     * This function serves as a hint or instruction for users,
     * indicating that if they know the password, they should submit it to the authenticate() function.
     *
     * Returns:
     * A string message: "If you know the password, submit it to authenticate()."
     */
    function method7123949() public pure returns (string memory) {
        return "If you know the password, submit it to authenticate().";
    }

    /**
     * @notice Authenticates a user by comparing the provided passkey with the stored password.
     *
     * @param passkey The passkey provided by the user for authentication.
     *
     * Steps:
     * 1. Hash the provided passkey using keccak256 and compare it with the hashed stored password.
     * 2. If the hashes match, set the `cleared` state variable to `true`, indicating successful authentication.
     */
    function authenticate(string memory passkey) public {
        if (keccak256(abi.encodePacked(passkey)) == keccak256(abi.encodePacked(password))) {
            cleared = true;
        }
    }

    /**
     * @notice Returns the current state of the `cleared` variable.
     *
     * @return bool The value of the `cleared` variable, indicating whether a certain condition has been met or not.
     */
    function getCleared() public view returns (bool) {
        return cleared;
    }
}