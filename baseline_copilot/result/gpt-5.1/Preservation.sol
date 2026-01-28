// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Preservation {
    // public library contracts 
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner; 
    uint256 public storedTime;

    /**
     * @notice Initializes the contract with the addresses of two time zone libraries and sets the deployer as the owner.
     *
     * @param _timeZone1LibraryAddress The address of the first time zone library.
     * @param _timeZone2LibraryAddress The address of the second time zone library.
     *
     * Steps:
     * 1. Assign the provided `_timeZone1LibraryAddress` to the `timeZone1Library` state variable.
     * 2. Assign the provided `_timeZone2LibraryAddress` to the `timeZone2Library` state variable.
     * 3. Set the deployer (`msg.sender`) as the owner of the contract.
     */
    constructor (address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
        timeZone1Library = _timeZone1LibraryAddress;
        timeZone2Library = _timeZone2LibraryAddress;
        owner = msg.sender;
    }

    /**
     * @notice Sets the timestamp using the `timeZone1Library` contract via delegatecall.
     *
     * @param _timeStamp The timestamp to be set.
     *
     * Steps:
     * 1. Perform a delegatecall to the `timeZone1Library` contract, passing the encoded function signature and the `_timeStamp` parameter.
     * 2. The `delegatecall` allows the function to execute in the context of the calling contract, using the storage of the caller.
     */
    function setFirstTime(uint256 _timeStamp) public {
        (bool success, ) = timeZone1Library.delegatecall(
            abi.encodeWithSignature("setTime(uint256)", _timeStamp)
        );
        require(success, "delegatecall to timeZone1Library failed");
    }

    /**
     * @notice Sets the timestamp for the second time zone by delegating the call to `timeZone2Library`.
     *
     * Steps:
     * 1. Delegates a call to `timeZone2Library` with the encoded function signature and the provided `_timeStamp`.
     * 2. The call is made using `delegatecall`, which executes the code in the context of the calling contract.
     */
    function setSecondTime(uint256 _timeStamp) public {
        (bool success, ) = timeZone2Library.delegatecall(
            abi.encodeWithSignature("setTime(uint256)", _timeStamp)
        );
        require(success, "delegatecall to timeZone2Library failed");
    }
}

contract LibraryContract {
    // storedTime can be customized by the library contract
    uint256 public storedTime;

    /**
     * @notice Sets the stored time to the provided value.
     *
     * @param _time The new time value to store.
     */
    function setTime(uint256 _time) public {
        storedTime = _time;
    }
}