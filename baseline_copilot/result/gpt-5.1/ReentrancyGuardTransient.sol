// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ReentrancyGuardTransient
/// @notice Transient storage based reentrancy guard compatible with EIP-1153.
/// @dev This guard is meant to be used with a function modifier on external/public functions.
///      It uses transient storage so the reentrancy state is cleared automatically at the end
///      of the transaction, without incurring permanent storage writes.
///      The `_useTransientReentrancyGuardOnlyOnMainnet` hook allows disabling the guard
///      on non-mainnet networks to ease testing or local execution.
contract ReentrancyGuardTransient {
    /// @dev Transient storage slot used as the reentrancy flag.
    ///      Using an uncommon slot reduces the risk of collisions with other transient state.
    ///      The actual value is irrelevant; non-zero means "entered".
    uint256 transient t_reentrancyStatus;

    /// @notice Thrown when a reentrant call is detected.
    error ReentrancyGuardTransientReentrantCall();

    /// @notice Modifier that prevents reentrant calls to a function.
    /// @dev Uses EIP-1153 transient storage, so the flag is automatically reset
    ///      at the end of the transaction. On chains where transient storage is
    ///      not supported or where the guard is disabled via
    ///      `_useTransientReentrancyGuardOnlyOnMainnet`, the modifier becomes a no-op.
    modifier nonReentrantTransient() {
        if (!_isGuardDisabled()) {
            // If already entered, revert.
            if (t_reentrancyStatus != 0) {
                revert ReentrancyGuardTransientReentrantCall();
            }
            // Mark as entered for the duration of this transaction.
            t_reentrancyStatus = 1;
        }
        _;
    }

    /// @notice Internal function to determine if the transient reentrancy guard
    ///         should only be used on the mainnet.
    /// @return bool Returns `true` if the guard should only be used on the mainnet,
    ///              otherwise `false`.
    function _useTransientReentrancyGuardOnlyOnMainnet()
        internal
        virtual
        view
        returns (bool)
    {
        // By default, only use the transient reentrancy guard on Ethereum mainnet
        // where `block.chainid == 1`. Child contracts can override this behavior.
        return block.chainid == 1;
    }

    /// @dev Returns true if the guard should be disabled on the current chain.
    ///      If `_useTransientReentrancyGuardOnlyOnMainnet()` returns true and the
    ///      current chain is not mainnet, the guard will be disabled.
    function _isGuardDisabled() internal view returns (bool) {
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            // Guard enabled only on mainnet; disable elsewhere.
            return block.chainid != 1;
        }
        // Guard enabled on all chains.
        return false;
    }
}