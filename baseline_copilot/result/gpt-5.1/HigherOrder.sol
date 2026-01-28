// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

contract HigherOrder {
    // Storage slot indices
    // slot 0: treasury address
    // slot 1: commander address
    address public treasury;
    address public commander;

    /**
     * @notice Registers a treasury address by storing it in the contract's storage.
     *
     * @dev This function uses inline assembly to directly store the treasury address 
     *      from the calldata into the contract's storage slot.
     *
     * Steps:
     * 1. Use inline assembly to load the treasury address from the calldata (starting at byte 4).
     * 2. Store the loaded address in the designated storage slot (`treasury_slot`).
     */
    function registerTreasury(uint8) public {
        assembly {
            // Skip the 4-byte function selector, load the next 32 bytes (the address argument)
            let arg := calldataload(4)
            // Mask to 20 bytes to get a clean address
            arg := and(arg, 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            // Store in storage slot 0 (treasury)
            sstore(0, arg)
        }
    }

    /**
     * @notice Allows a user to claim leadership (Commander role) if the treasury balance exceeds 255.
     *
     * Steps:
     * 1. Check if the treasury balance is greater than 255.
     * 2. If true, assign the caller (`msg.sender`) as the new Commander.
     * 3. If false, revert with the message "Only members of the Higher Order can become Commander".
     */
    function claimLeadership() public {
        require(
            treasury.balance > 255,
            "Only members of the Higher Order can become Commander"
        );
        commander = msg.sender;
    }
}