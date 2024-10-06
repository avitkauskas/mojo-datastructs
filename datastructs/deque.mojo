"""Defines the Deque type."""

from bit import bit_ceil
from collections import Optional
from memory import UnsafePointer, Reference


# ===----------------------------------------------------------------------===#
# Deque
# ===----------------------------------------------------------------------===#


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


struct Deque[ElementType: CollectionElement](
    CollectionElement, Sized, Boolable
):
    """The `Deque` type is a doble-ended queue..."""

    alias default_capacity: Int = 16

    # Fields
    var data: UnsafePointer[ElementType]
    """The underlying storage for the list."""

    var head: Int
    """The index of the head: contains the first element of the queue."""

    var tail: Int
    """The index of the tail: one behind the last element of the queue."""

    var capacity: Int
    """The amount of elements that can fit in the queue without resizing it."""

    var minlen: Int
    """The minimum required capacity in the number of elements of the deque."""

    var maxlen: Int
    """The maximum allowed capacity in the number of elements of the deque."""

    var shrinking: Bool
    """Defines if the deque allocated capacity should be made smaller when possible."""

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    fn __init__(
        inout self,
        *,
        minlen: Int = self.default_capacity,
        maxlen: Int = -1,
        shrinking: Bool = False,
    ):
        """Constructs a empty deque.

        Args:
            minlen: The required minimum capacity of the deque.
            maxlen: The maximum allowed capacity of the deque.
            shrinking: Should capacity be dealocated when not needed.
        """
        var min_capacity = minlen
        if min_capacity <= 0:
            min_capacity = self.default_capacity

        var capacity = bit_ceil(min_capacity)

        if maxlen >= 0:
            capacity = min(capacity, bit_ceil(maxlen))

        self.capacity = capacity
        self.data = UnsafePointer[ElementType].alloc(capacity)
        self.head = 0
        self.tail = 0
        self.minlen = capacity
        self.maxlen = maxlen
        self.shrinking = shrinking

    fn __init__(inout self, owned *values: ElementType):
        """Constructs a deque from the given values.

        Args:
            values: The values to populate the deque with.
        """
        self = Self(variadic_list=values^)

    fn __init__(inout self, *, owned variadic_list: VariadicListMem[ElementType, _]):
        """Constructs a deque from the given values.

        Args:
            variadic_list: The values to populate the deque with.
        """
        var length = len(variadic_list)

        self = Self()

        for i in range(length):
            var src = UnsafePointer.address_of(variadic_list[i])
            self.append(src[])

        # Mark the elements as unowned to avoid del'ing uninitialized objects.
        variadic_list._is_owned = False

    fn __moveinit__(inout self, owned existing: Self):
        """Move data of an existing deque into a new one.

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
            minlen=existing.minlen,
            maxlen=existing.maxlen,
            shrinking=existing.shrinking,
        )
        for i in range(len(existing)):
            try:
                self.append(existing[i])
            except:
                pass

    fn __del__(owned self):
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
        """Iterate over elements of the deque, returning immutable references.
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
        """
        var normalized_idx = idx
        if normalized_idx < 0:
            normalized_idx += len(self)

        if not 0 <= normalized_idx < len(self):
            raise "IndexError: Index out of range"

        var offset = (self.head + normalized_idx) & (self.capacity - 1)
        return (self.data + offset)[]

    fn append(inout self, owned value: ElementType):
        """Add `value` to the right side of the deque."""
        (self.data + self.tail).init_pointee_move(value^)
        self.tail = (self.tail + 1) & (self.capacity - 1)
        if self.head == self.tail:
            self._realloc(self.capacity << 1)
        if self.maxlen > 0 and len(self) > self.maxlen:
            (self.data + self.head).destroy_pointee()
            self.head = (self.head + 1) & (self.capacity - 1)

    fn appendleft(inout self, owned value: ElementType):
        """Add `value` to the left side of the deque."""
        self.head = (self.head - 1) & (self.capacity - 1)
        (self.data + self.head).init_pointee_move(value^)
        if self.head == self.tail:
            self._realloc(self.capacity << 1)
        if self.maxlen > 0 and len(self) > self.maxlen:
            self.tail = (self.tail - 1) & (self.capacity - 1)
            (self.data + self.tail).destroy_pointee()

    fn clear(inout self):
        """Remove all elements from the deque leaving it with length 0."""
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
        """Count the number of the deque elements equal to `value`."""
        var count = 0
        for i in range(len(self)):
            var offset = (self.head + i) & (self.capacity - 1)
            if (self.data + offset)[] == value:
                count += 1
        return count

    fn extend(inout self, owned values: List[ElementType]):
        """Extend the right side of the deque by appending elements from the list argument.
        """
        for value in values:
            self.append(value[])

    fn extendleft(inout self, owned values: List[ElementType]):
        """Extend the left side of the deque by appending elements from the list argument.

        The series of left appends results in reversing the order of elements in the list argument.
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
        """Return the position of `value` in the deque (at or after index start and before index stop).

        Returns the first match or raises ValueError if not found."""
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
        """Remove and return an element from the right side of the deque.

        If no elements are present, raises an IndexError."""
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
        """Remove and return an element from the left side of the deque.

        If no elements are present, raises an IndexError."""
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
        """Reverse the elements of the deque in-place."""
        var last = self.head + len(self) - 1
        for i in range(len(self) // 2):
            var src = (self.head + i) & (self.capacity - 1)
            var dst = (last - i) & (self.capacity - 1)
            var tmp = (self.data + dst).take_pointee()
            (self.data + src).move_pointee_into(self.data + dst)
            (self.data + src).init_pointee_move(tmp^)

    fn rotate(inout self, n: Int = 1):
        """Rotate the deque `n` steps to the right. If `n` is negative, rotate to the left.
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
        """Reallocate data to a new buffer of the size of `new_capacity`."""
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


fn _clip(value: Int, start: Int, end: Int) -> Int:
    return max(start, min(value, end))
