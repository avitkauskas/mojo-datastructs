# ===----------------------------------------------------------------------=== #
# Copyright (c) 2024, Your Name. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
# ===----------------------------------------------------------------------=== #
"""Defines the MinMaxHeap type.

A min-max heap is a complete binary tree data structure which combines the
advantages of a min-heap and a max-heap. In a min-max heap, the elements at even
levels are less than or equal to their descendants, while the elements at odd
levels are greater than or equal to their descendants.

Examples:
```mojo
from collections import MinMaxHeap

heap = MinMaxHeap[Int]()
heap.push(4)
heap.push(2)
min_val = heap.get_min()  # Returns 2
max_val = heap.get_max()  # Returns 4
```
"""

from memory import UnsafePointer
from collections import Optional


struct MinMaxHeap[ElementType: ComparableCollectionElement](
    Movable, ExplicitlyCopyable, Sized, Boolable
):
    """Implements a min-max heap data structure.

    Parameters:
        ElementType: The type of elements in the heap.
            Must implement the trait CollectionElement.
    """

    # ===-------------------------------------------------------------------===#
    # Aliases and Constants
    # ===-------------------------------------------------------------------===#

    alias default_capacity: Int = 16
    """The default initial capacity of the heap."""

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

    var _data: UnsafePointer[ElementType]
    """The underlying storage for the heap elements."""

    var _size: Int
    """Current number of elements in the heap."""

    var _capacity: Int
    """Current capacity of the heap's storage."""

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    fn __init__(out self, capacity: Int = Self.default_capacity):
        """Constructs an empty min-max heap.

        Args:
            capacity: Initial capacity of the heap.
        """
        if capacity <= 0:
            self._capacity = self.default_capacity
        else:
            self._capacity = capacity

        self._data = UnsafePointer[ElementType].alloc(self._capacity)
        self._size = 0

    fn __init__(out self, owned *values: ElementType):
        """Constructs a heap from the given values.

        Args:
            values: The values to populate the heap with.
        """
        self = Self(variadic_list=values^)

    fn __init__(
        out self, *, owned variadic_list: VariadicListMem[ElementType, _]
    ):
        """Constructs a heap from the given values.

        Args:
            variadic_list: The values to populate the heap with.
        """
        args_length = len(variadic_list)

        if args_length < self.default_capacity:
            capacity = self.default_capacity
        else:
            capacity = args_length

        self = Self(capacity=capacity)

        for i in range(args_length):
            src = UnsafePointer.address_of(variadic_list[i])
            dst = self._data + i
            src.move_pointee_into(dst)

        # Mark elements as unowned
        variadic_list._is_owned = False

        self._size = args_length
        self._heapify()

    fn __init__(out self, other: Self):
        """Creates a deepcopy of the given heap.

        Args:
            other: The heap to copy.
        """
        self = Self(capacity=other._capacity)

        for i in range(other._size):
            (self._data + i).init_pointee_copy((other._data + i)[])

        self._size = other._size

    fn __moveinit__(inout self, owned existing: Self):
        """Moves data from an existing heap into a new one.

        Args:
            existing: The existing heap.
        """
        self._data = existing._data
        self._size = existing._size
        self._capacity = existing._capacity

    fn __del__(owned self):
        """Destroys all elements in the heap and frees its memory."""
        for i in range(self._size):
            (self._data + i).destroy_pointee()
        self._data.free()

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __bool__(self) -> Bool:
        """Returns whether the heap has any elements.

        Returns:
            True if the heap is not empty, False otherwise.
        """
        return self._size > 0

    @always_inline
    fn __len__(self) -> Int:
        """Returns the number of elements in the heap.

        Returns:
            The number of elements in the heap.
        """
        return self._size

    # ===-------------------------------------------------------------------===#
    # Public methods
    # ===-------------------------------------------------------------------===#

    fn push(inout self, owned value: ElementType):
        """Pushes a new element onto the heap.

        Args:
            value: The value to add to the heap.
        """
        if self._size == self._capacity:
            self._grow()

        self._size += 1
        (self._data + self._size - 1).init_pointee_move(value^)
        self._bubble_up(self._size - 1)

    fn pop_min(inout self) raises -> ElementType:
        """Removes and returns the minimum element from the heap.

        Returns:
            The minimum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        result = (self._data).take_pointee()
        self._size -= 1

        if self._size > 0:
            # Move last element to root and restore heap property
            (self._data + self._size).move_pointee_into(self._data)
            self._trickle_down_min(0)

        return result

    fn pop_max(inout self) raises -> ElementType:
        """Removes and returns the maximum element from the heap.

        Returns:
            The maximum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        if self._size == 1:
            self._size -= 1
            return (self._data).take_pointee()

        # Find maximum among level 1 nodes
        max_idx = 1
        if self._size > 2 and (self._data + 2)[] > (self._data + 1)[]:
            max_idx = 2

        result = (self._data + max_idx).take_pointee()

        # Move last element to max position and restore heap property
        if self._size > max_idx + 1:
            (self._data + self._size - 1).move_pointee_into(self._data + max_idx)
            self._trickle_down_max(max_idx)

        self._size -= 1
        return result

    fn get_min(self) raises -> ElementType:
        """Returns the minimum element without removing it.

        Returns:
            The minimum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        return (self._data)[]

    fn get_max(self) raises -> ElementType:
        """Returns the maximum element without removing it.

        Returns:
            The maximum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        if self._size == 1:
            return (self._data)[]
        
        if self._size == 2:
            return (self._data + 1)[]

        # Find maximum among level 1 nodes (children of root)
        max_val = (self._data + 1)[]
        if self._size > 2:
            right_child = (self._data + 2)[]
            if right_child > max_val:
                max_val = right_child
        return max_val

    fn clear(inout self):
        """Removes all elements from the heap."""
        for i in range(self._size):
            (self._data + i).destroy_pointee()
        self._size = 0

    # ===-------------------------------------------------------------------===#
    # Private helper methods
    # ===-------------------------------------------------------------------===#

    fn _grow(inout self):
        """Doubles the capacity of the heap's internal storage."""
        new_capacity = self._capacity * 2
        new_data = UnsafePointer[ElementType].alloc(new_capacity)

        for i in range(self._size):
            (self._data + i).move_pointee_into(new_data + i)

        self._data.free()
        self._data = new_data
        self._capacity = new_capacity

    fn _heapify(inout self):
        """Converts the array into a min-max heap."""
        if self._size <= 1:
            return

        # Start from the last non-leaf node
        for i in range((self._size - 2) // 2, -1, -1):
            if self._is_min_level(i):
                self._trickle_down_min(i)
            else:
                self._trickle_down_max(i)

    fn _is_min_level(self, index: Int) -> Bool:
        """Determines if the given index is on a min level (0-based).

        Args:
            index: The index to check.

        Returns:
            True if the index is on a min level, False otherwise.
        """
        # Count number of edges from root to node (i.e., level in tree)
        level = 0
        i = index + 1  # Convert to 1-based indexing for level calculation
        while i > 1:
            i //= 2
            level += 1
        return level % 2 == 0

    fn _bubble_up(inout self, index: Int):
        """Moves an element up the heap until heap properties are satisfied.

        Args:
            index: The index of the element to bubble up.
        """
        if index == 0:
            return

        parent_idx = (index - 1) // 2

        if self._is_min_level(index):
            if (self._data + index)[] > (self._data + parent_idx)[]:
                # If we're at a min level but larger than parent (which is at max level)
                self._swap(index, parent_idx)
                self._bubble_up_max(parent_idx)
            else:
                # Compare with grandparent if at min level
                grandparent_idx = (parent_idx - 1) // 2
                if index >= 3 and (self._data + index)[] < (self._data + grandparent_idx)[]:
                    self._swap(index, grandparent_idx)
                    self._bubble_up_min(grandparent_idx)
        else:
            if (self._data + index)[] < (self._data + parent_idx)[]:
                # If we're at a max level but smaller than parent (which is at min level)
                self._swap(index, parent_idx)
                self._bubble_up_min(parent_idx)
            else:
                # Compare with grandparent if at max level
                grandparent_idx = (parent_idx - 1) // 2
                if index >= 3 and (self._data + index)[] > (self._data + grandparent_idx)[]:
                    self._swap(index, grandparent_idx)
                    self._bubble_up_max(grandparent_idx)

    fn _bubble_up_min(inout self, index: Int):
        """Bubbles up an element on a min level.

        Args:
            index: The index of the element to bubble up.
        """
        if index <= 2:
            return

        parent_idx = (index - 1) // 2
        grandparent_idx = (parent_idx - 1) // 2
        if (self._data + index)[] < (self._data + grandparent_idx)[]:
            self._swap(index, grandparent_idx)
            self._bubble_up_min(grandparent_idx)

    fn _bubble_up_max(inout self, index: Int):
        """Bubbles up an element on a max level.

        Args:
            index: The index of the element to bubble up.
        """
        if index <= 2:
            return

        parent_idx = (index - 1) // 2
        grandparent_idx = (parent_idx - 1) // 2
        if (self._data + index)[] > (self._data + grandparent_idx)[]:
            self._swap(index, grandparent_idx)
            self._bubble_up_max(grandparent_idx)

    fn _trickle_down_min(inout self, owned index: Int):
        """Moves an element down on a min level until heap properties are satisfied.

        Args:
            index: The index of the element to trickle down.
        """
        while index * 2 + 1 < self._size:  # While has children
            min_idx = index

            # Check children and grandchildren
            start = index * 2 + 1
            end = min(self._size, start + 4)  # Up to 4 descendants

            for i in range(start, end):
                if (self._data + i)[] < (self._data + min_idx)[]:
                    min_idx = i

            if min_idx == index:
                break

            self._swap(index, min_idx)

            if min_idx - start >= 2:  # If grandchild was smallest
                parent = (min_idx - 1) // 2
                if (self._data + min_idx)[] > (self._data + parent)[]:
                    self._swap(min_idx, parent)
                index = min_idx
            else:
                break

    fn _trickle_down_max(inout self, owned index: Int):
        """Moves an element down on a max level until heap properties are satisfied.

        Args:
            index: The index of the element to trickle down.
        """
        while True:
            # Find largest among children and grandchildren
            largest = index

            # Check children
            left = 2 * index + 1
            right = 2 * index + 2
            if left < self._size and (self._data + left)[] > (self._data + largest)[]:
                largest = left
            if right < self._size and (self._data + right)[] > (self._data + largest)[]:
                largest = right

            # Check grandchildren
            for i in range(4):
                grandchild = 4 * index + i + 3
                if grandchild < self._size and (self._data + grandchild)[] > (self._data + largest)[]:
                    largest = grandchild

            if largest == index:
                break

            self._swap(index, largest)

            # If we swapped with a grandchild, we might need to swap with its parent
            if largest >= 4 * index + 3:  # is grandchild
                parent = (largest - 1) // 2
                if (self._data + largest)[] < (self._data + parent)[]:
                    self._swap(largest, parent)

            index = largest

    fn _swap(inout self, i: Int, j: Int):
        """Swaps two elements in the heap.

        Args:
            i: Index of first element.
            j: Index of second element.
        """
        tmp = (self._data + i).take_pointee()
        (self._data + j).move_pointee_into(self._data + i)
        (self._data + j).init_pointee_move(tmp^)
