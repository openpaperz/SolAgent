// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Minimal IERC20 interface
interface IERC20 {
    function totalSupply() external returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @dev Minimal IERC20Metadata (note: intentionally not marked view on decimals to match required signature)
interface IERC20Metadata is IERC20 {
    function name() external returns (string memory);
    function symbol() external returns (string memory);
    function decimals() external returns (uint8);
}

/// @dev Simple Math helpers with rounding modes used by ERC4626
library Math {
    enum Rounding { Floor, Up }

    /// @dev multiply then divide with optional rounding up
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod = a * b;
            if (denominator == 0) revert();
            if (rounding == Rounding.Up && prod % denominator != 0) {
                result = prod / denominator + 1;
            } else {
                result = prod / denominator;
            }
        }
    }
}

/// @dev Minimal SafeERC20 utilities to support tokens that do not return bool.
library SafeERC20 {
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Tokens that return bool on success
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
}

/// @dev Minimal ERC20 implementation used as base for ERC4626.
contract ERC20 is IERC20, IERC20Metadata {
    string private _name = "ERC4626";
    string private _symbol = "vERC";
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // NOTE: decimals intentionally not marked view to match override patterns in this task
    function decimals() public virtual returns (uint8) {
        return 18;
    }

    function name() public virtual returns (string memory) {
        return _name;
    }

    function symbol() public virtual returns (string memory) {
        return _symbol;
    }

    function totalSupply() public virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    // Internal ERC20 operations
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero");
        require(to != address(0), "ERC20: transfer to zero");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero");
        unchecked {
            _totalSupply += amount;
            _balances[account] += amount;
        }
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from zero");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0) && spender != address(0), "ERC20: approve zero");
        _allowances[owner][spender] = amount;
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}

