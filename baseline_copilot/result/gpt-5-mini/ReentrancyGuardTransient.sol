// [ReentrancyGuardTransient.sol](ReentrancyGuardTransient.sol)
// [`ReentrancyGuardTransient._useTransientReentrancyGuardOnlyOnMainnet`](ReentrancyGuardTransient.sol)

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ReentrancyGuardTransient {
    /**
     * @notice Internal function to determine if the transient reentrancy guard should only be used on the mainnet.
     * @return bool Returns `true` if the guard should only be used on the mainnet, otherwise `false`.
     */
    function _useTransientReentrancyGuardOnlyOnMainnet() internal virtual view returns (bool) {
        // Mainnet has chain id 1. By default, enable "only on mainnet" behavior when on mainnet.
        return block.chainid == 1;
    }
}