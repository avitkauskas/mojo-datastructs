# ===----------------------------------------------------------------------=== #
# Copyright (c) 2024 Alvydas Vitkauskas
# Licensed under the MIT License.
# ===----------------------------------------------------------------------=== #

"""Defines the MinMaxHeap type.

A min-max heap is a complete binary tree data structure which combines the
advantages of a min-heap and a max-heap. In a min-max heap, the elements at even
levels are less than or equal to their descendants, while the elements at odd
levels are greater than or equal to their descendants.

Examples:
```mojo
from datastructs import MinMaxHeap

heap = MinMaxHeap[Int]()
heap.push(4)
heap.push(2)
min_val = heap.get_min()  # Returns 2
max_val = heap.get_max()  # Returns 4
```
"""

from bit import bit_width
from collections import Optional
from memory import UnsafePointer


struct MinMaxHeap[T: ComparableCollectionElement](
    Movable, ExplicitlyCopyable, Sized, Boolable
):
    """Implements a min-max heap data structure.

    Parameters:
        T: The type of elements in the heap.
            Must implement the trait CompareCollectionElement.
    """

    # ===-------------------------------------------------------------------===#
    # Aliases
    # ===-------------------------------------------------------------------===#

    alias default_capacity: Int = 16
    """The default initial capacity of the heap."""

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

    var _data: UnsafePointer[T]
    """The underlying storage for the heap elements."""

    var _size: Int
    """Current number of elements in the heap."""

    var _capacity: Int
    """Current capacity of the heap's storage."""

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    fn __init__(
        out self,
        *,
        owned elements: Optional[List[T]] = None,
        capacity: Int = Self.default_capacity,
    ):
        """Constructs an empty min-max heap.

        Args:
            elements: The optional list of initial heap elements.
            capacity: Initial capacity of the heap.
        """
        if capacity <= 0:
            self._capacity = self.default_capacity
        else:
            self._capacity = capacity

        if elements is not None and self._capacity < len(elements.value()):
            self._capacity = len(elements.value())

        self._data = UnsafePointer[T].alloc(self._capacity)
        self._size = 0

        if elements is not None:
            values = elements.value()
            for i in range(len(values)):
                (self._data + i).init_pointee_move(values[i])
            self._size = len(values)
            self._heapify()

    fn __init__(out self, owned *values: T):
        """Constructs a heap from the given values.

        Args:
            values: The values to populate the heap with.
        """
        self = Self(variadic_list=values^)

    fn __init__(out self, *, owned variadic_list: VariadicListMem[T, _]):
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

    fn __moveinit__(mut self, owned existing: Self):
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

    fn push(mut self, owned value: T):
        """Pushes a new element onto the heap.

        Args:
            value: The value to add to the heap.
        """
        if self._size == self._capacity:
            self._grow()

        (self._data + self._size).init_pointee_move(value^)
        self._bubble_up(self._size)
        self._size += 1

    fn pop_min(mut self) raises -> T:
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
            self._trickle_down(0, T.__lt__)

        return result

    fn pop_max(mut self) raises -> T:
        """Removes and returns the maximum element from the heap.

        Returns:
            The maximum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        if self._size == 1:
            self._size = 0
            return (self._data).take_pointee()

        if self._size == 2:
            self._size = 1
            return (self._data + 1).take_pointee()

        max_idx = 1 + (self._data[2] > self._data[1])
        result = (self._data + max_idx).take_pointee()

        # Move last element to max position and restore heap property
        if self._size > max_idx + 1:
            (self._data + self._size - 1).move_pointee_into(
                self._data + max_idx
            )
            self._trickle_down(max_idx, T.__gt__)

        self._size -= 1
        return result

    fn get_min(self) raises -> T:
        """Returns the minimum element without removing it.

        Returns:
            The minimum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        return self._data[0]

    fn get_max(self) raises -> T:
        """Returns the maximum element without removing it.

        Returns:
            The maximum element.

        Raises:
            IndexError: If the heap is empty.
        """
        if self._size == 0:
            raise "IndexError: Heap is empty"

        if self._size == 1:
            return self._data[0]

        if self._size == 2:
            return self._data[1]

        max_idx = 1 + (self._data[2] > self._data[1])
        return self._data[max_idx]

    fn clear(mut self):
        """Removes all elements from the heap."""
        for i in range(self._size):
            (self._data + i).destroy_pointee()
        self._size = 0

    # ===-------------------------------------------------------------------===#
    # Private helper methods
    # ===-------------------------------------------------------------------===#

    fn _grow(mut self):
        """Doubles the capacity of the heap's internal storage."""
        new_capacity = self._capacity * 2
        new_data = UnsafePointer[T].alloc(new_capacity)

        for i in range(self._size):
            (self._data + i).move_pointee_into(new_data + i)

        self._data.free()
        self._data = new_data
        self._capacity = new_capacity

    fn _heapify(mut self):
        """Converts the array into a min-max heap."""
        if self._size <= 1:
            return

        last_node = (self._size - 2) // 2
        first_with_grandchild = (self._size - 4) // 4

        # First phase: nodes that can only have children
        for i in range(last_node, first_with_grandchild, -1):
            # version that only checks children
            cmp = T.__lt__ if self._is_min_level(i) else T.__gt__
            self._trickle_down_to_children(i, cmp)

        # Second phase: nodes that might have grandchildren
        for i in range(first_with_grandchild, -1, -1):
            # full version that checks both children and grandchildren
            cmp = T.__lt__ if self._is_min_level(i) else T.__gt__
            self._trickle_down(i, cmp)

    @always_inline
    fn _is_min_level(self, index: Int) -> Bool:
        """Determines if the given index is on a min level (0-based).

        Args:
            index: The index to check.

        Returns:
            True if the index is on a min level, False otherwise.
        """
        return (bit_width(index + 1) & 1) == 1

    fn _bubble_up(mut self, index: Int):
        """Moves an element up the heap until heap properties are satisfied.

        Args:
            index: The index of the element to bubble up.
        """
        if index == 0:
            return

        # Select comparison functions based on level
        is_min_level = self._is_min_level(index)
        parent_cmp = T.__gt__ if is_min_level else T.__lt__
        grandparent_cmp = T.__lt__ if is_min_level else T.__gt__

        parent_idx = (index - 1) // 2
        if parent_cmp(self._data[index], self._data[parent_idx]):
            self._swap(index, parent_idx)
            self._bubble_up_to_grandparent(parent_idx, parent_cmp)
        else:
            grandparent_idx = (parent_idx - 1) // 2
            if index >= 3 and grandparent_cmp(
                self._data[index], self._data[grandparent_idx]
            ):
                self._swap(index, grandparent_idx)
                self._bubble_up_to_grandparent(grandparent_idx, grandparent_cmp)

    fn _bubble_up_to_grandparent(
        mut self, owned index: Int, cmp: fn (a: T, b: T) -> Bool
    ):
        """Bubbles up an element to its grandparent level if it satisfies the comparison.

        Args:
            index: The index of the element to bubble up.
            cmp: The comparison function to use.
        """
        while index > 2:
            grandparent_idx = (index - 3) // 4
            if cmp(self._data[index], self._data[grandparent_idx]):
                self._swap(index, grandparent_idx)
                index = grandparent_idx
            else:
                break

    fn _trickle_down(mut self, owned index: Int, cmp: fn (a: T, b: T) -> Bool):
        """Moves an element down the heap until heap properties are satisfied.

        Args:
            index: The index of the element to trickle down.
            cmp: The comparison function to use (less than for min level, greater than for max level).
        """
        while True:
            # Find the best element among children and grandchildren
            best_idx = index

            # Check children
            child_idx = 2 * index + 1
            for i in range(2):
                child = child_idx + i
                if child < self._size and cmp(
                    self._data[child], self._data[best_idx]
                ):
                    best_idx = child

            # Check grandchildren
            grandchild_idx = 4 * index + 3
            for i in range(4):
                grandchild = grandchild_idx + i
                if grandchild < self._size and cmp(
                    self._data[grandchild], self._data[best_idx]
                ):
                    best_idx = grandchild

            if best_idx == index:
                break

            self._swap(index, best_idx)

            # If we swapped with a grandchild, we might need to swap with its parent
            if best_idx >= grandchild_idx:
                parent_idx = (best_idx - 1) // 2
                # Use opposite comparison for parent level
                if cmp(self._data[parent_idx], self._data[best_idx]):
                    self._swap(best_idx, parent_idx)

            index = best_idx

    fn _trickle_down_to_children(
        mut self, owned index: Int, cmp: fn (a: T, b: T) -> Bool
    ):
        """Moves an element down checking only children (no grandchildren).

        Args:
            index: The index of the element to trickle down.
            cmp: The comparison function to use.
        """
        while True:
            best_idx = index

            # Check children
            child_idx = 2 * index + 1
            for i in range(2):
                child = child_idx + i
                if child < self._size and cmp(
                    self._data[child], self._data[best_idx]
                ):
                    best_idx = child

            if best_idx == index:
                break

            self._swap(index, best_idx)
            index = best_idx

    fn _swap(mut self, i: Int, j: Int):
        """Swaps two elements in the heap.

        Args:
            i: Index of first element.
            j: Index of second element.
        """
        tmp = (self._data + i).take_pointee()
        (self._data + j).move_pointee_into(self._data + i)
        (self._data + j).init_pointee_move(tmp^)
