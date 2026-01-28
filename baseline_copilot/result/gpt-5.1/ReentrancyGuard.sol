// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title ReentrancyGuard
/// @notice A simple reentrancy guard that can be inherited by other contracts
///         to protect functions from reentrant calls.
contract ReentrancyGuard {
    /// @dev The guard status constants.
    /// `_NOT_ENTERED` means the function is not currently being executed.
    /// `_ENTERED` means the function is currently being executed.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /// @dev The current guard status.
    uint256 private _status;

    /// @notice Initializes the contract setting the initial guard status to not entered.
    constructor() {
        _status = _NOT_ENTERED;
    }

    /// @notice Prevents a contract from calling itself, directly or indirectly.
    /// @dev Functions marked with this modifier cannot be reentered.
    modifier nonReentrant() {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED.
        require(_status != _ENTERED, "REENTRANCY");

        // Any calls to nonReentrant after this point will fail.
        _status = _ENTERED;

        _;

        // By storing the original value once again, we prevent a
        // reentrancy attack that might happen in the same transaction.
        _status = _NOT_ENTERED;
    }

    /// @notice Returns true if the contract is currently in a non-entered state.
    /// @return isNotEntered True if not currently in a non-reentrant call.
    function isNotEntered() external view returns (bool isNotEntered) {
        return _status == _NOT_ENTERED;
    }

    /// @notice Returns true if the contract is currently executing a nonReentrant function.
    /// @return isEntered True if currently inside a nonReentrant call.
    function isEntered() external view returns (bool isEntered) {
        return _status == _ENTERED;
    }
}