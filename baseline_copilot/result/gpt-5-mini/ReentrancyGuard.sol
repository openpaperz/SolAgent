// ...existing code...
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title ReentrancyGuard
/// @notice Simple reentrancy guard to prevent reentrant calls to functions.
abstract contract ReentrancyGuard {
    // Use uint256 to save gas compared to boolean when used with storage.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /// @notice Prevents a contract from calling itself, directly or indirectly.
    /// @dev Apply to functions to make them non-reentrant.
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /// @notice Returns true if the contract is currently in a non-reentrant call.
    function _isEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}