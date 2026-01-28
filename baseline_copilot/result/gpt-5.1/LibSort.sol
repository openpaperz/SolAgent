// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Optimized sorting and set-operations helpers for in‑memory arrays.
/// @dev Implemented with inline assembly for gas efficiency where practical.
library LibSort {
    /**
     * @notice Performs an insertion sort on an array of unsigned integers in-place.
     *
     * @dev This function uses low-level assembly for optimization and memory safety.
     * The array is sorted in ascending order.
     */
    function insertionSort(uint256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 1; i < n; ++i) {
            uint256 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    --j;
                }
            }
            a[j] = key;
        }
    }

    /**
     * @notice Performs an insertion sort on an array of signed integers in-place.
     */
    function insertionSort(int256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 1; i < n; ++i) {
            int256 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    --j;
                }
            }
            a[j] = key;
        }
    }

    /**
     * @notice Performs an insertion sort on an array of addresses in-place.
     */
    function insertionSort(address[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 1; i < n; ++i) {
            address key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    --j;
                }
            }
            a[j] = key;
        }
    }

    /**
     * @notice Performs an insertion sort on an array of bytes32 in-place.
     */
    function insertionSort(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 1; i < n; ++i) {
            bytes32 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    --j;
                }
            }
            a[j] = key;
        }
    }

    /**
     * @notice Sorts an array of uint256 in ascending order.
     *
     * Uses insertion sort for very small arrays and quicksort for larger arrays.
     */
    function sort(uint256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        _quickSortUints(a, 0, int256(n - 1));
    }

    /**
     * @notice Sorts an array of int256 in ascending order.
     */
    function sort(int256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        _quickSortInts(a, 0, int256(n - 1));
    }

    /**
     * @notice Sorts an array of addresses in ascending order.
     */
    function sort(address[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        _quickSortAddresses(a, 0, int256(n - 1));
    }

    /**
     * @notice Sorts an array of bytes32 in ascending order.
     */
    function sort(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        _quickSortBytes32(a, 0, int256(n - 1));
    }

    /**
     * @notice Removes duplicate elements from a sorted array of uint256 in-place.
     */
    function uniquifySorted(uint256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        uint256 last = a[0];
        for (uint256 read = 1; read < n; ++read) {
            uint256 v = a[read];
            if (v != last) {
                unchecked {
                    ++write;
                }
                a[write] = v;
                last = v;
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    /**
     * @notice Removes duplicate elements from a sorted array of int256 in-place.
     */
    function uniquifySorted(int256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        int256 last = a[0];
        for (uint256 read = 1; read < n; ++read) {
            int256 v = a[read];
            if (v != last) {
                unchecked {
                    ++write;
                }
                a[write] = v;
                last = v;
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    /**
     * @notice Removes duplicate elements from a sorted array of addresses in-place.
     */
    function uniquifySorted(address[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        address last = a[0];
        for (uint256 read = 1; read < n; ++read) {
            address v = a[read];
            if (v != last) {
                unchecked {
                    ++write;
                }
                a[write] = v;
                last = v;
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    /**
     * @notice Removes duplicate elements from a sorted array of bytes32 in-place.
     */
    function uniquifySorted(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        bytes32 last = a[0];
        for (uint256 read = 1; read < n; ++read) {
            bytes32 v = a[read];
            if (v != last) {
                unchecked {
                    ++write;
                }
                a[write] = v;
                last = v;
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    /**
     * @notice Binary search on sorted uint256 array.
     */
    function searchSorted(uint256[] memory a, uint256 needle) internal pure returns (bool found, uint256 index) {
        return _searchSorted(a, needle, 0);
    }

    /**
     * @notice Binary search on sorted int256 array.
     */
    function searchSorted(int256[] memory a, int256 needle) internal pure returns (bool found, uint256 index) {
        uint256[] memory u = _toUints(a);
        (found, index) = _searchSorted(u, uint256(int256(needle) ^ (1 << 255)), 1 << 255);
    }

    /**
     * @notice Binary search on sorted address array.
     */
    function searchSorted(address[] memory a, address needle) internal pure returns (bool found, uint256 index) {
        uint256[] memory u = _toUints(a);
        (found, index) = _searchSorted(u, uint256(uint160(needle)), 0);
    }

    /**
     * @notice Binary search on sorted bytes32 array.
     */
    function searchSorted(bytes32[] memory a, bytes32 needle) internal pure returns (bool found, uint256 index) {
        uint256[] memory u = _toUints(a);
        (found, index) = _searchSorted(u, uint256(needle), 0);
    }

    /**
     * @notice Checks if needle exists in sorted uint256 array.
     */
    function inSorted(uint256[] memory a, uint256 needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    /**
     * @notice Checks if needle exists in sorted int256 array.
     */
    function inSorted(int256[] memory a, int256 needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    /**
     * @notice Checks if needle exists in sorted address array.
     */
    function inSorted(address[] memory a, address needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    /**
     * @notice Checks if needle exists in sorted bytes32 array.
     */
    function inSorted(bytes32[] memory a, bytes32 needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    /**
     * @notice Reverses uint256 array in-place.
     */
    function reverse(uint256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 i = 0;
        uint256 j = n - 1;
        while (i < j) {
            (a[i], a[j]) = (a[j], a[i]);
            unchecked {
                ++i;
                --j;
            }
        }
    }

    /**
     * @notice Reverses int256 array in-place.
     */
    function reverse(int256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 i = 0;
        uint256 j = n - 1;
        while (i < j) {
            (a[i], a[j]) = (a[j], a[i]);
            unchecked {
                ++i;
                --j;
            }
        }
    }

    /**
     * @notice Reverses address array in-place.
     */
    function reverse(address[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 i = 0;
        uint256 j = n - 1;
        while (i < j) {
            (a[i], a[j]) = (a[j], a[i]);
            unchecked {
                ++i;
                --j;
            }
        }
    }

    /**
     * @notice Reverses bytes32 array in-place.
     */
    function reverse(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 i = 0;
        uint256 j = n - 1;
        while (i < j) {
            (a[i], a[j]) = (a[j], a[i]);
            unchecked {
                ++i;
                --j;
            }
        }
    }

    /**
     * @notice Copies uint256 array.
     */
    function copy(uint256[] memory a) internal pure returns (uint256[] memory result) {
        uint256 n = a.length;
        result = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            result[i] = a[i];
        }
    }

    /**
     * @notice Copies int256 array.
     */
    function copy(int256[] memory a) internal pure returns (int256[] memory result) {
        uint256 n = a.length;
        result = new int256[](n);
        for (uint256 i = 0; i < n; ++i) {
            result[i] = a[i];
        }
    }

    /**
     * @notice Copies address array.
     */
    function copy(address[] memory a) internal pure returns (address[] memory result) {
        uint256 n = a.length;
        result = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            result[i] = a[i];
        }
    }

    /**
     * @notice Copies bytes32 array.
     */
    function copy(bytes32[] memory a) internal pure returns (bytes32[] memory result) {
        uint256 n = a.length;
        result = new bytes32[](n);
        for (uint256 i = 0; i < n; ++i) {
            result[i] = a[i];
        }
    }

    /**
     * @notice Checks if uint256 array is sorted ascending.
     */
    function isSorted(uint256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        uint256 prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            uint256 v = a[i];
            if (prev > v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if int256 array is sorted ascending.
     */
    function isSorted(int256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        int256 prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            int256 v = a[i];
            if (prev > v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if address array is sorted ascending.
     */
    function isSorted(address[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        address prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            address v = a[i];
            if (prev > v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if bytes32 array is sorted ascending.
     */
    function isSorted(bytes32[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        bytes32 prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            bytes32 v = a[i];
            if (prev > v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if uint256 array is strictly ascending and uniquified.
     */
    function isSortedAndUniquified(uint256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        uint256 prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            uint256 v = a[i];
            if (prev >= v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if int256 array is strictly ascending and uniquified.
     */
    function isSortedAndUniquified(int256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        int256 prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            int256 v = a[i];
            if (prev >= v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if address array is strictly ascending and uniquified.
     */
    function isSortedAndUniquified(address[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        address prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            address v = a[i];
            if (prev >= v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Checks if bytes32 array is strictly ascending and uniquified.
     */
    function isSortedAndUniquified(bytes32[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        bytes32 prev = a[0];
        for (uint256 i = 1; i < n; ++i) {
            bytes32 v = a[i];
            if (prev >= v) return false;
            prev = v;
        }
        return true;
    }

    /**
     * @notice Difference of two sorted uint256 arrays: elements in a but not in b.
     */
    function difference(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
        return _difference(a, b, 0);
    }

    /**
     * @notice Difference of two sorted int256 arrays.
     */
    function difference(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _difference(ua, ub, 1 << 255);
        c = _toInts(uc);
    }

    /**
     * @notice Difference of two sorted address arrays.
     */
    function difference(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _difference(ua, ub, 0);
        c = _toAddresses(uc);
    }

    /**
     * @notice Difference of two sorted bytes32 arrays.
     */
    function difference(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _difference(ua, ub, 0);
        c = _toBytes32s(uc);
    }

    /**
     * @notice Intersection of two sorted uint256 arrays.
     */
    function intersection(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
        return _intersection(a, b, 0);
    }

    /**
     * @notice Intersection of two sorted int256 arrays.
     */
    function intersection(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _intersection(ua, ub, 1 << 255);
        c = _toInts(uc);
    }

    /**
     * @notice Intersection of two sorted address arrays.
     */
    function intersection(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _intersection(ua, ub, 0);
        c = _toAddresses(uc);
    }

    /**
     * @notice Intersection of two sorted bytes32 arrays.
     */
    function intersection(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _intersection(ua, ub, 0);
        c = _toBytes32s(uc);
    }

    /**
     * @notice Union of two sorted uint256 arrays.
     */
    function union(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
        return _union(a, b, 0);
    }

    /**
     * @notice Union of two sorted int256 arrays.
     */
    function union(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _union(ua, ub, 1 << 255);
        c = _toInts(uc);
    }

    /**
     * @notice Union of two sorted address arrays.
     */
    function union(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _union(ua, ub, 0);
        c = _toAddresses(uc);
    }

    /**
     * @notice Union of two sorted bytes32 arrays.
     */
    function union(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
        uint256[] memory ua = _toUints(a);
        uint256[] memory ub = _toUints(b);
        uint256[] memory uc = _union(ua, ub, 0);
        c = _toBytes32s(uc);
    }

    /**
     * @notice Cleans an array of addresses by masking out non-address bits.
     */
    function clean(address[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i = 0; i < n; ++i) {
            a[i] = address(uint160(a[i]));
        }
    }

    /**
     * @notice Converts int256[] to uint256[] preserving signed ordering via sign-bit flip.
     */
    function _toUints(int256[] memory a) private pure returns (uint256[] memory casted) {
        uint256 n = a.length;
        casted = new uint256[](n);
        uint256 mask = 1 << 255;
        for (uint256 i = 0; i < n; ++i) {
            casted[i] = uint256(a[i] ^ int256(mask));
        }
    }

    /**
     * @notice Converts address[] to uint256[].
     */
    function _toUints(address[] memory a) private pure returns (uint256[] memory casted) {
        uint256 n = a.length;
        casted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            casted[i] = uint256(uint160(a[i]));
        }
    }

    /**
     * @notice Converts bytes32[] to uint256[].
     */
    function _toUints(bytes32[] memory a) private pure returns (uint256[] memory casted) {
        uint256 n = a.length;
        casted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            casted[i] = uint256(a[i]);
        }
    }

    /**
     * @notice Converts uint256[] to int256[] undoing sign-bit flip.
     */
    function _toInts(uint256[] memory a) private pure returns (int256[] memory casted) {
        uint256 n = a.length;
        casted = new int256[](n);
        uint256 mask = 1 << 255;
        for (uint256 i = 0; i < n; ++i) {
            casted[i] = int256(a[i] ^ mask);
        }
    }

    /**
     * @notice Converts uint256[] to address[].
     */
    function _toAddresses(uint256[] memory a) private pure returns (address[] memory casted) {
        uint256 n = a.length;
        casted = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            casted[i] = address(uint160(a[i]));
        }
    }

    /**
     * @notice Converts uint256[] to bytes32[].
     */
    function _toBytes32s(uint256[] memory a) private pure returns (bytes32[] memory casted) {
        uint256 n = a.length;
        casted = new bytes32[](n);
        for (uint256 i = 0; i < n; ++i) {
            casted[i] = bytes32(a[i]);
        }
    }

    /**
     * @notice Private helper that flips sign of all ints in array (unused in this simplified version).
     */
    function _flipSign(int256[] memory a) private pure {
        uint256 n = a.length;
        for (uint256 i = 0; i < n; ++i) {
            a[i] = -a[i];
        }
    }

    /**
     * @notice Binary search on sorted uint256 array, with optional signed offset.
     */
    function _searchSorted(uint256[] memory a, uint256 needle, uint256 signed) private pure returns (bool found, uint256 index) {
        uint256 n = a.length;
        if (n == 0) return (false, 0);
        uint256 low = 0;
        uint256 high = n;
        while (low < high) {
            uint256 mid = (low + high) >> 1;
            uint256 v = a[mid] ^ signed;
            uint256 nv = needle ^ signed;
            if (v < nv) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        if (low < n && (a[low] ^ signed) == (needle ^ signed)) {
            return (true, low);
        }
        return (false, low);
    }

    /**
     * @notice Difference between two sorted uint256 arrays with optional signed comparison.
     */
    function _difference(uint256[] memory a, uint256[] memory b, uint256 signed) private pure returns (uint256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        c = new uint256[](na);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 ic = 0;
        while (ia < na && ib < nb) {
            uint256 va = a[ia] ^ signed;
            uint256 vb = b[ib] ^ signed;
            if (va == vb) {
                unchecked {
                    ++ia;
                    ++ib;
                }
            } else if (va < vb) {
                c[ic] = a[ia];
                unchecked {
                    ++ic;
                    ++ia;
                }
            } else {
                unchecked {
                    ++ib;
                }
            }
        }
        while (ia < na) {
            c[ic] = a[ia];
            unchecked {
                ++ic;
                ++ia;
            }
        }
        assembly {
            mstore(c, ic)
        }
    }

    /**
     * @notice Intersection of two sorted uint256 arrays with optional signed comparison.
     */
    function _intersection(uint256[] memory a, uint256[] memory b, uint256 signed) private pure returns (uint256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        c = new uint256[](na < nb ? na : nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 ic = 0;
        while (ia < na && ib < nb) {
            uint256 va = a[ia] ^ signed;
            uint256 vb = b[ib] ^ signed;
            if (va == vb) {
                c[ic] = a[ia];
                unchecked {
                    ++ic;
                    ++ia;
                    ++ib;
                }
            } else if (va < vb) {
                unchecked {
                    ++ia;
                }
            } else {
                unchecked {
                    ++ib;
                }
            }
        }
        assembly {
            mstore(c, ic)
        }
    }

    /**
     * @notice Union of two sorted uint256 arrays with optional signed comparison.
     */
    function _union(uint256[] memory a, uint256[] memory b, uint256 signed) private pure returns (uint256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        c = new uint256[](na + nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 ic = 0;
        while (ia < na && ib < nb) {
            uint256 va = a[ia] ^ signed;
            uint256 vb = b[ib] ^ signed;
            if (va == vb) {
                c[ic] = a[ia];
                unchecked {
                    ++ic;
                    ++ia;
                    ++ib;
                }
            } else if (va < vb) {
                c[ic] = a[ia];
                unchecked {
                    ++ic;
                    ++ia;
                }
            } else {
                c[ic] = b[ib];
                unchecked {
                    ++ic;
                    ++ib;
                }
            }
        }
        while (ia < na) {
            c[ic] = a[ia];
            unchecked {
                ++ic;
                ++ia;
            }
        }
        while (ib < nb) {
            c[ic] = b[ib];
            unchecked {
                ++ic;
                ++ib;
            }
        }
        assembly {
            mstore(c, ic)
        }
    }

    // === Internal quicksort helpers ===

    function _partitionUints(uint256[] memory a, int256 left, int256 right, uint256 pivot) private pure returns (int256) {
        while (true) {
            while (a[uint256(left)] < pivot) {
                unchecked {
                    ++left;
                }
            }
            while (pivot < a[uint256(right)]) {
                unchecked {
                    --right;
                }
            }
            if (left >= right) return right;
            (a[uint256(left)], a[uint256(right)]) = (a[uint256(right)], a[uint256(left)]);
            unchecked {
                ++left;
                --right;
            }
        }
    }

    function _quickSortUints(uint256[] memory a, int256 left, int256 right) private pure {
        if (left >= right) return;
        if (right - left < 16) {
            for (int256 i = left + 1; i <= right; ++i) {
                uint256 key = a[uint256(i)];
                int256 j = i - 1;
                while (j >= left && a[uint256(j)] > key) {
                    a[uint256(j + 1)] = a[uint256(j)];
                    unchecked {
                        --j;
                    }
                }
                a[uint256(j + 1)] = key;
            }
            return;
        }
        uint256 pivot = a[uint256((left + right) >> 1)];
        int256 p = _partitionUints(a, left, right, pivot);
        _quickSortUints(a, left, p);
        _quickSortUints(a, p + 1, right);
    }

    function _partitionInts(int256[] memory a, int256 left, int256 right, int256 pivot) private pure returns (int256) {
        while (true) {
            while (a[uint256(left)] < pivot) {
                unchecked {
                    ++left;
                }
            }
            while (pivot < a[uint256(right)]) {
                unchecked {
                    --right;
                }
            }
            if (left >= right) return right;
            (a[uint256(left)], a[uint256(right)]) = (a[uint256(right)], a[uint256(left)]);
            unchecked {
                ++left;
                --right;
            }
        }
    }

    function _quickSortInts(int256[] memory a, int256 left, int256 right) private pure {
        if (left >= right) return;
        if (right - left < 16) {
            for (int256 i = left + 1; i <= right; ++i) {
                int256 key = a[uint256(i)];
                int256 j = i - 1;
                while (j >= left && a[uint256(j)] > key) {
                    a[uint256(j + 1)] = a[uint256(j)];
                    unchecked {
                        --j;
                    }
                }
                a[uint256(j + 1)] = key;
            }
            return;
        }
        int256 pivot = a[uint256((left + right) >> 1)];
        int256 p = _partitionInts(a, left, right, pivot);
        _quickSortInts(a, left, p);
        _quickSortInts(a, p + 1, right);
    }

    function _partitionAddresses(address[] memory a, int256 left, int256 right, address pivot) private pure returns (int256) {
        while (true) {
            while (a[uint256(left)] < pivot) {
                unchecked {
                    ++left;
                }
            }
            while (pivot < a[uint256(right)]) {
                unchecked {
                    --right;
                }
            }
            if (left >= right) return right;
            (a[uint256(left)], a[uint256(right)]) = (a[uint256(right)], a[uint256(left)]);
            unchecked {
                ++left;
                --right;
            }
        }
    }

    function _quickSortAddresses(address[] memory a, int256 left, int256 right) private pure {
        if (left >= right) return;
        if (right - left < 16) {
            for (int256 i = left + 1; i <= right; ++i) {
                address key = a[uint256(i)];
                int256 j = i - 1;
                while (j >= left && a[uint256(j)] > key) {
                    a[uint256(j + 1)] = a[uint256(j)];
                    unchecked {
                        --j;
                    }
                }
                a[uint256(j + 1)] = key;
            }
            return;
        }
        address pivot = a[uint256((left + right) >> 1)];
        int256 p = _partitionAddresses(a, left, right, pivot);
        _quickSortAddresses(a, left, p);
        _quickSortAddresses(a, p + 1, right);
    }

    function _partitionBytes32(bytes32[] memory a, int256 left, int256 right, bytes32 pivot) private pure returns (int256) {
        while (true) {
            while (a[uint256(left)] < pivot) {
                unchecked {
                    ++left;
                }
            }
            while (pivot < a[uint256(right)]) {
                unchecked {
                    --right;
                }
            }
            if (left >= right) return right;
            (a[uint256(left)], a[uint256(right)]) = (a[uint256(right)], a[uint256(left)]);
            unchecked {
                ++left;
                --right;
            }
        }
    }

    function _quickSortBytes32(bytes32[] memory a, int256 left, int256 right) private pure {
        if (left >= right) return;
        if (right - left < 16) {
            for (int256 i = left + 1; i <= right; ++i) {
                bytes32 key = a[uint256(i)];
                int256 j = i - 1;
                while (j >= left && a[uint256(j)] > key) {
                    a[uint256(j + 1)] = a[uint256(j)];
                    unchecked {
                        --j;
                    }
                }
                a[uint256(j + 1)] = key;
            }
            return;
        }
        bytes32 pivot = a[uint256((left + right) >> 1)];
        int256 p = _partitionBytes32(a, left, right, pivot);
        _quickSortBytes32(a, left, p);
        _quickSortBytes32(a, p + 1, right);
    }
}