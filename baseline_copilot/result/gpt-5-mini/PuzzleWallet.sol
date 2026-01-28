// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UpgradeableProxy {
    address public implementation;

    constructor(address _implementation, bytes memory _initData) {
        implementation = _implementation;
        if (_initData.length > 0) {
            (bool success, ) = _implementation.delegatecall(_initData);
            require(success, "Initialization failed");
        }
    }

    fallback() external payable {
        _delegate(implementation);
    }

    receive() external payable {
        _delegate(implementation);
    }

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch result
            case 0 { revert(0, size) }
            default { return(0, size) }
        }
    }
}

contract PuzzleProxy is UpgradeableProxy {
    address public pendingAdmin;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    /**
     * @notice Initializes the UpgradeableProxy contract with an admin, implementation address, and initialization data.
     *
     * @param _admin The address of the admin who will manage the proxy.
     * @param _implementation The address of the implementation contract that the proxy will delegate calls to.
     * @param _initData The initialization data to be passed to the implementation contract during setup.
     */
    constructor(address _admin, address _implementation, bytes memory _initData) UpgradeableProxy(_implementation, _initData) {
        admin = _admin;
    }

    /**
     * @notice Proposes a new admin address to be set as the pending admin.
     *
     * @param _newAdmin The address of the proposed new admin.
     */
    function proposeNewAdmin(address _newAdmin) external {
        pendingAdmin = _newAdmin;
    }

    /**
     * @notice Approves a new admin address if it matches the pending admin.
     * @dev This function can only be called by the current admin.
     * @param _expectedAdmin The address of the expected new admin.
     */
    function approveNewAdmin(address _expectedAdmin) external onlyAdmin {
        require(pendingAdmin == _expectedAdmin, "Expected new admin by the current admin is not the pending admin");
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
    mapping(address => uint256) public balances;
    mapping(address => bool) public whitelist;
    address public owner;
    uint256 public maxBalance;

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }

    /**
     * @notice Initializes the contract with a maximum balance and sets the caller as owner.
     *
     * @param _maxBalance The maximum balance to set.
     */
    function init(uint256 _maxBalance) public {
        require(maxBalance == 0, "Already initialized");
        maxBalance = _maxBalance;
        owner = msg.sender;
    }

    /**
     * @notice Sets the maximum balance allowed for the contract.
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
     * @param addr The address to whitelist.
     */
    function addToWhitelist(address addr) external {
        require(msg.sender == owner, "Only owner can add to whitelist");
        whitelist[addr] = true;
    }

    /**
     * @notice Allows whitelisted users to deposit ETH into the contract.
     */
    function deposit() external payable onlyWhitelisted {
        require(address(this).balance <= maxBalance, "Exceeds max balance");
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Executes a transaction from the contract to a specified address.
     *
     * @param to The target address.
     * @param value The amount of wei to send.
     * @param data The call data to forward.
     */
    function execute(address to, uint256 value, bytes calldata data) external onlyWhitelisted {
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] -= value;
        (bool success, ) = to.call{value: value}(data);
        require(success, "Execution failed");
    }

    /**
     * @notice Executes multiple function calls in sequence using delegatecall.
     *         Ensures that the deposit function is called at most once.
     *
     * @param data An array of calldata entries to delegatecall.
     */
    function multicall(bytes[] calldata data) external payable onlyWhitelisted {
        bool depositCalled = false;
        for (uint256 i = 0; i < data.length; i++) {
            bytes calldata callData = data[i];
            bytes4 selector;
            assembly {
                // bytes calldata layout: at callData.offset the length is stored, so payload starts at offset + 32
                selector := calldataload(add(callData.offset, 0x20))
            }
            if (selector == this.deposit.selector) {
                require(!depositCalled, "Deposit can only be called once");
                depositCalled = true;
            }
            (bool success, ) = address(this).delegatecall(callData);
            require(success, "Delegatecall failed");
        }
    }
}