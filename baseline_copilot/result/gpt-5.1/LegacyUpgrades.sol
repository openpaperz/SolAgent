// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Core, Options } from "./Core.sol";

library Upgrades {
    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed to the upgrade function.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `upgradeProxy` function from the `Core` contract, passing the proxy address, contract name, data, and options.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        Options memory opts
    ) internal {
        Core.upgradeProxy(proxy, contractName, data, opts);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed to the upgrade function.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `upgradeProxy` function from the `Core` contract, passing the proxy address, contract name, data, and options.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data
    ) internal {
        Options memory opts;
        Core.upgradeProxy(proxy, contractName, data, opts);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed to the upgrade function.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `upgradeProxy` function from the `Core` contract, passing the proxy address, contract name, data, and options.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        Options memory opts,
        address tryCaller
    ) internal {
        Core.upgradeProxy(proxy, contractName, data, opts, tryCaller);
    }

    /**
     * @notice Upgrades a proxy contract to a new implementation.
     *
     * @param proxy The address of the proxy contract to be upgraded.
     * @param contractName The name of the new contract implementation.
     * @param data Additional data to be passed to the upgrade function.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `upgradeProxy` function from the `Core` contract, passing the proxy address, contract name, data, and options.
     */
    function upgradeProxy(
        address proxy,
        string memory contractName,
        bytes memory data,
        address tryCaller
    ) internal {
        Options memory opts;
        Core.upgradeProxy(proxy, contractName, data, opts, tryCaller);
    }

    /**
     * @notice Upgrades the beacon contract to a new implementation specified by the contract name.
     *
     * @param beacon The address of the beacon contract to be upgraded.
     * @param contractName The name of the new contract implementation to upgrade the beacon to.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `Core.upgradeBeacon` function with the provided beacon address, contract name, and empty options.
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName,
        Options memory opts
    ) internal {
        Core.upgradeBeacon(beacon, contractName, opts);
    }

    /**
     * @notice Upgrades the beacon contract to a new implementation specified by the contract name.
     *
     * @param beacon The address of the beacon contract to be upgraded.
     * @param contractName The name of the new contract implementation to upgrade the beacon to.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `Core.upgradeBeacon` function with the provided beacon address, contract name, and empty options.
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName
    ) internal {
        Options memory opts;
        Core.upgradeBeacon(beacon, contractName, opts);
    }

    /**
     * @notice Upgrades the beacon contract to a new implementation specified by the contract name.
     *
     * @param beacon The address of the beacon contract to be upgraded.
     * @param contractName The name of the new contract implementation to upgrade the beacon to.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `Core.upgradeBeacon` function with the provided beacon address, contract name, and empty options.
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName,
        Options memory opts,
        address tryCaller
    ) internal {
        Core.upgradeBeacon(beacon, contractName, opts, tryCaller);
    }

    /**
     * @notice Upgrades the beacon contract to a new implementation specified by the contract name.
     *
     * @param beacon The address of the beacon contract to be upgraded.
     * @param contractName The name of the new contract implementation to upgrade the beacon to.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `Core.upgradeBeacon` function with the provided beacon address, contract name, and empty options.
     */
    function upgradeBeacon(
        address beacon,
        string memory contractName,
        address tryCaller
    ) internal {
        Options memory opts;
        Core.upgradeBeacon(beacon, contractName, opts, tryCaller);
    }

    /**
     * @notice Validates the upgrade of a contract by calling the `validateUpgrade` function from the `Core` contract.
     *
     * @param contractName The name of the contract to be upgraded.
     * @param opts The options for the upgrade, passed as a struct of type `Options`.
     */
    function validateUpgrade(
        string memory contractName,
        Options memory opts
    ) internal {
        Core.validateUpgrade(contractName, opts);
    }

    /**
     * @notice Prepares an upgrade for a specified contract.
     *
     * @param contractName The name of the contract to be upgraded.
     * @param opts The options for the upgrade process.
     * @return The address of the prepared upgrade.
     *
     * Steps:
     * 1. Calls the `prepareUpgrade` function from the `Core` contract.
     * 2. Returns the address of the prepared upgrade.
     */
    function prepareUpgrade(
        string memory contractName,
        Options memory opts
    ) internal returns (address) {
        return Core.prepareUpgrade(contractName, opts);
    }

    /**
     * @notice Retrieves the admin address for a given proxy contract.
     *
     * @param proxy The address of the proxy contract for which the admin address is to be retrieved.
     * @return The address of the admin associated with the given proxy contract.
     *
     * Steps:
     * 1. Calls the `getAdminAddress` function from the `Core` contract, passing the proxy address as an argument.
     * 2. Returns the admin address associated with the proxy.
     */
    function getAdminAddress(address proxy) internal view returns (address) {
        return Core.getAdminAddress(proxy);
    }

    /**
     * @notice Deploys a beacon contract with the specified contract name and initial owner.
     *
     * @param contractName The name of the contract to be deployed as a beacon.
     * @param initialOwner The address of the initial owner of the beacon contract.
     *
     * @return The address of the deployed beacon contract.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `deployBeacon` function with the provided `contractName`, `initialOwner`, and the empty `Options` struct.
     * 3. Return the address of the deployed beacon contract.
     */
    function getImplementationAddress(
        address proxy
    ) internal view returns (address) {
        return Core.getImplementationAddress(proxy);
    }

    /**
     * @notice Retrieves the beacon address associated with a given proxy address.
     *
     * @param proxy The address of the proxy contract.
     * @return The beacon address linked to the proxy.
     *
     * Steps:
     * 1. Call the `getBeaconAddress` function from the `Core` contract, passing the proxy address.
     * 2. Return the beacon address retrieved from the `Core` contract.
     */
    function getBeaconAddress(
        address proxy
    ) internal view returns (address) {
        return Core.getBeaconAddress(proxy);
    }
}

