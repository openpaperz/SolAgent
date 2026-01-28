// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

contract HigherOrder {
    address public commander;
    uint256 public treasury;

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
            sstore(treasury_slot, calldataload(4))
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
        if (treasury > 255) {
            commander = msg.sender;
        } else {
            revert("Only members of the Higher Order can become Commander");
        }
    }
}
