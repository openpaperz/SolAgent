// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Switch {
    bool public switchOn;

    modifier onlyThis() {
        require(msg.sender == address(this), "only this contract can call");
        _;
    }

    modifier onlyOff() {
        require(!switchOn, "switch is on");
        _;
    }

    /**
     * @notice Flips the switch by executing a low-level call with the provided data.
     * @dev This function can only be called when the switch is in the "off" state (enforced by `onlyOff` modifier).
     * @param _data The encoded function call data to be executed.
     *
     * Steps:
     * 1. Perform a low-level call to the contract itself with the provided `_data`.
     * 2. Require that the call is successful; otherwise, revert with the message "call failed :(".
     */
    function flipSwitch(bytes memory _data) public onlyOff {
        (bool success, ) = address(this).call(_data);
        require(success, "call failed :(");
    }

    /**
     * @notice Turns the switch on.
     * @dev This function can only be called by the contract itself (using `onlyThis` modifier).
     * It sets the `switchOn` state variable to `true`.
     */
    function turnSwitchOn() public onlyThis {
        switchOn = true;
    }

    /**
     * @notice Turns the switch off. This function can only be called by the contract itself.
     *
     * Steps:
     * 1. Set the `switchOn` state variable to `false`.
     *
     * Modifiers:
     * - `onlyThis`: Ensures that only the contract itself can call this function.
     */
    function turnSwitchOff() public onlyThis {
        switchOn = false;
    }
}
// ...existing code...