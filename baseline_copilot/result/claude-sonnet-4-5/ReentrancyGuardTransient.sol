```solidity: ReentrancyGuardTransient.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ReentrancyGuardTransient
/// @notice Provides reentrancy protection using transient storage
/// @dev Uses EIP-1153 transient storage for gas-efficient reentrancy guards
contract ReentrancyGuardTransient {
    /// @dev The reentrancy guard state slot
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x929eee149b4bd21268;

    /// @dev Unauthorized reentrant call
    error Reentrancy();

    /**
     * @dev Guards a function from reentrancy
     */
    modifier nonReentrant() {
        assembly {
            if tload(_REENTRANCY_GUARD_SLOT) {
                mstore(0x00, 0xab143c06) // `Reentrancy()` selector
                revert(0x1c, 0x04)
            }
            tstore(_REENTRANCY_GUARD_SLOT, 1)
        }
        _;
        assembly {
            tstore(_REENTRANCY_GUARD_SLOT, 0)
        }
    }

    /**
     * @dev Guards a function from reentrancy, but only if the chain is mainnet
     */
    modifier nonReentrantOnMainnet() {
        assembly {
            if tload(_REENTRANCY_GUARD_SLOT) {
                mstore(0x00, 0xab143c06) // `Reentrancy()` selector
                revert(0x1c, 0x04)
            }
        }
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            assembly {
                tstore(_REENTRANCY_GUARD_SLOT, 1)
            }
        }
        _;
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            assembly {
                tstore(_REENTRANCY_GUARD_SLOT, 0)
            }
        }
    }

    /**
     * @notice Internal function to determine if the transient reentrancy guard should only be used on the mainnet.
     * @return bool Returns `true` if the guard should only be used on the mainnet, otherwise `false`.
     */
    function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual returns (bool) {
        return block.chainid == 1;
    }
}
```
