// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Minimal IERC20 interface
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

/// @notice Simple, minimal ERC20 implementation used by SwappableTokenTwo
contract ERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

/// @title DexTwo
contract DexTwo {
    address public owner;
    address public token1;
    address public token2;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice An empty constructor.
     */
    constructor () {
        owner = msg.sender;
    }

    /**
     * @notice Sets the addresses of two tokens.
     * @dev This function can only be called by the owner.
     * @param _token1 The address of the first token.
     * @param _token2 The address of the second token.
     */
    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
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
        require(token_address != address(0), "Invalid token");
        require(amount > 0, "Amount must be > 0");
        bool ok = IERC20(token_address).transferFrom(msg.sender, address(this), amount);
        require(ok, "transferFrom failed");
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
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Insufficient balance");
        uint256 swapAmount = getSwapAmount(from, to, amount);
        require(swapAmount > 0, "Swap amount zero");

        // Transfer 'amount' of token 'from' from sender to this contract
        bool ok = IERC20(from).transferFrom(msg.sender, address(this), amount);
        require(ok, "transferFrom failed");

        // Transfer the computed swap amount of token 'to' from contract to sender
        // (No need to approve the contract to spend its own tokens.)
        ok = IERC20(to).transfer(msg.sender, swapAmount);
        require(ok, "transfer failed");
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
        uint256 fromBalance = IERC20(from).balanceOf(address(this));
        uint256 toBalance = IERC20(to).balanceOf(address(this));
        require(fromBalance > 0, "Insufficient liquidity for from token");
        // swapAmount = (amount * toBalance) / fromBalance
        return (amount * toBalance) / fromBalance;
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
        if (token1 != address(0)) {
            IERC20(token1).approve(spender, amount);
        }
        if (token2 != address(0)) {
            IERC20(token2).approve(spender, amount);
        }
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

/// @title SwappableTokenTwo
contract SwappableTokenTwo is ERC20 {
    address public dex;

    /**
     * @notice A constructor that initializes an ERC20 token with a specified name, symbol, and initial supply.
     *
     * Steps:
     * 1. Initialize the ERC20 token with the provided name and symbol.
     * 2. Mint the initial supply of tokens to the message sender's address.
     * 3. Set the DEX instance address for future interactions.
     */
    constructor (address dexInstance, string memory name_, string memory symbol_, uint256 initialSupply) ERC20(name_, symbol_) {
        dex = dexInstance;
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /**
     * @notice Approves an address to spend a specified amount of tokens on behalf of the owner.
     *
     * Steps:
     * 1. Validate that the owner is not the DEX address (to prevent invalid approvals).
     * 2. Call the parent's _approve function to set the spending allowance.
     */
    function approve(address owner, address spender, uint256 amount) public {
        require(owner != dex, "Owner cannot be DEX");
        require(msg.sender == owner, "Caller must be owner");
        _approve(owner, spender, amount);
    }
}
