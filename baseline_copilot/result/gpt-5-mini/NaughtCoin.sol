// See plan: [plan.txt](plan.txt)
// File: [NaughtCoin.sol](NaughtCoin.sol)

SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title NaughtCoin
/// @notice ERC20 token used in the Ethernaut NaughtCoin challenge.
/// Implements a time lock on transfers for the initial player.
contract NaughtCoin is ERC20 {
    /// @notice The player address who initially receives all tokens.
    address public player;

    /// @notice Timestamp until which the player's tokens are locked.
    uint256 public timeLock;

    /**
     * @notice Initializes the ERC20 token with a custom name, symbol, and initial supply, and assigns the initial supply to the specified player.
     *
     * @param _player The address of the player who will receive the initial supply of tokens.
     *
     * Steps:
     * 1. Call the ERC20 constructor with the name "NaughtCoin" and symbol "0x0".
     * 2. Set the `player` state variable to the provided `_player` address.
     * 3. Calculate the initial supply as 1,000,000 tokens multiplied by 10^decimals (to account for token precision).
     * 4. Mint the initial supply of tokens to the `player` address.
     * 5. Emit a `Transfer` event from the zero address to the `player` address with the initial supply.
     */
    constructor(address _player) ERC20("NaughtCoin", "0x0") {
        player = _player;
        // Lock tokens for 10 years from contract deployment
        timeLock = block.timestamp + 10 * 365 days;

        uint256 initialSupply = 1_000_000 * (10 ** uint256(decimals()));
        _mint(player, initialSupply);
        // _mint emits the Transfer event from address(0) to player
    }

    /**
     * @dev Modifier that prevents the initial player from transferring tokens until the timelock expires.
     */
    modifier lockTokens() {
        if (msg.sender == player) {
            require(block.timestamp > timeLock, "Tokens are locked");
        }
        _;
    }

    /**
     * @notice Transfers tokens from the caller's address to the specified address.
     * @dev Overrides the `transfer` function from the parent contract and applies the `lockTokens` modifier.
     * @param _to The address to which tokens will be transferred.
     * @param _value The amount of tokens to transfer.
     * @return A boolean indicating whether the transfer was successful.
     */
    function transfer(address _to, uint256 _value) public override lockTokens returns (bool) {
        return super.transfer(_to, _value);
    }
}