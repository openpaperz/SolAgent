// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoinFlip {
    uint256 public consecutiveWins;
    uint256 private lastHash;
    uint256 private constant FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    /**
     * @notice Initializes the contract by setting the `consecutiveWins` counter to 0.
     *
     * Steps:
     * 1. Set the `consecutiveWins` state variable to 0.
     */
    constructor () {
        consecutiveWins = 0;
    }

    /**
     * @notice Simulates a coin flip game where the outcome is determined by the previous block's hash.
     *
     * @param _guess The player's guess (true or false) for the coin flip outcome.
     * @return bool Returns true if the guess matches the outcome, otherwise false.
     *
     * Steps:
     * 1. Retrieve the hash of the previous block and convert it to a uint256 value.
     * 2. Check if the previous block's hash matches the last recorded hash. If it does, revert the transaction to prevent replay attacks.
     * 3. Store the current block's hash as the last recorded hash.
     * 4. Calculate the coin flip outcome by dividing the block hash by a predefined factor (`FACTOR`).
     * 5. Determine the side of the coin flip (true or false) based on the calculated value.
     * 6. Compare the player's guess with the calculated outcome:
     *    - If they match, increment the consecutive wins counter and return true.
     *    - If they don't match, reset the consecutive wins counter to 0 and return false.
     */
    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        require(blockValue != lastHash, "Already used this block hash");
        lastHash = blockValue;

        uint256 coinFlip = blockValue / FACTOR;
        bool side = (coinFlip == 1);

        if (side == _guess) {
            consecutiveWins += 1;
            return true;
        } else {
            consecutiveWins = 0;
            return false;
        }
    }
}