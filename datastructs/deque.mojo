# ===----------------------------------------------------------------------=== #
# Copyright (c) 2024 Alvydas Vitkauskas
# Licensed under the MIT License.
# ===----------------------------------------------------------------------=== #

"""Defines the Deque type."""

from bit import bit_ceil
from collections import Optional
from memory import UnsafePointer, Reference


# ===----------------------------------------------------------------------===#
# Deque
# ===----------------------------------------------------------------------===#


struct Deque[ElementType: CollectionElement](
    CollectionElement, Sized, Boolable
):
    """The `Deque` type is a double-ended queue.

    It supports pushing and popping from both ends in O(1) time resizing the
    underlying storage as needed.  When it is deallocated, it frees its memory.
    """

    alias default_capacity: Int = 64
    """The default capacity of the deque: must be the power of 2."""

    # Fields
    var data: UnsafePointer[ElementType]
    """The underlying storage for the deque."""

    var head: Int
    """The index of the head: contains the first element of the deque."""

    var tail: Int
    """The index of the tail: one behind the last element of the deque."""

    var capacity: Int
    """The amount of elements that can fit in the deque without resizing it."""

    var minlen: Int
    """The minimum required capacity in the number of elements of the deque."""

    var maxlen: Int
    """The maximum allowed capacity in the number of elements of the deque."""

    var shrinking: Bool
    """The flag defining if the deque storage is reallocated to make it smaller when possible."""

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    fn __init__(
        inout self,
        *,
        capacity: Int = self.default_capacity,
        minlen: Int = self.default_capacity,
        maxlen: Int = -1,
        shrinking: Bool = True,
    ):
        """Constructs an empty deque.

        Args:
            capacity: The initial capacity of the deque.
            minlen: The minimum allowed capacity of the deque.
            maxlen: The maximum allowed capacity of the deque.
            shrinking: Should storage be dealocated when not needed.
        """
        var deque_capacity = self.default_capacity if capacity <= 0 else bit_ceil(
            capacity
        )
        var min_capacity = self.default_capacity if minlen <= 0 else bit_ceil(
            minlen
        )

        if min_capacity > deque_capacity:
            deque_capacity = min_capacity

        if maxlen >= 0:
            deque_capacity = min(deque_capacity, bit_ceil(maxlen))

        self.capacity = deque_capacity
        self.data = UnsafePointer[ElementType].alloc(capacity)
        self.head = 0
        self.tail = 0
        self.minlen = min_capacity
        self.maxlen = maxlen
        self.shrinking = shrinking

    fn __init__(inout self, owned *values: ElementType):
        """Constructs a deque from the given values.

        Args:
            values: The values to populate the deque with.
        """
        self = Self(variadic_list=values^)

    fn __init__(
        inout self, *, owned variadic_list: VariadicListMem[ElementType, _]
    ):
        """Constructs a deque from the given values.

        Args:
            variadic_list: The values to populate the deque with.
        """
        var length = len(variadic_list)
        var capacity = self.default_capacity if length < self.default_capacity else length

        self = Self(capacity=capacity)

        for i in range(length):
            var src = UnsafePointer.address_of(variadic_list[i])
            var dst = self.data + i
            src.move_pointee_into(dst)

        # Mark the elements as unowned to avoid del'ing uninitialized objects.
        variadic_list._is_owned = False

        self.tail = length

    fn __moveinit__(inout self, owned existing: Self):
        """Moves data of an existing deque into a new one.

        Args:
            existing: The existing deque.
        """
        self.data = existing.data
        self.capacity = existing.capacity
        self.head = existing.head
        self.tail = existing.tail
        self.minlen = existing.minlen
        self.maxlen = existing.maxlen
        self.shrinking = existing.shrinking

    fn __copyinit__(inout self, existing: Self):
        """Creates a deepcopy of the given deque.

        Args:
            existing: The deque to copy.
        """
        self = Self(
            capacity=existing.capacity,
            minlen=existing.minlen,
            maxlen=existing.maxlen,
            shrinking=existing.shrinking,
        )
        for i in range(len(existing)):
            var offset = (existing.head + i) & (existing.capacity - 1)
            (self.data + i).init_pointee_copy((existing.data + offset)[])

        self.tail = len(existing)

    fn __del__(owned self):
        """Destroys all elements in the deque and free its memory."""
        for i in range(len(self)):
            var offset = (self.head + i) & (self.capacity - 1)
            (self.data + offset).destroy_pointee()
        self.data.free()

    # ===-------------------------------------------------------------------===#
    # Operator dunders
    # ===-------------------------------------------------------------------===#

    fn __iter__(
        ref [_]self,
    ) -> _DequeIter[ElementType]:
        """Iterates over elements of the deque, returning copies of the elements.
        """
        return _DequeIter[ElementType](0, self)

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __len__(self) -> Int:
        """Gets the number of elements in the deque.

        Returns:
            The number of elements in the deque.
        """
        return (self.tail - self.head) & (self.capacity - 1)

    @always_inline
    fn __bool__(self) -> Bool:
        """Checks whether the deque has any elements or not.

        Returns:
            `False` if the deque is empty, `True` if there is at least one element.
        """
        return self.head != self.tail

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    fn __getitem__(
        ref [_]self, idx: Int
    ) raises -> ref [__lifetime_of(self)] ElementType:
        """Gets the deque element at the given index.

        Args:
            idx: The index of the element.

        Returns:
            A reference to the element at the given index.

        Raises:
            IndexError: If the `idx` is out of bounds.
        """
        var normalized_idx = idx
        if normalized_idx < 0:
            normalized_idx += len(self)

        if not 0 <= normalized_idx < len(self):
            raise "IndexError: Index out of range"

        var offset = (self.head + normalized_idx) & (self.capacity - 1)
        return (self.data + offset)[]

    fn append(inout self, owned value: ElementType):
        """Appends a value to the right side of the deque.

        Args:
            value: The value to append.
        """
        (self.data + self.tail).init_pointee_move(value^)
        self.tail = (self.tail + 1) & (self.capacity - 1)
        if self.head == self.tail:
            self._realloc(self.capacity << 1)
        if self.maxlen > 0 and len(self) > self.maxlen:
            (self.data + self.head).destroy_pointee()
            self.head = (self.head + 1) & (self.capacity - 1)

    fn appendleft(inout self, owned value: ElementType):
        """Appends a value to the left side of the deque.

        Args:
            value: The value to append.
        """
        self.head = (self.head - 1) & (self.capacity - 1)
        (self.data + self.head).init_pointee_move(value^)
        if self.head == self.tail:
            self._realloc(self.capacity << 1)
        if self.maxlen > 0 and len(self) > self.maxlen:
            self.tail = (self.tail - 1) & (self.capacity - 1)
            (self.data + self.tail).destroy_pointee()

    fn clear(inout self):
        """Removes all elements from the deque leaving it with length 0.

        Resets the underlying storage capacity to `minlen`.
        """
        for i in range(len(self)):
            var offset = (self.head + i) & (self.capacity - 1)
            (self.data + offset).destroy_pointee()
        self.data.free()
        self.capacity = self.minlen
        self.data = UnsafePointer[ElementType].alloc(self.capacity)
        self.head = 0
        self.tail = 0

    fn count[
        EqualityElementType: EqualityComparableCollectionElement, //
    ](self: Deque[EqualityElementType], value: EqualityElementType) -> Int:
        """Counts the number of occurrences of a `value` in the deque.

        Parameters:
            EqualityElementType: The type of the elements in the deque.
                Must implement the trait `EqualityComparableCollectionElement`.

        Args:
            value: The value to count.

        Returns:
            The number of occurrences of the value in the deque.
        """
        var count = 0
        for i in range(len(self)):
            var offset = (self.head + i) & (self.capacity - 1)
            if (self.data + offset)[] == value:
                count += 1
        return count

    fn extend(inout self, owned values: List[ElementType]):
        """Extends the right side of the deque by consuming elements of the list argument.

        Args:
            values: List whose elements will be added at the right side of the deque.
        """
        for value in values:
            self.append(value[])

    fn extendleft(inout self, owned values: List[ElementType]):
        """Extends the left side of the deque by consuming elements from the list argument.

        The series of left appends results in reversing the order of elements in the list argument.

        Args:
            values: List whose elements will be added at the left side of the deque.
        """
        for value in values:
            self.appendleft(value[])

    fn index[
        EqualityElementType: EqualityComparableCollectionElement, //
    ](
        self: Deque[EqualityElementType],
        value: EqualityElementType,
        start: Int = 0,
        stop: Optional[Int] = None,
    ) raises -> Int:
        """Returns the index of the first occurrence of a `value` in a deque
        restricted by the range given the `start` and `stop` bounds.

        Args:
            value: The value to search for.
            start: The starting index of the search, treated as a slice index
                (defaults to 0).
            stop: The ending index of the search, treated as a slice index
                (defaults to None, which means the end of the deque).

        Parameters:
            EqualityElementType: The type of the elements in the deque.
                Must implement the `EqualityComparableCollectionElement` trait.

        Returns:
            The index of the first occurrence of the value in the deque.

        Raises:
            ValueError: If the value is not found in the deque.
        """
        var start_normalized = start

        var stop_normalized: Int
        if stop is None:
            stop_normalized = len(self)
        else:
            stop_normalized = stop.value()

        if start_normalized < 0:
            start_normalized += len(self)
        if stop_normalized < 0:
            stop_normalized += len(self)

        start_normalized = _clip(start_normalized, 0, len(self))
        stop_normalized = _clip(stop_normalized, 0, len(self))

        for i in range(start_normalized, stop_normalized):
            var offset = (self.head + i) & (self.capacity - 1)
            if (self.data + offset)[] == value:
                return i
        raise "ValueError: Given element is not in deque"

    fn pop(inout self) raises -> ElementType:
        """Removes and returns the element from the right side of the deque.

        Returns:
            The popped value.

        Raises:
            IndexError: If the deque is empty.
        """
        if self.head == self.tail:
            raise "IndexError: Deque is empty"

        self.tail = (self.tail - 1) & (self.capacity - 1)
        var result = (self.data + self.tail).take_pointee()

        if (
            self.shrinking
            and self.capacity > self.minlen
            and self.capacity // 4 >= len(self)
        ):
            self._realloc(self.capacity >> 1)

        return result

    fn popleft(inout self) raises -> ElementType:
        """Removes and returns the element from the left side of the deque.

        Returns:
            The popped value.

        Raises:
            IndexError: If the deque is empty.
        """
        if self.head == self.tail:
            raise "IndexError: Deque is empty"

        result = (self.data + self.head).take_pointee()
        self.head = (self.head + 1) & (self.capacity - 1)

        if (
            self.shrinking
            and self.capacity > self.minlen
            and self.capacity // 4 >= len(self)
        ):
            self._realloc(self.capacity >> 1)

        return result

    fn reverse(inout self):
        """Reverses the elements of the deque in-place."""
        var last = self.head + len(self) - 1
        for i in range(len(self) // 2):
            var src = (self.head + i) & (self.capacity - 1)
            var dst = (last - i) & (self.capacity - 1)
            var tmp = (self.data + dst).take_pointee()
            (self.data + src).move_pointee_into(self.data + dst)
            (self.data + src).init_pointee_move(tmp^)

    fn rotate(inout self, n: Int = 1):
        """Rotates the deque by `n` steps.

        If `n` is posstive, rotataes to the right.
        If `n` is negative, rotates to the left.

        Args:
            n: Number of steps to rotate the deque
                (defaults to 1).
        """
        if n > 0:
            for _ in range(n):
                self.tail = (self.tail - 1) & (self.capacity - 1)
                self.head = (self.head - 1) & (self.capacity - 1)
                (self.data + self.tail).move_pointee_into(self.data + self.head)
        else:
            for _ in range(-n):
                (self.data + self.head).move_pointee_into(self.data + self.tail)
                self.tail = (self.tail + 1) & (self.capacity - 1)
                self.head = (self.head + 1) & (self.capacity - 1)

    fn _realloc(inout self, new_capacity: Int):
        """Relocates data to a new storage buffer of the size of `new_capacity`.
        """
        var deque_len = len(self) if self else self.capacity

        var tail_len = self.tail
        var head_len = self.capacity - self.head

        if head_len > deque_len:
            head_len = deque_len
            tail_len = 0

        var new_data = UnsafePointer[ElementType].alloc(new_capacity)

        var src = self.data + self.head
        var dsc = new_data
        for i in range(head_len):
            (src + i).move_pointee_into(dsc + i)

        src = self.data
        dsc = new_data + head_len
        for i in range(tail_len):
            (src + i).move_pointee_into(dsc + i)

        self.head = 0
        self.tail = deque_len

        if self.data:
            self.data.free()
        self.data = new_data
        self.capacity = new_capacity


struct _DequeIter[ElementType: CollectionElement]:
    """Iterator for Deque."""

    var index: Int
    var src: Deque[ElementType]

    fn __init__(inout self, index: Int, ref [_]src: Deque[ElementType]):
        self.index = index
        self.src = src

    fn __next__(
        inout self,
    ) -> ElementType:
        self.index += 1
        var offset = (self.src.head + self.index - 1) & (self.src.capacity - 1)
        return (self.src.data + offset)[]

    fn __len__(self) -> Int:
        return len(self.src) - self.index


fn _clip(value: Int, start: Int, end: Int) -> Int:
    return max(start, min(value, end))
