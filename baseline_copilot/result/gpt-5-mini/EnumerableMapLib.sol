// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

error EnumerableMapKeyNotFound();

library EnumerableSetLib {
    struct Bytes32Set {
        bytes32[] _values;
        mapping(bytes32 => uint256) _indexes; // value -> index+1
    }

    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        if (set._indexes[value] != 0) return false;
        set._values.push(value);
        set._indexes[value] = set._values.length;
        return true;
    }

    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        uint256 index = set._indexes[value];
        if (index == 0) return false;
        uint256 lastIndex = set._values.length;
        bytes32 lastValue = set._values[lastIndex - 1];

        set._values[index - 1] = lastValue;
        set._indexes[lastValue] = index;

        set._values.pop();
        delete set._indexes[value];

        return true;
    }

    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }

    function length(Bytes32Set storage set) internal view returns (uint256) {
        return set._values.length;
    }

    function at(Bytes32Set storage set, uint256 i) internal view returns (bytes32) {
        return set._values[i];
    }

    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return set._values;
    }

    // Uint256Set wrapper
    struct Uint256Set {
        Bytes32Set _inner;
    }

    function add(Uint256Set storage set, uint256 value) internal returns (bool) {
        return add(set._inner, bytes32(value));
    }

    function remove(Uint256Set storage set, uint256 value) internal returns (bool) {
        return remove(set._inner, bytes32(value));
    }

    function contains(Uint256Set storage set, uint256 value) internal view returns (bool) {
        return contains(set._inner, bytes32(value));
    }

    function length(Uint256Set storage set) internal view returns (uint256) {
        return length(set._inner);
    }

    function at(Uint256Set storage set, uint256 i) internal view returns (uint256) {
        return uint256(uint256(at(set._inner, i)));
    }

    function values(Uint256Set storage set) internal view returns (uint256[] memory) {
        bytes32[] memory raw = values(set._inner);
        uint256[] memory out = new uint256[](raw.length);
        for (uint256 i = 0; i < raw.length; i++) out[i] = uint256(uint256(raw[i]));
        return out;
    }

    // AddressSet wrapper
    struct AddressSet {
        Bytes32Set _inner;
    }

    function add(AddressSet storage set, address value) internal returns (bool) {
        return add(set._inner, bytes32(uint256(uint160(value))));
    }

    function remove(AddressSet storage set, address value) internal returns (bool) {
        return remove(set._inner, bytes32(uint256(uint160(value))));
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return contains(set._inner, bytes32(uint256(uint160(value))));
    }

    function length(AddressSet storage set) internal view returns (uint256) {
        return length(set._inner);
    }

    function at(AddressSet storage set, uint256 i) internal view returns (address) {
        return address(uint160(uint256(at(set._inner, i))));
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory raw = values(set._inner);
        address[] memory out = new address[](raw.length);
        for (uint256 i = 0; i < raw.length; i++) out[i] = address(uint160(uint256(raw[i])));
        return out;
    }
}

