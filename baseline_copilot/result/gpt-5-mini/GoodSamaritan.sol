// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface INotifyable {
  /**
   * @notice Notification callback with transferred amount.
   */
  function notify(uint256 amount) external;
}

contract Coin {
  mapping(address => uint256) public balances;
  error InsufficientBalance(uint256 available, uint256 required);

  /**
   * @notice Initialize with 1_000_000 tokens assigned to the wallet.
   */
  constructor(address wallet_) {
    balances[wallet_] = 1_000_000;
  }

  /**
   * @notice Transfer tokens from msg.sender to dest_.
   * Reverts with InsufficientBalance if sender has not enough funds.
   * If dest_ is a contract, notifies it via INotifyable.notify.
   */
  function transfer(address dest_, uint256 amount_) external {
    uint256 bal = balances[msg.sender];
    if (amount_ > bal) revert InsufficientBalance(bal, amount_);
    balances[msg.sender] = bal - amount_;
    balances[dest_] += amount_;

    if (dest_.code.length > 0) {
      INotifyable(dest_).notify(amount_);
    }
  }
}

contract Wallet {
  address public owner;
  Coin public coin;
  error NotEnoughBalance();

  modifier onlyOwner() {
    require(msg.sender == owner, "Wallet: caller is not the owner");
    _;
  }

  /**
   * @notice Set owner to the deployer (the creating contract/address).
   */
  constructor() {
    owner = msg.sender;
  }

  /**
   * @notice Donate exactly 10 coins to dest_. Only callable by owner.
   * Reverts with NotEnoughBalance() if contract has less than 10 coins.
   */
  function donate10(address dest_) external onlyOwner {
    if (coin.balances(address(this)) < 10) revert NotEnoughBalance();
    coin.transfer(dest_, 10);
  }

  /**
   * @notice Transfer the remaining coin balance to dest_. Only owner.
   */
  function transferRemainder(address dest_) external onlyOwner {
    uint256 balance = coin.balances(address(this));
    if (balance > 0) {
      coin.transfer(dest_, balance);
    }
  }

  /**
   * @notice Set the Coin contract address. Only owner.
   */
  function setCoin(Coin coin_) external onlyOwner {
    coin = coin_;
  }
}

contract GoodSamaritan {
  Wallet public wallet;
  Coin public coin;

  bytes4 private constant NOT_ENOUGH_SELECTOR = bytes4(keccak256("NotEnoughBalance()"));

  /**
   * @notice Deploys a new Wallet and Coin, then links the coin into the wallet.
   */
  constructor() {
    wallet = new Wallet();
    coin = new Coin(address(wallet));
    wallet.setCoin(coin);
  }

  /**
   * @notice Requests a donation of 10 coins to the caller.
   *
   * Attempts to call wallet.donate10(msg.sender). If it succeeds, returns true.
   * If it reverts with NotEnoughBalance(), calls wallet.transferRemainder(msg.sender) and returns false.
   * Other revert reasons are bubbled up.
   */
  function requestDonation() external returns (bool enoughBalance) {
    try wallet.donate10(msg.sender) {
      return true;
    } catch (bytes memory reason) {
      // Check for NotEnoughBalance() selector (custom error)
      if (reason.length >= 4) {
        bytes4 sig;
        assembly {
          sig := mload(add(reason, 32))
        }
        if (sig == NOT_ENOUGH_SELECTOR) {
          wallet.transferRemainder(msg.sender);
          return false;
        }
      }
      // Revert with original reason for any other error
      assembly {
        revert(add(reason, 32), mload(reason))
      }
    }
  }
}