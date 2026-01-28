// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UpgradeableProxy {
    address public implementation;

    constructor(address _implementation, bytes memory _initData) {
        implementation = _implementation;
        if (_initData.length > 0) {
            (bool success,) = _implementation.delegatecall(_initData);
            require(success, "Initialization failed");
        }
    }

    fallback() external payable {
        address _impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

contract PuzzleProxy is UpgradeableProxy {
    address public pendingAdmin;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    /**
     * @notice Initializes the UpgradeableProxy contract with an admin, implementation address, and initialization data.
     *
     * @param _admin The address of the admin who will manage the proxy.
     * @param _implementation The address of the implementation contract that the proxy will delegate calls to.
     * @param _initData The initialization data to be passed to the implementation contract during setup.
     *
     * Steps:
     * 1. Call the `UpgradeableProxy` constructor with the provided implementation address and initialization data.
     * 2. Assign the provided admin address to the `admin` state variable.
     */
    constructor(address _admin, address _implementation, bytes memory _initData) 
        UpgradeableProxy(_implementation, _initData) 
    {
        admin = _admin;
    }

    /**
     * @notice Proposes a new admin address to be set as the pending admin.
     *
     * @param _newAdmin The address of the proposed new admin.
     *
     * Steps:
     * 1. Assign the provided `_newAdmin` address to the `pendingAdmin` state variable.
     */
    function proposeNewAdmin(address _newAdmin) external {
        pendingAdmin = _newAdmin;
    }

    /**
     * @notice Approves a new admin address if it matches the pending admin.
     * @dev This function can only be called by the current admin.
     * @param _expectedAdmin The address of the expected new admin.
     * Requirements:
     * - The `_expectedAdmin` must match the `pendingAdmin`.
     * Effects:
     * - Updates the `admin` to the `pendingAdmin`.
     * Reverts:
     * - If `_expectedAdmin` does not match `pendingAdmin`, reverts with the message "Expected new admin by the current admin is not the pending admin".
     */
    function approveNewAdmin(address _expectedAdmin) external onlyAdmin {
        require(_expectedAdmin == pendingAdmin, "Expected new admin by the current admin is not the pending admin");
        admin = pendingAdmin;
    }

    /**
     * @notice Upgrades the contract to a new implementation address.
     * @dev This function can only be called by the admin.
     * @param _newImplementation The address of the new implementation to upgrade to.
     */
    function upgradeTo(address _newImplementation) external onlyAdmin {
        implementation = _newImplementation;
    }
}

contract PuzzleWallet {
    address public owner;
    uint256 public maxBalance;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public balances;

    modifier onlyWhitelisted() {
        require(whitelisted[msg.sender], "Not whitelisted");
        _;
    }

    /**
     * @notice Initializes the contract with a maximum balance and sets the caller as owner.
     *
     * Steps:
     * 1. Require that maxBalance is not already set (equals 0).
     * 2. Set the maxBalance to the provided value.
     * 3. Set the owner to the address of the message sender.
     */
    function init(uint256 _maxBalance) public {
        require(maxBalance == 0, "Already initialized");
        maxBalance = _maxBalance;
        owner = msg.sender;
    }

    /**
     * @notice Sets the maximum balance allowed for the contract.
     *
     * Steps:
     * 1. Require that the contract's current balance is 0.
     * 2. Set the maxBalance state variable to the provided value.
     *
     * @param _maxBalance The new maximum balance to be set.
     */
    function setMaxBalance(uint256 _maxBalance) external onlyWhitelisted {
        require(address(this).balance == 0, "Contract balance must be 0");
        maxBalance = _maxBalance;
    }

    /**
     * @notice Adds an address to the whitelist.
     *
     * Requirements:
     * - The caller must be the owner of the contract.
     *
     * Effects:
     * - The specified address is marked as whitelisted.
     */
    function addToWhitelist(address addr) external {
        require(msg.sender == owner, "Only the owner can add to whitelist");
        whitelisted[addr] = true;
    }

    /**
     * @notice Allows whitelisted users to deposit ETH into the contract.
     *
     * Requirements:
     * - The caller must be whitelisted.
     * - The contract's total balance must not exceed the maximum allowed balance.
     *
     * Process:
     * 1. Validate that the caller is whitelisted.
     * 2. Check that adding the deposited amount won't exceed the maxBalance.
     * 3. Update the sender's balance by adding the deposited amount.
     */
    function deposit() external payable onlyWhitelisted {
        require(address(this).balance <= maxBalance, "Max balance reached");
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Executes a transaction from the contract to a specified address.
     *
     * Steps:
     * 1. Validate that the caller is whitelisted.
     * 2. Check that the caller has sufficient balance to cover the value being sent.
     * 3. Deduct the sent value from the caller's balance.
     * 4. Execute the call to the target address with the specified value and data.
     * 5. Revert if the execution fails.
     */
    function execute(address to, uint256 value, bytes calldata data) external payable onlyWhitelisted {
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] -= value;
        (bool success,) = to.call{value: value}(data);
        require(success, "Execution failed");
    }

    /**
     * @notice Executes multiple function calls in sequence using delegatecall.
     *         Ensures that the deposit function is called at most once.
     *
     * Steps:
     * 1. Initialize a flag to track whether deposit has been called.
     * 2. Iterate through each calldata entry in the input array.
     * 3. Extract the function selector from the calldata.
     * 4. If the selector matches the deposit function:
     *    - Check that deposit hasn't been called already.
     *    - Set the flag to prevent reuse of msg.value.
     * 5. Execute the function call via delegatecall.
     * 6. Revert if any delegatecall fails.
     */
    function multicall(bytes[] calldata data) external payable onlyWhitelisted {
        bool depositCalled = false;
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory _data = data[i];
            bytes4 selector;
            assembly {
                selector := mload(add(_data, 32))
            }
            if (selector == this.deposit.selector) {
                require(!depositCalled, "Deposit can only be called once");
                depositCalled = true;
            }
            (bool success,) = address(this).delegatecall(data[i]);
            require(success, "Error while delegating call");
        }
    }
}
