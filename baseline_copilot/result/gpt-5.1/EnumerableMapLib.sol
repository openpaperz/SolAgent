// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./EnumerableSetLib.sol";

library EnumerableMapLib {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    /**
     * @notice A struct representing a mapping from bytes32 keys to bytes32 values.
     *
     * Fields:
     * - `_keys`: An enumerable set of bytes32 keys.
     * - `_values`: A mapping from bytes32 keys to bytes32 values.
     */
    struct Bytes32ToBytes32Map {
        EnumerableSetLib.Bytes32Set _keys;
        mapping(bytes32 => bytes32) _values;
    }

    /**
     * @notice A struct that maps `bytes32` keys to `uint256` values.
     *
     * The struct contains:
     * - `_keys`: An `EnumerableSetLib.Bytes32Set` to store the keys.
     * - `_values`: A mapping from `bytes32` keys to `uint256` values.
     */
    struct Bytes32ToUint256Map {
        EnumerableSetLib.Bytes32Set _keys;
        mapping(bytes32 => uint256) _values;
    }

    /**
     * @notice A struct representing a mapping from bytes32 keys to address values.
     *
     * Fields:
     * - `_keys`: An EnumerableSet of bytes32 keys to track the keys in the mapping.
     * - `_values`: A mapping from bytes32 keys to their corresponding address values.
     */
    struct Bytes32ToAddressMap {
        EnumerableSetLib.Bytes32Set _keys;
        mapping(bytes32 => address) _values;
    }

    /**
     * @notice A struct that maps uint256 keys to bytes32 values.
     *
     * The struct contains:
     * 1. `_keys`: An EnumerableSet of uint256 keys.
     * 2. `_values`: A mapping from uint256 keys to bytes32 values.
     */
    struct Uint256ToBytes32Map {
        EnumerableSetLib.Uint256Set _keys;
        mapping(uint256 => bytes32) _values;
    }

    /**
     * @notice A struct representing a mapping from uint256 keys to uint256 values.
     *
     * Fields:
     * - `_keys`: An EnumerableSet of uint256 keys.
     * - `_values`: A mapping from uint256 keys to uint256 values.
     */
    struct Uint256ToUint256Map {
        EnumerableSetLib.Uint256Set _keys;
        mapping(uint256 => uint256) _values;
    }

    /**
     * @notice A struct representing a mapping from uint256 keys to address values.
     *
     * Fields:
     * - `_keys`: An EnumerableSet of uint256 keys.
     * - `_values`: A mapping from uint256 keys to address values.
     */
    struct Uint256ToAddressMap {
        EnumerableSetLib.Uint256Set _keys;
        mapping(uint256 => address) _values;
    }

    /**
     * @notice A struct that maps addresses to bytes32 values.
     *
     * Fields:
     * - `_keys`: An enumerable set of addresses used to store the keys of the mapping.
     * - `_values`: A mapping from addresses to bytes32 values, storing the actual data.
     */
    struct AddressToBytes32Map {
        EnumerableSetLib.AddressSet _keys;
        mapping(address => bytes32) _values;
    }

    /**
     * @notice Defines a mapping structure that associates addresses with uint256 values.
     *
     * The structure consists of:
     * 1. `_keys`: An enumerable set of addresses (using `EnumerableSetLib.AddressSet`) to keep track of all keys in the mapping.
     * 2. `_values`: A mapping from addresses to uint256 values, storing the actual data associated with each address.
     *
     * This structure allows for efficient storage and retrieval of uint256 values by address, while also enabling enumeration of all keys in the mapping.
     */
    struct AddressToUint256Map {
        EnumerableSetLib.AddressSet _keys;
        mapping(address => uint256) _values;
    }

    /**
     * @notice A struct representing a mapping from addresses to addresses.
     *
     * The struct contains:
     * 1. `_keys`: An enumerable set of addresses representing the keys in the mapping.
     * 2. `_values`: A mapping from addresses to addresses, storing the actual values.
     */
    struct AddressToAddressMap {
        EnumerableSetLib.AddressSet _keys;
        mapping(address => address) _values;
    }

    // =============================================================
    //                      BYTES32 => BYTES32
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `Bytes32ToBytes32Map` storage map.
     */
    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `Bytes32ToBytes32Map` storage map.
     */
    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the Bytes32ToBytes32Map.
     */
    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `Bytes32ToBytes32Map`.
     */
    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a Bytes32ToBytes32Map.
     */
    function at(Bytes32ToBytes32Map storage map, uint256 i) internal view returns (bytes32 key, bytes32 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `Bytes32ToBytes32Map` storage map using a given key.
     */
    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        if (value != bytes32(0) || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `Bytes32ToBytes32Map` storage map.
     */
    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `Bytes32ToBytes32Map`.
     */
    function keys(Bytes32ToBytes32Map storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      BYTES32 => UINT256
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `Bytes32ToUint256Map` storage map.
     */
    function set(Bytes32ToUint256Map storage map, bytes32 key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `Bytes32ToUint256Map` storage map.
     */
    function remove(Bytes32ToUint256Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the Bytes32ToUint256Map.
     */
    function contains(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `Bytes32ToUint256Map`.
     */
    function length(Bytes32ToUint256Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a Bytes32ToUint256Map.
     */
    function at(Bytes32ToUint256Map storage map, uint256 i) internal view returns (bytes32 key, uint256 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `Bytes32ToUint256Map` storage map using a given key.
     */
    function tryGet(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        if (value != 0 || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `Bytes32ToUint256Map` storage map.
     */
    function get(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `Bytes32ToUint256Map`.
     */
    function keys(Bytes32ToUint256Map storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      BYTES32 => ADDRESS
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `Bytes32ToAddressMap` storage map.
     */
    function set(Bytes32ToAddressMap storage map, bytes32 key, address value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `Bytes32ToAddressMap` storage map.
     */
    function remove(Bytes32ToAddressMap storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the Bytes32ToAddressMap.
     */
    function contains(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `Bytes32ToAddressMap`.
     */
    function length(Bytes32ToAddressMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a Bytes32ToAddressMap.
     */
    function at(Bytes32ToAddressMap storage map, uint256 i) internal view returns (bytes32 key, address value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `Bytes32ToAddressMap` storage map using a given key.
     */
    function tryGet(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool exists, address value) {
        value = map._values[key];
        if (value != address(0) || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `Bytes32ToAddressMap` storage map.
     */
    function get(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `Bytes32ToAddressMap`.
     */
    function keys(Bytes32ToAddressMap storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      UINT256 => BYTES32
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `Uint256ToBytes32Map` storage map.
     */
    function set(Uint256ToBytes32Map storage map, uint256 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `Uint256ToBytes32Map` storage map.
     */
    function remove(Uint256ToBytes32Map storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the Uint256ToBytes32Map.
     */
    function contains(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `Uint256ToBytes32Map`.
     */
    function length(Uint256ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a Uint256ToBytes32Map.
     */
    function at(Uint256ToBytes32Map storage map, uint256 i) internal view returns (uint256 key, bytes32 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `Uint256ToBytes32Map` storage map using a given key.
     */
    function tryGet(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        if (value != bytes32(0) || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `Uint256ToBytes32Map` storage map.
     */
    function get(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `Uint256ToBytes32Map`.
     */
    function keys(Uint256ToBytes32Map storage map) internal view returns (uint256[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      UINT256 => UINT256
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `Uint256ToUint256Map` storage map.
     */
    function set(Uint256ToUint256Map storage map, uint256 key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `Uint256ToUint256Map` storage map.
     */
    function remove(Uint256ToUint256Map storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the Uint256ToUint256Map.
     */
    function contains(Uint256ToUint256Map storage map, uint256 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `Uint256ToUint256Map`.
     */
    function length(Uint256ToUint256Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a Uint256ToUint256Map.
     */
    function at(Uint256ToUint256Map storage map, uint256 i) internal view returns (uint256 key, uint256 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `Uint256ToUint256Map` storage map using a given key.
     */
    function tryGet(Uint256ToUint256Map storage map, uint256 key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        if (value != 0 || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `Uint256ToUint256Map` storage map.
     */
    function get(Uint256ToUint256Map storage map, uint256 key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `Uint256ToUint256Map`.
     */
    function keys(Uint256ToUint256Map storage map) internal view returns (uint256[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      UINT256 => ADDRESS
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `Uint256ToAddressMap` storage map.
     */
    function set(Uint256ToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `Uint256ToAddressMap` storage map.
     */
    function remove(Uint256ToAddressMap storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the Uint256ToAddressMap.
     */
    function contains(Uint256ToAddressMap storage map, uint256 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `Uint256ToAddressMap`.
     */
    function length(Uint256ToAddressMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a Uint256ToAddressMap.
     */
    function at(Uint256ToAddressMap storage map, uint256 i) internal view returns (uint256 key, address value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `Uint256ToAddressMap` storage map using a given key.
     */
    function tryGet(Uint256ToAddressMap storage map, uint256 key) internal view returns (bool exists, address value) {
        value = map._values[key];
        if (value != address(0) || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `Uint256ToAddressMap` storage map.
     */
    function get(Uint256ToAddressMap storage map, uint256 key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `Uint256ToAddressMap`.
     */
    function keys(Uint256ToAddressMap storage map) internal view returns (uint256[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      ADDRESS => BYTES32
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `AddressToBytes32Map` storage map.
     */
    function set(AddressToBytes32Map storage map, address key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `AddressToBytes32Map` storage map.
     */
    function remove(AddressToBytes32Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the AddressToBytes32Map.
     */
    function contains(AddressToBytes32Map storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `AddressToBytes32Map`.
     */
    function length(AddressToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a AddressToBytes32Map.
     */
    function at(AddressToBytes32Map storage map, uint256 i) internal view returns (address key, bytes32 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `AddressToBytes32Map` storage map using a given key.
     */
    function tryGet(AddressToBytes32Map storage map, address key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        if (value != bytes32(0) || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `AddressToBytes32Map` storage map.
     */
    function get(AddressToBytes32Map storage map, address key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `AddressToBytes32Map`.
     */
    function keys(AddressToBytes32Map storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      ADDRESS => UINT256
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `AddressToUint256Map` storage map.
     */
    function set(AddressToUint256Map storage map, address key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `AddressToUint256Map` storage map.
     */
    function remove(AddressToUint256Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the AddressToUint256Map.
     */
    function contains(AddressToUint256Map storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `AddressToUint256Map`.
     */
    function length(AddressToUint256Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a AddressToUint256Map.
     */
    function at(AddressToUint256Map storage map, uint256 i) internal view returns (address key, uint256 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `AddressToUint256Map` storage map using a given key.
     */
    function tryGet(AddressToUint256Map storage map, address key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        if (value != 0 || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `AddressToUint256Map` storage map.
     */
    function get(AddressToUint256Map storage map, address key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `AddressToUint256Map`.
     */
    function keys(AddressToUint256Map storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                      ADDRESS => ADDRESS
    // =============================================================

    /**
     * @notice Sets a key-value pair in a `AddressToAddressMap` storage map.
     */
    function set(AddressToAddressMap storage map, address key, address value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @notice Removes a key-value pair from a `AddressToAddressMap` storage map.
     */
    function remove(AddressToAddressMap storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @notice Checks if a given key exists in the AddressToAddressMap.
     */
    function contains(AddressToAddressMap storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @notice Returns the number of key-value pairs stored in the `AddressToAddressMap`.
     */
    function length(AddressToAddressMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @notice Retrieves the key and value at a specific index in a AddressToAddressMap.
     */
    function at(AddressToAddressMap storage map, uint256 i) internal view returns (address key, address value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    /**
     * @notice Attempts to retrieve a value from a `AddressToAddressMap` storage map using a given key.
     */
    function tryGet(AddressToAddressMap storage map, address key) internal view returns (bool exists, address value) {
        value = map._values[key];
        if (value != address(0) || map._keys.contains(key)) {
            exists = true;
        }
    }

    /**
     * @notice Retrieves the value associated with a given key from a `AddressToAddressMap` storage map.
     */
    function get(AddressToAddressMap storage map, address key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !map._keys.contains(key)) _revertNotFound();
    }

    /**
     * @notice Retrieves all the keys stored in a `AddressToAddressMap`.
     */
    function keys(AddressToAddressMap storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    // =============================================================
    //                        INTERNAL HELPERS
    // =============================================================

    error EnumerableMapKeyNotFound();

    /**
     * @notice Reverts the transaction with a custom error indicating that a key was not found in an enumerable map.
     *
     * Steps:
     * 1. Store the error selector `EnumerableMapKeyNotFound()` at memory location 0x00.
     * 2. Revert the transaction, returning the error selector stored in memory.
     */
    function _revertNotFound() private pure {
        assembly {
            mstore(0x00, 0x1d5f2f4a) // selector for EnumerableMapKeyNotFound()
            revert(0x00, 0x04)
        }
    }
}