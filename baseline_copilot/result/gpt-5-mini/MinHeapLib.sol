// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library MinHeapLib {
    error HeapIsEmpty();

    struct Heap {
        uint256[] data;
    }

    struct MemHeap {
        uint256[] data;
    }

    /* ============================
       Root
       ============================ */

    function root(Heap storage heap) internal view returns (uint256 result) {
        if (heap.data.length == 0) revert HeapIsEmpty();
        return heap.data[0];
    }

    function root(MemHeap memory heap) internal pure returns (uint256 result) {
        if (heap.data.length == 0) revert HeapIsEmpty();
        return heap.data[0];
    }

    /* ============================
       Reserve (memory helper)
       ============================ */

    function reserve(MemHeap memory heap, uint256 minimum) internal pure {
        // If current length is less than minimum, allocate a new memory array
        uint256 len = heap.data.length;
        if (len >= minimum) return;

        uint256[] memory newArr = new uint256[](minimum);
        for (uint256 i = 0; i < len; i++) {
            newArr[i] = heap.data[i];
        }
        heap.data = newArr;
    }

    /* ============================
       Smallest (returns first k smallest values)
       ============================ */

    function smallest(Heap storage heap, uint256 k) internal view returns (uint256[] memory a) {
        uint256 n = heap.data.length;
        if (n == 0 || k == 0) {
            return new uint256[](0);
        }
        uint256 m = k < n ? k : n;
        // Copy to memory for selection
        uint256[] memory tmp = new uint256[](n);
        for (uint256 i = 0; i < n; i++) tmp[i] = heap.data[i];

        a = new uint256[](m);

        // Simple selection: repeatedly extract minimum
        for (uint256 i = 0; i < m; i++) {
            uint256 minIdx = i;
            // find minimum in tmp[i..n-1]
            for (uint256 j = i; j < n; j++) {
                if (tmp[j] < tmp[minIdx]) minIdx = j;
            }
            // place min at a[i] and mark spot
            a[i] = tmp[minIdx];
            // swap tmp[i] and tmp[minIdx]
            (tmp[i], tmp[minIdx]) = (tmp[minIdx], tmp[i]);
        }
    }

    function smallest(MemHeap memory heap, uint256 k) internal pure returns (uint256[] memory a) {
        uint256 n = heap.data.length;
        if (n == 0 || k == 0) {
            return new uint256[](0);
        }
        uint256 m = k < n ? k : n;
        uint256[] memory tmp = new uint256[](n);
        for (uint256 i = 0; i < n; i++) tmp[i] = heap.data[i];

        a = new uint256[](m);

        for (uint256 i = 0; i < m; i++) {
            uint256 minIdx = i;
            for (uint256 j = i; j < n; j++) {
                if (tmp[j] < tmp[minIdx]) minIdx = j;
            }
            a[i] = tmp[minIdx];
            (tmp[i], tmp[minIdx]) = (tmp[minIdx], tmp[i]);
        }
    }

    /* ============================
       Length helpers
       ============================ */

    function length(Heap storage heap) internal view returns (uint256) {
        return heap.data.length;
    }

    function length(MemHeap memory heap) internal pure returns (uint256) {
        return heap.data.length;
    }

    /* ============================
       Push / Pop / Replace / PushPop (storage)
       ============================ */

    function push(Heap storage heap, uint256 value) internal {
        uint256[] storage arr = heap.data;
        arr.push(value);
        _siftUpStorage(arr, arr.length - 1);
    }

    function push(MemHeap memory heap, uint256 value) internal pure {
        uint256[] memory arr = heap.data;
        // create new array with one more slot and copy
        uint256 len = arr.length;
        uint256[] memory newArr = new uint256[](len + 1);
        for (uint256 i = 0; i < len; i++) newArr[i] = arr[i];
        newArr[len] = value;
        // sift up in memory
        _siftUpMemory(newArr, len);
        heap.data = newArr;
    }

    function pop(Heap storage heap) internal returns (uint256 popped) {
        ( , popped) = _set(heap, 0, 0, 1); // mode 1 = pop
        return popped;
    }

    function pop(MemHeap memory heap) internal pure returns (uint256 popped) {
        ( , popped) = _set(heap, 0, 0, 1); // memory variant
        return popped;
    }

    function pushPop(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        ( , popped) = _set(heap, value, 0, 4);
        return popped;
    }

    function pushPop(MemHeap memory heap, uint256 value) internal pure returns (uint256 popped) {
        ( , popped) = _set(heap, value, 0, 4);
        return popped;
    }

    function replace(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        ( , popped) = _set(heap, value, 0, 2);
        return popped;
    }

    function replace(MemHeap memory heap, uint256 value) internal pure returns (uint256 popped) {
        ( , popped) = _set(heap, value, 0, 2);
        return popped;
    }

    /* ============================
       Enqueue with maxLength
       ============================ */

    function enqueue(Heap storage heap, uint256 value, uint256 maxLength) internal returns (bool success, bool hasPopped, uint256 popped) {
        if (maxLength == 0) {
            // nothing allowed
            return (false, false, 0);
        }
        uint256 len = heap.data.length;
        if (len < maxLength) {
            push(heap, value);
            return (true, false, 0);
        }
        // If full: if value > root, replace root (pop smallest) with value, otherwise do nothing
        uint256 r = heap.data[0];
        if (value > r) {
            popped = r;
            // replace root with value and siftdown
            heap.data[0] = value;
            _siftDownStorage(heap.data, 0, len);
            return (true, true, popped);
        } else {
            // value is not greater than smallest - don't enqueue
            return (false, false, 0);
        }
    }

    function enqueue(MemHeap memory heap, uint256 value, uint256 maxLength) internal pure returns (bool success, bool hasPopped, uint256 popped) {
        if (maxLength == 0) {
            return (false, false, 0);
        }
        uint256 len = heap.data.length;
        if (len < maxLength) {
            // push in memory
            push(heap, value);
            return (true, false, 0);
        }
        uint256 r = heap.data.length > 0 ? heap.data[0] : type(uint256).max;
        if (value > r) {
            popped = r;
            heap.data[0] = value;
            _siftDownMemory(heap.data, 0, len);
            return (true, true, popped);
        } else {
            return (false, false, 0);
        }
    }

    /* ============================
       bumpFreeMemoryPointer
       ============================ */

    function bumpFreeMemoryPointer() internal pure {
        uint256 zero = 0;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, zero)
            mstore(0x40, add(ptr, 0x20))
        }
    }

    /* ============================
       Internal _set (storage)
       Modes:
         0 = enqueue
         1 = pop
         2 = replace
         3 = push
         4 = pushPop
       Returns:
         status, popped
       ============================ */

    function _set(Heap storage heap, uint256 value, uint256 maxLength, uint256 mode) private returns (uint256 status, uint256 popped) {
        uint256 len = heap.data.length;

        if (mode == 1) {
            // pop
            if (len == 0) revert HeapIsEmpty();
            popped = heap.data[0];
            if (len == 1) {
                heap.data.pop();
                return (1, popped);
            }
            heap.data[0] = heap.data[len - 1];
            heap.data.pop();
            _siftDownStorage(heap.data, 0, len - 1);
            return (1, popped);
        }

        if (mode == 2) {
            // replace root with value
            if (len == 0) revert HeapIsEmpty();
            popped = heap.data[0];
            heap.data[0] = value;
            _siftDownStorage(heap.data, 0, len);
            return (3, popped); // status 3 = replaced
        }

        if (mode == 3) {
            // push ignoring maxLength
            push(heap, value);
            return (1, 0);
        }

        if (mode == 4) {
            // pushPop: push then pop smallest (root)
            if (len == 0) {
                // pushing then popping yields value
                // push then pop -> popped = value
                // but to keep semantics, do not store then remove unnecessarily
                return (1, value);
            }
            // Optimization: if value <= root, then value is the smallest and will be popped immediately
            uint256 r = heap.data[0];
            if (value <= r) {
                return (1, value);
            }
            // otherwise push then pop root
            push(heap, value);
            // pop
            ( , popped) = _set(heap, 0, 0, 1);
            return (1, popped);
        }

        // default: enqueue (mode == 0)
        if (mode == 0) {
            if (maxLength == 0 || len < maxLength) {
                push(heap, value);
                return (1, 0);
            }
            // full: if value > root, replace root
            uint256 r2 = heap.data[0];
            if (value > r2) {
                popped = r2;
                heap.data[0] = value;
                _siftDownStorage(heap.data, 0, len);
                return (3, popped);
            } else {
                return (0, 0);
            }
        }

        return (0, 0);
    }

    /* ============================
       Internal _set (memory)
       ============================ */

    function _set(MemHeap memory heap, uint256 value, uint256 maxLength, uint256 mode) private pure returns (uint256 status, uint256 popped) {
        uint256 len = heap.data.length;

        if (mode == 1) {
            if (len == 0) revert HeapIsEmpty();
            popped = heap.data[0];
            if (len == 1) {
                uint256[] memory emptyArr = new uint256[](0);
                heap.data = emptyArr;
                return (1, popped);
            }
            // create new array with last element moved to root
            uint256[] memory newArr = new uint256[](len - 1);
            for (uint256 i = 0; i < len - 1; i++) {
                newArr[i] = heap.data[i + 1];
            }
            newArr[0] = heap.data[len - 1];
            _siftDownMemory(newArr, 0, len - 1);
            heap.data = newArr;
            return (1, popped);
        }

        if (mode == 2) {
            if (len == 0) revert HeapIsEmpty();
            popped = heap.data[0];
            heap.data[0] = value;
            _siftDownMemory(heap.data, 0, len);
            return (3, popped);
        }

        if (mode == 3) {
            push(heap, value);
            return (1, 0);
        }

        if (mode == 4) {
            if (len == 0) {
                return (1, value);
            }
            uint256 r = heap.data[0];
            if (value <= r) {
                return (1, value);
            }
            push(heap, value);
            ( , popped) = _set(heap, 0, 0, 1);
            return (1, popped);
        }

        // enqueue mode (0)
        if (mode == 0) {
            if (maxLength == 0 || len < maxLength) {
                push(heap, value);
                return (1, 0);
            }
            uint256 r2 = heap.data[0];
            if (value > r2) {
                popped = r2;
                heap.data[0] = value;
                _siftDownMemory(heap.data, 0, len);
                return (3, popped);
            } else {
                return (0, 0);
            }
        }

        return (0, 0);
    }

    /* ============================
       Internal sift helpers (storage)
       ============================ */

    function _siftUpStorage(uint256[] storage arr, uint256 idx) private {
        while (idx > 0) {
            uint256 parent = (idx - 1) / 2;
            if (arr[idx] < arr[parent]) {
                (arr[idx], arr[parent]) = (arr[parent], arr[idx]);
                idx = parent;
            } else {
                break;
            }
        }
    }

    function _siftDownStorage(uint256[] storage arr, uint256 idx, uint256 len) private {
        uint256 i = idx;
        while (true) {
            uint256 left = 2 * i + 1;
            uint256 right = left + 1;
            uint256 smallest = i;
            if (left < len && arr[left] < arr[smallest]) smallest = left;
            if (right < len && arr[right] < arr[smallest]) smallest = right;
            if (smallest == i) break;
            (arr[i], arr[smallest]) = (arr[smallest], arr[i]);
            i = smallest;
        }
    }

    /* ============================
       Internal sift helpers (memory)
       ============================ */

    function _siftUpMemory(uint256[] memory arr, uint256 idx) private pure {
        while (idx > 0) {
            uint256 parent = (idx - 1) / 2;
            if (arr[idx] < arr[parent]) {
                (arr[idx], arr[parent]) = (arr[parent], arr[idx]);
                idx = parent;
            } else {
                break;
            }
        }
    }

    function _siftDownMemory(uint256[] memory arr, uint256 idx, uint256 len) private pure {
        uint256 i = idx;
        while (true) {
            uint256 left = 2 * i + 1;
            uint256 right = left + 1;
            uint256 smallest = i;
            if (left < len && arr[left] < arr[smallest]) smallest = left;
            if (right < len && arr[right] < arr[smallest]) smallest = right;
            if (smallest == i) break;
            (arr[i], arr[smallest]) = (arr[smallest], arr[i]);
            i = smallest;
        }
    }
}