// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Arrays
 * @dev Utility library for array sorting and unsafe array access.
 *
 * NOTE: This implementation follows the function signatures provided in the task.
 * It implements an in-memory, pointer-based QuickSort for memory arrays and
 * several binary-search helpers for storage and memory arrays. It also provides
 * unsafe accessors that bypass bounds checks using inline assembly.
 */
library Arrays {
    using Math for uint256;

    /**
     * @notice Sorts an array of unsigned integers using a custom comparison function.
     */
    function sort(uint256[] memory array, function(uint256, uint256) pure returns (bool) comp) internal pure returns (uint256[] memory) {
        if (array.length <= 1) {
            return array;
        }
        uint256 beginPtr = _begin(array);
        uint256 endPtr = _end(array);
        _quickSort(beginPtr, endPtr, comp);
        return array;
    }

    /**
     * @notice Sorts an array of unsigned integers using the default ascending comparison.
     */
    function sort(uint256[] memory array) internal pure returns (uint256[] memory) {
        return sort(array, _defaultUintComp);
    }

    /**
     * @notice Sorts an array of addresses using a custom comparison function.
     */
    function sort(address[] memory array, function(address, address) pure returns (bool) comp) internal pure returns (address[] memory) {
        if (array.length <= 1) {
            return array;
        }
        // Cast address[] memory to uint256[] memory and cast the comparator
        uint256[] memory asUint = _castToUint256Array(array);
        function(uint256, uint256) pure returns (bool) compUint = _castToUint256Comp(comp);
        _quickSort(_begin(asUint), _end(asUint), compUint);
        return array;
    }

    /**
     * @notice Sorts an array of addresses using default ascending order.
     */
    function sort(address[] memory array) internal pure returns (address[] memory) {
        // default comparator: compare addresses by their numeric value
        return sort(array, _defaultAddressComp);
    }

    /**
     * @notice Sorts an array of bytes32 using a custom comparison function.
     */
    function sort(bytes32[] memory array, function(bytes32, bytes32) pure returns (bool) comp) internal pure returns (bytes32[] memory) {
        if (array.length <= 1) {
            return array;
        }
        uint256[] memory asUint = _castToUint256Array(array);
        function(uint256, uint256) pure returns (bool) compUint = _castToUint256Comp(comp);
        _quickSort(_begin(asUint), _end(asUint), compUint);
        return array;
    }

    /**
     * @notice Sorts an array of bytes32 using default ascending order.
     */
    function sort(bytes32[] memory array) internal pure returns (bytes32[] memory) {
        return sort(array, _defaultBytes32Comp);
    }

    /**
     * @notice Implements the QuickSort algorithm to sort a range of elements in memory.
     *
     * The `begin` and `end` parameters are memory pointers (addresses).
     * `begin` points to the first element (32 bytes aligned).
     * `end` points to one past the last element.
     */
    function _quickSort(uint256 begin, uint256 end, function(uint256, uint256) pure returns (bool) comp) private pure {
        // Range size in bytes
        if (end <= begin || end - begin < 0x40) {
            // less than two elements (0x20) or small range: nothing to do
            return;
        }

        // pivot := mload(begin)
        uint256 pivot = _mload(begin);
        uint256 pos = begin; // pos points to last element of "less than pivot" region
        uint256 ptr = begin + 0x20;

        while (ptr < end) {
            uint256 val = _mload(ptr);
            if (comp(val, pivot)) {
                pos += 0x20;
                _swap(ptr, pos);
            }
            ptr += 0x20;
        }

        // place pivot at pos
        _swap(begin, pos);

        // recursively sort left [begin, pos)
        if (pos > begin + 0x20) {
            _quickSort(begin, pos, comp);
        }

        // recursively sort right (pos+0x20, end)
        uint256 rightBegin = pos + 0x20;
        if (end > rightBegin + 0x20) {
            _quickSort(rightBegin, end, comp);
        } else if (end > rightBegin) {
            // handle two-element right partition
            if (_mload(rightBegin) < _mload(rightBegin + 0x20)) {
                // already sorted
            }
        }
    }

    /**
     * @notice Calculate pointer to first element of memory uint256[] array.
     */
    function _begin(uint256[] memory array) private pure returns (uint256 ptr) {
        assembly {
            ptr := add(array, 0x20)
        }
    }

    /**
     * @notice Calculate end pointer (one past last element) for a memory uint256[] array.
     */
    function _end(uint256[] memory array) private pure returns (uint256 ptr) {
        uint256 b = _begin(array);
        assembly {
            let len := mload(array)
            ptr := add(b, mul(len, 0x20))
        }
    }

    /**
     * @notice Load 256-bit word from memory pointer.
     */
    function _mload(uint256 ptr) private pure returns (uint256 value) {
        assembly {
            value := mload(ptr)
        }
    }

    /**
     * @notice Swap two 32-byte words in memory at pointers ptr1 and ptr2.
     */
    function _swap(uint256 ptr1, uint256 ptr2) private pure {
        if (ptr1 == ptr2) {
            return;
        }
        uint256 a;
        uint256 b;
        assembly {
            a := mload(ptr1)
            b := mload(ptr2)
            mstore(ptr1, b)
            mstore(ptr2, a)
        }
    }

    /**
     * @notice Casts an address[] memory array to uint256[] memory by aliasing the memory pointer.
     */
    function _castToUint256Array(address[] memory input) private pure returns (uint256[] memory output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Casts a bytes32[] memory array to uint256[] memory by aliasing the memory pointer.
     */
    function _castToUint256Array(bytes32[] memory input) private pure returns (uint256[] memory output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Casts a function(address,address) pure returns (bool) into function(uint256,uint256) pure returns (bool)
     */
    function _castToUint256Comp(function(address, address) pure returns (bool) input) private pure returns (function(uint256, uint256) pure returns (bool) output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Casts a function(bytes32,bytes32) pure returns (bool) into function(uint256,uint256) pure returns (bool)
     */
    function _castToUint256Comp(function(bytes32, bytes32) pure returns (bool) input) private pure returns (function(uint256, uint256) pure returns (bool) output) {
        assembly {
            output := input
        }
    }

    /**
     * @notice Default comparator for uint256 (ascending).
     */
    function _defaultUintComp(uint256 a, uint256 b) private pure returns (bool) {
        return a < b;
    }

    /**
     * @notice Default comparator for addresses (ascending).
     */
    function _defaultAddressComp(address a, address b) private pure returns (bool) {
        return uint256(uint160(a)) < uint256(uint160(b));
    }

    /**
     * @notice Default comparator for bytes32 (ascending lexicographic).
     */
    function _defaultBytes32Comp(bytes32 a, bytes32 b) private pure returns (bool) {
        return uint256(a) < uint256(b);
    }

    /**
     * @notice Finds the upper bound of a given element in a sorted storage array using binary search.
     * Returns either the index of the equal element (inclusive upper bound) or the exclusive upper bound.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // low is exclusive upper bound
        if (low > 0 && array[low - 1] == element) {
            return low - 1; // inclusive upper bound
        }
        return low; // exclusive upper bound
    }

    /**
     * @notice Finds the lower bound index of a given element in a sorted storage array using binary search.
     */
    function lowerBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] < element) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return low;
    }

    /**
     * @notice Finds the upper bound of a given element in a sorted storage array using binary search.
     */
    function upperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return low;
    }

    /**
     * @notice Finds the lower bound index for a given element in a sorted memory array using binary search.
     */
    function lowerBoundMemory(uint256[] memory array, uint256 element) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] < element) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return low;
    }

    /**
     * @notice Finds the upper bound index for a given element in a sorted memory array using binary search.
     */
    function upperBoundMemory(uint256[] memory array, uint256 element) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return low;
    }

    /**
     * @notice Accesses a specific position in an `address[]` storage array and returns the storage slot wrapper.
     */
    function unsafeAccess(address[] storage arr, uint256 pos) internal pure returns (StorageSlot.AddressSlot storage) {
        bytes32 baseSlot;
        assembly {
            baseSlot := arr.slot
        }
        // compute keccak256(baseSlot) + pos
        bytes32 elementSlot;
        assembly {
            mstore(0x00, baseSlot)
            elementSlot := keccak256(0x00, 0x20)
            elementSlot := add(elementSlot, pos)
        }
        return StorageSlot.getAddressSlot(elementSlot);
    }

    /**
     * @notice Accesses a specific position in a `bytes32[]` storage array and returns the storage slot wrapper.
     */
    function unsafeAccess(bytes32[] storage arr, uint256 pos) internal pure returns (StorageSlot.Bytes32Slot storage) {
        bytes32 baseSlot;
        assembly {
            baseSlot := arr.slot
        }
        bytes32 elementSlot;
        assembly {
            mstore(0x00, baseSlot)
            elementSlot := keccak256(0x00, 0x20)
            elementSlot := add(elementSlot, pos)
        }
        return StorageSlot.getBytes32Slot(elementSlot);
    }

    /**
     * @notice Accesses a specific position in a `uint256[]` storage array and returns the storage slot wrapper.
     */
    function unsafeAccess(uint256[] storage arr, uint256 pos) internal pure returns (StorageSlot.Uint256Slot storage) {
        bytes32 baseSlot;
        assembly {
            baseSlot := arr.slot
        }
        bytes32 elementSlot;
        assembly {
            mstore(0x00, baseSlot)
            elementSlot := keccak256(0x00, 0x20)
            elementSlot := add(elementSlot, pos)
        }
        return StorageSlot.getUint256Slot(elementSlot);
    }

    /**
     * @notice Accesses an element in a memory address[] array at a specific position without bounds checking.
     */
    function unsafeMemoryAccess(address[] memory arr, uint256 pos) internal pure returns (address res) {
        uint256 ptr;
        assembly {
            ptr := add(arr, 0x20)
            ptr := add(ptr, mul(pos, 0x20))
            res := mload(ptr)
        }
    }

    /**
     * @notice Accesses an element in a memory bytes32[] array at a specific position without bounds checking.
     */
    function unsafeMemoryAccess(bytes32[] memory arr, uint256 pos) internal pure returns (bytes32 res) {
        uint256 ptr;
        assembly {
            ptr := add(arr, 0x20)
            ptr := add(ptr, mul(pos, 0x20))
            res := mload(ptr)
        }
    }

    /**
     * @notice Accesses an element in a memory uint256[] array at a specific position without bounds checking.
     */
    function unsafeMemoryAccess(uint256[] memory arr, uint256 pos) internal pure returns (uint256 res) {
        uint256 ptr;
        assembly {
            ptr := add(arr, 0x20)
            ptr := add(ptr, mul(pos, 0x20))
            res := mload(ptr)
        }
    }

    /**
     * @notice Unsafely sets the length of an address[] storage array.
     */
    function unsafeSetLength(address[] storage array, uint256 len) internal {
        assembly {
            sstore(array.slot, len)
        }
    }

    /**
     * @notice Unsafely sets the length of a bytes32[] storage array.
     */
    function unsafeSetLength(bytes32[] storage array, uint256 len) internal {
        assembly {
            sstore(array.slot, len)
        }
    }

    /**
     * @notice Unsafely sets the length of a uint256[] storage array.
     */
    function unsafeSetLength(uint256[] storage array, uint256 len) internal {
        assembly {
            sstore(array.slot, len)
        }
    }
}