library UnsafeUpgrades {
    /**
     * @notice Upgrades the implementation of a proxy contract.
     *
     * Steps:
     * 1. Takes in three parameters: the proxy address, the new implementation address, and calldata for initialization.
     * 2. Calls the Core.upgradeProxyTo function with these parameters to perform the upgrade.
     */
    function upgradeProxy(
        address proxy,
        address newImpl,
        bytes memory data
    ) internal {
        Core.upgradeProxyTo(proxy, newImpl, data);
    }

    /**
     * @notice Upgrades the implementation of a proxy contract.
     *
     * Steps:
     * 1. Takes in three parameters: the proxy address, the new implementation address, and calldata for initialization.
     * 2. Calls the Core.upgradeProxyTo function with these parameters to perform the upgrade.
     */
    function upgradeProxy(
        address proxy,
        address newImpl,
        bytes memory data,
        address tryCaller
    ) internal {
        Core.upgradeProxyTo(proxy, newImpl, data, tryCaller);
    }

    /**
     * @notice Upgrades a beacon to point to a new implementation contract.
     *
     * Steps:
     * 1. Takes the address of a beacon and the address of a new implementation contract.
     * 2. Calls the Core.upgradeBeaconTo function to perform the actual upgrade.
     * 3. This function is internal, meaning it can only be called from within the contract or its derived contracts.
     */
    function upgradeBeacon(
        address beacon,
        address newImpl
    ) internal {
        Core.upgradeBeaconTo(beacon, newImpl);
    }

    /**
     * @notice Deploys a Beacon Proxy contract using the provided beacon address and initialization data.
     *
     * @param beacon The address of the beacon contract that will be used to manage the proxy.
     * @param data The initialization data to be passed to the proxy contract upon deployment.
     * @return The address of the newly deployed Beacon Proxy contract.
     *
     * Steps:
     * 1. Create an empty `Options` struct to pass as default options.
     * 2. Call the `deployBeaconProxy` function with the provided beacon, data, and default options.
     * 3. Return the address of the deployed Beacon Proxy contract.
     */
    function upgradeBeacon(
        address beacon,
        address newImpl,
        address tryCaller
    ) internal {
        Core.upgradeBeaconTo(beacon, newImpl, tryCaller);
    }

    /**
     * @notice Retrieves the admin address for a given proxy contract.
     *
     * @param proxy The address of the proxy contract for which the admin address is to be retrieved.
     * @return The address of the admin associated with the given proxy contract.
     *
     * Steps:
     * 1. Calls the `getAdminAddress` function from the `Core` contract, passing the proxy address as an argument.
     * 2. Returns the admin address associated with the proxy.
     */
    function getAdminAddress(address proxy) internal view returns (address) {
        return Core.getAdminAddress(proxy);
    }

    /**
     * @notice Deploys a beacon contract with the specified contract name and initial owner.
     *
     * @param contractName The name of the contract to be deployed as a beacon.
     * @param initialOwner The address of the initial owner of the beacon contract.
     *
     * @return The address of the deployed beacon contract.
     *
     * Steps:
     * 1. Initialize an empty `Options` struct.
     * 2. Call the `deployBeacon` function with the provided `contractName`, `initialOwner`, and the empty `Options` struct.
     * 3. Return the address of the deployed beacon contract.
     */
    function getImplementationAddress(
        address proxy
    ) internal view returns (address) {
        return Core.getImplementationAddress(proxy);
    }

    /**
     * @notice Retrieves the beacon address associated with a given proxy address.
     *
     * @param proxy The address of the proxy contract.
     * @return The beacon address linked to the proxy.
     *
     * Steps:
     * 1. Call the `getBeaconAddress` function from the `Core` contract, passing the proxy address.
     * 2. Return the beacon address retrieved from the `Core` contract.
     */
    function getBeaconAddress(
        address proxy
    ) internal view returns (address) {
        return Core.getBeaconAddress(proxy);
    }
}