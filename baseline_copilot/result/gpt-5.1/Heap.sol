// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Heap {
    /**
     * @notice Defines a data structure for a heap of uint256 values.
     *
     * The `Uint256Heap` struct contains a dynamic array `tree` that represents the heap.
     * This structure can be used to implement a priority queue or other heap-based algorithms.
     */
    struct Uint256Heap {
        uint256[] tree;
    }

    /**
     * @notice Returns the smallest element in the heap without removing it.
     *
     * @dev This function accesses the first element of the heap's underlying array (`self.tree[0]`),
     * which represents the smallest element in a min-heap. If the heap is empty, accessing `self.tree[0]`
     * will result in an `ARRAY_ACCESS_OUT_OF_BOUNDS` panic.
     *
     * @param self The heap storage reference.
     * @return The smallest element in the heap.
     */
    function peek(Uint256Heap storage self) internal view returns (uint256) {
        return self.tree[0];
    }

    /**
     * @notice Removes and returns the root element from a heap, then re-heapifies the structure.
     *
     * @param self The heap storage reference.
     * @return The value of the root element that was removed.
     *
     * Steps:
     * 1. Check the size of the heap. If it is empty, revert with a panic error (EMPTY_ARRAY_POP).
     * 2. Cache the value of the root element and the last element in the heap.
     * 3. Swap the last element with the root element and shrink the heap by removing the last element.
     * 4. Re-heapify the heap by sifting down the new root element to maintain the heap property.
     * 5. Return the original root value.
     *
     * @dev This function uses unchecked arithmetic for gas optimization.
     */
    function pop(Uint256Heap storage self) internal returns (uint256) {
        return pop(self, _defaultComparator);
    }

    /**
     * @notice Removes and returns the root element from a heap, then re-heapifies the structure.
     *
     * @param self The heap storage reference.
     * @param comp The comparison function used to maintain heap order.
     * @return The value of the root element that was removed.
     *
     * Steps:
     * 1. Check the size of the heap. If it is empty, revert with a panic error (EMPTY_ARRAY_POP).
     * 2. Cache the value of the root element and the last element in the heap.
     * 3. Swap the last element with the root element and shrink the heap by removing the last element.
     * 4. Re-heapify the heap by sifting down the new root element to maintain the heap property.
     * 5. Return the original root value.
     *
     * @dev This function uses unchecked arithmetic for gas optimization.
     */
    function pop(
        Uint256Heap storage self,
        function(uint256, uint256) view returns (bool) comp
    ) internal returns (uint256) {
        uint256 size = self.tree.length;
        // If size == 0, this will underflow and revert with a panic (EMPTY_ARRAY_POP),
        // matching the documented behavior.
        unchecked {
            size--;
        }

        uint256 root = self.tree[0];

        if (size > 0) {
            uint256 last = self.tree[size];
            self.tree.pop();
            // Place last at root and sift it down.
            self.tree[0] = last;
            _siftDown(self, size, 0, last, comp);
        } else {
            // Only one element, just pop it.
            self.tree.pop();
        }

        return root;
    }

    /**
     * @notice Inserts a new value into the heap and maintains the heap property.
     *
     * @param self The storage reference to the heap.
     * @param value The value to be inserted into the heap.
     *
     * Steps:
     * 1. Retrieve the current size of the heap.
     * 2. Push the new value onto the heap.
     * 3. Re-heapify the heap by sifting up the newly inserted value to maintain the heap property.
     */
    function insert(Uint256Heap storage self, uint256 value) internal {
        insert(self, value, _defaultComparator);
    }

    /**
     * @notice Inserts a new value into the heap and maintains the heap property.
     *
     * @param self The storage reference to the heap.
     * @param value The value to be inserted into the heap.
     * @param comp A comparison function used to determine the order of elements in the heap.
     *
     * Steps:
     * 1. Retrieve the current size of the heap.
     * 2. Push the new value onto the heap.
     * 3. Re-heapify the heap by sifting up the newly inserted value to maintain the heap property.
     */
    function insert(
        Uint256Heap storage self,
        uint256 value,
        function(uint256, uint256) view returns (bool) comp
    ) internal {
        uint256 index = self.tree.length;
        self.tree.push(value);
        if (index > 0) {
            _siftUp(self, index, value, comp);
        }
    }

    /**
     * @notice Replaces a value in the Uint256Heap with a new value using the default comparator (less than).
     * @param self The heap storage reference.
     * @param newValue The new value to replace the existing value.
     * @return The replaced value.
     */
    function replace(
        Uint256Heap storage self,
        uint256 newValue
    ) internal returns (uint256) {
        return replace(self, newValue, _defaultComparator);
    }

    /**
     * @notice Replaces a value in the Uint256Heap with a new value using a custom comparator.
     * @param self The heap storage reference.
     * @param newValue The new value to replace the existing value.
     * @param comp The comparison function defining the heap order.
     * @return The replaced value.
     */
    function replace(
        Uint256Heap storage self,
        uint256 newValue,
        function(uint256, uint256) view returns (bool) comp
    ) internal returns (uint256) {
        // Reuse the documented behavior of replacing the root.
        uint256 oldValue = self.tree[0];
        self.tree[0] = newValue;

        uint256 size = self.tree.length;
        if (size > 1) {
            // Determine whether to sift up or down based on comparator.
            // If newValue should come before its parent, sift up.
            uint256 index = 0;
            if (size > 1) {
                // Try sifting down first as it's more common for replacement at root.
                _siftDown(self, size, index, newValue, comp);
            }
        }

        return oldValue;
    }

    /**
     * @notice Returns the number of elements in the Uint256Heap.
     *
     * @param self The Uint256Heap storage reference.
     * @return uint256 The length of the heap's underlying tree structure.
     *
     * Steps:
     * 1. Access the `length` property of the `tree` array within the `self` Uint256Heap.
     * 2. Return the length as a uint256 value.
     */
    function length(Uint256Heap storage self) internal view returns (uint256) {
        return self.tree.length;
    }

    /**
     * @notice Clears the contents of a Uint256Heap storage.
     * 
     * Steps:
     * 1. Sets the length of the underlying tree array to 0, effectively clearing it.
     */
    function clear(Uint256Heap storage self) internal {
        delete self.tree;
    }

    /**
     * @notice Swaps the values of two nodes in a Uint256Heap.
     *
     * Steps:
     * 1. Access the storage slots for the nodes at indices `i` and `j`.
     * 2. Swap the values of the two nodes.
     */
    function _swap(
        Uint256Heap storage self,
        uint256 i,
        uint256 j
    ) private {
        uint256 tmp = self.tree[i];
        self.tree[i] = self.tree[j];
        self.tree[j] = tmp;
    }

    /**
     * @notice Sifts down a value in a heap to maintain the heap property.
     *
     * Steps:
     * 1. Check if the current index is at risk of overflow when computing child indices. If so, sifting is done.
     * 2. Compute the indices of the left and right child nodes.
     * 3. Handle three cases:
     *    a. Both children exist: Continue sifting on the branch with the appropriate child based on the comparison function.
     *    b. Only the left child exists: Continue sifting on the left branch if necessary.
     *    c. Neither child exists: Sifting is complete.
     * 4. If sifting continues, swap the current node with the appropriate child and recursively call `_siftDown`.
     *
     * @param self The heap storage reference.
     * @param size The size of the heap.
     * @param index The current index to sift down from.
     * @param value The value to sift down.
     * @param comp The comparison function used to determine the heap order.
     */
    function _siftDown(
        Uint256Heap storage self,
        uint256 size,
        uint256 index,
        uint256 value,
        function(uint256, uint256) view returns (bool) comp
    ) private {
        while (true) {
            // Left child index = 2 * index + 1
            uint256 left = 2 * index + 1;
            if (left >= size) {
                // No children, done.
                break;
            }

            uint256 right = left + 1;
            uint256 bestChild = left;
            uint256 bestValue = self.tree[left];

            if (right < size) {
                uint256 rightValue = self.tree[right];
                if (comp(rightValue, bestValue)) {
                    bestChild = right;
                    bestValue = rightValue;
                }
            }

            // If the chosen child does not need to come before value, we're done.
            if (!comp(bestValue, value)) {
                break;
            }

            // Move child value up.
            self.tree[index] = bestValue;
            index = bestChild;
        }

        self.tree[index] = value;
    }

    /**
     * @notice Sifts up a value in a heap to maintain the heap property.
     *
     * Steps:
     * 1. Check if the index is greater than 0 (i.e., not the root).
     * 2. Calculate the parent index of the current index.
     * 3. Retrieve the parent value from the heap.
     * 4. If the parent value satisfies the comparison condition, break the loop.
     * 5. Otherwise, swap the current value with the parent value.
     * 6. Update the index to the parent index and repeat the process.
     *
     * @param self The heap storage reference.
     * @param index The index of the value to sift up.
     * @param value The value to sift up.
     * @param comp The comparison function to determine the heap property.
     */
    function _siftUp(
        Uint256Heap storage self,
        uint256 index,
        uint256 value,
        function(uint256, uint256) view returns (bool) comp
    ) private {
        while (index > 0) {
            uint256 parent = (index - 1) / 2;
            uint256 parentValue = self.tree[parent];

            // If parent is already before value according to comparator, stop.
            if (!comp(value, parentValue)) {
                break;
            }

            // Move parent down.
            self.tree[index] = parentValue;
            index = parent;
        }

        self.tree[index] = value;
    }

    /**
     * @dev Default comparator for a min-heap: returns true if `a` should come before `b`.
     */
    function _defaultComparator(uint256 a, uint256 b) private pure returns (bool) {
        return a < b;
    }
}