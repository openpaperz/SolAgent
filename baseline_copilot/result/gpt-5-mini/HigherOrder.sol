// [HigherOrder.sol](HigherOrder.sol)
// [plan.txt](plan.txt)
// Referenced symbols:
// [`HigherOrder.registerTreasury`](HigherOrder.sol)
// [`HigherOrder.claimLeadership`](HigherOrder.sol)

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

contract HigherOrder {
    // commander is stored at slot 0
    address public commander;
    // treasury is stored at slot 1
    address public treasury;
    // named slot for clarity (value 1)
    uint256 private constant treasury_slot = 1;

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
            // calldataload(4) reads 32 bytes starting at byte offset 4 (skipping the 4-byte selector)
            let val := calldataload(4)
            // store the loaded value into storage slot 1 (treasury_slot)
            sstore(1, val)
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
        require(address(treasury).balance > 255, "Only members of the Higher Order can become Commander");
        commander = msg.sender;
    }
}