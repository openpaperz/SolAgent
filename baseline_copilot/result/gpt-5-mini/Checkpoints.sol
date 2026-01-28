// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Checkpoints {
    struct Checkpoint224 {
        uint32 _key;
        uint224 _value;
    }

    struct Trace224 {
        Checkpoint224[] _checkpoints;
    }

    struct Checkpoint208 {
        uint48 _key;
        uint208 _value;
    }

    struct Trace208 {
        Checkpoint208[] _checkpoints;
    }

    struct Checkpoint160 {
        uint96 _key;
        uint160 _value;
    }

    struct Trace160 {
        Checkpoint160[] _checkpoints;
    }

    // -------------------------
    // Trace224 API
    // -------------------------

    function push(Trace224 storage self, uint32 key, uint224 value) internal returns (uint224 oldValue, uint224 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    function lowerLookup(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;

        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        Checkpoint224 storage ck = _unsafeAccess(self._checkpoints, pos);
        if (ck._key > key) return 0;
        return ck._value;
    }

    function upperLookup(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        if (pos == 0) return 0;
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    function upperLookupRecent(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;

        uint256 low = 0;
        uint256 high = len;
        if (len > 5) {
            uint256 pos = len - _sqrt(len);
            if (_unsafeAccess(self._checkpoints, pos)._key <= key) {
                low = pos;
            } else {
                high = pos;
            }
        }

        uint256 idx = _upperBinaryLookup(self._checkpoints, key, low, high);
        if (idx == 0) return 0;
        return _unsafeAccess(self._checkpoints, idx - 1)._value;
    }

    function latest(Trace224 storage self) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        return _unsafeAccess(self._checkpoints, len - 1)._value;
    }

    function latestCheckpoint(Trace224 storage self) internal view returns (bool exists, uint32 _key, uint224 _value) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return (false, 0, 0);
        Checkpoint224 storage ck = _unsafeAccess(self._checkpoints, len - 1);
        return (true, ck._key, ck._value);
    }

    function length(Trace224 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    function at(Trace224 storage self, uint32 pos) internal view returns (Checkpoint224 memory) {
        return self._checkpoints[uint256(pos)];
    }

    function _insert(Checkpoint224[] storage self, uint32 key, uint224 value) private returns (uint224 oldValue, uint224 newValue) {
        uint256 len = self.length;
        if (len == 0) {
            self.push(Checkpoint224({ _key: key, _value: value }));
            return (0, value);
        } else {
            Checkpoint224 storage last = _unsafeAccess(self, len - 1);
            uint32 lastKey = last._key;
            uint224 lastValue = last._value;
            require(key >= lastKey, "CHECKPOINTS: KEY_ORDER");
            if (key == lastKey) {
                oldValue = lastValue;
                last._value = value;
                newValue = value;
                return (oldValue, newValue);
            } else {
                self.push(Checkpoint224({ _key: key, _value: value }));
                return (0, value);
            }
        }
    }

    function _upperBinaryLookup(Checkpoint224[] storage self, uint32 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    function _lowerBinaryLookup(Checkpoint224[] storage self, uint32 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (_unsafeAccess(self, mid)._key <= key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        if (low == 0) return 0;
        return low - 1;
    }

    function _unsafeAccess(Checkpoint224[] storage self, uint256 pos) private pure returns (Checkpoint224 storage result) {
        assembly {
            mstore(0, self.slot)
            let location := keccak256(0, 0x20)
            result.slot := add(location, pos)
        }
    }

    // -------------------------
    // Trace208 API
    // -------------------------

    function push(Trace208 storage self, uint48 key, uint208 value) internal returns (uint208 oldValue, uint208 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    function lowerLookup(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        Checkpoint208 storage ck = _unsafeAccess(self._checkpoints, pos);
        if (ck._key > key) return 0;
        return ck._value;
    }

    function upperLookup(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        if (pos == 0) return 0;
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    function upperLookupRecent(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;

        uint256 low = 0;
        uint256 high = len;
        if (len > 5) {
            uint256 pos = len - _sqrt(len);
            if (_unsafeAccess(self._checkpoints, pos)._key <= key) {
                low = pos;
            } else {
                high = pos;
            }
        }

        uint256 idx = _upperBinaryLookup(self._checkpoints, key, low, high);
        if (idx == 0) return 0;
        return _unsafeAccess(self._checkpoints, idx - 1)._value;
    }

    function latest(Trace208 storage self) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        return _unsafeAccess(self._checkpoints, len - 1)._value;
    }

    function latestCheckpoint(Trace208 storage self) internal view returns (bool exists, uint48 _key, uint208 _value) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return (false, 0, 0);
        Checkpoint208 storage ck = _unsafeAccess(self._checkpoints, len - 1);
        return (true, ck._key, ck._value);
    }

    function length(Trace208 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    function at(Trace208 storage self, uint32 pos) internal view returns (Checkpoint208 memory) {
        return self._checkpoints[uint256(pos)];
    }

    function _insert(Checkpoint208[] storage self, uint48 key, uint208 value) private returns (uint208 oldValue, uint208 newValue) {
        uint256 len = self.length;
        if (len == 0) {
            self.push(Checkpoint208({ _key: key, _value: value }));
            return (0, value);
        } else {
            Checkpoint208 storage last = _unsafeAccess(self, len - 1);
            uint48 lastKey = last._key;
            uint208 lastValue = last._value;
            require(key >= lastKey, "CHECKPOINTS: KEY_ORDER");
            if (key == lastKey) {
                oldValue = lastValue;
                last._value = value;
                newValue = value;
                return (oldValue, newValue);
            } else {
                self.push(Checkpoint208({ _key: key, _value: value }));
                return (0, value);
            }
        }
    }

    function _upperBinaryLookup(Checkpoint208[] storage self, uint48 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    function _lowerBinaryLookup(Checkpoint208[] storage self, uint48 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (_unsafeAccess(self, mid)._key <= key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        if (low == 0) return 0;
        return low - 1;
    }

    function _unsafeAccess(Checkpoint208[] storage self, uint256 pos) private pure returns (Checkpoint208 storage result) {
        assembly {
            mstore(0, self.slot)
            let location := keccak256(0, 0x20)
            result.slot := add(location, pos)
        }
    }

    // -------------------------
    // Trace160 API
    // -------------------------

    function push(Trace160 storage self, uint96 key, uint160 value) internal returns (uint160 oldValue, uint160 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    function lowerLookup(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        Checkpoint160 storage ck = _unsafeAccess(self._checkpoints, pos);
        if (ck._key > key) return 0;
        return ck._value;
    }

    function upperLookup(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        if (pos == 0) return 0;
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    function upperLookupRecent(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;

        uint256 low = 0;
        uint256 high = len;
        if (len > 5) {
            uint256 pos = len - _sqrt(len);
            if (_unsafeAccess(self._checkpoints, pos)._key <= key) {
                low = pos;
            } else {
                high = pos;
            }
        }

        uint256 idx = _upperBinaryLookup(self._checkpoints, key, low, high);
        if (idx == 0) return 0;
        return _unsafeAccess(self._checkpoints, idx - 1)._value;
    }

    function latest(Trace160 storage self) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return 0;
        return _unsafeAccess(self._checkpoints, len - 1)._value;
    }

    function latestCheckpoint(Trace160 storage self) internal view returns (bool exists, uint96 _key, uint160 _value) {
        uint256 len = self._checkpoints.length;
        if (len == 0) return (false, 0, 0);
        Checkpoint160 storage ck = _unsafeAccess(self._checkpoints, len - 1);
        return (true, ck._key, ck._value);
    }

    function length(Trace160 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    function at(Trace160 storage self, uint32 pos) internal view returns (Checkpoint160 memory) {
        return self._checkpoints[uint256(pos)];
    }

    function _insert(Checkpoint160[] storage self, uint96 key, uint160 value) private returns (uint160 oldValue, uint160 newValue) {
        uint256 len = self.length;
        if (len == 0) {
            self.push(Checkpoint160({ _key: key, _value: value }));
            return (0, value);
        } else {
            Checkpoint160 storage last = _unsafeAccess(self, len - 1);
            uint96 lastKey = last._key;
            uint160 lastValue = last._value;
            require(key >= lastKey, "CHECKPOINTS: KEY_ORDER");
            if (key == lastKey) {
                oldValue = lastValue;
                last._value = value;
                newValue = value;
                return (oldValue, newValue);
            } else {
                self.push(Checkpoint160({ _key: key, _value: value }));
                return (0, value);
            }
        }
    }

    function _upperBinaryLookup(Checkpoint160[] storage self, uint96 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    function _lowerBinaryLookup(Checkpoint160[] storage self, uint96 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (_unsafeAccess(self, mid)._key <= key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        if (low == 0) return 0;
        return low - 1;
    }

    function _unsafeAccess(Checkpoint160[] storage self, uint256 pos) private pure returns (Checkpoint160 storage result) {
        assembly {
            mstore(0, self.slot)
            let location := keccak256(0, 0x20)
            result.slot := add(location, pos)
        }
    }

    // -------------------------
    // Utilities
    // -------------------------

    function _sqrt(uint256 x) private pure returns (uint256 z) {
        if (x == 0) return 0;
        uint256 y = x;
        z = 1;
        if (y >= 0x100000000000000000000000000000000) { y >>= 128; z <<= 64; }
        if (y >= 0x10000000000000000) { y >>= 64; z <<= 32; }
        if (y >= 0x100000000) { y >>= 32; z <<= 16; }
        if (y >= 0x10000) { y >>= 16; z <<= 8; }
        if (y >= 0x100) { y >>= 8; z <<= 4; }
        if (y >= 0x10) { y >>= 4; z <<= 2; }
        if (y >= 0x8) { z <<= 1; }
        // Babylonian method
        unchecked {
            for (uint8 i = 0; i < 7; ++i) {
                z = (z + x / z) >> 1;
            }
        }
    }
}
