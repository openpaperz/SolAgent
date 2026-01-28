// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library MinHeapLib {
    /// @dev Thrown when an operation that requires a non-empty heap is performed on an empty heap.
    error HeapIsEmpty();

    /**
     * @notice Defines a struct named `Heap` that represents a heap data structure.
     *
     * @dev The `Heap` struct contains a single field:
     * - `data`: An array of `uint256` values representing the elements stored in the heap.
     */
    struct Heap {
        uint256[] data;
    }

    /**
     * @notice Defines a struct named `MemHeap` that represents a memory heap.
     *
     * The struct contains:
     * - `data`: A dynamic array of `uint256` values, representing the heap's data.
     */
    struct MemHeap {
        uint256[] data;
    }

    /**
     * @notice Retrieves the root element of the heap.
     * @dev This function uses low-level assembly to interact with storage directly.
     *      It checks if the heap is empty and reverts with a custom error if it is.
     *      Otherwise, it retrieves and returns the root element of the heap.
     *
     * @param heap The heap storage reference from which to retrieve the root element.
     * @return result The root element of the heap.
     *
     * Steps:
     * 1. Check if the heap is empty by verifying if the slot is zero.
     *    - If the heap is empty, revert with a custom error `HeapIsEmpty()`.
     * 2. If the heap is not empty, compute the storage slot for the root element.
     * 3. Load and return the root element from the computed storage slot.
     */
    function root(Heap storage heap) internal view returns (uint256 result) {
        assembly {
            // Load the length of the storage array `heap.data`.
            mstore(0x00, heap.slot)
            let lenSlot := keccak256(0x00, 0x20)
            let len := sload(lenSlot)
            if iszero(len) {
                // revert HeapIsEmpty()
                mstore(0x00, 0x4e3f8f80) // bytes4(keccak256("HeapIsEmpty()"))
                revert(0x1c, 0x04)
            }
            // First element is at slot = keccak256(slotOfData, 32).
            result := sload(add(lenSlot, 1))
        }
    }

    /**
     * @notice Retrieves the root element of the heap.
     * @dev This function uses low-level assembly to interact with memory directly.
     *      It checks if the heap is empty and reverts with a custom error if it is.
     *      Otherwise, it retrieves and returns the root element of the heap.
     *
     * @param heap The heap memory reference from which to retrieve the root element.
     * @return result The root element of the heap.
     */
    function root(MemHeap memory heap) internal pure returns (uint256 result) {
        uint256[] memory d = heap.data;
        if (d.length == 0) revert HeapIsEmpty();
        assembly {
            // First element of the dynamic array.
            result := mload(add(d, 0x20))
        }
    }

    /**
     * @notice Reserves memory for the heap and ensures it has a minimum capacity.
     *
     * @param heap The memory heap structure to reserve memory for.
     * @param minimum The minimum required capacity for the heap.
     *
     * Steps:
     * 1. Calculate the current capacity of the heap.
     * 2. Check if the current capacity is insufficient for the minimum requirement.
     * 3. If insufficient, allocate new memory with the required capacity.
     * 4. Copy existing data from the old heap to the newly allocated memory.
     * 5. Update the heap's data pointer to point to the new memory location.
     */
    function reserve(MemHeap memory heap, uint256 minimum) internal pure {
        uint256[] memory data = heap.data;
        assembly {
            if iszero(data) {
                // Allocate a new array with length 0 but capacity at least `minimum`.
                let cap := minimum
                if lt(cap, 1) { cap := 1 }
                let size := add(0x20, shl(5, cap))
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, size))
                mstore(ptr, 0)
                heap := heap // silence unused warning
                mstore(add(heap, 0x20), ptr)
            }
        }
        // Simple safe implementation without deep capacity tracking.
        if (data.length < minimum) {
            uint256 len = data.length;
            uint256[] memory newData = new uint256[](minimum);
            for (uint256 i = 0; i < len; ++i) {
                newData[i] = data[i];
            }
            heap.data = newData;
        }
    }

    /**
     * @notice Retrieves the smallest `k` elements from a heap data structure.
     *
     * @dev Builds a temporary heap in memory from storage and extracts the smallest elements.
     *
     * @param heap The heap storage reference from which to retrieve the smallest elements.
     * @param k The number of smallest elements to retrieve.
     * @return a An array containing the smallest `k` elements from the heap.
     */
    function smallest(Heap storage heap, uint256 k) internal view returns (uint256[] memory a) {
        uint256 n = heap.data.length;
        if (k == 0 || n == 0) {
            return new uint256[](0);
        }
        if (k > n) k = n;
        // Build a memory copy and pop k times.
        uint256[] memory m = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            m[i] = heap.data[i];
        }
        MemHeap memory mh = MemHeap(m);
        a = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) {
            a[i] = pop(mh);
        }
    }

    /**
     * @notice Retrieves the smallest `k` elements from a heap data structure.
     *
     * @dev This function uses the given memory heap and repeatedly pops the root.
     *
     * @param heap The heap memory reference from which to retrieve the smallest elements.
     * @param k The number of smallest elements to retrieve.
     * @return a An array containing the smallest `k` elements from the heap.
     */
    function smallest(MemHeap memory heap, uint256 k) internal pure returns (uint256[] memory a) {
        uint256 n = heap.data.length;
        if (k == 0 || n == 0) {
            return new uint256[](0);
        }
        if (k > n) k = n;
        a = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) {
            a[i] = pop(heap);
        }
    }

    /**
     * @notice Returns the length of the heap's data array.
     *
     * @param heap The heap storage reference.
     * @return The length of the heap's data array.
     */
    function length(Heap storage heap) internal view returns (uint256) {
        return heap.data.length;
    }

    /**
     * @notice Returns the length of the heap's data array.
     *
     * @param heap The heap memory reference.
     * @return The length of the heap's data array.
     */
    function length(MemHeap memory heap) internal pure returns (uint256) {
        return heap.data.length;
    }

    /**
     * @notice Pushes a new value into the heap.
     *
     * @param heap The heap storage reference where the value will be pushed.
     * @param value The value to be added to the heap.
     *
     * Steps:
     * 1. Call the internal `_set` function to insert the value into the heap.
     */
    function push(Heap storage heap, uint256 value) internal {
        _set(heap, value, 0, 3);
    }

    /**
     * @notice Pushes a new value into the heap.
     *
     * @param heap The memory heap reference where the value will be pushed.
     * @param value The value to be added to the heap.
     */
    function push(MemHeap memory heap, uint256 value) internal pure {
        _set(heap, value, 0, 3);
    }

    /**
     * @notice Removes and returns the root element from the heap.
     *
     * @param heap The heap storage reference from which the root element is to be removed.
     * @return popped The value of the root element that was removed from the heap.
     */
    function pop(Heap storage heap) internal returns (uint256 popped) {
        (, popped) = _set(heap, 0, 0, 1);
    }

    /**
     * @notice Removes and returns the root element from the heap.
     *
     * @param heap The heap memory reference from which the root element is to be removed.
     * @return popped The value of the root element that was removed from the heap.
     */
    function pop(MemHeap memory heap) internal pure returns (uint256 popped) {
        (, popped) = _set(heap, 0, 0, 1);
    }

    /**
     * @notice Pushes a new value onto the heap and pops the smallest value from the heap.
     *
     * @param heap The heap storage reference where the value is pushed and popped.
     * @param value The value to be pushed onto the heap.
     * @return popped The smallest value that was popped from the heap.
     */
    function pushPop(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 4);
    }

    /**
     * @notice Pushes a new value onto the heap and pops the smallest value from the heap.
     *
     * @param heap The heap memory reference where the value is pushed and popped.
     * @param value The value to be pushed onto the heap.
     * @return popped The smallest value that was popped from the heap.
     */
    function pushPop(MemHeap memory heap, uint256 value) internal pure returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 4);
    }

    /**
     * @notice Replaces the root value of the heap with a new value and returns the old root value.
     *
     * @param heap The heap storage reference where the replacement will occur.
     * @param value The new value to be inserted into the heap.
     * @return popped The old root value that was replaced.
     */
    function replace(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 2);
    }

    /**
     * @notice Replaces the root value of the heap with a new value and returns the old root value.
     *
     * @param heap The heap memory reference where the replacement will occur.
     * @param value The new value to be inserted into the heap.
     * @return popped The old root value that was replaced.
     */
    function replace(MemHeap memory heap, uint256 value) internal pure returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 2);
    }

    /**
     * @notice Enqueues a value into a heap storage structure, ensuring it does not exceed the maximum length.
     *
     * @param heap The heap storage structure where the value will be enqueued.
     * @param value The value to be enqueued into the heap.
     * @param maxLength The maximum allowed length of the heap.
     *
     * @return success A boolean indicating whether the enqueue operation was successful.
     * @return hasPopped A boolean indicating whether an element was popped from the heap during the operation.
     * @return popped The value that was popped from the heap (if any).
     */
    function enqueue(Heap storage heap, uint256 value, uint256 maxLength)
        internal
        returns (bool success, bool hasPopped, uint256 popped)
    {
        (uint256 status, uint256 p) = _set(heap, value, maxLength, 0);
        popped = p;
        hasPopped = (status & 2) != 0;
        success = (status & 1) != 0;
    }

    /**
     * @notice Enqueues a value into a heap memory structure, ensuring it does not exceed the maximum length.
     *
     * @param heap The heap memory structure where the value will be enqueued.
     * @param value The value to be enqueued into the heap.
     * @param maxLength The maximum allowed length of the heap.
     *
     * @return success A boolean indicating whether the enqueue operation was successful.
     * @return hasPopped A boolean indicating whether an element was popped from the heap during the operation.
     * @return popped The value that was popped from the heap (if any).
     */
    function enqueue(MemHeap memory heap, uint256 value, uint256 maxLength)
        internal
        pure
        returns (bool success, bool hasPopped, uint256 popped)
    {
        (uint256 status, uint256 p) = _set(heap, value, maxLength, 0);
        popped = p;
        hasPopped = (status & 2) != 0;
        success = (status & 1) != 0;
    }

    /**
     * @notice Bumps the free memory pointer to allocate memory in Solidity.
     *
     * Steps:
     * 1. Declare a variable `zero` initialized to 0.
     * 2. Use inline assembly to:
     *    a. Load the current free memory pointer (0x40).
     *    b. Store the value of `zero` at the memory location pointed to by the free memory pointer.
     *    c. Update the free memory pointer by adding 0x20 (32 bytes) to the current memory location.
     *
     * This ensures that the free memory pointer is moved forward, preventing memory corruption.
     */
    function bumpFreeMemoryPointer() internal pure {
        uint256 zero = 0;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, zero)
            mstore(0x40, add(ptr, 0x20))
        }
    }

    /**
     * @notice Internal function to manage heap operations such as enqueue, pop, replace, push, and pushPop.
     *
     * @param heap The heap storage reference.
     * @param value The value to be inserted or compared.
     * @param maxLength The maximum allowed length of the heap.
     * @param mode The operation mode:
     *              - 0: Enqueue (adds value to the heap if space is available).
     *              - 1: Pop (removes and returns the root value).
     *              - 2: Replace (replaces the root value with the given value).
     *              - 3: Push (adds value to the heap, ignoring maxLength).
     *              - 4: PushPop (adds value and immediately pops the smallest value).
     *
     * @return status The status of the operation:
     *              bit0 (1): successfully enqueued / operation done.
     *              bit1 (2): an element was popped.
     * @return popped The value removed from the heap during pop or replace operations.
     */
    function _set(Heap storage heap, uint256 value, uint256 maxLength, uint256 mode)
        private
        returns (uint256 status, uint256 popped)
    {
        uint256[] storage data = heap.data;
        uint256 len = data.length;

        if (mode == 1) {
            // Pop
            if (len == 0) revert HeapIsEmpty();
            popped = data[0];
            uint256 last = data[len - 1];
            data.pop();
            len--;
            if (len > 0) {
                data[0] = last;
                _siftDownStorage(data, 0);
            }
            status = 3; // popped
            return (status, popped);
        }

        if (mode == 2) {
            // Replace root
            if (len == 0) revert HeapIsEmpty();
            popped = data[0];
            data[0] = value;
            _siftDownStorage(data, 0);
            status = 3;
            return (status, popped);
        }

        if (mode == 3) {
            // Push ignoring maxLength
            data.push(value);
            _siftUpStorage(data, len);
            status = 1;
            return (status, 0);
        }

        if (mode == 4) {
            // PushPop
            if (len == 0) {
                popped = value;
                return (0, popped);
            }
            if (value <= data[0]) {
                popped = value;
                return (0, popped);
            }
            popped = data[0];
            data[0] = value;
            _siftDownStorage(data, 0);
            status = 3;
            return (status, popped);
        }

        // mode == 0: enqueue with maxLength
        if (len < maxLength) {
            data.push(value);
            _siftUpStorage(data, len);
            status = 1; // enqueued
            return (status, 0);
        }

        if (maxLength == 0) {
            // cannot enqueue anything
            return (0, 0);
        }

        // heap is full; only replace if value is greater than root
        if (len != 0 && value > data[0]) {
            popped = data[0];
            data[0] = value;
            _siftDownStorage(data, 0);
            status = 3; // replaced root, popped one element
        }

        return (status, popped);
    }

    /**
     * @notice Internal function to manage heap operations such as enqueue, pop, replace, push, and pushPop for memory heaps.
     */
    function _set(MemHeap memory heap, uint256 value, uint256 maxLength, uint256 mode)
        private
        pure
        returns (uint256 status, uint256 popped)
    {
        uint256[] memory data = heap.data;
        uint256 len = data.length;

        if (mode == 1) {
            // Pop
            if (len == 0) revert HeapIsEmpty();
            popped = data[0];
            uint256 last = data[len - 1];
            unchecked {
                --len;
            }
            if (len > 0) {
                data[0] = last;
                _siftDownMemory(data, 0, len);
            }
            assembly {
                mstore(data, len)
            }
            status = 3;
            return (status, popped);
        }

        if (mode == 2) {
            // Replace root
            if (len == 0) revert HeapIsEmpty();
            popped = data[0];
            data[0] = value;
            _siftDownMemory(data, 0, len);
            status = 3;
            return (status, popped);
        }

        if (mode == 3) {
            // Push ignoring maxLength
            uint256 newLen = len + 1;
            uint256[] memory nd = new uint256[](newLen);
            for (uint256 i = 0; i < len; ++i) {
                nd[i] = data[i];
            }
            nd[len] = value;
            _siftUpMemory(nd, len);
            heap.data = nd;
            status = 1;
            return (status, 0);
        }

        if (mode == 4) {
            // PushPop
            if (len == 0) {
                popped = value;
                return (0, popped);
            }
            if (value <= data[0]) {
                popped = value;
                return (0, popped);
            }
            popped = data[0];
            data[0] = value;
            _siftDownMemory(data, 0, len);
            status = 3;
            return (status, popped);
        }

        // mode == 0: enqueue with maxLength
        if (len < maxLength) {
            uint256 newLen2 = len + 1;
            uint256[] memory nd2 = new uint256[](newLen2);
            for (uint256 i2 = 0; i2 < len; ++i2) {
                nd2[i2] = data[i2];
            }
            nd2[len] = value;
            _siftUpMemory(nd2, len);
            heap.data = nd2;
            status = 1;
            return (status, 0);
        }

        if (maxLength == 0) {
            return (0, 0);
        }

        if (len != 0 && value > data[0]) {
            popped = data[0];
            data[0] = value;
            _siftDownMemory(data, 0, len);
            status = 3;
        }

        return (status, popped);
    }

    // ------- Internal heap helpers for storage -------

    function _siftUpStorage(uint256[] storage data, uint256 idx) private {
        while (idx > 0) {
            uint256 parent = (idx - 1) >> 1;
            if (data[idx] >= data[parent]) break;
            (data[idx], data[parent]) = (data[parent], data[idx]);
            idx = parent;
        }
    }

    function _siftDownStorage(uint256[] storage data, uint256 idx) private {
        uint256 len = data.length;
        while (true) {
            uint256 left = (idx << 1) + 1;
            if (left >= len) break;
            uint256 right = left + 1;
            uint256 smallest = left;
            if (right < len && data[right] < data[left]) {
                smallest = right;
            }
            if (data[idx] <= data[smallest]) break;
            (data[idx], data[smallest]) = (data[smallest], data[idx]);
            idx = smallest;
        }
    }

    // ------- Internal heap helpers for memory -------

    function _siftUpMemory(uint256[] memory data, uint256 idx) private pure {
        while (idx > 0) {
            uint256 parent = (idx - 1) >> 1;
            if (data[idx] >= data[parent]) break;
            (data[idx], data[parent]) = (data[parent], data[idx]);
            idx = parent;
        }
    }

    function _siftDownMemory(uint256[] memory data, uint256 idx, uint256 len) private pure {
        while (true) {
            uint256 left = (idx << 1) + 1;
            if (left >= len) break;
            uint256 right = left + 1;
            uint256 smallest = left;
            if (right < len && data[right] < data[left]) {
                smallest = right;
            }
            if (data[idx] <= data[smallest]) break;
            (data[idx], data[smallest]) = (data[smallest], data[idx]);
            idx = smallest;
        }
    }
}