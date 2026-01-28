// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWETH {
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);
}

contract Stake {
    IWETH public WETH;
    uint256 public totalStaked;

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
        require(_weth != address(0), "Invalid WETH address");
        WETH = IWETH(_weth);

        if (msg.value > 0) {
            totalStaked += msg.value;
            UserStake[msg.sender] += msg.value;
            Stakers[msg.sender] = true;
        }
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

        uint256 allowed = WETH.allowance(msg.sender, address(this));
        require(allowed >= amount, "How am I moving the funds honey?");

        totalStaked += amount;
        UserStake[msg.sender] += amount;

        bool success = WETH.transferFrom(msg.sender, address(this), amount);
        require(success, "WETH transfer failed");

        Stakers[msg.sender] = true;

        return true;
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
    function Unstake(uint256 amount) public returns (bool success) {
        require(amount > 0, "Amount must be greater than zero");
        uint256 staked = UserStake[msg.sender];
        require(staked >= amount, "Insufficient staked balance");

        UserStake[msg.sender] = staked - amount;
        totalStaked -= amount;

        // Prefer sending ETH if available; otherwise, try returning WETH.
        if (address(this).balance >= amount) {
            (bool sent, ) = msg.sender.call{value: amount}("");
            require(sent, "ETH transfer failed");
            success = true;
        } else {
            bool transferred = WETH.transfer(msg.sender, amount);
            require(transferred, "WETH transfer failed");
            success = true;
        }

        if (UserStake[msg.sender] == 0) {
            Stakers[msg.sender] = false;
        }

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
    function bytesToUint(bytes memory data) internal pure returns (uint256 result) {
        require(data.length >= 32, "Data too short");
        assembly {
            result := mload(add(data, 32))
        }
    }

    // Fallbacks to allow receiving ETH directly.
    receive() external payable {
        totalStaked += msg.value;
        UserStake[msg.sender] += msg.value;
        Stakers[msg.sender] = true;
    }

    fallback() external payable {
        if (msg.value > 0) {
            totalStaked += msg.value;
            UserStake[msg.sender] += msg.value;
            Stakers[msg.sender] = true;
        }
    }
}