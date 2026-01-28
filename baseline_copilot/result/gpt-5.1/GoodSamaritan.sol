// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

error NotEnoughBalance();
error InsufficientBalance(uint256 current, uint256 requested);

interface INotifyable {
    /**
     * @notice An external function that accepts a uint256 amount parameter.
     *
     * This is an interface function declaration without implementation.
     * It likely serves as a callback or notification mechanism that can be called
     * externally with an amount value.
     */
    function notify(uint256 amount) external;
}

contract Coin {
    mapping(address => uint256) public balances;

    /**
     * @notice A constructor that initializes the contract with an initial balance for a specified wallet address.
     *
     * Parameters:
     * - wallet_: The address that will receive the initial balance of one million coins.
     *
     * Behavior:
     * - Sets the balance of the provided wallet address to 10^6 (one million).
     */
    constructor(address wallet_) {
        balances[wallet_] = 1_000_000;
    }

    /**
     * @notice Transfers tokens from the sender to a specified address.
     *
     * Steps:
     * 1. Retrieve the current balance of the sender.
     *
     * 2. Check if the transfer amount is less than or equal to the sender's balance.
     *
     * 3. If sufficient balance:
     *    - Deduct the transfer amount from the sender's balance.
     *    - Add the transfer amount to the destination address's balance.
     *    - If the destination is a contract, notify it of the transfer.
     *
     * 4. If insufficient balance:
     *    - Revert with an InsufficientBalance error including current and requested amounts.
     */
    function transfer(address dest_, uint256 amount_) external {
        uint256 currentBalance = balances[msg.sender];

        if (amount_ > currentBalance) {
            revert InsufficientBalance(currentBalance, amount_);
        }

        unchecked {
            balances[msg.sender] = currentBalance - amount_;
            balances[dest_] += amount_;
        }

        if (_isContract(dest_)) {
            try INotifyable(dest_).notify(amount_) {
                // notification succeeded
            } catch {
                // ignore notification failure
            }
        }
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}

contract Wallet {
    address public owner;
    Coin public coin;

    modifier onlyOwner() {
        require(msg.sender == owner, "Wallet: caller is not the owner");
        _;
    }

    /**
     * @notice Initializes the contract by deploying a new Wallet and Coin instance, and linking them together.
     *
     * Steps:
     * 1. Deploy a new Wallet instance and assign it to the `wallet` state variable.
     * 2. Deploy a new Coin instance, passing the address of the deployed Wallet as an argument.
     * 3. Set the deployed Coin instance in the Wallet by calling `setCoin` on the Wallet.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Allows the owner to donate 10 coins to a specified address.
     *
     * Requirements:
     * - The caller must be the owner.
     * - The contract must have at least 10 coins in its balance.
     *
     * Steps:
     * 1. Check if the contract's coin balance is less than 10.
     * 2. If balance is insufficient, revert with NotEnoughBalance error.
     * 3. Otherwise, transfer exactly 10 coins from the contract to the destination address.
     */
    function donate10(address dest_) external onlyOwner {
        uint256 balance = coin.balances(address(this));
        if (balance < 10) {
            revert NotEnoughBalance();
        }
        coin.transfer(dest_, 10);
    }

    /**
     * @notice Transfers the remaining balance of the contract to a specified destination address.
     *
     * Steps:
     * 1. Only the owner can call this function (enforced by `onlyOwner` modifier).
     * 2. Transfer the remaining balance of the `coin` token from this contract to the specified destination address.
     */
    function transferRemainder(address dest_) external onlyOwner {
        uint256 balance = coin.balances(address(this));
        if (balance > 0) {
            coin.transfer(dest_, balance);
        }
    }

    /**
     * @notice Sets the coin contract address.
     *
     * Steps:
     * 1. Accepts a Coin contract address as a parameter.
     * 2. Requires the caller to be the owner of the contract.
     * 3. Updates the internal coin storage variable with the provided address.
     */
    function setCoin(Coin coin_) external onlyOwner {
        coin = coin_;
    }
}

contract GoodSamaritan {
    Wallet public wallet;
    Coin public coin;

    /**
     * @notice Initializes the contract by deploying a new Wallet and Coin instance, and linking them together.
     *
     * Steps:
     * 1. Deploy a new Wallet instance and assign it to the `wallet` state variable.
     * 2. Deploy a new Coin instance, passing the address of the deployed Wallet as an argument.
     * 3. Set the deployed Coin instance in the Wallet by calling `setCoin` on the Wallet.
     */
    constructor() {
        wallet = new Wallet();
        coin = new Coin(address(wallet));
        wallet.setCoin(coin);
    }

    /**
     * @notice Requests a donation of 10 coins from the wallet to the caller.
     *
     * Steps:
     * 1. Attempt to donate 10 coins to the caller using the `donate10` function of the wallet.
     * 2. If the donation is successful, return `true`.
     * 3. If the donation fails due to insufficient balance, catch the error and check if it matches the "NotEnoughBalance()" error signature.
     * 4. If the error matches, transfer the remaining balance to the caller using the `transferRemainder` function of the wallet.
     * 5. Return `false` to indicate that the full donation could not be completed.
     *
     * @return enoughBalance A boolean indicating whether the full donation of 10 coins was successful (`true`) or not (`false`).
     */
    function requestDonation() external returns (bool enoughBalance) {
        try wallet.donate10(msg.sender) {
            return true;
        } catch (bytes memory err) {
            if (_isNotEnoughBalanceError(err)) {
                wallet.transferRemainder(msg.sender);
            }
            return false;
        }
    }

    function _isNotEnoughBalanceError(bytes memory err) internal pure returns (bool) {
        if (err.length < 4) {
            return false;
        }
        bytes4 selector;
        assembly {
            selector := mload(add(err, 0x20))
        }
        return selector == NotEnoughBalance.selector;
    }
}