library EnumerableMapLib {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    // Structs
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

    // Bytes32 -> Bytes32
    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(Bytes32ToBytes32Map storage map, uint256 i) internal view returns (bytes32 key, bytes32 value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        exists = (value != bytes32(0) || EnumerableSetLib.contains(map._keys, key));
    }

    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(Bytes32ToBytes32Map storage map) internal view returns (bytes32[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Bytes32 -> Uint256
    function set(Bytes32ToUint256Map storage map, bytes32 key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(Bytes32ToUint256Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(Bytes32ToUint256Map storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(Bytes32ToUint256Map storage map, uint256 i) internal view returns (bytes32 key, uint256 value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        exists = (value != 0 || EnumerableSetLib.contains(map._keys, key));
    }

    function get(Bytes32ToUint256Map storage map, bytes32 key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(Bytes32ToUint256Map storage map) internal view returns (bytes32[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Bytes32 -> Address
    function set(Bytes32ToAddressMap storage map, bytes32 key, address value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(Bytes32ToAddressMap storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(Bytes32ToAddressMap storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(Bytes32ToAddressMap storage map, uint256 i) internal view returns (bytes32 key, address value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool exists, address value) {
        value = map._values[key];
        exists = (value != address(0) || EnumerableSetLib.contains(map._keys, key));
    }

    function get(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(Bytes32ToAddressMap storage map) internal view returns (bytes32[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Uint256 -> Bytes32
    function set(Uint256ToBytes32Map storage map, uint256 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(Uint256ToBytes32Map storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(Uint256ToBytes32Map storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(Uint256ToBytes32Map storage map, uint256 i) internal view returns (uint256 key, bytes32 value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        exists = (value != bytes32(0) || EnumerableSetLib.contains(map._keys, key));
    }

    function get(Uint256ToBytes32Map storage map, uint256 key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(Uint256ToBytes32Map storage map) internal view returns (uint256[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Uint256 -> Uint256
    function set(Uint256ToUint256Map storage map, uint256 key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(Uint256ToUint256Map storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(Uint256ToUint256Map storage map, uint256 key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(Uint256ToUint256Map storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(Uint256ToUint256Map storage map, uint256 i) internal view returns (uint256 key, uint256 value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(Uint256ToUint256Map storage map, uint256 key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        exists = (value != 0 || EnumerableSetLib.contains(map._keys, key));
    }

    function get(Uint256ToUint256Map storage map, uint256 key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(Uint256ToUint256Map storage map) internal view returns (uint256[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Uint256 -> Address
    function set(Uint256ToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(Uint256ToAddressMap storage map, uint256 key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(Uint256ToAddressMap storage map, uint256 key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(Uint256ToAddressMap storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(Uint256ToAddressMap storage map, uint256 i) internal view returns (uint256 key, address value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(Uint256ToAddressMap storage map, uint256 key) internal view returns (bool exists, address value) {
        value = map._values[key];
        exists = (value != address(0) || EnumerableSetLib.contains(map._keys, key));
    }

    function get(Uint256ToAddressMap storage map, uint256 key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(Uint256ToAddressMap storage map) internal view returns (uint256[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Address -> Bytes32
    function set(AddressToBytes32Map storage map, address key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(AddressToBytes32Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(AddressToBytes32Map storage map, address key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(AddressToBytes32Map storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(AddressToBytes32Map storage map, uint256 i) internal view returns (address key, bytes32 value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(AddressToBytes32Map storage map, address key) internal view returns (bool exists, bytes32 value) {
        value = map._values[key];
        exists = (value != bytes32(0) || EnumerableSetLib.contains(map._keys, key));
    }

    function get(AddressToBytes32Map storage map, address key) internal view returns (bytes32 value) {
        value = map._values[key];
        if (value == bytes32(0) && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(AddressToBytes32Map storage map) internal view returns (address[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Address -> Uint256
    function set(AddressToUint256Map storage map, address key, uint256 value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(AddressToUint256Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(AddressToUint256Map storage map, address key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(AddressToUint256Map storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(AddressToUint256Map storage map, uint256 i) internal view returns (address key, uint256 value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(AddressToUint256Map storage map, address key) internal view returns (bool exists, uint256 value) {
        value = map._values[key];
        exists = (value != 0 || EnumerableSetLib.contains(map._keys, key));
    }

    function get(AddressToUint256Map storage map, address key) internal view returns (uint256 value) {
        value = map._values[key];
        if (value == 0 && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(AddressToUint256Map storage map) internal view returns (address[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Address -> Address
    function set(AddressToAddressMap storage map, address key, address value) internal returns (bool) {
        map._values[key] = value;
        return EnumerableSetLib.add(map._keys, key);
    }

    function remove(AddressToAddressMap storage map, address key) internal returns (bool) {
        delete map._values[key];
        return EnumerableSetLib.remove(map._keys, key);
    }

    function contains(AddressToAddressMap storage map, address key) internal view returns (bool) {
        return EnumerableSetLib.contains(map._keys, key);
    }

    function length(AddressToAddressMap storage map) internal view returns (uint256) {
        return EnumerableSetLib.length(map._keys);
    }

    function at(AddressToAddressMap storage map, uint256 i) internal view returns (address key, address value) {
        key = EnumerableSetLib.at(map._keys, i);
        value = map._values[key];
    }

    function tryGet(AddressToAddressMap storage map, address key) internal view returns (bool exists, address value) {
        value = map._values[key];
        exists = (value != address(0) || EnumerableSetLib.contains(map._keys, key));
    }

    function get(AddressToAddressMap storage map, address key) internal view returns (address value) {
        value = map._values[key];
        if (value == address(0) && !EnumerableSetLib.contains(map._keys, key)) _revertNotFound();
    }

    function keys(AddressToAddressMap storage map) internal view returns (address[] memory) {
        return EnumerableSetLib.values(map._keys);
    }

    // Private helper to revert with a consistent error
    function _revertNotFound() private pure {
        revert EnumerableMapKeyNotFound();
    }
}