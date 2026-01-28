// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Checkpoints {
    /**
     * @notice Defines a struct `Trace224` that contains an array of `Checkpoint224` elements.
     *
     * The struct is used to store a sequence of checkpoints, where each checkpoint is of type `Checkpoint224`.
     * This could be used for tracking changes or states over time, such as balances or other historical data.
     */
    struct Trace224 {
        Checkpoint224[] _checkpoints;
    }

    /**
     * @notice Defines a struct named `Checkpoint224` with two fields:
     * - `_key`: A 32-bit unsigned integer representing the key.
     * - `_value`: A 224-bit unsigned integer representing the value.
     */
    struct Checkpoint224 {
        uint32 _key;
        uint224 _value;
    }

    /**
     * @notice Inserts a new key-value pair into the Trace224 storage.
     *
     * @param self The storage reference to the Trace224 structure.
     * @param key The key to be inserted or updated.
     * @param value The value to be associated with the key.
     *
     * @return oldValue The previous value associated with the key (if any).
     * @return newValue The new value associated with the key after insertion.
     *
     * Steps:
     * 1. Calls the internal `_insert` function with the provided key and value.
     * 2. Returns the old and new values associated with the key.
     */
    function push(Trace224 storage self, uint32 key, uint224 value) internal returns (uint224 oldValue, uint224 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @notice Performs a lower-bound binary lookup on a sorted array of checkpoints to find the value associated with a given key.
     *
     * @param self The storage reference to the Trace224 struct containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The value associated with the largest checkpoint key less than or equal to the given key. Returns 0 if no such checkpoint exists.
     *
     * Steps:
     * 1. Determine the length of the checkpoints array.
     * 2. Perform a binary search to find the position of the largest checkpoint key less than or equal to the given key.
     * 3. If the position is equal to the length of the array, return 0 (no valid checkpoint found).
     * 4. Otherwise, return the value at the found position using unsafe access to avoid bounds checking.
     */
    function lowerLookup(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 length_ = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, length_);
        if (pos == length_) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @notice Performs an upper binary lookup on a Trace224 checkpoint array to find the value associated with the given key.
     *
     * @param self The Trace224 storage reference containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The value associated with the key, or 0 if no valid checkpoint is found.
     *
     * Steps:
     * 1. Retrieve the length of the checkpoints array.
     * 2. Use `_upperBinaryLookup` to find the position of the key in the checkpoints array.
     * 3. If the position is 0, return 0 (no valid checkpoint found).
     * 4. Otherwise, return the value from the checkpoint at the position minus one using `_unsafeAccess`.
     */
    function upperLookup(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 length_ = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, length_);
        if (pos == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @notice Performs an upper binary lookup on a Trace224 storage structure to find the most recent value associated with a given key.
     *
     * @param self The Trace224 storage structure containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The most recent value associated with the key, or 0 if no such value exists.
     *
     * Steps:
     * 1. Determine the length of the checkpoints array.
     * 2. Initialize low and high pointers for binary search.
     * 3. If the length of the checkpoints array is greater than 5, optimize the search by narrowing the range:
     *    - Calculate a midpoint using the square root of the length.
     *    - Adjust the high or low pointer based on whether the key is less than the key at the midpoint.
     * 4. Perform an upper binary lookup within the narrowed range to find the position of the key.
     * 5. Return the value at the position found, or 0 if no valid position is found.
     */
    function upperLookupRecent(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = length_;

        if (length_ > 5) {
            uint256 mid = _sqrt(length_ - 1);
            if (_unsafeAccess(self._checkpoints, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);
        if (pos == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @notice Retrieves the latest value from a Trace224 checkpoint array.
     *
     * @param self The Trace224 storage reference containing the checkpoints.
     * @return The latest value stored in the checkpoints. If no checkpoints exist, returns 0.
     *
     * Steps:
     * 1. Determine the length of the checkpoint array.
     * 2. If the array is empty, return 0.
     * 3. Otherwise, access the last checkpoint in the array and return its value.
     */
    function latest(Trace224 storage self) internal view returns (uint224) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, length_ - 1)._value;
    }

    /**
     * @notice Retrieves the latest checkpoint from a Trace224 storage structure.
     *
     * @param self The Trace224 storage structure containing the checkpoints.
     * @return exists A boolean indicating whether a checkpoint exists.
     * @return _key The key (uint32) of the latest checkpoint if it exists.
     * @return _value The value (uint224) of the latest checkpoint if it exists.
     *
     * Steps:
     * 1. Determine the position of the last checkpoint in the `_checkpoints` array.
     * 2. If no checkpoints exist, return `false` with default values for `_key` and `_value`.
     * 3. If checkpoints exist, access the latest checkpoint using `_unsafeAccess`.
     * 4. Return `true` along with the key and value of the latest checkpoint.
     */
    function latestCheckpoint(Trace224 storage self) internal view returns (bool exists, uint32 _key, uint224 _value) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return (false, 0, 0);
        }
        Checkpoint224 storage ckpt = _unsafeAccess(self._checkpoints, length_ - 1);
        return (true, ckpt._key, ckpt._value);
    }

    /**
     * @notice Returns the number of checkpoints stored in the Trace224 structure.
     *
     * @param self The Trace224 storage reference.
     * @return uint256 The number of checkpoints in the Trace224 structure.
     *
     * Steps:
     * 1. Access the `_checkpoints` array within the Trace224 structure.
     * 2. Return the length of the `_checkpoints` array.
     */
    function length(Trace224 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @notice Retrieves a checkpoint from the `Trace224` storage at a specified position.
     *
     * @param self The `Trace224` storage reference containing the checkpoints.
     * @param pos The position (index) of the checkpoint to retrieve.
     * @return Checkpoint224 The checkpoint at the specified position.
     *
     * Steps:
     * 1. Access the `_checkpoints` array in the `Trace224` storage.
     * 2. Return the checkpoint located at the given position (`pos`).
     */
    function at(Trace224 storage self, uint32 pos) internal view returns (Checkpoint224 memory) {
        require(pos < self._checkpoints.length, "Checkpoints: out of bounds");
        Checkpoint224 storage ckpt = _unsafeAccess(self._checkpoints, pos);
        return Checkpoint224({ _key: ckpt._key, _value: ckpt._value });
    }

    /**
     * @notice Inserts a new checkpoint into the storage array or updates an existing one.
     *
     * Steps:
     * 1. Determine the current length of the checkpoint array.
     * 2. If the array is not empty:
     *    a. Access the last checkpoint in the array.
     *    b. Retrieve the key and value of the last checkpoint.
     *    c. Ensure that the new key is not less than the last key to maintain order.
     *    d. If the keys match, update the value of the last checkpoint.
     *    e. If the keys do not match, push a new checkpoint to the array.
     *    f. Return the old value and the new value.
     * 3. If the array is empty:
     *    a. Push a new checkpoint to the array.
     *    b. Return 0 as the old value and the new value.
     *
     * @param self The storage array of Checkpoint224.
     * @param key The key of the checkpoint to insert or update.
     * @param value The value of the checkpoint to insert or update.
     * @return oldValue The previous value associated with the key (0 if new).
     * @return newValue The new value associated with the key.
     *
     * @dev Reverts if the key is less than the last key in the array.
     */
    function _insert(Checkpoint224[] storage self, uint32 key, uint224 value) private returns (uint224 oldValue, uint224 newValue) {
        uint256 length_ = self.length;
        if (length_ > 0) {
            Checkpoint224 storage last = _unsafeAccess(self, length_ - 1);
            uint32 lastKey = last._key;
            uint224 lastValue = last._value;
            require(key >= lastKey, "Checkpoints: decreasing keys");
            if (key == lastKey) {
                last._value = value;
                return (lastValue, value);
            } else {
                self.push(Checkpoint224({ _key: key, _value: value }));
                return (lastValue, value);
            }
        } else {
            self.push(Checkpoint224({ _key: key, _value: value }));
            return (0, value);
        }
    }

    /**
     * @notice Performs an upper binary lookup on a sorted array of Checkpoint208 structs.
     *
     * @param self The storage array of Checkpoint208 structs to search.
     * @param key The key to search for within the array.
     * @param low The lower bound index for the binary search.
     * @param high The upper bound index for the binary search.
     *
     * @return high The index of the first element in the array that is greater than the key.
     *
     * Steps:
     * 1. While the lower bound is less than the upper bound:
     *    a. Calculate the middle index.
     *    b. If the key at the middle index is greater than the search key:
     *       - Set the upper bound to the middle index.
     *    c. Else:
     *       - Set the lower bound to the middle index + 1.
     * 2. Return the upper bound index as the result.
     */
    function _upperBinaryLookup(Checkpoint224[] storage self, uint32 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @notice Performs a binary search to find the position of a key in a sorted array of Checkpoint160 structs.
     *
     * @param self The storage array of Checkpoint160 structs to search within.
     * @param key The key to search for.
     * @param low The lower bound of the search range.
     * @param high The upper bound of the search range.
     *
     * @return The index of the key in the array, or the position where it should be inserted to maintain order.
     *
     * Steps:
     * 1. While the lower bound is less than the upper bound:
     *    a. Calculate the midpoint of the current search range.
     *    b. Compare the key at the midpoint with the target key.
     *    c. Adjust the search range based on the comparison:
     *       - If the midpoint key is less than the target key, move the lower bound up.
     *       - Otherwise, move the upper bound down.
     * 2. Return the final position (high) where the key is found or should be inserted.
     */
    function _lowerBinaryLookup(Checkpoint224[] storage self, uint32 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @notice Accesses a specific checkpoint in a storage array at a given position without bounds checking.
     * 
     * Steps:
     * 1. Store the slot of the storage array in memory.
     * 2. Calculate the storage slot of the checkpoint at the given position using keccak256.
     * 3. Return the checkpoint at the calculated storage slot.
     *
     * @dev This function is marked as private and pure, meaning it does not modify state and is only callable within the contract.
     * @dev The function uses inline assembly to directly manipulate storage slots, which is unsafe and should be used with caution.
     *
     * @param self The storage array of Checkpoint208 to access.
     * @param pos The position in the array to access.
     * @return result The checkpoint at the specified position.
     */
    function _unsafeAccess(Checkpoint224[] storage self, uint256 pos) private pure returns (Checkpoint224 storage result) {
        assembly {
            mstore(0x0, self.slot)
            let baseSlot := keccak256(0x0, 0x20)
            result.slot := add(baseSlot, pos)
        }
    }

    /**
     * @notice Defines a struct named `Trace208` that contains an array of `Checkpoint208` structs.
     * - `_checkpoints`: An array of `Checkpoint208` structs, representing a sequence of checkpoints.
     */
    struct Trace208 {
        Checkpoint208[] _checkpoints;
    }

    /**
     * @notice Defines a struct named `Checkpoint208` with two fields:
     * - `_key`: A 48-bit unsigned integer representing the key.
     * - `_value`: A 208-bit unsigned integer representing the value.
     */
    struct Checkpoint208 {
        uint48 _key;
        uint208 _value;
    }

    /**
     * @notice Inserts a new key-value pair into the Trace224 storage.
     *
     * @param self The storage reference to the Trace224 structure.
     * @param key The key to be inserted or updated.
     * @param value The value to be associated with the key.
     *
     * @return oldValue The previous value associated with the key (if any).
     * @return newValue The new value associated with the key after insertion.
     *
     * Steps:
     * 1. Calls the internal `_insert` function with the provided key and value.
     * 2. Returns the old and new values associated with the key.
     */
    function push(Trace208 storage self, uint48 key, uint208 value) internal returns (uint208 oldValue, uint208 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @notice Performs a lower-bound binary lookup on a sorted array of checkpoints to find the value associated with a given key.
     *
     * @param self The storage reference to the Trace224 struct containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The value associated with the largest checkpoint key less than or equal to the given key. Returns 0 if no such checkpoint exists.
     *
     * Steps:
     * 1. Determine the length of the checkpoints array.
     * 2. Perform a binary search to find the position of the largest checkpoint key less than or equal to the given key.
     * 3. If the position is equal to the length of the array, return 0 (no valid checkpoint found).
     * 4. Otherwise, return the value at the found position using unsafe access to avoid bounds checking.
     */
    function lowerLookup(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 length_ = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, length_);
        if (pos == length_) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @notice Performs an upper binary lookup on a Trace224 checkpoint array to find the value associated with the given key.
     *
     * @param self The Trace224 storage reference containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The value associated with the key, or 0 if no valid checkpoint is found.
     *
     * Steps:
     * 1. Retrieve the length of the checkpoints array.
     * 2. Use `_upperBinaryLookup` to find the position of the key in the checkpoints array.
     * 3. If the position is 0, return 0 (no valid checkpoint found).
     * 4. Otherwise, return the value from the checkpoint at the position minus one using `_unsafeAccess`.
     */
    function upperLookup(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 length_ = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, length_);
        if (pos == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @notice Performs an upper binary lookup on a Trace224 storage structure to find the most recent value associated with a given key.
     *
     * @param self The Trace224 storage structure containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The most recent value associated with the key, or 0 if no such value exists.
     *
     * Steps:
     * 1. Determine the length of the checkpoints array.
     * 2. Initialize low and high pointers for binary search.
     * 3. If the length of the checkpoints array is greater than 5, optimize the search by narrowing the range:
     *    - Calculate a midpoint using the square root of the length.
     *    - Adjust the high or low pointer based on whether the key is less than the key at the midpoint.
     * 4. Perform an upper binary lookup within the narrowed range to find the position of the key.
     * 5. Return the value at the position found, or 0 if no valid position is found.
     */
    function upperLookupRecent(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = length_;

        if (length_ > 5) {
            uint256 mid = _sqrt(length_ - 1);
            if (_unsafeAccess(self._checkpoints, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);
        if (pos == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @notice Retrieves the latest value from a Trace224 checkpoint array.
     *
     * @param self The Trace224 storage reference containing the checkpoints.
     * @return The latest value stored in the checkpoints. If no checkpoints exist, returns 0.
     *
     * Steps:
     * 1. Determine the length of the checkpoint array.
     * 2. If the array is empty, return 0.
     * 3. Otherwise, access the last checkpoint in the array and return its value.
     */
    function latest(Trace208 storage self) internal view returns (uint208) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, length_ - 1)._value;
    }

    /**
     * @notice Retrieves the latest checkpoint from a Trace224 storage structure.
     *
     * @param self The Trace224 storage structure containing the checkpoints.
     * @return exists A boolean indicating whether a checkpoint exists.
     * @return _key The key (uint32) of the latest checkpoint if it exists.
     * @return _value The value (uint224) of the latest checkpoint if it exists.
     *
     * Steps:
     * 1. Determine the position of the last checkpoint in the `_checkpoints` array.
     * 2. If no checkpoints exist, return `false` with default values for `_key` and `_value`.
     * 3. If checkpoints exist, access the latest checkpoint using `_unsafeAccess`.
     * 4. Return `true` along with the key and value of the latest checkpoint.
     */
    function latestCheckpoint(Trace208 storage self) internal view returns (bool exists, uint48 _key, uint208 _value) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return (false, 0, 0);
        }
        Checkpoint208 storage ckpt = _unsafeAccess(self._checkpoints, length_ - 1);
        return (true, ckpt._key, ckpt._value);
    }

    /**
     * @notice Returns the number of checkpoints stored in the Trace224 structure.
     *
     * @param self The Trace224 storage reference.
     * @return uint256 The number of checkpoints in the Trace224 structure.
     *
     * Steps:
     * 1. Access the `_checkpoints` array within the Trace224 structure.
     * 2. Return the length of the `_checkpoints` array.
     */
    function length(Trace208 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @notice Retrieves a checkpoint from the `Trace224` storage at a specified position.
     *
     * @param self The `Trace224` storage reference containing the checkpoints.
     * @param pos The position (index) of the checkpoint to retrieve.
     * @return Checkpoint224 The checkpoint at the specified position.
     *
     * Steps:
     * 1. Access the `_checkpoints` array in the `Trace224` storage.
     * 2. Return the checkpoint located at the given position (`pos`).
     */
    function at(Trace208 storage self, uint32 pos) internal view returns (Checkpoint208 memory) {
        require(pos < self._checkpoints.length, "Checkpoints: out of bounds");
        Checkpoint208 storage ckpt = _unsafeAccess(self._checkpoints, pos);
        return Checkpoint208({ _key: ckpt._key, _value: ckpt._value });
    }

    /**
     * @notice Inserts a new checkpoint into the storage array or updates an existing one.
     *
     * Steps:
     * 1. Determine the current length of the checkpoint array.
     * 2. If the array is not empty:
     *    a. Access the last checkpoint in the array.
     *    b. Retrieve the key and value of the last checkpoint.
     *    c. Ensure that the new key is not less than the last key to maintain order.
     *    d. If the keys match, update the value of the last checkpoint.
     *    e. If the keys do not match, push a new checkpoint to the array.
     *    f. Return the old value and the new value.
     * 3. If the array is empty:
     *    a. Push a new checkpoint to the array.
     *    b. Return 0 as the old value and the new value.
     *
     * @param self The storage array of Checkpoint224.
     * @param key The key of the checkpoint to insert or update.
     * @param value The value of the checkpoint to insert or update.
     * @return oldValue The previous value associated with the key (0 if new).
     * @return newValue The new value associated with the key.
     *
     * @dev Reverts if the key is less than the last key in the array.
     */
    function _insert(Checkpoint208[] storage self, uint48 key, uint208 value) private returns (uint208 oldValue, uint208 newValue) {
        uint256 length_ = self.length;
        if (length_ > 0) {
            Checkpoint208 storage last = _unsafeAccess(self, length_ - 1);
            uint48 lastKey = last._key;
            uint208 lastValue = last._value;
            require(key >= lastKey, "Checkpoints: decreasing keys");
            if (key == lastKey) {
                last._value = value;
                return (lastValue, value);
            } else {
                self.push(Checkpoint208({ _key: key, _value: value }));
                return (lastValue, value);
            }
        } else {
            self.push(Checkpoint208({ _key: key, _value: value }));
            return (0, value);
        }
    }

    /**
     * @notice Performs an upper binary lookup on a sorted array of Checkpoint208 structs.
     *
     * @param self The storage array of Checkpoint208 structs to search.
     * @param key The key to search for within the array.
     * @param low The lower bound index for the binary search.
     * @param high The upper bound index for the binary search.
     *
     * @return high The index of the first element in the array that is greater than the key.
     *
     * Steps:
     * 1. While the lower bound is less than the upper bound:
     *    a. Calculate the middle index.
     *    b. If the key at the middle index is greater than the search key:
     *       - Set the upper bound to the middle index.
     *    c. Else:
     *       - Set the lower bound to the middle index + 1.
     * 2. Return the upper bound index as the result.
     */
    function _upperBinaryLookup(Checkpoint208[] storage self, uint48 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @notice Performs a binary search to find the position of a key in a sorted array of Checkpoint160 structs.
     *
     * @param self The storage array of Checkpoint160 structs to search within.
     * @param key The key to search for.
     * @param low The lower bound of the search range.
     * @param high The upper bound of the search range.
     *
     * @return The index of the key in the array, or the position where it should be inserted to maintain order.
     *
     * Steps:
     * 1. While the lower bound is less than the upper bound:
     *    a. Calculate the midpoint of the current search range.
     *    b. Compare the key at the midpoint with the target key.
     *    c. Adjust the search range based on the comparison:
     *       - If the midpoint key is less than the target key, move the lower bound up.
     *       - Otherwise, move the upper bound down.
     * 2. Return the final position (high) where the key is found or should be inserted.
     */
    function _lowerBinaryLookup(Checkpoint208[] storage self, uint48 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @notice Accesses a specific checkpoint in a storage array at a given position without bounds checking.
     * 
     * Steps:
     * 1. Store the slot of the storage array in memory.
     * 2. Calculate the storage slot of the checkpoint at the given position using keccak256.
     * 3. Return the checkpoint at the calculated storage slot.
     *
     * @dev This function is marked as private and pure, meaning it does not modify state and is only callable within the contract.
     * @dev The function uses inline assembly to directly manipulate storage slots, which is unsafe and should be used with caution.
     *
     * @param self The storage array of Checkpoint208 to access.
     * @param pos The position in the array to access.
     * @return result The checkpoint at the specified position.
     */
    function _unsafeAccess(Checkpoint208[] storage self, uint256 pos) private pure returns (Checkpoint208 storage result) {
        assembly {
            mstore(0x0, self.slot)
            let baseSlot := keccak256(0x0, 0x20)
            result.slot := add(baseSlot, pos)
        }
    }

    /**
     * @notice A struct representing a trace of 160-bit checkpoints.
     * @dev Contains an array of Checkpoint160 structs to store historical data or state changes.
     */
    struct Trace160 {
        Checkpoint160[] _checkpoints;
    }

    /**
     * @notice A struct representing a checkpoint with a 96-bit key and a 160-bit value.
     * @dev This struct can be used to store key-value pairs where the key is a 96-bit unsigned integer and the value is a 160-bit unsigned integer.
     * @param _key The 96-bit unsigned integer key.
     * @param _value The 160-bit unsigned integer value.
     */
    struct Checkpoint160 {
        uint96 _key;
        uint160 _value;
    }

    /**
     * @notice Inserts a new key-value pair into the Trace224 storage.
     *
     * @param self The storage reference to the Trace224 structure.
     * @param key The key to be inserted or updated.
     * @param value The value to be associated with the key.
     *
     * @return oldValue The previous value associated with the key (if any).
     * @return newValue The new value associated with the key after insertion.
     *
     * Steps:
     * 1. Calls the internal `_insert` function with the provided key and value.
     * 2. Returns the old and new values associated with the key.
     */
    function push(Trace160 storage self, uint96 key, uint160 value) internal returns (uint160 oldValue, uint160 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @notice Performs a lower-bound binary lookup on a sorted array of checkpoints to find the value associated with a given key.
     *
     * @param self The storage reference to the Trace224 struct containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The value associated with the largest checkpoint key less than or equal to the given key. Returns 0 if no such checkpoint exists.
     *
     * Steps:
     * 1. Determine the length of the checkpoints array.
     * 2. Perform a binary search to find the position of the largest checkpoint key less than or equal to the given key.
     * 3. If the position is equal to the length of the array, return 0 (no valid checkpoint found).
     * 4. Otherwise, return the value at the found position using unsafe access to avoid bounds checking.
     */
    function lowerLookup(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 length_ = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, length_);
        if (pos == length_) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @notice Performs an upper binary lookup on a Trace224 checkpoint array to find the value associated with the given key.
     *
     * @param self The Trace224 storage reference containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The value associated with the key, or 0 if no valid checkpoint is found.
     *
     * Steps:
     * 1. Retrieve the length of the checkpoints array.
     * 2. Use `_upperBinaryLookup` to find the position of the key in the checkpoints array.
     * 3. If the position is 0, return 0 (no valid checkpoint found).
     * 4. Otherwise, return the value from the checkpoint at the position minus one using `_unsafeAccess`.
     */
    function upperLookup(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 length_ = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, length_);
        if (pos == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @notice Performs an upper binary lookup on a Trace224 storage structure to find the most recent value associated with a given key.
     *
     * @param self The Trace224 storage structure containing the checkpoints.
     * @param key The key to search for in the checkpoints.
     * @return The most recent value associated with the key, or 0 if no such value exists.
     *
     * Steps:
     * 1. Determine the length of the checkpoints array.
     * 2. Initialize low and high pointers for binary search.
     * 3. If the length of the checkpoints array is greater than 5, optimize the search by narrowing the range:
     *    - Calculate a midpoint using the square root of the length.
     *    - Adjust the high or low pointer based on whether the key is less than the key at the midpoint.
     * 4. Perform an upper binary lookup within the narrowed range to find the position of the key.
     * 5. Return the value at the position found, or 0 if no valid position is found.
     */
    function upperLookupRecent(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = length_;

        if (length_ > 5) {
            uint256 mid = _sqrt(length_ - 1);
            if (_unsafeAccess(self._checkpoints, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);
        if (pos == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @notice Retrieves the latest value from a Trace224 checkpoint array.
     *
     * @param self The Trace224 storage reference containing the checkpoints.
     * @return The latest value stored in the checkpoints. If no checkpoints exist, returns 0.
     *
     * Steps:
     * 1. Determine the length of the checkpoint array.
     * 2. If the array is empty, return 0.
     * 3. Otherwise, access the last checkpoint in the array and return its value.
     */
    function latest(Trace160 storage self) internal view returns (uint160) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return 0;
        }
        return _unsafeAccess(self._checkpoints, length_ - 1)._value;
    }

    /**
     * @notice Retrieves the latest checkpoint from a Trace224 storage structure.
     *
     * @param self The Trace224 storage structure containing the checkpoints.
     * @return exists A boolean indicating whether a checkpoint exists.
     * @return _key The key (uint32) of the latest checkpoint if it exists.
     * @return _value The value (uint224) of the latest checkpoint if it exists.
     *
     * Steps:
     * 1. Determine the position of the last checkpoint in the `_checkpoints` array.
     * 2. If no checkpoints exist, return `false` with default values for `_key` and `_value`.
     * 3. If checkpoints exist, access the latest checkpoint using `_unsafeAccess`.
     * 4. Return `true` along with the key and value of the latest checkpoint.
     */
    function latestCheckpoint(Trace160 storage self) internal view returns (bool exists, uint96 _key, uint160 _value) {
        uint256 length_ = self._checkpoints.length;
        if (length_ == 0) {
            return (false, 0, 0);
        }
        Checkpoint160 storage ckpt = _unsafeAccess(self._checkpoints, length_ - 1);
        return (true, ckpt._key, ckpt._value);
    }

    /**
     * @notice Returns the number of checkpoints stored in the Trace224 structure.
     *
     * @param self The Trace224 storage reference.
     * @return uint256 The number of checkpoints in the Trace224 structure.
     *
     * Steps:
     * 1. Access the `_checkpoints` array within the Trace224 structure.
     * 2. Return the length of the `_checkpoints` array.
     */
    function length(Trace160 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @notice Retrieves a checkpoint from the `Trace224` storage at a specified position.
     *
     * @param self The `Trace224` storage reference containing the checkpoints.
     * @param pos The position (index) of the checkpoint to retrieve.
     * @return Checkpoint224 The checkpoint at the specified position.
     *
     * Steps:
     * 1. Access the `_checkpoints` array in the `Trace224` storage.
     * 2. Return the checkpoint located at the given position (`pos`).
     */
    function at(Trace160 storage self, uint32 pos) internal view returns (Checkpoint160 memory) {
        require(pos < self._checkpoints.length, "Checkpoints: out of bounds");
        Checkpoint160 storage ckpt = _unsafeAccess(self._checkpoints, pos);
        return Checkpoint160({ _key: ckpt._key, _value: ckpt._value });
    }

    /**
     * @notice Inserts a new checkpoint into the storage array or updates an existing one.
     *
     * Steps:
     * 1. Determine the current length of the checkpoint array.
     * 2. If the array is not empty:
     *    a. Access the last checkpoint in the array.
     *    b. Retrieve the key and value of the last checkpoint.
     *    c. Ensure that the new key is not less than the last key to maintain order.
     *    d. If the keys match, update the value of the last checkpoint.
     *    e. If the keys do not match, push a new checkpoint to the array.
     *    f. Return the old value and the new value.
     * 3. If the array is empty:
     *    a. Push a new checkpoint to the array.
     *    b. Return 0 as the old value and the new value.
     *
     * @param self The storage array of Checkpoint224.
     * @param key The key of the checkpoint to insert or update.
     * @param value The value of the checkpoint to insert or update.
     * @return oldValue The previous value associated with the key (0 if new).
     * @return newValue The new value associated with the key.
     *
     * @dev Reverts if the key is less than the last key in the array.
     */
    function _insert(Checkpoint160[] storage self, uint96 key, uint160 value) private returns (uint160 oldValue, uint160 newValue) {
        uint256 length_ = self.length;
        if (length_ > 0) {
            Checkpoint160 storage last = _unsafeAccess(self, length_ - 1);
            uint96 lastKey = last._key;
            uint160 lastValue = last._value;
            require(key >= lastKey, "Checkpoints: decreasing keys");
            if (key == lastKey) {
                last._value = value;
                return (lastValue, value);
            } else {
                self.push(Checkpoint160({ _key: key, _value: value }));
                return (lastValue, value);
            }
        } else {
            self.push(Checkpoint160({ _key: key, _value: value }));
            return (0, value);
        }
    }

    /**
     * @notice Performs an upper binary lookup on a sorted array of Checkpoint208 structs.
     *
     * @param self The storage array of Checkpoint208 structs to search.
     * @param key The key to search for within the array.
     * @param low The lower bound index for the binary search.
     * @param high The upper bound index for the binary search.
     *
     * @return high The index of the first element in the array that is greater than the key.
     *
     * Steps:
     * 1. While the lower bound is less than the upper bound:
     *    a. Calculate the middle index.
     *    b. If the key at the middle index is greater than the search key:
     *       - Set the upper bound to the middle index.
     *    c. Else:
     *       - Set the lower bound to the middle index + 1.
     * 2. Return the upper bound index as the result.
     */
    function _upperBinaryLookup(Checkpoint160[] storage self, uint96 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @notice Performs a binary search to find the position of a key in a sorted array of Checkpoint160 structs.
     *
     * @param self The storage array of Checkpoint160 structs to search within.
     * @param key The key to search for.
     * @param low The lower bound of the search range.
     * @param high The upper bound of the search range.
     *
     * @return The index of the key in the array, or the position where it should be inserted to maintain order.
     *
     * Steps:
     * 1. While the lower bound is less than the upper bound:
     *    a. Calculate the midpoint of the current search range.
     *    b. Compare the key at the midpoint with the target key.
     *    c. Adjust the search range based on the comparison:
     *       - If the midpoint key is less than the target key, move the lower bound up.
     *       - Otherwise, move the upper bound down.
     * 2. Return the final position (high) where the key is found or should be inserted.
     */
    function _lowerBinaryLookup(Checkpoint160[] storage self, uint96 key, uint256 low, uint256 high) private view returns (uint256) {
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @notice Accesses a specific checkpoint in a storage array at a given position without bounds checking.
     * 
     * Steps:
     * 1. Store the slot of the storage array in memory.
     * 2. Calculate the storage slot of the checkpoint at the given position using keccak256.
     * 3. Return the checkpoint at the calculated storage slot.
     *
     * @dev This function is marked as private and pure, meaning it does not modify state and is only callable within the contract.
     * @dev The function uses inline assembly to directly manipulate storage slots, which is unsafe and should be used with caution.
     *
     * @param self The storage array of Checkpoint208 to access.
     * @param pos The position in the array to access.
     * @return result The checkpoint at the specified position.
     */
    function _unsafeAccess(Checkpoint160[] storage self, uint256 pos) private pure returns (Checkpoint160 storage result) {
        assembly {
            mstore(0x0, self.slot)
            let baseSlot := keccak256(0x0, 0x20)
            result.slot := add(baseSlot, pos)
        }
    }

    function _sqrt(uint256 x) private pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}