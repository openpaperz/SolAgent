// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Minimal library for heap operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/MinHeapLib.sol)
library MinHeapLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The heap is empty.
    error HeapIsEmpty();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Defines a struct named `Heap` that represents a heap data structure.
    ///
    /// @dev The `Heap` struct contains a single field:
    /// - `data`: An array of `uint256` values representing the elements stored in the heap.
    struct Heap {
        uint256[] data;
    }

    /// @notice Defines a struct named `MemHeap` that represents a memory heap.
    /// 
    /// The struct contains:
    /// - `data`: A dynamic array of `uint256` values, representing the heap's data.
    struct MemHeap {
        uint256[] data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      HEAP OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Retrieves the root element of the heap.
    /// @dev This function uses low-level assembly to interact with storage directly.
    ///      It checks if the heap is empty and reverts with a custom error if it is.
    ///      Otherwise, it retrieves and returns the root element of the heap.
    ///
    /// @param heap The heap storage reference from which to retrieve the root element.
    /// @return result The root element of the heap.
    ///
    /// Steps:
    /// 1. Check if the heap is empty by verifying if the slot is zero.
    ///    - If the heap is empty, revert with a custom error `HeapIsEmpty()`.
    /// 2. If the heap is not empty, compute the storage slot for the root element.
    /// 3. Load and return the root element from the computed storage slot.
    function root(Heap storage heap) internal view returns (uint256 result) {
        assembly {
            let slot := sload(heap.slot)
            if iszero(slot) {
                mstore(0x00, 0xd0163c9d) // `HeapIsEmpty()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, heap.slot)
            result := sload(keccak256(0x00, 0x20))
        }
    }

    /// @notice Retrieves the root element of the heap.
    /// @dev This function uses low-level assembly to interact with storage directly.
    ///      It checks if the heap is empty and reverts with a custom error if it is.
    ///      Otherwise, it retrieves and returns the root element of the heap.
    ///
    /// @param heap The heap storage reference from which to retrieve the root element.
    /// @return result The root element of the heap.
    ///
    /// Steps:
    /// 1. Check if the heap is empty by verifying if the slot is zero.
    ///    - If the heap is empty, revert with a custom error `HeapIsEmpty()`.
    /// 2. If the heap is not empty, compute the storage slot for the root element.
    /// 3. Load and return the root element from the computed storage slot.
    function root(MemHeap memory heap) internal pure returns (uint256 result) {
        assembly {
            let data := mload(heap)
            let length := mload(data)
            if iszero(length) {
                mstore(0x00, 0xd0163c9d) // `HeapIsEmpty()`.
                revert(0x1c, 0x04)
            }
            result := mload(add(data, 0x20))
        }
    }

    /// @notice Reserves memory for the heap and ensures it has a minimum capacity.
    /// 
    /// @param heap The memory heap structure to reserve memory for.
    /// @param minimum The minimum required capacity for the heap.
    ///
    /// Steps:
    /// 1. Calculate the current capacity of the heap.
    /// 2. Check if the current capacity is insufficient for the minimum requirement.
    /// 3. If insufficient, allocate new memory with the required capacity.
    /// 4. Copy existing data from the old heap to the newly allocated memory.
    /// 5. Update the heap's data pointer to point to the new memory location.
    ///
    /// Assembly Details:
    /// - Uses low-level assembly for memory manipulation.
    /// - Ensures memory safety by rounding up to the nearest multiple of 32.
    /// - Uses a prime number for capacity calculations to avoid collisions.
    /// - Copies data from the old heap to the new heap if data exists.
    function reserve(MemHeap memory heap, uint256 minimum) internal pure {
        assembly {
            let data := mload(heap)
            let capacity := mload(sub(data, 0x20))
            let length := mload(data)
            if lt(capacity, minimum) {
                let newCapacity := minimum
                if lt(newCapacity, add(capacity, shr(1, capacity))) {
                    newCapacity := add(capacity, shr(1, capacity))
                }
                newCapacity := add(shl(5, newCapacity), 0x61)
                let newData := mload(0x40)
                mstore(0x40, add(newData, newCapacity))
                mstore(add(newData, 0x40), mload(heap))
                mstore(newData, shr(5, sub(newCapacity, 0x61)))
                mstore(add(newData, 0x20), length)
                for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                    mstore(add(add(newData, 0x40), shl(5, i)), mload(add(add(data, 0x20), shl(5, i))))
                }
                mstore(heap, add(newData, 0x20))
            }
        }
    }

    /// @notice Retrieves the smallest `k` elements from a heap data structure.
    ///
    /// @dev This function uses inline assembly to efficiently manipulate the heap and retrieve the smallest elements.
    /// It implements a priority queue to manage the heap and uses sift-up and sift-down operations to maintain the heap property.
    ///
    /// @param heap The heap storage reference from which to retrieve the smallest elements.
    /// @param k The number of smallest elements to retrieve.
    /// @return a An array containing the smallest `k` elements from the heap.
    ///
    /// Steps:
    /// 1. Define helper functions for heap operations:
    ///    - `pIndex`: Retrieves the index of a heap element.
    ///    - `pValue`: Retrieves the value of a heap element.
    ///    - `pSet`: Sets the value and index of a heap element.
    ///    - `pSiftdown`: Performs a sift-down operation to maintain the heap property.
    ///    - `pSiftup`: Performs a sift-up operation to maintain the heap property.
    ///
    /// 2. Initialize memory for the result array `a`.
    /// 3. Calculate the storage offset for the heap.
    /// 4. Determine the number of elements to retrieve (`m`), which is the minimum of `k` and the heap size.
    /// 5. Initialize a priority queue (`h`) to manage the heap elements.
    /// 6. Store the root element of the heap in the priority queue.
    /// 7. Iterate through the heap:
    ///    - Extract the smallest element from the priority queue and store it in the result array.
    ///    - Update the priority queue by sifting up or down based on the heap structure.
    /// 8. Store the length of the result array and allocate memory for it.
    function smallest(Heap storage heap, uint256 k) internal view returns (uint256[] memory a) {
        assembly {
            function pIndex(p) -> r { r := shr(128, mload(p)) }
            function pValue(p) -> r { r := and(mload(p), 0xffffffffffffffffffffffffffffffff) }
            function pSet(p, index, value) { mstore(p, or(shl(128, index), value)) }
            function pSiftdown(h, offset, n, i) {
                for {} 1 {} {
                    let l := add(add(i, i), 1)
                    if iszero(lt(l, n)) { break }
                    let r := add(l, 1)
                    let minChild := l
                    if lt(r, n) {
                        if lt(pValue(add(h, shl(5, r))), pValue(add(h, shl(5, l)))) {
                            minChild := r
                        }
                    }
                    let childPtr := add(h, shl(5, minChild))
                    let iPtr := add(h, shl(5, i))
                    if iszero(lt(pValue(childPtr), pValue(iPtr))) { break }
                    let temp := mload(iPtr)
                    mstore(iPtr, mload(childPtr))
                    mstore(childPtr, temp)
                    i := minChild
                }
            }
            function pSiftup(h, i) {
                for {} gt(i, 0) {} {
                    let parent := shr(1, sub(i, 1))
                    let parentPtr := add(h, shl(5, parent))
                    let iPtr := add(h, shl(5, i))
                    if iszero(lt(pValue(iPtr), pValue(parentPtr))) { break }
                    let temp := mload(iPtr)
                    mstore(iPtr, mload(parentPtr))
                    mstore(parentPtr, temp)
                    i := parent
                }
            }

            mstore(0x00, heap.slot)
            let offset := keccak256(0x00, 0x20)
            let n := sload(heap.slot)
            let m := k
            if lt(n, m) { m := n }
            a := mload(0x40)
            let h := add(a, 0x20)
            mstore(0x40, add(h, shl(5, add(m, 1))))
            if iszero(n) {
                mstore(a, 0)
                leave
            }
            pSet(h, 0, sload(offset))
            let hLen := 1
            for { let j := 0 } lt(j, m) { j := add(j, 1) } {
                let minPtr := h
                let minIdx := pIndex(minPtr)
                let minValue := pValue(minPtr)
                mstore(add(a, add(0x20, shl(5, j))), minValue)
                let l := add(add(minIdx, minIdx), 1)
                let r := add(l, 1)
                let shouldPushL := lt(l, n)
                let shouldPushR := lt(r, n)
                if shouldPushL {
                    pSet(minPtr, l, sload(add(offset, l)))
                    pSiftdown(h, offset, hLen, 0)
                    if shouldPushR {
                        pSet(add(h, shl(5, hLen)), r, sload(add(offset, r)))
                        pSiftup(h, hLen)
                        hLen := add(hLen, 1)
                    }
                }
                if and(iszero(shouldPushL), iszero(shouldPushR)) {
                    mstore(minPtr, mload(add(h, shl(5, sub(hLen, 1)))))
                    hLen := sub(hLen, 1)
                    if gt(hLen, 0) { pSiftdown(h, offset, hLen, 0) }
                }
            }
            mstore(a, m)
        }
    }

    /// @notice Retrieves the smallest `k` elements from a heap data structure.
    ///
    /// @dev This function uses inline assembly to efficiently manipulate the heap and retrieve the smallest elements.
    /// It implements a priority queue to manage the heap and uses sift-up and sift-down operations to maintain the heap property.
    ///
    /// @param heap The heap storage reference from which to retrieve the smallest elements.
    /// @param k The number of smallest elements to retrieve.
    /// @return a An array containing the smallest `k` elements from the heap.
    ///
    /// Steps:
    /// 1. Define helper functions for heap operations:
    ///    - `pIndex`: Retrieves the index of a heap element.
    ///    - `pValue`: Retrieves the value of a heap element.
    ///    - `pSet`: Sets the value and index of a heap element.
    ///    - `pSiftdown`: Performs a sift-down operation to maintain the heap property.
    ///    - `pSiftup`: Performs a sift-up operation to maintain the heap property.
    ///
    /// 2. Initialize memory for the result array `a`.
    /// 3. Calculate the storage offset for the heap.
    /// 4. Determine the number of elements to retrieve (`m`), which is the minimum of `k` and the heap size.
    /// 5. Initialize a priority queue (`h`) to manage the heap elements.
    /// 6. Store the root element of the heap in the priority queue.
    /// 7. Iterate through the heap:
    ///    - Extract the smallest element from the priority queue and store it in the result array.
    ///    - Update the priority queue by sifting up or down based on the heap structure.
    /// 8. Store the length of the result array and allocate memory for it.
    function smallest(MemHeap memory heap, uint256 k) internal pure returns (uint256[] memory a) {
        assembly {
            function pIndex(p) -> r { r := shr(128, mload(p)) }
            function pValue(p) -> r { r := and(mload(p), 0xffffffffffffffffffffffffffffffff) }
            function pSet(p, index, value) { mstore(p, or(shl(128, index), value)) }
            function pSiftdown(h, dataPtr, n, i) {
                for {} 1 {} {
                    let l := add(add(i, i), 1)
                    if iszero(lt(l, n)) { break }
                    let r := add(l, 1)
                    let minChild := l
                    if lt(r, n) {
                        if lt(pValue(add(h, shl(5, r))), pValue(add(h, shl(5, l)))) {
                            minChild := r
                        }
                    }
                    let childPtr := add(h, shl(5, minChild))
                    let iPtr := add(h, shl(5, i))
                    if iszero(lt(pValue(childPtr), pValue(iPtr))) { break }
                    let temp := mload(iPtr)
                    mstore(iPtr, mload(childPtr))
                    mstore(childPtr, temp)
                    i := minChild
                }
            }
            function pSiftup(h, i) {
                for {} gt(i, 0) {} {
                    let parent := shr(1, sub(i, 1))
                    let parentPtr := add(h, shl(5, parent))
                    let iPtr := add(h, shl(5, i))
                    if iszero(lt(pValue(iPtr), pValue(parentPtr))) { break }
                    let temp := mload(iPtr)
                    mstore(iPtr, mload(parentPtr))
                    mstore(parentPtr, temp)
                    i := parent
                }
            }

            let data := mload(heap)
            let n := mload(data)
            let m := k
            if lt(n, m) { m := n }
            a := mload(0x40)
            let h := add(a, 0x20)
            mstore(0x40, add(h, shl(5, add(m, 1))))
            if iszero(n) {
                mstore(a, 0)
                leave
            }
            let dataPtr := add(data, 0x20)
            pSet(h, 0, mload(dataPtr))
            let hLen := 1
            for { let j := 0 } lt(j, m) { j := add(j, 1) } {
                let minPtr := h
                let minIdx := pIndex(minPtr)
                let minValue := pValue(minPtr)
                mstore(add(a, add(0x20, shl(5, j))), minValue)
                let l := add(add(minIdx, minIdx), 1)
                let r := add(l, 1)
                let shouldPushL := lt(l, n)
                let shouldPushR := lt(r, n)
                if shouldPushL {
                    pSet(minPtr, l, mload(add(dataPtr, shl(5, l))))
                    pSiftdown(h, dataPtr, hLen, 0)
                    if shouldPushR {
                        pSet(add(h, shl(5, hLen)), r, mload(add(dataPtr, shl(5, r))))
                        pSiftup(h, hLen)
                        hLen := add(hLen, 1)
                    }
                }
                if and(iszero(shouldPushL), iszero(shouldPushR)) {
                    mstore(minPtr, mload(add(h, shl(5, sub(hLen, 1)))))
                    hLen := sub(hLen, 1)
                    if gt(hLen, 0) { pSiftdown(h, dataPtr, hLen, 0) }
                }
            }
            mstore(a, m)
        }
    }

    /// @notice Returns the length of the heap's data array.
    ///
    /// @param heap The heap storage reference.
    /// @return The length of the heap's data array.
    function length(Heap storage heap) internal view returns (uint256) {
        return heap.data.length;
    }

    /// @notice Returns the length of the heap's data array.
    ///
    /// @param heap The heap storage reference.
    /// @return The length of the heap's data array.
    function length(MemHeap memory heap) internal pure returns (uint256) {
        return heap.data.length;
    }

    /// @notice Pushes a new value into the heap.
    ///
    /// @param heap The heap storage reference where the value will be pushed.
    /// @param value The value to be added to the heap.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function to insert the value into the heap.
    ///   - The `_set` function is called with the heap, the value, and two additional parameters (0 and 3).
    ///   - The exact behavior of `_set` depends on its implementation, but it likely handles the insertion logic.
    function push(Heap storage heap, uint256 value) internal {
        _set(heap, value, 0, 3);
    }

    /// @notice Pushes a new value into the heap.
    ///
    /// @param heap The heap storage reference where the value will be pushed.
    /// @param value The value to be added to the heap.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function to insert the value into the heap.
    ///   - The `_set` function is called with the heap, the value, and two additional parameters (0 and 3).
    ///   - The exact behavior of `_set` depends on its implementation, but it likely handles the insertion logic.
    function push(MemHeap memory heap, uint256 value) internal pure {
        _set(heap, value, 0, 3);
    }

    /// @notice Removes and returns the root element from the heap.
    ///
    /// @dev This function internally calls `_set` to remove the root element and reorganize the heap.
    /// The `_set` function is used with parameters to indicate that the root element should be removed.
    ///
    /// @param heap The heap storage reference from which the root element is to be removed.
    /// @return popped The value of the root element that was removed from the heap.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function with the heap, index 0, value 0, and flag 2.
    /// 2. The `_set` function removes the root element and returns the popped value.
    /// 3. Return the popped value to the caller.
    function pop(Heap storage heap) internal returns (uint256 popped) {
        (, popped) = _set(heap, 0, 0, 1);
    }

    /// @notice Removes and returns the root element from the heap.
    ///
    /// @dev This function internally calls `_set` to remove the root element and reorganize the heap.
    /// The `_set` function is used with parameters to indicate that the root element should be removed.
    ///
    /// @param heap The heap storage reference from which the root element is to be removed.
    /// @return popped The value of the root element that was removed from the heap.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function with the heap, index 0, value 0, and flag 2.
    /// 2. The `_set` function removes the root element and returns the popped value.
    /// 3. Return the popped value to the caller.
    function pop(MemHeap memory heap) internal pure returns (uint256 popped) {
        (, popped) = _set(heap, 0, 0, 1);
    }

    /// @notice Pushes a new value onto the heap and pops the smallest value from the heap.
    ///
    /// @param heap The heap storage reference where the value is pushed and popped.
    /// @param value The value to be pushed onto the heap.
    /// @return popped The smallest value that was popped from the heap.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function with the provided heap, value, and specific parameters (0 and 4).
    /// 2. The `_set` function handles the push and pop operations.
    /// 3. Return the smallest value that was popped from the heap.
    function pushPop(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 4);
    }

    /// @notice Pushes a new value onto the heap and pops the smallest value from the heap.
    ///
    /// @param heap The heap storage reference where the value is pushed and popped.
    /// @param value The value to be pushed onto the heap.
    /// @return popped The smallest value that was popped from the heap.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function with the provided heap, value, and specific parameters (0 and 4).
    /// 2. The `_set` function handles the push and pop operations.
    /// 3. Return the smallest value that was popped from the heap.
    function pushPop(MemHeap memory heap, uint256 value) internal pure returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 4);
    }

    /// @notice Replaces the root value of the heap with a new value and returns the old root value.
    ///
    /// @param heap The heap storage reference where the replacement will occur.
    /// @param value The new value to be inserted into the heap.
    /// @return popped The old root value that was replaced.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function to replace the root value with the new value.
    /// 2. The `_set` function returns the old root value, which is then returned by this function.
    function replace(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 2);
    }

    /// @notice Replaces the root value of the heap with a new value and returns the old root value.
    ///
    /// @param heap The heap storage reference where the replacement will occur.
    /// @param value The new value to be inserted into the heap.
    /// @return popped The old root value that was replaced.
    ///
    /// Steps:
    /// 1. Call the internal `_set` function to replace the root value with the new value.
    /// 2. The `_set` function returns the old root value, which is then returned by this function.
    function replace(MemHeap memory heap, uint256 value) internal pure returns (uint256 popped) {
        (, popped) = _set(heap, value, 0, 2);
    }

    /// @notice Enqueues a value into a heap storage structure, ensuring it does not exceed the maximum length.
    ///
    /// @param heap The heap storage structure where the value will be enqueued.
    /// @param value The value to be enqueued into the heap.
    /// @param maxLength The maximum allowed length of the heap.
    ///
    /// @return success A boolean indicating whether the enqueue operation was successful.
    /// @return hasPopped A boolean indicating whether an element was popped from the heap during the operation.
    /// @return popped The value that was popped from the heap (if any).
    ///
    /// Steps:
    /// 1. Call the internal `_set` function to handle the insertion of the value into the heap, ensuring it does not exceed the maximum length.
    /// 2. Use inline assembly to check if an element was popped (`hasPopped`) and whether the operation was successful (`success`).
    /// 3. Return the results of the operation, including whether an element was popped and its value.
    function enqueue(Heap storage heap, uint256 value, uint256 maxLength)
        internal
        returns (bool success, bool hasPopped, uint256 popped)
    {
        uint256 status;
        (status, popped) = _set(heap, value, maxLength, 0);
        assembly {
            success := and(status, 1)
            hasPopped := and(shr(1, status), 1)
        }
    }

    /// @notice Enqueues a value into a heap storage structure, ensuring it does not exceed the maximum length.
    ///
    /// @param heap The heap storage structure where the value will be enqueued.
    /// @param value The value to be enqueued into the heap.
    /// @param maxLength The maximum allowed length of the heap.
    ///
    /// @return success A boolean indicating whether the enqueue operation was successful.
    /// @return hasPopped A boolean indicating whether an element was popped from the heap during the operation.
    /// @return popped The value that was popped from the heap (if any).
    ///
    /// Steps:
    /// 1. Call the internal `_set` function to handle the insertion of the value into the heap, ensuring it does not exceed the maximum length.
    /// 2. Use inline assembly to check if an element was popped (`hasPopped`) and whether the operation was successful (`success`).
    /// 3. Return the results of the operation, including whether an element was popped and its value.
    function enqueue(MemHeap memory heap, uint256 value, uint256 maxLength)
        internal
        pure
        returns (bool success, bool hasPopped, uint256 popped)
    {
        uint256 status;
        (status, popped) = _set(heap, value, maxLength, 0);
        assembly {
            success := and(status, 1)
            hasPopped := and(shr(1, status), 1)
        }
    }

    /// @notice Bumps the free memory pointer to allocate memory in Solidity.
    ///
    /// Steps:
    /// 1. Declare a variable `zero` initialized to 0.
    /// 2. Use inline assembly to:
    ///    a. Load the current free memory pointer (0x40).
    ///    b. Store the value of `zero` at the memory location pointed to by the free memory pointer.
    ///    c. Update the free memory pointer by adding 0x20 (32 bytes) to the current memory location.
    ///
    /// This ensures that the free memory pointer is moved forward, preventing memory corruption.
    function bumpFreeMemoryPointer() internal pure {
        uint256 zero;
        assembly {
            let m := mload(0x40)
            mstore(m, zero)
            mstore(0x40, add(m, 0x20))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Internal function to manage heap operations such as enqueue, pop, replace, push, and pushPop.
    /// 
    /// @param heap The heap storage reference.
    /// @param value The value to be inserted or compared.
    /// @param maxLength The maximum allowed length of the heap.
    /// @param mode The operation mode:
    ///              - 0: Enqueue (adds value to the heap if space is available).
    ///              - 1: Pop (removes and returns the root value).
    ///              - 2: Replace (replaces the root value with the given value).
    ///              - 3: Push (adds value to the heap, ignoring maxLength).
    ///              - 4: PushPop (adds value and immediately pops the smallest value).
    ///
    /// @return status The status of the operation:
    ///              - 1: Successfully enqueued.
    ///              - 3: Replaced the root value.
    ///              - Other: Operation-specific status.
    /// @return popped The value removed from the heap during pop or replace operations.
    ///
    /// Steps:
    /// 1. Load the current length of the heap.
    /// 2. Calculate the storage slot offset for the heap array.
    /// 3. Perform operations based on the specified mode:
    ///    - Enqueue: Add value if space is available, otherwise replace the smallest value.
    ///    - Pop: Remove and return the root value.
    ///    - Replace: Replace the root value with the given value.
    ///    - Push: Add value to the heap, ignoring maxLength.
    ///    - PushPop: Add value and immediately pop the smallest value.
    /// 4. Perform sift-up and sift-down operations to maintain heap properties.
    /// 5. Update the heap storage with the new value and return the operation status and popped value.
    function _set(Heap storage heap, uint256 value, uint256 maxLength, uint256 mode)
        private
        returns (uint256 status, uint256 popped)
    {
        assembly {
            function siftUp(offset, i) {
                for {} gt(i, 0) {} {
                    let p := shr(1, sub(i, 1))
                    let pSlot := add(offset, p)
                    let iSlot := add(offset, i)
                    let pValue := sload(pSlot)
                    let iValue := sload(iSlot)
                    if iszero(gt(pValue, iValue)) { break }
                    sstore(pSlot, iValue)
                    sstore(iSlot, pValue)
                    i := p
                }
            }
            function siftDown(offset, n, i) {
                for {} 1 {} {
                    let l := add(shl(1, i), 1)
                    if iszero(lt(l, n)) { break }
                    let r := add(l, 1)
                    let minChild := l
                    if and(lt(r, n), lt(sload(add(offset, r)), sload(add(offset, l)))) {
                        minChild := r
                    }
                    let iSlot := add(offset, i)
                    let minSlot := add(offset, minChild)
                    let iValue := sload(iSlot)
                    let minValue := sload(minSlot)
                    if iszero(gt(iValue, minValue)) { break }
                    sstore(iSlot, minValue)
                    sstore(minSlot, iValue)
                    i := minChild
                }
            }

            let n := sload(heap.slot)
            mstore(0x00, heap.slot)
            let offset := keccak256(0x00, 0x20)

            switch mode
            case 0 {
                // Enqueue
                if lt(n, maxLength) {
                    sstore(add(offset, n), value)
                    siftUp(offset, n)
                    sstore(heap.slot, add(n, 1))
                    status := 1
                    leave
                }
                if iszero(n) { leave }
                let rootValue := sload(offset)
                if lt(value, rootValue) { leave }
                popped := rootValue
                sstore(offset, value)
                siftDown(offset, n, 0)
                status := 3
            }
            case 1 {
                // Pop
                if iszero(n) {
                    mstore(0x00, 0xd0163c9d) // `HeapIsEmpty()`.
                    revert(0x1c, 0x04)
                }
                popped := sload(offset)
                let newN := sub(n, 1)
                if gt(newN, 0) {
                    sstore(offset, sload(add(offset, newN)))
                    siftDown(offset, newN, 0)
                }
                sstore(heap.slot, newN)
            }
            case 2 {
                // Replace
                if iszero(n) {
                    mstore(0x00, 0xd0163c9d) // `HeapIsEmpty()`.
                    revert(0x1c, 0x04)
                }
                popped := sload(offset)
                sstore(offset, value)
                siftDown(offset, n, 0)
            }
            case 3 {
                // Push
                sstore(add(offset, n), value)
                siftUp(offset, n)
                sstore(heap.slot, add(n, 1))
            }
            case 4 {
                // PushPop
                if iszero(n) {
                    popped := value
                    leave
                }
                let rootValue := sload(offset)
                if lt(value, rootValue) {
                    popped := value
                    leave
                }
                popped := rootValue
                sstore(offset, value)
                siftDown(offset, n, 0)
            }
        }
    }

    /// @notice Internal function to manage heap operations such as enqueue, pop, replace, push, and pushPop.
    /// 
    /// @param heap The heap storage reference.
    /// @param value The value to be inserted or compared.
    /// @param maxLength The maximum allowed length of the heap.
    /// @param mode The operation mode:
    ///              - 0: Enqueue (adds value to the heap if space is available).
    ///              - 1: Pop (removes and returns the root value).
    ///              - 2: Replace (replaces the root value with the given value).
    ///              - 3: Push (adds value to the heap, ignoring maxLength).
    ///              - 4: PushPop (adds value and immediately pops the smallest value).
    ///
    /// @return status The status of the operation:
    ///              - 1: Successfully enqueued.
    ///              - 3: Replaced the root value.
    ///              - Other: Operation-specific status.
    /// @return popped The value removed from the heap during pop or replace operations.
    ///
    /// Steps:
    /// 1. Load the current length of the heap.
    /// 2. Calculate the storage slot offset for the heap array.
    /// 3. Perform operations based on the specified mode:
    ///    - Enqueue: Add value if space is available, otherwise replace the smallest value.
    ///    - Pop: Remove and return the root value.
    ///    - Replace: Replace the root value with the given value.
    ///    - Push: Add value to the heap, ignoring maxLength.
    ///    - PushPop: Add value and immediately pop the smallest value.
    /// 4. Perform sift-up and sift-down operations to maintain heap properties.
    /// 5. Update the heap storage with the new value and return the operation status and popped value.
    function _set(MemHeap memory heap, uint256 value, uint256 maxLength, uint256 mode)
        private
        pure
        returns (uint256 status, uint256 popped)
    {
        assembly {
            function siftUp(data, i) {
                for {} gt(i, 0) {} {
                    let p := shr(1, sub(i, 1))
                    let pPtr := add(data, shl(5, add(p, 1)))
                    let iPtr := add(data, shl(5, add(i, 1)))
                    let pValue := mload(pPtr)
                    let iValue := mload(iPtr)
                    if iszero(gt(pValue, iValue)) { break }
                    mstore(pPtr, iValue)
                    mstore(iPtr, pValue)
                    i := p
                }
            }
            function siftDown(data, n, i) {
                for {} 1 {} {
                    let l := add(shl(1, i), 1)
                    if iszero(lt(l, n)) { break }
                    let r := add(l, 1)
                    let minChild := l
                    if and(lt(r, n), lt(mload(add(data, shl(5, add(r, 1)))), mload(add(data, shl(5, add(l, 1)))))) {
                        minChild := r
                    }
                    let iPtr := add(data, shl(5, add(i, 1)))
                    let minPtr := add(data, shl(5, add(minChild, 1)))
                    let iValue := mload(iPtr)
                    let minValue := mload(minPtr)
                    if iszero(gt(iValue, minValue)) { break }
                    mstore(iPtr, minValue)
                    mstore(minPtr, iValue)
                    i := minChild
                }
            }

            let data := mload(heap)
            let n := mload(data)

            switch mode
            case 0 {
                // Enqueue
                if lt(n, maxLength) {
                    let newN := add(n, 1)
                    let capacity := mload(sub(data, 0x20))
                    if gt(newN, capacity) {
                        let newCapacity := newN
                        if lt(newCapacity, add(capacity, shr(1, capacity))) {
                            newCapacity := add(capacity, shr(1, capacity))
                        }
                        newCapacity := add(shl(5, newCapacity), 0x61)
                        let newData := mload(0x40)
                        mstore(0x40, add(newData, newCapacity))
                        mstore(newData, shr(5, sub(newCapacity, 0x61)))
                        mstore(add(newData, 0x20), n)
                        for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                            mstore(add(add(newData, 0x40), shl(5, i)), mload(add(add(data, 0x20), shl(5, i))))
                        }
                        data := add(newData, 0x20)
                        mstore(heap, data)
                    }
                    mstore(add(data, shl(5, newN)), value)
                    siftUp(data, n)
                    mstore(data, newN)
                    status := 1
                    leave
                }
                if iszero(n) { leave }
                let rootValue := mload(add(data, 0x20))
                if lt(value, rootValue) { leave }
                popped := rootValue
                mstore(add(data, 0x20), value)
                siftDown(data, n, 0)
                status := 3
            }
            case 1 {
                // Pop
                if iszero(n) {
                    mstore(0x00, 0xd0163c9d) // `HeapIsEmpty()`.
                    revert(0x1c, 0x04)
                }
                popped := mload(add(data, 0x20))
                let newN := sub(n, 1)
                if gt(newN, 0) {
                    mstore(add(data, 0x20), mload(add(data, shl(5, add(newN, 1)))))
                    siftDown(data, newN, 0)
                }
                mstore(data, newN)
            }
            case 2 {
                // Replace
                if iszero(n) {
                    mstore(0x00, 0xd0163c9d) // `HeapIsEmpty()`.
                    revert(0x1c, 0x04)
                }
                popped := mload(add(data, 0x20))
                mstore(add(data, 0x20), value)
                siftDown(data, n, 0)
            }
            case 3 {
                // Push
                let newN := add(n, 1)
                let capacity := mload(sub(data, 0x20))
                if gt(newN, capacity) {
                    let newCapacity := newN
                    if lt(newCapacity, add(capacity, shr(1, capacity))) {
                        newCapacity := add(capacity, shr(1, capacity))
                    }
                    newCapacity := add(shl(5, newCapacity), 0x61)
                    let newData := mload(0x40)
                    mstore(0x40, add(newData, newCapacity))
                    mstore(newData, shr(5, sub(newCapacity, 0x61)))
                    mstore(add(newData, 0x20), n)
                    for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                        mstore(add(add(newData, 0x40), shl(5, i)), mload(add(add(data, 0x20), shl(5, i))))
                    }
                    data := add(newData, 0x20)
                    mstore(heap, data)
                }
                mstore(add(data, shl(5, newN)), value)
                siftUp(data, n)
                mstore(data, newN)
            }
            case 4 {
                // PushPop
                if iszero(n) {
                    popped := value
                    leave
                }
                let rootValue := mload(add(data, 0x20))
                if lt(value, rootValue) {
                    popped := value
                    leave
                }
                popped := rootValue
                mstore(add(data, 0x20), value)
                siftDown(data, n, 0)
            }
        }
    }
}
