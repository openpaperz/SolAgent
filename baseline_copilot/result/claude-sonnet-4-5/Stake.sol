```solidity: Stake.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWETH {
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract Stake {
    uint256 public totalStaked;
    address public WETH;
    
    mapping(address => uint256) public UserStake;
    mapping(address => bool) public Stakers;

    /**
     * @notice Initializes the contract with the WETH token address and accepts an initial ETH deposit.
     *
     * @param _weth The address of the WETH (Wrapped Ether) token contract.
     *
     * Steps:
     * 1. Increment the `totalStaked` state variable by the amount of ETH sent with the transaction (`msg.value`).
     * 2. Assign the provided WETH token address to the `WETH` state variable.
     */
    constructor(address _weth) payable {
        totalStaked += msg.value;
        WETH = _weth;
    }

    /**
     * @notice Allows users to stake ETH in the contract.
     *
     * Requirements:
     * - The amount of ETH sent must be greater than 0.001 ether.
     *
     * Effects:
     * - Increases the total staked amount by the sent value.
     * - Updates the staked amount for the sender in the UserStake mapping.
     * - Marks the sender as a staker in the Stakers mapping.
     */
    function StakeETH() public payable {
        require(msg.value > 0.001 ether, "Don't be cheap");
        totalStaked += msg.value;
        UserStake[msg.sender] += msg.value;
        Stakers[msg.sender] = true;
    }

    /**
     * @notice Allows a user to stake WETH (Wrapped Ether) tokens.
     *
     * @param amount The amount of WETH tokens to stake. Must be greater than 0.001 ether.
     * @return bool Returns `true` if the staking operation is successful, otherwise reverts.
     *
     * Steps:
     * 1. Ensure the staking amount is greater than 0.001 ether, otherwise revert with "Don't be cheap".
     * 2. Check the allowance of WETH tokens for the caller (`msg.sender`) to this contract.
     * 3. Ensure the allowance is greater than or equal to the staking amount, otherwise revert with "How am I moving the funds honey?".
     * 4. Update the total staked amount by adding the staked amount.
     * 5. Update the user's staked amount in the `UserStake` mapping.
     * 6. Transfer the WETH tokens from the caller to this contract using the `transferFrom` function.
     * 7. Mark the caller as a staker in the `Stakers` mapping.
     * 8. Return `true` if the transfer is successful.
     */
    function StakeWETH(uint256 amount) public returns (bool) {
        require(amount > 0.001 ether, "Don't be cheap");
        uint256 allowance = IWETH(WETH).allowance(msg.sender, address(this));
        require(allowance >= amount, "How am I moving the funds honey?");
        totalStaked += amount;
        UserStake[msg.sender] += amount;
        bool success = IWETH(WETH).transferFrom(msg.sender, address(this), amount);
        Stakers[msg.sender] = true;
        return success;
    }

    /**
     * @notice Allows a user to unstake a specified amount of tokens.
     *
     * @param amount The amount of tokens to unstake.
     * @return success A boolean indicating whether the unstaking operation was successful.
     *
     * Steps:
     * 1. Check that the user has staked at least the specified amount of tokens.
     * 2. Deduct the unstaked amount from the user's staked balance.
     * 3. Deduct the unstaked amount from the total staked amount.
     * 4. Transfer the unstaked amount back to the user's address.
     * 5. Return a boolean indicating the success of the transfer operation.
     */
    function Unstake(uint256 amount) public returns (bool) {
        require(UserStake[msg.sender] >= amount, "Insufficient staked amount");
        UserStake[msg.sender] -= amount;
        totalStaked -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        return success;
    }

    /**
     * @notice Converts a bytes array to a uint256 value.
     *
     * Steps:
     * 1. Require that the input data length is at least 32 bytes.
     * 2. Use inline assembly to load the first 32 bytes of the data into a uint256 variable.
     * 3. Return the resulting uint256 value.
     *
     * @param data The bytes array to be converted.
     * @return result The uint256 value derived from the bytes array.
     */
    function bytesToUint(bytes memory data) internal pure returns (uint256) {
        require(data.length >= 32, "Data length must be at least 32 bytes");
        uint256 result;
        assembly {
            result := mload(add(data, 0x20))
        }
        return result;
    }
}
```