/// @title ERC4626 - Vault Standard (simplified, single-file)
contract ERC4626 is ERC20 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 private _asset;
    uint8 private _underlyingDecimals;
    uint8 private _decimalsOffsetValue;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Initializes the contract with an ERC20 asset and attempts to retrieve its decimals.
    /// @param asset_ The ERC20 token asset to be associated with this contract.
    constructor (IERC20 asset_) {
        (bool ok, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        if (ok) {
            _underlyingDecimals = assetDecimals;
        } else {
            _underlyingDecimals = 18;
        }
        _asset = asset_;
        _decimalsOffsetValue = 0;
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
        (bool success, bytes memory data) = address(asset_).staticcall(abi.encodeWithSignature("decimals()"));
        if (!success || data.length < 32) return (false, 0);
        uint256 decoded = abi.decode(data, (uint256));
        if (decoded > type(uint8).max) return (false, 0);
        return (true, uint8(decoded));
    }

    /**
     * @notice Returns the number of decimals used by the token.
     * @dev This function overrides the `decimals` function from both `IERC20Metadata` and `ERC20`.
     * @return uint8 The total number of decimals, calculated as the sum of `_underlyingDecimals` and `_decimalsOffset`.
     */
    function decimals() public virtual override(IERC20Metadata, ERC20) returns (uint8) {
        unchecked {
            return uint8(uint256(_underlyingDecimals) + uint256(_decimalsOffset()));
        }
    }

    /**
     * @notice Returns the address of the underlying asset.
     *
     * @return The address of the asset stored in the `_asset` variable.
     */
    function asset() public virtual view returns (address) {
        return address(_asset);
    }

    /**
     * @notice Returns the total amount of assets held by the contract.
     *
     * @return The balance of the asset held by the contract.
     */
    function totalAssets() public virtual view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /**
     * @notice Converts a given amount of assets into the equivalent number of shares.
     * @dev This function is a virtual view function that internally calls `_convertToShares` with the provided assets and a rounding mode of `Math.Rounding.Floor`.
     * @param assets The amount of assets to be converted into shares.
     * @return The equivalent number of shares for the given assets.
     */
    function convertToShares(uint256 assets) public virtual view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @notice Converts a given amount of shares to the corresponding amount of assets.
     * @dev This function is a virtual view function that internally calls `_convertToAssets` with the specified rounding mode (Floor).
     * @param shares The amount of shares to convert.
     * @return The equivalent amount of assets based on the provided shares.
     */
    function convertToAssets(uint256 shares) public virtual view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /**
     * @notice Returns the maximum deposit amount allowed for a given address.
     * @dev This is a virtual function that can be overridden by derived contracts.
     * @param /*address*/ The address for which the maximum deposit is being queried.
     * @return uint256 The maximum deposit amount, which is set to the maximum value of uint256.
     */
    function maxDeposit(address) public virtual view returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Returns the maximum amount of tokens that can be minted for a given address.
     * @dev This function is virtual and can be overridden by derived contracts.
     * @param /*address*/ The address for which the maximum mintable amount is queried.
     * @return uint256 The maximum amount of tokens that can be minted, which is the maximum value of uint256.
     */
    function maxMint(address) public virtual view returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Returns the maximum amount of assets that can be withdrawn by the owner.
     * @param owner The address of the owner whose maximum withdrawable assets are being queried.
     * @return The maximum amount of assets that can be withdrawn, calculated by converting the owner's balance to assets using floor rounding.
     */
    function maxWithdraw(address owner) public virtual view returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    /**
     * @notice Returns the maximum amount of tokens that can be redeemed by the specified owner.
     * @dev This function is virtual and can be overridden by derived contracts.
     * @param owner The address of the token owner.
     * @return uint256 The maximum amount of tokens that can be redeemed, which is equal to the owner's balance.
     */
    function maxRedeem(address owner) public virtual view returns (uint256) {
        return balanceOf(owner);
    }

    /**
     * @notice Previews the amount of shares that would be received for depositing a given amount of assets.
     * @param assets The amount of assets to be deposited.
     * @return The amount of shares that would be received, calculated using the `_convertToShares` function with rounding down.
     */
    function previewDeposit(uint256 assets) public virtual view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /**
     * @notice Previews the amount of assets that would be minted for a given number of shares.
     * @param shares The number of shares to preview the minting for.
     * @return The amount of assets that would be minted, rounded up to the nearest whole number.
     */
    function previewMint(uint256 shares) public virtual view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Up);
    }

    /**
     * @notice Previews the amount of shares that would be received when withdrawing a given amount of assets.
     * @param assets The amount of assets to be withdrawn.
     * @return The amount of shares that would be received, rounded up to the nearest integer.
     */
    function previewWithdraw(uint256 assets) public virtual view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Up);
    }

    /**
     * @notice Previews the amount of assets that would be received upon redeeming a given number of shares.
     * @param shares The number of shares to be redeemed.
     * @return The amount of assets that would be received, calculated using the `_convertToAssets` function with rounding down.
     */
    function previewRedeem(uint256 shares) public virtual view returns (uint256) {
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
        require(assets <= maxDeposit(receiver), "ERC4626: deposit exceeds max");
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
        require(shares <= maxMint(receiver), "ERC4626: mint exceeds max");
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
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw exceeds max");
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
        require(shares <= maxRedeem(owner), "ERC4626: redeem exceeds max");
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
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal virtual view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 offset = _decimalsOffsetMultiplier();
        uint256 numeratorFactor = supply + offset;
        uint256 denominatorFactor = totalAssets() + 1;
        if (numeratorFactor == 0) {
            // If no supply, define 1:1 behavior (assets -> shares)
            return assets;
        }
        if (rounding == Math.Rounding.Floor) {
            return Math.mulDiv(assets, numeratorFactor, denominatorFactor, Math.Rounding.Floor);
        } else {
            return Math.mulDiv(assets, numeratorFactor, denominatorFactor, Math.Rounding.Up);
        }
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
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal virtual view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 offset = _decimalsOffsetMultiplier();
        uint256 denom = supply + offset;
        uint256 numeratorFactor = totalAssets() + 1;
        if (denom == 0) {
            // If denom is zero, interpret as shares == assets
            return shares;
        }
        if (rounding == Math.Rounding.Floor) {
            return Math.mulDiv(shares, numeratorFactor, denom, Math.Rounding.Floor);
        } else {
            return Math.mulDiv(shares, numeratorFactor, denom, Math.Rounding.Up);
        }
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
        // Transfer assets from caller to vault
        SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
        // Mint shares to receiver
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
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal virtual {
        if (caller != owner) {
            // spender is withdrawing on behalf of owner, spend allowance in shares
            _spendAllowance(owner, caller, shares);
        }
        // Burn owner's shares
        _burn(owner, shares);
        // Transfer assets to receiver
        SafeERC20.safeTransfer(_asset, receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * @notice Returns the decimal offset for the token.
     * @dev This is a virtual function that can be overridden by derived contracts.
     * @return uint8 The decimal offset, which is 0 by default.
     */
    function _decimalsOffset() internal virtual view returns (uint8) {
        return _decimalsOffsetValue;
    }

    /// @dev Internal helper to compute 10 ** _decimalsOffset()
    function _decimalsOffsetMultiplier() internal view returns (uint256) {
        uint8 offset = _decimalsOffset();
        uint256 mult = 1;
        for (uint8 i = 0; i < offset; ++i) {
            mult *= 10;
        }
        return mult;
    }
}