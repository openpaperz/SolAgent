// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}

contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor() {
    _transferOwnership(_msgSender());
  }

  modifier onlyOwner() {
    require(owner() == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  function owner() public view virtual returns (address) {
    return _owner;
  }

  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  function transferOwnership(address newOwner) public virtual onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}

contract ERC20 is Context, IERC20 {
  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
  }

  function name() public view virtual returns (string memory) {
    return _name;
  }

  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  function decimals() public pure virtual returns (uint8) {
    return 18;
  }

  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);
    uint256 currentAllowance = _allowances[sender][_msgSender()];
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    unchecked {
      _approve(sender, _msgSender(), currentAllowance - amount);
    }
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowances[_msgSender()][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
      _approve(_msgSender(), spender, currentAllowance - subtractedValue);
    }
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
    unchecked {
      _balances[sender] = senderBalance - amount;
    }
    _balances[recipient] += amount;

    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    _totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: burn from the zero address");

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
      _balances[account] = accountBalance - amount;
    }
    _totalSupply -= amount;

    emit Transfer(account, address(0), amount);
  }

  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}

contract Dex is Ownable {
  address public token1;
  address public token2;

  /**
   * @notice An empty constructor.
   */
  constructor() {}

  /**
   * @notice Sets the addresses of two tokens.
   * @dev This function can only be called by the owner.
   * @param _token1 The address of the first token.
   * @param _token2 The address of the second token.
   */
  function setTokens(address _token1, address _token2) public onlyOwner {
    require(_token1 != address(0) && _token2 != address(0), "Dex: zero address");
    require(_token1 != _token2, "Dex: identical tokens");
    token1 = _token1;
    token2 = _token2;
  }

  /**
   * @notice Adds liquidity by transferring tokens from the caller to the contract.
   * 
   * Steps:
   * 1. Transfers the specified amount of tokens from the caller to the contract.
   * 
   * Requirements:
   * - The caller must be the owner of the contract.
   * - The token address must be valid.
   * - The amount must be greater than zero.
   */
  function addLiquidity(address token_address, uint256 amount) public onlyOwner {
    require(amount > 0, "Dex: amount zero");
    require(token_address == token1 || token_address == token2, "Dex: unsupported token");
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
  }

  /**
   * @notice Swaps tokens between two supported token pairs.
   *
   * @param from The address of the token to swap from.
   * @param to The address of the token to swap to.
   * @param amount The amount of tokens to swap.
   *
   * Requirements:
   * 1. The `from` and `to` tokens must be one of the supported pairs (`token1` and `token2`).
   * 2. The caller must have a sufficient balance of the `from` token to perform the swap.
   *
   * Steps:
   * 1. Calculate the swap amount using the `getSwapPrice` function.
   * 2. Transfer the `amount` of `from` tokens from the caller to this contract.
   * 3. Approve the contract to transfer the calculated `swapAmount` of `to` tokens.
   * 4. Transfer the `swapAmount` of `to` tokens from the contract to the caller.
   *
   * Reverts:
   * - If the `from` and `to` tokens are not a valid pair, with the message "Invalid tokens".
   * - If the caller does not have enough `from` tokens, with the message "Not enough to swap".
   */
  function swap(address from, address to, uint256 amount) public {
    require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint256 swapAmount = getSwapPrice(from, to, amount);

    IERC20(from).transferFrom(msg.sender, address(this), amount);

    // Step 3 in description is redundant in practice for this pattern,
    // but we'll keep an explicit approval from this contract to itself for clarity.
    IERC20(to).approve(address(this), swapAmount);

    IERC20(to).transfer(msg.sender, swapAmount);
  }

  /**
   * @notice Calculates the swap price between two tokens based on their balances in the contract.
   *
   * @param from The address of the token to swap from.
   * @param to The address of the token to swap to.
   * @param amount The amount of the `from` token to calculate the swap price for.
   *
   * @return The calculated swap price in terms of the `to` token.
   *
   * Formula:
   * Swap Price = (amount * balance of `to` token in contract) / balance of `from` token in contract
   */
  function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
    uint256 fromBalance = IERC20(from).balanceOf(address(this));
    uint256 toBalance = IERC20(to).balanceOf(address(this));
    require(fromBalance > 0 && toBalance > 0, "Dex: empty reserves");
    return (amount * toBalance) / fromBalance;
  }

  /**
   * @notice Approves a spender to spend a specified amount of tokens on behalf of the caller for both token1 and token2.
   *
   * @param spender The address of the spender to be approved.
   * @param amount The amount of tokens the spender is allowed to spend.
   *
   * Steps:
   * 1. Call the `approve` function of `SwappableToken` for `token1`, approving the spender to spend the specified amount on behalf of the caller (`msg.sender`).
   * 2. Call the `approve` function of `SwappableToken` for `token2`, approving the spender to spend the specified amount on behalf of the caller (`msg.sender`).
   */
  function approve(address spender, uint256 amount) public {
    require(token1 != address(0) && token2 != address(0), "Dex: tokens not set");
    IERC20(token1).approve(spender, amount);
    IERC20(token2).approve(spender, amount);
  }

  /**
   * @notice Retrieves the token balance of a specified account for a given ERC20 token.
   *
   * @param token The address of the ERC20 token contract.
   * @param account The address of the account to query the balance for.
   * @return uint256 The token balance of the specified account.
   */
  function balanceOf(address token, address account) public view returns (uint256) {
    return IERC20(token).balanceOf(account);
  }
}

contract SwappableToken is ERC20 {
  address private _dex;

  /**
   * @notice Initializes the token contract with a DEX instance, name, symbol, and initial supply.
   *
   * Steps:
   * 1. Call the parent ERC20 constructor with the provided name and symbol.
   * 2. Mint the initial supply of tokens to the message sender.
   * 3. Store the DEX instance address in the private _dex state variable.
   */
  constructor(
    address dexInstance,
    string memory name,
    string memory symbol,
    uint256 initialSupply
  ) ERC20(name, symbol) {
    require(dexInstance != address(0), "SwappableToken: dex is zero address");
    _dex = dexInstance;
    _mint(msg.sender, initialSupply);
  }

  /**
   * @notice Approves an address to spend a specific amount of tokens on behalf of the owner.
   *
   * Steps:
   * 1. Check that the owner is not the DEX contract itself (to prevent invalid approvals).
   * 2. Call the parent's _approve function to set the spending allowance.
   */
  function approve(address owner, address spender, uint256 amount) public {
    require(owner != _dex, "SwappableToken: dex cannot approve itself");
    _approve(owner, spender, amount);
  }
}