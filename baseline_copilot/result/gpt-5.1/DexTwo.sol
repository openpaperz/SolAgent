// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor() {
    owner = msg.sender;
    emit OwnershipTransferred(address(0), msg.sender);
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Ownable: caller is not the owner");
    _;
  }

  function transferOwnership(address newOwner) external onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}

contract DexTwo is Ownable {
  IERC20 public token1;
  IERC20 public token2;

  /**
   * @notice An empty constructor.
   */
  constructor() Ownable() {}

  /**
   * @notice Sets the addresses of two tokens.
   * @dev This function can only be called by the owner.
   * @param _token1 The address of the first token.
   * @param _token2 The address of the second token.
   */
  function setTokens(address _token1, address _token2) public onlyOwner {
    require(_token1 != address(0) && _token2 != address(0), "DexTwo: zero address");
    token1 = IERC20(_token1);
    token2 = IERC20(_token2);
  }

  /**
   * @notice Adds liquidity by transferring tokens from the caller to the contract.
   * 
   * Steps:
   * 1. The function is restricted to the contract owner using the `onlyOwner` modifier.
   * 2. Transfers the specified `amount` of tokens from the caller (`msg.sender`) to the contract.
   * 3. The token address is specified by `token_address`.
   */
  function add_liquidity(address token_address, uint256 amount) public onlyOwner {
    require(token_address != address(0), "DexTwo: zero token");
    require(amount > 0, "DexTwo: amount 0");
    IERC20 token = IERC20(token_address);
    require(token.transferFrom(msg.sender, address(this), amount), "DexTwo: transferFrom failed");
  }

  /**
   * @notice Swaps tokens from one address to another.
   *
   * @param from The address of the token to swap from.
   * @param to The address of the token to swap to.
   * @param amount The amount of tokens to swap.
   *
   * Steps:
   * 1. Check if the sender has enough tokens to swap (revert if not).
   * 2. Calculate the swap amount using the `getSwapAmount` function.
   * 3. Transfer the `amount` of tokens from the sender to this contract.
   * 4. Approve the contract to spend the `swapAmount` of the target token.
   * 5. Transfer the `swapAmount` of the target token from the contract to the sender.
   *
   * Reverts:
   * - If the sender does not have enough tokens to swap.
   */
  function swap(address from, address to, uint256 amount) public {
    require(from != address(0) && to != address(0), "DexTwo: zero address");
    require(from != to, "DexTwo: identical tokens");
    require(amount > 0, "DexTwo: amount 0");

    IERC20 fromToken = IERC20(from);
    IERC20 toToken = IERC20(to);

    uint256 senderBalance = fromToken.balanceOf(msg.sender);
    require(senderBalance >= amount, "DexTwo: insufficient balance");

    uint256 swapAmount = getSwapAmount(from, to, amount);

    require(fromToken.transferFrom(msg.sender, address(this), amount), "DexTwo: transferFrom failed");

    // Local "approval" step (for demonstration, as the DEX is transferring its own tokens)
    // This does not affect actual ERC20 allowances but follows the described step.
    // We ignore the boolean result to stay generic across tokens that may not return it.
    toToken.approve(address(this), swapAmount);

    require(toToken.transfer(msg.sender, swapAmount), "DexTwo: transfer failed");
  }

  /**
   * @notice Calculates the swap amount based on the balance of tokens in the contract.
   *
   * @param from The address of the token to swap from.
   * @param to The address of the token to swap to.
   * @param amount The amount of tokens to swap.
   *
   * @return The calculated swap amount, derived from the ratio of the balances of the two tokens in the contract.
   */
  function getSwapAmount(address from, address to, uint256 amount) public view returns (uint256) {
    require(from != address(0) && to != address(0), "DexTwo: zero address");
    require(amount > 0, "DexTwo: amount 0");

    IERC20 fromToken = IERC20(from);
    IERC20 toToken = IERC20(to);

    uint256 fromBalance = fromToken.balanceOf(address(this));
    uint256 toBalance = toToken.balanceOf(address(this));
    require(fromBalance > 0 && toBalance > 0, "DexTwo: empty reserves");

    // swapAmount = amount * toBalance / fromBalance
    uint256 swapAmount = (amount * toBalance) / fromBalance;
    return swapAmount;
  }

  /**
   * @notice Approves a spender to spend a specified amount of tokens on behalf of the caller.
   *
   * Steps:
   * 1. Calls the `approve` function on `token1` to approve the spender for the specified amount.
   * 2. Calls the `approve` function on `token2` to approve the spender for the specified amount.
   *
   * @param spender The address of the spender to be approved.
   * @param amount The amount of tokens the spender is allowed to spend.
   */
  function approve(address spender, uint256 amount) public {
    require(spender != address(0), "DexTwo: zero spender");
    require(address(token1) != address(0) && address(token2) != address(0), "DexTwo: tokens not set");

    require(token1.approve(spender, amount), "DexTwo: token1 approve failed");
    require(token2.approve(spender, amount), "DexTwo: token2 approve failed");
  }

  /**
   * @notice Retrieves the token balance of a specified account for a given ERC20 token.
   * 
   * @param token The address of the ERC20 token contract.
   * @param account The address of the account to query the balance for.
   * @return uint256 The token balance of the specified account.
   */
  function balanceOf(address token, address account) public view returns (uint256) {
    require(token != address(0), "DexTwo: zero token");
    return IERC20(token).balanceOf(account);
  }
}

