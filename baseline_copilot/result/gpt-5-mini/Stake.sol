// [plan.txt](plan.txt)
// [Stake.sol](Stake.sol)
// [`Stake`](Stake.sol)
// [`IERC20`](Stake.sol)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
}

contract Stake {
  address public WETH;
  mapping(address => uint256) public UserStake;
  mapping(address => bool) public Stakers;
  uint256 public totalStaked;

  /**
   * @notice Initializes the contract with the WETH token address and accepts an initial ETH deposit.
   *
   * @param _weth The address of the WETH (Wrapped Ether) token contract.
   *
   * Steps:
   * 1. Increment the `totalStaked` state variable by the amount of ETH sent with the transaction (`msg.value`).
   * 2. Assign the provided WETH token address to the `WETH` state variable.
   */
  constructor (address _weth) payable {
    WETH = _weth;
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
    require(msg.value > 0.001 ether, "Stake must be > 0.001 ether");
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
    IERC20 weth = IERC20(WETH);
    uint256 allowed = weth.allowance(msg.sender, address(this));
    require(allowed >= amount, "How am I moving the funds honey?");
    totalStaked += amount;
    UserStake[msg.sender] += amount;
    bool ok = weth.transferFrom(msg.sender, address(this), amount);
    require(ok, "WETH transfer failed");
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
  function Unstake(uint256 amount) public returns (bool) {
    require(UserStake[msg.sender] >= amount, "Not enough staked");
    UserStake[msg.sender] -= amount;
    totalStaked -= amount;

    // Attempt to send ETH back to the user.
    (bool sent, ) = msg.sender.call{value: amount}("");
    // If ETH transfer fails but contract holds WETH, try to transfer WETH as fallback.
    if (!sent) {
      IERC20 weth = IERC20(WETH);
      // Ensure contract has enough WETH to refund
      uint256 bal = weth.balanceOf(address(this));
      require(bal >= amount, "Refund failed: no ETH and insufficient WETH");
      bool ok = weth.transfer(msg.sender, amount);
      require(ok, "WETH refund failed");
      return true;
    }
    return sent;
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
    require(data.length >= 32, "Insufficient data length");
    assembly {
      result := mload(add(data, 32))
    }
  }

  // Allow contract to receive ETH
  receive() external payable {
    totalStaked += msg.value;
    UserStake[msg.sender] += msg.value;
    Stakers[msg.sender] = true;
  }
}