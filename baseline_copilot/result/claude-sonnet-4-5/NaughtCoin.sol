// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NaughtCoin is ERC20 {
    uint256 public timeLock = block.timestamp + 10 * 365 days;
    address public player;

    modifier lockTokens() {
        require(block.timestamp >= timeLock, "Tokens are locked");
        _;
    }

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
        uint256 initialSupply = 1000000 * (10 ** decimals());
        _mint(_player, initialSupply);
    }

    /**
     * @notice Transfers tokens from the caller's address to the specified address.
     * @dev Overrides the `transfer` function from the parent contract and applies the `lockTokens` modifier.
     * @param _to The address to which tokens will be transferred.
     * @param _value The amount of tokens to transfer.
     * @return A boolean indicating whether the transfer was successful.
     */
    function transfer(address _to, uint256 _value) public lockTokens override returns (bool) {
        return super.transfer(_to, _value);
    }
}