contract SwappableTokenTwo is IERC20 {
  string public name;
  string public symbol;
  uint8 public decimals = 18;
  uint256 private _totalSupply;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  address public dex;

  /**
   * @notice A constructor that initializes an ERC20 token with a specified name, symbol, and initial supply.
   *
   * Steps:
   * 1. Initialize the ERC20 token with the provided name and symbol.
   * 2. Mint the initial supply of tokens to the message sender's address.
   * 3. Set the DEX instance address for future interactions.
   */
  constructor(
    address dexInstance,
    string memory name_,
    string memory symbol_,
    uint256 initialSupply
  ) {
    require(dexInstance != address(0), "SwappableTokenTwo: zero dex");
    dex = dexInstance;
    name = name_;
    symbol = symbol_;
    _mint(msg.sender, initialSupply);
  }

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address to, uint256 amount) external override returns (bool) {
    _transfer(msg.sender, to, amount);
    return true;
  }

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @notice Approves an address to spend a specified amount of tokens on behalf of the owner.
   *
   * Steps:
   * 1. Validate that the owner is not the DEX address (to prevent invalid approvals).
   * 2. Call the parent's _approve function to set the spending allowance.
   */
  function approve(address owner, address spender, uint256 amount) public override returns (bool) {
    require(owner != dex, "SwappableTokenTwo: dex cannot approve");
    _approve(owner, spender, amount);
    return true;
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    // Standard ERC20-style approve from msg.sender
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
    uint256 currentAllowance = _allowances[from][msg.sender];
    require(currentAllowance >= amount, "SwappableTokenTwo: insufficient allowance");
    _approve(from, msg.sender, currentAllowance - amount);
    _transfer(from, to, amount);
    return true;
  }

  function _transfer(address from, address to, uint256 amount) internal {
    require(from != address(0) && to != address(0), "SwappableTokenTwo: zero address");
    require(amount > 0, "SwappableTokenTwo: amount 0");
    uint256 fromBalance = _balances[from];
    require(fromBalance >= amount, "SwappableTokenTwo: insufficient balance");
    unchecked {
      _balances[from] = fromBalance - amount;
    }
    _balances[to] += amount;
    emit Transfer(from, to, amount);
  }

  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "SwappableTokenTwo: mint to zero");
    _totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0) && spender != address(0), "SwappableTokenTwo: zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}