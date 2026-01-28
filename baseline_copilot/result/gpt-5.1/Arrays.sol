// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/math/Math.sol";
import "./utils/StorageSlot.sol";

library Arrays {
    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     *
     * @param array The array of unsigned integers to be sorted.
     * @param comp A comparison function that defines the sort order. It takes two uint256 values and returns a boolean indicating whether the first value should come before the second.
     *
     * @return The sorted array.
     *
     * Steps:
     * 1. Call the internal `_quickSort` function, passing the beginning and end of the array along with the comparison function.
     * 2. Return the sorted array.
     */
    function sort(
        uint256[] memory array,
        function(uint256, uint256) pure returns (bool) comp
    ) internal pure returns (uint256[] memory) {
        if (array.length > 1) {
            _quickSort(_begin(array), _end(array), comp);
        }
        return array;
    }

    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     *
     * @param array The array of unsigned integers to be sorted.
     * @param comp A comparison function that defines the sort order. It takes two uint256 values and returns a boolean indicating whether the first value should come before the second.
     *
     * @return The sorted array.
     *
     * Steps:
     * 1. Call the internal `_quickSort` function, passing the beginning and end of the array along with the comparison function.
     * 2. Return the sorted array.
     */
    function sort(uint256[] memory array) internal pure returns (uint256[] memory) {
        return sort(array, _defaultUintComp);
    }

    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     *
     * @param array The array of unsigned integers to be sorted.
     * @param comp A comparison function that defines the sort order. It takes two uint256 values and returns a boolean indicating whether the first value should come before the second.
     *
     * @return The sorted array.
     *
     * Steps:
     * 1. Call the internal `_quickSort` function, passing the beginning and end of the array along with the comparison function.
     * 2. Return the sorted array.
     */
    function sort(
        address[] memory array,
        function(address, address) pure returns (bool) comp
    ) internal pure returns (address[] memory) {
        if (array.length > 1) {
            uint256[] memory casted = _castToUint256Array(array);
            _quickSort(_begin(casted), _end(casted), _castToUint256Comp(comp));
        }
        return array;
    }

    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     *
     * @param array The array of unsigned integers to be sorted.
     * @param comp A comparison function that defines the sort order. It takes two uint256 values and returns a boolean indicating whether the first value should come before the second.
     *
     * @return The sorted array.
     *
     * Steps:
     * 1. Call the internal `_quickSort` function, passing the beginning and end of the array along with the comparison function.
     * 2. Return the sorted array.
     */
    function sort(address[] memory array) internal pure returns (address[] memory) {
        return sort(array, _defaultAddressComp);
    }

    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     *
     * @param array The array of unsigned integers to be sorted.
     * @param comp A comparison function that defines the sort order. It takes two uint256 values and returns a boolean indicating whether the first value should come before the second.
     *
     * @return The sorted array.
     *
     * Steps:
     * 1. Call the internal `_quickSort` function, passing the beginning and end of the array along with the comparison function.
     * 2. Return the sorted array.
     */
    function sort(
        bytes32[] memory array,
        function(bytes32, bytes32) pure returns (bool) comp
    ) internal pure returns (bytes32[] memory) {
        if (array.length > 1) {
            uint256[] memory casted = _castToUint256Array(array);
            _quickSort(_begin(casted), _end(casted), _castToUint256Comp(comp));
        }
        return array;
    }

    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     *
     * @param array The array of unsigned integers to be sorted.
     * @param comp A comparison function that defines the sort order. It takes two uint256 values and returns a boolean indicating whether the first value should come before the second.
     *
     * @return The sorted array.
     *
     * Steps:
     * 1. Call the internal `_quickSort` function, passing the beginning and end of the array along with the comparison function.
     * 2. Return the sorted array.
     */
    function sort(bytes32[] memory array) internal pure returns (bytes32[] memory) {
        return sort(array, _defaultBytes32Comp);
    }

    /**
     * @notice Implements the QuickSort algorithm to sort a range of elements in memory.
     *
     * Steps:
     * 1. Check if the range (end - begin) is less than 0x40 (64 bytes). If so, return early as no sorting is needed.
     * 2. Use the first element in the range as the pivot.
     * 3. Initialize a position variable `pos` to track where the pivot should be placed.
     * 4. Iterate through the range starting from the second element.
     * 5. For each element, compare it with the pivot using the provided comparison function `comp`.
     * 6. If the element should come before the pivot, increment `pos` and swap the element with the element at `pos`.
     * 7. After the loop, swap the pivot into its correct position at `pos`.
     * 8. Recursively sort the left side of the pivot (from `begin` to `pos`).
     * 9. Recursively sort the right side of the pivot (from `pos + 0x20` to `end`).
     *
     * @param begin The starting memory position of the range to sort.
     * @param end The ending memory position of the range to sort.
     * @param comp A comparison function that determines the order of elements.
     */
    function _quickSort(
        uint256 begin,
        uint256 end,
        function(uint256, uint256) pure returns (bool) comp
    ) private pure {
        if (end - begin < 0x40) {
            return;
        }

        uint256 pivotPtr = begin;
        uint256 pivot = _mload(pivotPtr);

        uint256 pos = begin;
        for (uint256 ptr = begin + 0x20; ptr < end; ptr += 0x20) {
            uint256 val = _mload(ptr);
            if (comp(val, pivot)) {
                pos += 0x20;
                _swap(pos, ptr);
            }
        }

        _swap(pivotPtr, pos);

        unchecked {
            _quickSort(begin, pos, comp);
            _quickSort(pos + 0x20, end, comp);
        }
    }

    /**
     * @notice A private pure function that calculates the memory pointer for the start of a given array.
     *
     * Steps:
     * 1. Use inline assembly to calculate the memory pointer.
     * 2. The pointer is calculated by adding 0x20 (32 bytes) to the base address of the array, 
     *    which skips the length slot and points to the first element of the array.
     * 3. Return the calculated pointer.
     */
    function _begin(uint256[] memory array) private pure returns (uint256 ptr) {
        assembly {
            ptr := add(array, 0x20)
        }
    }

    /**
     * @notice Calculates the end pointer of a dynamic array in memory.
     * 
     * Steps:
     * 1. Takes a dynamic array of uint256 as input.
     * 2. Uses the `_begin` function to get the starting pointer of the array.
     * 3. Adds the length of the array multiplied by 0x20 (32 bytes, the size of each uint256 element) to the starting pointer.
     * 4. Returns the calculated end pointer.
     * 
     * @param array The dynamic array of uint256 for which the end pointer is calculated.
     * @return ptr The end pointer of the array in memory.
     */
    function _end(uint256[] memory array) private pure returns (uint256 ptr) {
        assembly {
            ptr := add(add(array, 0x20), mul(mload(array), 0x20))
        }
    }

    /**
     * @notice Loads a 256-bit value from memory at the specified pointer.
     * @dev This function uses inline assembly to perform the memory load operation.
     * @param ptr The memory pointer from which to load the value.
     * @return value The 256-bit value loaded from memory.
     */
    function _mload(uint256 ptr) private pure returns (uint256 value) {
        assembly {
            value := mload(ptr)
        }
    }

    /**
     * @notice Swaps the values stored at two memory pointers.
     *
     * Steps:
     * 1. Load the value from the first pointer (`ptr1`) into `value1`.
     * 2. Load the value from the second pointer (`ptr2`) into `value2`.
     * 3. Store `value2` at the memory location of `ptr1`.
     * 4. Store `value1` at the memory location of `ptr2`.
     *
     * @dev This function uses inline assembly to perform the swap operation efficiently.
     */
    function _swap(uint256 ptr1, uint256 ptr2) private pure {
        if (ptr1 == ptr2) return;
        assembly {
            let v1 := mload(ptr1)
            let v2 := mload(ptr2)
            mstore(ptr1, v2)
            mstore(ptr2, v1)
        }
    }

    /**
     * @notice Converts an array of addresses into an array of uint256 values.
     * @dev This function uses inline assembly to directly cast the input array of addresses to an array of uint256.
     * @param input The array of addresses to be cast.
     * @return output The resulting array of uint256 values.
     */
    function _castToUint256Array(address[] memory input) private pure returns (uint256[] memory output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Converts an array of addresses into an array of uint256 values.
     * @dev This function uses inline assembly to directly cast the input array of addresses to an array of uint256.
     * @param input The array of addresses to be cast.
     * @return output The resulting array of uint256 values.
     */
    function _castToUint256Array(bytes32[] memory input) private pure returns (uint256[] memory output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Casts a function that takes two `bytes32` inputs and returns a `bool` 
     *         into a function that takes two `uint256` inputs and returns a `bool`.
     * 
     * @dev This is achieved using inline assembly to directly assign the input function 
     *      to the output function without any runtime checks or conversions.
     * 
     * @param input The original function with `bytes32` inputs.
     * @return output The casted function with `uint256` inputs.
     */
    function _castToUint256Comp(
        function(address, address) pure returns (bool) input
    ) private pure returns (function(uint256, uint256) pure returns (bool) output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Casts a function that takes two `bytes32` inputs and returns a `bool` 
     *         into a function that takes two `uint256` inputs and returns a `bool`.
     * 
     * @dev This is achieved using inline assembly to directly assign the input function 
     *      to the output function without any runtime checks or conversions.
     * 
     * @param input The original function with `bytes32` inputs.
     * @return output The casted function with `uint256` inputs.
     */
    function _castToUint256Comp(
        function(bytes32, bytes32) pure returns (bool) input
    ) private pure returns (function(uint256, uint256) pure returns (bool) output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Finds the upper bound of a given element in a sorted array using binary search.
     *
     * Steps:
     * 1. Initialize `low` to 0 and `high` to the length of the array.
     * 2. If the array is empty, return 0.
     *
     * 3. Perform a binary search:
     *    - Calculate the midpoint `mid` using `Math.average(low, high)`.
     *    - If the value at `mid` is greater than the target element, set `high` to `mid`.
     *    - Otherwise, set `low` to `mid + 1`.
     *
     * 4. After the loop, `low` represents the exclusive upper bound.
     * 5. If the element at `low - 1` equals the target element, return `low - 1` (inclusive upper bound).
     * 6. Otherwise, return `low` (exclusive upper bound).
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        if (high == 0) {
            return 0;
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] > element) {
                high = mid;
            } else {
                unchecked {
                    low = mid + 1;
                }
            }
        }

        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    /**
     * @notice Finds the lower bound index of a given element in a sorted array using binary search.
     *
     * Steps:
     * 1. Initialize `low` to 0 and `high` to the length of the array.
     * 2. If the array is empty, return 0.
     *
     * 3. Perform a binary search:
     *    - Calculate the midpoint `mid` using `Math.average(low, high)`.
     *    - If the value at `mid` is less than the target element, update `low` to `mid + 1`.
     *    - Otherwise, update `high` to `mid`.
     *
     * 4. The loop continues until `low` is no longer less than `high`.
     * 5. Return the index `low`, which is the lower bound for the element in the array.
     *
     * @dev The function assumes the array is sorted. The `unchecked` block is used to prevent overflow since `mid` is always less than `high`.
     */
    function lowerBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] < element) {
                unchecked {
                    low = mid + 1;
                }
            } else {
                high = mid;
            }
        }

        return low;
    }

    /**
     * @notice Finds the upper bound of a given element in a sorted array using binary search.
     *
     * Steps:
     * 1. Initialize `low` to 0 and `high` to the length of the array.
     * 2. If the array is empty, return 0 immediately.
     *
     * 3. Perform binary search:
     *    - Calculate the midpoint `mid` using `Math.average(low, high)`.
     *    - If the value at `mid` is greater than the target `element`, set `high` to `mid`.
     *    - Otherwise, increment `low` to `mid + 1` (this cannot overflow due to `mid < high`).
     *
     * 4. Return the index `low`, which represents the upper bound of the element in the array.
     *
     * @dev The function assumes the array is sorted in ascending order.
     * @param array The sorted array to search.
     * @param element The element to find the upper bound for.
     * @return The index of the upper bound of the element in the array.
     */
    function upperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] > element) {
                high = mid;
            } else {
                unchecked {
                    low = mid + 1;
                }
            }
        }

        return low;
    }

    /**
     * @notice Finds the lower bound index for a given element in a sorted memory array using binary search.
     *
     * Steps:
     * 1. Initialize `low` to 0 and `high` to the length of the array.
     * 2. If the array is empty, return 0.
     * 3. Perform binary search:
     *    a. Calculate the middle index `mid` using `Math.average`.
     *    b. If the element at `mid` is less than the target element, adjust `low` to `mid + 1`.
     *    c. Otherwise, adjust `high` to `mid`.
     * 4. Continue the search until `low` is no longer less than `high`.
     * 5. Return the `low` index as the lower bound.
     *
     * @dev The function assumes the array is sorted. It uses `unsafeMemoryAccess` to access array elements.
     *      The `unchecked` block is used to prevent overflow since `mid` is always less than `high`.
     *
     * @param array The sorted memory array to search.
     * @param element The element to find the lower bound for.
     * @return The index of the lower bound for the element in the array.
     */
    function lowerBoundMemory(uint256[] memory array, uint256 element) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (unsafeMemoryAccess(array, mid) < element) {
                unchecked {
                    low = mid + 1;
                }
            } else {
                high = mid;
            }
        }

        return low;
    }

    /**
     * @notice Finds the upper bound index for a given element in a sorted memory array using binary search.
     *
     * Steps:
     * 1. Initialize `low` to 0 and `high` to the length of the array.
     * 2. If the array is empty, return 0 immediately.
     * 3. Perform a binary search:
     *    - Calculate the middle index `mid` using `Math.average`.
     *    - If the element at `mid` is greater than the target element, set `high` to `mid`.
     *    - Otherwise, set `low` to `mid + 1` (this cannot overflow due to `mid < high`).
     * 4. Return the `low` index, which represents the upper bound for the element.
     *
     * @param array The sorted memory array to search.
     * @param element The element to find the upper bound for.
     * @return The index of the upper bound for the element.
     */
    function upperBoundMemory(uint256[] memory array, uint256 element) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (unsafeMemoryAccess(array, mid) > element) {
                high = mid;
            } else {
                unchecked {
                    low = mid + 1;
                }
            }
        }

        return low;
    }

    /**
     * @notice Accesses a specific position in a `bytes32` array stored in storage.
     * 
     * @param arr The storage array of `bytes32` elements.
     * @param pos The position in the array to access.
     * @return A `Bytes32Slot` representing the storage slot of the element at the specified position.
     * 
     * Steps:
     * 1. Retrieve the base storage slot of the array.
     * 2. Derive the storage slot for the element at the specified position.
     * 3. Return the `Bytes32Slot` for the derived storage slot.
     */
    function unsafeAccess(
        address[] storage arr,
        uint256 pos
    ) internal pure returns (StorageSlot.AddressSlot storage) {
        bytes32 slot;
        assembly {
            slot := arr.slot
        }
        bytes32 elementSlot = keccak256(abi.encodePacked(slot));
        unchecked {
            elementSlot = bytes32(uint256(elementSlot) + pos);
        }
        return StorageSlot.getAddressSlot(elementSlot);
    }

    /**
     * @notice Accesses a specific position in a `bytes32` array stored in storage.
     * 
     * @param arr The storage array of `bytes32` elements.
     * @param pos The position in the array to access.
     * @return A `Bytes32Slot` representing the storage slot of the element at the specified position.
     * 
     * Steps:
     * 1. Retrieve the base storage slot of the array.
     * 2. Derive the storage slot for the element at the specified position.
     * 3. Return the `Bytes32Slot` for the derived storage slot.
     */
    function unsafeAccess(
        bytes32[] storage arr,
        uint256 pos
    ) internal pure returns (StorageSlot.Bytes32Slot storage) {
        bytes32 slot;
        assembly {
            slot := arr.slot
        }
        bytes32 elementSlot = keccak256(abi.encodePacked(slot));
        unchecked {
            elementSlot = bytes32(uint256(elementSlot) + pos);
        }
        return StorageSlot.getBytes32Slot(elementSlot);
    }

    /**
     * @notice Accesses a specific position in a `bytes32` array stored in storage.
     * 
     * @param arr The storage array of `bytes32` elements.
     * @param pos The position in the array to access.
     * @return A `Bytes32Slot` representing the storage slot of the element at the specified position.
     * 
     * Steps:
     * 1. Retrieve the base storage slot of the array.
     * 2. Derive the storage slot for the element at the specified position.
     * 3. Return the `Bytes32Slot` for the derived storage slot.
     */
    function unsafeAccess(
        uint256[] storage arr,
        uint256 pos
    ) internal pure returns (StorageSlot.Uint256Slot storage) {
        bytes32 slot;
        assembly {
            slot := arr.slot
        }
        bytes32 elementSlot = keccak256(abi.encodePacked(slot));
        unchecked {
            elementSlot = bytes32(uint256(elementSlot) + pos);
        }
        return StorageSlot.getUint256Slot(elementSlot);
    }

    /**
     * @notice Accesses an element in a memory array at a specific position without bounds checking.
     * 
     * @param arr The memory array to access.
     * @param pos The position of the element to retrieve.
     * @return res The value at the specified position in the array.
     * 
     * @dev This function uses inline assembly to directly access memory, which is unsafe as it does not perform bounds checking.
     *      The caller must ensure that the position is within the array's bounds to avoid undefined behavior.
     */
    function unsafeMemoryAccess(address[] memory arr, uint256 pos) internal pure returns (address res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }

    /**
     * @notice Accesses an element in a memory array at a specific position without bounds checking.
     * 
     * @param arr The memory array to access.
     * @param pos The position of the element to retrieve.
     * @return res The value at the specified position in the array.
     * 
     * @dev This function uses inline assembly to directly access memory, which is unsafe as it does not perform bounds checking.
     *      The caller must ensure that the position is within the array's bounds to avoid undefined behavior.
     */
    function unsafeMemoryAccess(bytes32[] memory arr, uint256 pos) internal pure returns (bytes32 res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }

    /**
     * @notice Accesses an element in a memory array at a specific position without bounds checking.
     * 
     * @param arr The memory array to access.
     * @param pos The position of the element to retrieve.
     * @return res The value at the specified position in the array.
     * 
     * @dev This function uses inline assembly to directly access memory, which is unsafe as it does not perform bounds checking.
     *      The caller must ensure that the position is within the array's bounds to avoid undefined behavior.
     */
    function unsafeMemoryAccess(uint256[] memory arr, uint256 pos) internal pure returns (uint256 res) {
        assembly {
            res := mload(add(add(arr, 0x20), mul(pos, 0x20)))
        }
    }

    /**
     * @notice Unsafely sets the length of a bytes32 array in storage.
     * @dev This function uses inline assembly to directly modify the storage slot of the array.
     * @param array The storage array whose length is to be modified.
     * @param len The new length to set for the array.
     * @warning This function bypasses Solidity's safety checks and should be used with caution.
     */
    function unsafeSetLength(address[] storage array, uint256 len) internal {
        assembly {
            sstore(array.slot, len)
        }
    }

    /**
     * @notice Unsafely sets the length of a bytes32 array in storage.
     * @dev This function uses inline assembly to directly modify the storage slot of the array.
     * @param array The storage array whose length is to be modified.
     * @param len The new length to set for the array.
     * @warning This function bypasses Solidity's safety checks and should be used with caution.
     */
    function unsafeSetLength(bytes32[] storage array, uint256 len) internal {
        assembly {
            sstore(array.slot, len)
        }
    }

    /**
     * @notice Unsafely sets the length of a bytes32 array in storage.
     * @dev This function uses inline assembly to directly modify the storage slot of the array.
     * @param array The storage array whose length is to be modified.
     * @param len The new length to set for the array.
     * @warning This function bypasses Solidity's safety checks and should be used with caution.
     */
    function unsafeSetLength(uint256[] storage array, uint256 len) internal {
        assembly {
            sstore(array.slot, len)
        }
    }

    // Default comparison helpers

    function _defaultUintComp(uint256 a, uint256 b) private pure returns (bool) {
        return a < b;
    }

    function _defaultAddressComp(address a, address b) private pure returns (bool) {
        return a < b;
    }

    function _defaultBytes32Comp(bytes32 a, bytes32 b) private pure returns (bool) {
        return a < b;
    }
}