// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC20Metadata} from "./interfaces/IERC20Metadata.sol";
import {ERC20} from "./token/ERC20.sol";
import {SafeERC20} from "./utils/SafeERC20.sol";
import {Math} from "./utils/Math.sol";

/**
 * @dev Implementation of the ERC4626 "Tokenized Vault Standard" as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[EIP-4626].
 *
 * This extension allows the minting and burning of "shares" (represented using the ERC20 inheritance) in exchange for
 * underlying "assets" through standardized {deposit}, {mint}, {redeem} and {burn} workflows. This contract extends
 * the ERC20 standard. Any additional extensions included along it would affect the "shares" token represented by this
 * contract and not the "assets" token which is an independent contract.
 */
contract ERC4626 is ERC20, IERC20Metadata {
    using Math for uint256;

    IERC20 private immutable _asset;
    uint8 private immutable _underlyingDecimals;

    /**
     * @dev Attempted to deposit more assets than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);

    /**
     * @dev Attempted to mint more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /**
     * @dev Attempted to withdraw more assets than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /**
     * @dev Attempted to redeem more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /**
     * @dev Emitted when assets are deposited into the vault via the mint and deposit methods.
     */
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /**
     * @dev Emitted when shares are withdrawn from the vault by a depositor in the redeem or withdraw methods.
     */
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @notice Initializes the contract with an ERC20 asset and attempts to retrieve its decimals.
     *
     * @param asset_ The ERC20 token asset to be associated with this contract.
     *
     * Steps:
     * 1. Attempt to retrieve the decimals of the provided ERC20 asset using `_tryGetAssetDecimals`.
     * 2. If successful, store the retrieved decimals in `_underlyingDecimals`. Otherwise, default to 18.
     * 3. Assign the provided ERC20 asset to the `_asset` state variable.
     */
    constructor(IERC20 asset_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = asset_;
    }

    /**
     * @notice Attempts to retrieve the decimals of an ERC20 token.
     *
     * Steps:
     * 1. Perform a static call to the `decimals` function of the ERC20 token.
     * 2. Check if the call was successful and if the returned data is at least 32 bytes long.
     * 3. Decode the returned data into a uint256.
     * 4. If the decoded value is within the range of a uint8, return `true` and the decoded value.
     * 5. If the call fails or the decoded value is out of range, return `false` and `0`.
     */
    function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory returndata) = address(asset_).staticcall(
            abi.encodeCall(IERC20Metadata.decimals, ())
        );
        if (success && returndata.length >= 32) {
            uint256 result = abi.decode(returndata, (uint256));
            if (result <= type(uint8).max) {
                return (true, uint8(result));
            }
        }
        return (false, 0);
    }

    /**
     * @notice Returns the number of decimals used by the token.
     * @dev This function overrides the `decimals` function from both `IERC20Metadata` and `ERC20`.
     * @return uint8 The total number of decimals, calculated as the sum of `_underlyingDecimals` and `_decimalsOffset`.
     */
    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    /**
     * @notice Returns the address of the underlying asset.
     *
     * @return The address of the asset stored in the `_asset` variable.
     */
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /**
     * @notice Returns the total amount of assets held by the contract.
     *
     * @return The balance of the asset held by the contract.
     */
    function totalAssets() public view virtual returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /**
     * @notice Converts a given amount of assets into the equivalent number of shares.
     * @dev This function is a virtual view function that internally calls `_convertToShares` with the provided assets and a rounding mode of `Math.Rounding.Floor`.
     * @param assets The amount of assets to be converted into shares.
     * @return The equivalent number of shares for the given assets.
     */
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @notice Converts a given amount of shares to the corresponding amount of assets.
     * @dev This function is a virtual view function that internally calls `_convertToAssets` with the specified rounding mode (Floor).
     * @param shares The amount of shares to convert.
     * @return The equivalent amount of assets based on the provided shares.
     */
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /**
     * @notice Returns the maximum deposit amount allowed for a given address.
     * @dev This is a virtual function that can be overridden by derived contracts.
     * @param address The address for which the maximum deposit is being queried.
     * @return uint256 The maximum deposit amount, which is set to the maximum value of uint256.
     */
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Returns the maximum amount of tokens that can be minted for a given address.
     * @dev This function is virtual and can be overridden by derived contracts.
     * @param address The address for which the maximum mintable amount is queried.
     * @return uint256 The maximum amount of tokens that can be minted, which is the maximum value of uint256.
     */
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Returns the maximum amount of assets that can be withdrawn by the owner.
     * @param owner The address of the owner whose maximum withdrawable assets are being queried.
     * @return The maximum amount of assets that can be withdrawn, calculated by converting the owner's balance to assets using floor rounding.
     */
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    /**
     * @notice Returns the maximum amount of tokens that can be redeemed by the specified owner.
     * @dev This function is virtual and can be overridden by derived contracts.
     * @param owner The address of the token owner.
     * @return uint256 The maximum amount of tokens that can be redeemed, which is equal to the owner's balance.
     */
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

    /**
     * @notice Previews the amount of shares that would be received for depositing a given amount of assets.
     * @param assets The amount of assets to be deposited.
     * @return The amount of shares that would be received, calculated using the `_convertToShares` function with rounding down.
     */
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @notice Previews the amount of assets that would be minted for a given number of shares.
     * @param shares The number of shares to preview the minting for.
     * @return The amount of assets that would be minted, rounded up to the nearest whole number.
     */
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /**
     * @notice Previews the amount of shares that would be received when withdrawing a given amount of assets.
     * @param assets The amount of assets to be withdrawn.
     * @return The amount of shares that would be received, rounded up to the nearest integer.
     */
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /**
     * @notice Previews the amount of assets that would be received upon redeeming a given number of shares.
     * @param shares The number of shares to be redeemed.
     * @return The amount of assets that would be received, calculated using the `_convertToAssets` function with rounding down.
     */
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /**
     * @notice Deposits assets into the contract and mints shares to the receiver.
     *
     * Steps:
     * 1. Retrieve the maximum allowed deposit amount for the receiver.
     * 2. If the requested deposit amount exceeds the maximum allowed, revert with an error.
     * 3. Calculate the number of shares to be minted based on the deposited assets.
     * 4. Perform the deposit operation, transferring assets from the sender to the contract and minting shares to the receiver.
     * 5. Return the number of shares minted.
     */
    function deposit(uint256 assets, address receiver) public virtual returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /**
     * @notice Mints a specified number of shares for a receiver by depositing the equivalent amount of assets.
     *
     * Steps:
     * 1. Calculate the maximum number of shares that can be minted for the receiver using `maxMint`.
     * 2. If the requested number of shares exceeds the maximum allowed, revert with an error indicating the limit is exceeded.
     * 3. Calculate the equivalent amount of assets required to mint the specified shares using `previewMint`.
     * 4. Deposit the calculated assets and mint the shares for the receiver using `_deposit`.
     * 5. Return the amount of assets deposited.
     */
    function mint(uint256 shares, address receiver) public virtual returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(msg.sender, receiver, assets, shares);

        return assets;
    }

    /**
     * @notice Withdraws a specified amount of assets from the contract and transfers them to the receiver.
     *
     * Steps:
     * 1. Retrieve the maximum amount of assets that can be withdrawn by the owner.
     * 2. If the requested assets exceed the maximum allowed, revert with an error indicating the limit is exceeded.
     * 3. Calculate the equivalent number of shares for the requested assets using `previewWithdraw`.
     * 4. Execute the withdrawal by calling the internal `_withdraw` function, transferring assets to the receiver and burning the corresponding shares.
     * 5. Return the number of shares burned during the withdrawal.
     *
     * @param assets The amount of assets to withdraw.
     * @param receiver The address to receive the withdrawn assets.
     * @param owner The address of the owner whose assets are being withdrawn.
     * @return The number of shares burned during the withdrawal.
     */
    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @notice Redeems shares for assets and transfers them to the receiver.
     *
     * Steps:
     * 1. Retrieve the maximum number of shares that can be redeemed by the owner.
     * 2. If the requested shares exceed the maximum redeemable shares, revert with an error.
     *
     * 3. Calculate the equivalent assets for the given shares using `previewRedeem`.
     * 4. Withdraw the assets from the owner and transfer them to the receiver.
     *
     * 5. Return the amount of assets redeemed.
     *
     * @param shares The number of shares to redeem.
     * @param receiver The address to receive the redeemed assets.
     * @param owner The address of the owner of the shares.
     * @return The amount of assets redeemed.
     */
    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @notice Converts a given amount of assets into shares based on the current total supply and total assets.
     * 
     * @param assets The amount of assets to convert into shares.
     * @param rounding The rounding mode to use during the calculation.
     * 
     * @return The calculated amount of shares corresponding to the provided assets.
     * 
     * The calculation uses the formula: 
     * shares = assets * (totalSupply + 10^decimalsOffset) / (totalAssets + 1)
     * 
     * This function is internal and virtual, allowing it to be overridden by derived contracts.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @notice Converts a given number of shares into the corresponding amount of assets.
     *
     * @param shares The number of shares to convert.
     * @param rounding The rounding mode to use during the calculation.
     * @return The equivalent amount of assets based on the current total assets and total supply.
     *
     * The calculation uses the formula: 
     * assets = shares * (totalAssets + 1) / (totalSupply + 10 ** _decimalsOffset())
     * where _decimalsOffset() is used to adjust for decimal precision.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @notice Internal function to handle the deposit of assets and minting of shares.
     *
     * Steps:
     * 1. Transfer assets from the caller to the contract using `safeTransferFrom` to prevent reentrancy attacks.
     * 2. Mint shares to the receiver.
     * 3. Emit a `Deposit` event with the caller, receiver, assets, and shares as parameters.
     *
     * @dev This function is designed to handle potential reentrancy attacks by ensuring the transfer happens before minting.
     *      This ensures that any reentrancy would occur before the assets are transferred and shares are minted, maintaining a valid state.
     *
     * @param caller The address initiating the deposit.
     * @param receiver The address receiving the shares.
     * @param assets The amount of assets being deposited.
     * @param shares The amount of shares being minted.
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
        SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @notice Internal function to handle the withdrawal of assets and shares.
     *
     * Steps:
     * 1. Check if the caller is not the owner. If true, spend the allowance granted to the caller by the owner.
     * 2. Burn the shares from the owner's account.
     * 3. Transfer the specified amount of assets to the receiver using SafeERC20.safeTransfer.
     * 4. Emit a Withdraw event with the details of the withdrawal.
     *
     * Notes:
     * - If the asset is ERC-777, the transfer can trigger a reentrancy attack after the transfer via the `tokensReceived` hook.
     * - The `tokensToSend` hook, triggered before the transfer, calls the vault, which is assumed to be non-malicious.
     * - To mitigate reentrancy, the transfer is performed after burning the shares, ensuring any reentrancy occurs after the state is valid.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        SafeERC20.safeTransfer(_asset, receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * @notice Returns the decimal offset for the token.
     * @dev This is a virtual function that can be overridden by derived contracts.
     * @return uint8 The decimal offset, which is 0 by default.
     */
    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }
}
