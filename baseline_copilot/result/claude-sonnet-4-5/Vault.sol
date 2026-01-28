// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    bool public locked;
    bytes32 private password;

    /**
     * @notice Initializes the contract with a password and locks it by default.
     *
     * @param _password The password to be stored in the contract, used for unlocking.
     *
     * Steps:
     * 1. Set the `locked` state variable to `true` to lock the contract.
     * 2. Store the provided password in the `password` state variable.
     */
    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    /**
     * @notice Unlocks the contract if the provided password matches the stored password.
     *
     * @param _password The password to be checked against the stored password.
     *
     * Steps:
     * 1. Check if the provided `_password` matches the stored `password`.
     * 2. If the passwords match, set the `locked` state variable to `false`, unlocking the contract.
     */
    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}
