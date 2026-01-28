// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./EnumerableSetLib.sol";

library EnumerableMapLib {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    error EnumerableMapKeyNotFound();

    struct Bytes32ToBytes32Map {
        EnumerableSetLib.Bytes32Set _keys;
        mapping(bytes32 => bytes32) _values;
    }

    struct Bytes32ToUint256Map {
        EnumerableSetLib.Bytes32Set _keys;
        mapping(bytes32 => uint256) _values;
    }

    struct Bytes32ToAddressMap {
        EnumerableSetLib.Bytes32Set _keys;
        mapping(bytes32 => address) _values;
    }

    struct Uint256ToBytes32Map {
        EnumerableSetLib.Uint256Set _keys;
        mapping(uint256 => bytes32) _values;
    }

    struct Uint256ToUint256Map {
        EnumerableSetLib.Uint256Set _keys;
        mapping(uint256 => uint256) _values;
    }

    struct Uint256ToAddressMap {
        EnumerableSetLib.Uint256Set _keys;
        mapping(uint256 => address) _values;
    }

    struct AddressToBytes32Map {
        EnumerableSetLib.AddressSet _keys;
        mapping(address => bytes32) _values;
    }

    struct AddressToUint256Map {
        EnumerableSetLib.AddressSet _keys;
        mapping(address => uint256) _values;
    }

    struct AddressToAddressMap {
        EnumerableSetLib.AddressSet _keys;
        mapping(address => address) _values;
    }

    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(Bytes32ToBytes32Map storage map, uint256 i) internal view returns (bytes32 key, bytes32 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        exists = value != bytes32(0) || map._keys.contains(key);
    }

    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(Bytes32ToBytes32Map storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    function set(Bytes32ToUint256Map storage map, bytes32 key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Bytes32ToUint256Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(Bytes32ToUint256Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(Bytes32ToUint256Map storage map, uint256 i) internal view returns (bytes32 key, uint256 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        exists = value != 0 || map._keys.contains(key);
    }

    function get(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(Bytes32ToUint256Map storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    function set(Bytes32ToAddressMap storage map, bytes32 key, address value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Bytes32ToAddressMap storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(Bytes32ToAddressMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(Bytes32ToAddressMap storage map, uint256 i) internal view returns (bytes32 key, address value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool exists, address value) {
        value = map._values[key];
        exists = value != address(0) || map._keys.contains(key);
    }

    function get(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(Bytes32ToAddressMap storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    function set(Uint256ToBytes32Map storage map, uint256 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Uint256ToBytes32Map storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(Uint256ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(Uint256ToBytes32Map storage map, uint256 i) internal view returns (uint256 key, bytes32 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        exists = value != bytes32(0) || map._keys.contains(key);
    }

    function get(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(Uint256ToBytes32Map storage map) internal view returns (uint256[] memory) {
        return map._keys.values();
    }

    function set(Uint256ToUint256Map storage map, uint256 key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Uint256ToUint256Map storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(Uint256ToUint256Map storage map, uint256 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(Uint256ToUint256Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(Uint256ToUint256Map storage map, uint256 i) internal view returns (uint256 key, uint256 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(Uint256ToUint256Map storage map, uint256 key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        exists = value != 0 || map._keys.contains(key);
    }

    function get(Uint256ToUint256Map storage map, uint256 key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(Uint256ToUint256Map storage map) internal view returns (uint256[] memory) {
        return map._keys.values();
    }

    function set(Uint256ToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Uint256ToAddressMap storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(Uint256ToAddressMap storage map, uint256 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(Uint256ToAddressMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(Uint256ToAddressMap storage map, uint256 i) internal view returns (uint256 key, address value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(Uint256ToAddressMap storage map, uint256 key) internal view returns (bool exists, address value) {
        value = map._values[key];
        exists = value != address(0) || map._keys.contains(key);
    }

    function get(Uint256ToAddressMap storage map, uint256 key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(Uint256ToAddressMap storage map) internal view returns (uint256[] memory) {
        return map._keys.values();
    }

    function set(AddressToBytes32Map storage map, address key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(AddressToBytes32Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(AddressToBytes32Map storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(AddressToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(AddressToBytes32Map storage map, uint256 i) internal view returns (address key, bytes32 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(AddressToBytes32Map storage map, address key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        exists = value != bytes32(0) || map._keys.contains(key);
    }

    function get(AddressToBytes32Map storage map, address key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(AddressToBytes32Map storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    function set(AddressToUint256Map storage map, address key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(AddressToUint256Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(AddressToUint256Map storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(AddressToUint256Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(AddressToUint256Map storage map, uint256 i) internal view returns (address key, uint256 value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(AddressToUint256Map storage map, address key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        exists = value != 0 || map._keys.contains(key);
    }

    function get(AddressToUint256Map storage map, address key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(AddressToUint256Map storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    function set(AddressToAddressMap storage map, address key, address value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(AddressToAddressMap storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    function contains(AddressToAddressMap storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function length(AddressToAddressMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    function at(AddressToAddressMap storage map, uint256 i) internal view returns (address key, address value) {
        key = map._keys.at(i);
        value = map._values[key];
    }

    function tryGet(AddressToAddressMap storage map, address key) internal view returns (bool exists, address value) {
        value = map._values[key];
        exists = value != address(0) || map._keys.contains(key);
    }

    function get(AddressToAddressMap storage map, address key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !contains(map, key)) {
            _revertNotFound();
        }
    }

    function keys(AddressToAddressMap storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    function _revertNotFound() private pure {
        assembly {
            mstore(0x00, 0x6cb88b79)
            revert(0x1c, 0x04)
        }
    }
}