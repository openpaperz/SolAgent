// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library LibSort {
    /* --------------------------------- Insertion Sort --------------------------------- */

    function insertionSort(uint256[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i = 1; i < n; ++i) {
            uint256 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                --j;
            }
            a[j] = key;
        }
    }

    function insertionSort(int256[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i = 1; i < n; ++i) {
            int256 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                --j;
            }
            a[j] = key;
        }
    }

    function insertionSort(address[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i = 1; i < n; ++i) {
            address key = a[i];
            uint256 j = i;
            while (j > 0 && uint160(a[j - 1]) > uint160(key)) {
                a[j] = a[j - 1];
                --j;
            }
            a[j] = key;
        }
    }

    function insertionSort(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i = 1; i < n; ++i) {
            bytes32 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                --j;
            }
            a[j] = key;
        }
    }

    /* ------------------------------------- Sort -------------------------------------- */
    // For simplicity and correctness we delegate to insertionSort for all sorts.
    // For large arrays a more advanced algorithm would be used (quicksort/merge/etc).

    function sort(uint256[] memory a) internal pure {
        insertionSort(a);
    }

    function sort(int256[] memory a) internal pure {
        insertionSort(a);
    }

    function sort(address[] memory a) internal pure {
        insertionSort(a);
    }

    function sort(bytes32[] memory a) internal pure {
        insertionSort(a);
    }

    /* --------------------------------- Uniquify ------------------------------------- */

    function uniquifySorted(uint256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        for (uint256 read = 1; read < n; ++read) {
            if (a[read] != a[write]) {
                ++write;
                a[write] = a[read];
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    function uniquifySorted(int256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        for (uint256 read = 1; read < n; ++read) {
            if (a[read] != a[write]) {
                ++write;
                a[write] = a[read];
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    function uniquifySorted(address[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        for (uint256 read = 1; read < n; ++read) {
            if (a[read] != a[write]) {
                ++write;
                a[write] = a[read];
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    function uniquifySorted(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        uint256 write = 0;
        for (uint256 read = 1; read < n; ++read) {
            if (a[read] != a[write]) {
                ++write;
                a[write] = a[read];
            }
        }
        assembly {
            mstore(a, add(write, 1))
        }
    }

    /* --------------------------------- Search Sorted -------------------------------- */

    function searchSorted(uint256[] memory a, uint256 needle) internal pure returns (bool found, uint256 index) {
        uint256 lo = 0;
        uint256 hi = a.length;
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1;
            if (a[mid] == needle) {
                return (true, mid);
            } else if (a[mid] < needle) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return (false, lo);
    }

    function searchSorted(int256[] memory a, int256 needle) internal pure returns (bool found, uint256 index) {
        uint256 lo = 0;
        uint256 hi = a.length;
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1;
            if (a[mid] == needle) {
                return (true, mid);
            } else if (a[mid] < needle) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return (false, lo);
    }

    function searchSorted(address[] memory a, address needle) internal pure returns (bool found, uint256 index) {
        uint256 lo = 0;
        uint256 hi = a.length;
        uint256 key = uint160(needle);
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1;
            uint256 midv = uint160(a[mid]);
            if (midv == key) {
                return (true, mid);
            } else if (midv < key) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return (false, lo);
    }

    function searchSorted(bytes32[] memory a, bytes32 needle) internal pure returns (bool found, uint256 index) {
        uint256 lo = 0;
        uint256 hi = a.length;
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1;
            if (a[mid] == needle) {
                return (true, mid);
            } else if (a[mid] < needle) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return (false, lo);
    }

    /* ------------------------------------ InSorted ----------------------------------- */

    function inSorted(uint256[] memory a, uint256 needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    function inSorted(int256[] memory a, int256 needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    function inSorted(address[] memory a, address needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    function inSorted(bytes32[] memory a, bytes32 needle) internal pure returns (bool found) {
        (found, ) = searchSorted(a, needle);
    }

    /* ------------------------------------- Reverse ----------------------------------- */

    function reverse(uint256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 0; i < n / 2; ++i) {
            uint256 j = n - 1 - i;
            (a[i], a[j]) = (a[j], a[i]);
        }
    }

    function reverse(int256[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 0; i < n / 2; ++i) {
            uint256 j = n - 1 - i;
            (a[i], a[j]) = (a[j], a[i]);
        }
    }

    function reverse(address[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 0; i < n / 2; ++i) {
            uint256 j = n - 1 - i;
            (a[i], a[j]) = (a[j], a[i]);
        }
    }

    function reverse(bytes32[] memory a) internal pure {
        uint256 n = a.length;
        if (n < 2) return;
        for (uint256 i = 0; i < n / 2; ++i) {
            uint256 j = n - 1 - i;
            (a[i], a[j]) = (a[j], a[i]);
        }
    }

    /* -------------------------------------- Copy ------------------------------------- */

    function copy(uint256[] memory a) internal pure returns (uint256[] memory result) {
        uint256 n = a.length;
        result = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) result[i] = a[i];
    }

    function copy(int256[] memory a) internal pure returns (int256[] memory result) {
        uint256 n = a.length;
        result = new int256[](n);
        for (uint256 i = 0; i < n; ++i) result[i] = a[i];
    }

    function copy(address[] memory a) internal pure returns (address[] memory result) {
        uint256 n = a.length;
        result = new address[](n);
        for (uint256 i = 0; i < n; ++i) result[i] = a[i];
    }

    function copy(bytes32[] memory a) internal pure returns (bytes32[] memory result) {
        uint256 n = a.length;
        result = new bytes32[](n);
        for (uint256 i = 0; i < n; ++i) result[i] = a[i];
    }

    /* ------------------------------------ IsSorted ----------------------------------- */

    function isSorted(uint256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (a[i] > a[i + 1]) return false;
        }
        return true;
    }

    function isSorted(int256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (a[i] > a[i + 1]) return false;
        }
        return true;
    }

    function isSorted(address[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (uint160(a[i]) > uint160(a[i + 1])) return false;
        }
        return true;
    }

    function isSorted(bytes32[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (a[i] > a[i + 1]) return false;
        }
        return true;
    }

    /* ---------------------------- IsSortedAndUniquified ----------------------------- */

    function isSortedAndUniquified(uint256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (a[i] >= a[i + 1]) return false;
        }
        return true;
    }

    function isSortedAndUniquified(int256[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (a[i] >= a[i + 1]) return false;
        }
        return true;
    }

    function isSortedAndUniquified(address[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (uint160(a[i]) >= uint160(a[i + 1])) return false;
        }
        return true;
    }

    function isSortedAndUniquified(bytes32[] memory a) internal pure returns (bool result) {
        uint256 n = a.length;
        if (n < 2) return true;
        for (uint256 i = 0; i < n - 1; ++i) {
            if (a[i] >= a[i + 1]) return false;
        }
        return true;
    }

    /* --------------------------------- Set Operations -------------------------------- */

    function difference(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
        c = _difference(a, b, 0);
    }

    function difference(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
        // compute on ints directly
        uint256 na = a.length;
        uint256 nb = b.length;
        int256[] memory tmp = new int256[](na);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                tmp[k++] = a[ia++];
            } else {
                ++ib;
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        c = new int256[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function difference(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        address[] memory tmp = new address[](na);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            uint160 va = uint160(a[ia]);
            uint160 vb = uint160(b[ib]);
            if (va == vb) {
                ++ia;
                ++ib;
            } else if (va < vb) {
                tmp[k++] = a[ia++];
            } else {
                ++ib;
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        c = new address[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function difference(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        bytes32[] memory tmp = new bytes32[](na);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                tmp[k++] = a[ia++];
            } else {
                ++ib;
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        c = new bytes32[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function intersection(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
        c = _intersection(a, b, 0);
    }

    function intersection(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        int256[] memory tmp = new int256[](na < nb ? na : nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                ++ia;
            } else {
                ++ib;
            }
        }
        c = new int256[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function intersection(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        address[] memory tmp = new address[](na < nb ? na : nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            uint160 va = uint160(a[ia]);
            uint160 vb = uint160(b[ib]);
            if (va == vb) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (va < vb) {
                ++ia;
            } else {
                ++ib;
            }
        }
        c = new address[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function intersection(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        bytes32[] memory tmp = new bytes32[](na < nb ? na : nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                ++ia;
            } else {
                ++ib;
            }
        }
        c = new bytes32[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function union(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
        c = _union(a, b, 0);
    }

    function union(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        int256[] memory tmp = new int256[](na + nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                tmp[k++] = a[ia++];
            } else {
                tmp[k++] = b[ib++];
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        while (ib < nb) tmp[k++] = b[ib++];
        c = new int256[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function union(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        address[] memory tmp = new address[](na + nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            uint160 va = uint160(a[ia]);
            uint160 vb = uint160(b[ib]);
            if (va == vb) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (va < vb) {
                tmp[k++] = a[ia++];
            } else {
                tmp[k++] = b[ib++];
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        while (ib < nb) tmp[k++] = b[ib++];
        c = new address[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function union(bytes32[] memory a, bytes32[] memory b) internal pure returns (bytes32[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        bytes32[] memory tmp = new bytes32[](na + nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                tmp[k++] = a[ia++];
            } else {
                tmp[k++] = b[ib++];
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        while (ib < nb) tmp[k++] = b[ib++];
        c = new bytes32[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    /* ------------------------------------- Clean ------------------------------------ */

    function clean(address[] memory a) internal pure {
        for (uint256 i = 0; i < a.length; ++i) {
            a[i] = address(uint160(a[i]));
        }
    }

    /* --------------------------------- Conversions ---------------------------------- */

    function _toUints(int256[] memory a) private pure returns (uint256[] memory casted) {
        uint256 n = a.length;
        casted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) casted[i] = uint256(uint256(int256(a[i])));
    }

    function _toUints(address[] memory a) private pure returns (uint256[] memory casted) {
        uint256 n = a.length;
        casted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) casted[i] = uint256(uint160(a[i]));
    }

    function _toUints(bytes32[] memory a) private pure returns (uint256[] memory casted) {
        uint256 n = a.length;
        casted = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) casted[i] = uint256(uint256(a[i]));
    }

    function _toInts(uint256[] memory a) private pure returns (int256[] memory casted) {
        uint256 n = a.length;
        casted = new int256[](n);
        for (uint256 i = 0; i < n; ++i) casted[i] = int256(a[i]);
    }

    function _toAddresses(uint256[] memory a) private pure returns (address[] memory casted) {
        uint256 n = a.length;
        casted = new address[](n);
        for (uint256 i = 0; i < n; ++i) casted[i] = address(uint160(a[i]));
    }

    function _toBytes32s(uint256[] memory a) private pure returns (bytes32[] memory casted) {
        uint256 n = a.length;
        casted = new bytes32[](n);
        for (uint256 i = 0; i < n; ++i) casted[i] = bytes32(a[i]);
    }

    /* ------------------------------------ FlipSign ---------------------------------- */

    function _flipSign(int256[] memory a) private pure {
        for (uint256 i = 0; i < a.length; ++i) {
            a[i] = -a[i];
        }
    }

    /* --------------------------------- Binary Search -------------------------------- */

    function _searchSorted(uint256[] memory a, uint256 needle, uint256 /* signed */) private pure returns (bool found, uint256 index) {
        return searchSorted(a, needle);
    }

    /* --------------------------------- Internal Helpers ------------------------------ */

    function _difference(uint256[] memory a, uint256[] memory b, uint256 /* signed */) private pure returns (uint256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        uint256[] memory tmp = new uint256[](na);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                tmp[k++] = a[ia++];
            } else {
                ++ib;
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        c = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function _intersection(uint256[] memory a, uint256[] memory b, uint256 /* signed */) private pure returns (uint256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        uint256[] memory tmp = new uint256[](na < nb ? na : nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                ++ia;
            } else {
                ++ib;
            }
        }
        c = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }

    function _union(uint256[] memory a, uint256[] memory b, uint256 /* signed */) private pure returns (uint256[] memory c) {
        uint256 na = a.length;
        uint256 nb = b.length;
        uint256[] memory tmp = new uint256[](na + nb);
        uint256 ia = 0;
        uint256 ib = 0;
        uint256 k = 0;
        while (ia < na && ib < nb) {
            if (a[ia] == b[ib]) {
                tmp[k++] = a[ia];
                ++ia;
                ++ib;
            } else if (a[ia] < b[ib]) {
                tmp[k++] = a[ia++];
            } else {
                tmp[k++] = b[ib++];
            }
        }
        while (ia < na) tmp[k++] = a[ia++];
        while (ib < nb) tmp[k++] = b[ib++];
        c = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) c[i] = tmp[i];
    }
}