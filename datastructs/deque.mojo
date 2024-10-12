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
    Movable, ExplicitlyCopyable, Sized, Boolable
):
    """Implements a double-ended queue.

    It supports pushing and popping from both ends in O(1) time resizing the
    underlying storage as needed.

    Parameters:
        ElementType: The type of the elements in the deque.
            Must implement the trait `CollectionElement`.
    """

    # ===-------------------------------------------------------------------===#
    # Aliases
    # ===-------------------------------------------------------------------===#

    alias default_capacity: Int = 64
    """The default capacity of the deque: must be the power of 2."""

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

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

    var shrink: Bool
    """The flag defining if the deque storage is re-allocated to make it smaller when possible."""

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    fn __init__(
        inout self,
        *,
        elements: Optional[List[ElementType]] = None,
        capacity: Int = self.default_capacity,
        minlen: Int = self.default_capacity,
        maxlen: Int = -1,
        shrink: Bool = True,
    ):
        """Constructs an empty deque.

        Args:
            elements: Optional list of initial deque elements.
            capacity: The initial capacity of the deque.
            minlen: The minimum allowed capacity of the deque when shrinking.
            maxlen: The maximum allowed capacity of the deque when growing.
            shrink: Should storage be de-allocated when not needed.
        """
        if capacity <= 0:
            deque_capacity = self.default_capacity
        else:
            deque_capacity = bit_ceil(capacity)

        if minlen <= 0:
            min_capacity = self.default_capacity
        else:
            min_capacity = bit_ceil(minlen)

        if maxlen <= 0:
            max_capacity = -1
        else:
            max_capacity = maxlen
            deque_capacity = min(deque_capacity, bit_ceil(maxlen))

        self.capacity = deque_capacity
        self.data = UnsafePointer[ElementType].alloc(capacity)
        self.head = 0
        self.tail = 0
        self.minlen = min_capacity
        self.maxlen = max_capacity
        self.shrink = shrink

        if elements is not None:
            self.extend(elements.value())

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
        args_length = len(variadic_list)

        if args_length < self.default_capacity:
            capacity = self.default_capacity
        else:
            capacity = args_length

        self = Self(capacity=capacity)

        for i in range(args_length):
            src = UnsafePointer.address_of(variadic_list[i])
            dst = self.data + i
            src.move_pointee_into(dst)

        # Mark the elements as unowned to avoid del'ing uninitialized objects.
        variadic_list._is_owned = False

        self.tail = args_length

    fn __init__(inout self, other: Self):
        """Creates a deepcopy of the given deque.

        Args:
            other: The deque to copy.
        """
        self = Self(
            capacity=other.capacity,
            minlen=other.minlen,
            maxlen=other.maxlen,
            shrink=other.shrink,
        )
        for i in range(len(other)):
            offset = (other.head + i) & (other.capacity - 1)
            (self.data + i).init_pointee_copy((other.data + offset)[])

        self.tail = len(other)

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
        self.shrink = existing.shrink

    fn __del__(owned self):
        """Destroys all elements in the deque and free its memory."""
        for i in range(len(self)):
            offset = (self.head + i) & (self.capacity - 1)
            (self.data + offset).destroy_pointee()
        self.data.free()

    # ===-------------------------------------------------------------------===#
    # Operator dunders
    # ===-------------------------------------------------------------------===#

    fn __add__(self, other: Self) -> Self:
        """Concatenates self with other and returns the result as a new deque.

        Args:
            other: Deque whose elements will be appended to the elements of self.

        Returns:
            The newly created deque with the default characteristics.
        """
        total_len = len(self) + len(other)
        
        if total_len < self.default_capacity:
            new_capacity = self.default_capacity
        else:
            new_capacity = bit_ceil(total_len)

        if new_capacity == total_len:
            new_capacity <<= 1

        new = Self(capacity=new_capacity)

        for i in range(len(self)):
            offset = (self.head + i) & (self.capacity - 1)
            (new.data + i).init_pointee_copy((self.data + offset)[])

        dst = new.data + len(self)
        for i in range(len(other)):
            offset = (other.head + i) & (other.capacity - 1)
            (dst + i).init_pointee_copy((other.data + offset)[])

        new.tail = total_len
        return new^

    fn __eq__[
        EqualityElementType: EqualityComparableCollectionElement, //
    ](
        self: Deque[EqualityElementType], other: Deque[EqualityElementType]
    ) -> Bool:
        """Checks if two deques are equal.

        Parameters:
            EqualityElementType: The type of the elements in the deque.
                Must implement the trait `EqualityComparableCollectionElement`.

        Args:
            other: The deque to compare with.

        Returns:
            `True` if the deques are equal, `False` otherwise.
        """
        if len(self) != len(other):
            return False
        for i in range(len(self)):
            offset_self = (self.head + i) & (self.capacity - 1)
            offset_other = (other.head + i) & (other.capacity - 1)
            if (self.data + offset_self)[] != (other.data + offset_other)[]:
                return False
        return True

    fn __ne__[
        EqualityElementType: EqualityComparableCollectionElement, //
    ](
        self: Deque[EqualityElementType], other: Deque[EqualityElementType]
    ) -> Bool:
        """Checks if two deques are not equal.

        Parameters:
            EqualityElementType: The type of the elements in the deque.
                Must implement the trait `EqualityComparableCollectionElement`.

        Args:
            other: The deque to compare with.

        Returns:
            `True` if the deques are not equal, `False` otherwise.
        """
        return not (self == other)

    fn __contains__[
        EqualityElementType: EqualityComparableCollectionElement, //
    ](self: Deque[EqualityElementType], value: EqualityElementType) -> Bool:
        """Verify if a given value is present in the deque.

        Parameters:
            EqualityElementType: The type of the elements in the deque.
                Must implement the trait `EqualityComparableCollectionElement`.

        Args:
            value: The value to find.

        Returns:
            True if the value is contained in the deque, False otherwise.
        """
        for i in range(len(self)):
            offset = (self.head + i) & (self.capacity - 1)
            if (self.data + offset)[] == value:
                return True
        return False

    fn __iter__(
        ref [_]self,
    ) -> _DequeIter[ElementType, __lifetime_of(self)]:
        """Iterates over elements of the deque, returning the references.

        Returns:
            An iterator of the references to the deque elements.
        """
        return _DequeIter(0, Pointer.address_of(self))

    fn __reversed__(
        ref [_]self,
    ) -> _DequeIter[ElementType, __lifetime_of(self), False]:
        """Iterate backwards over the deque, returning the references.

        Returns:
            A reversed iterator of the references to the deque elements.
        """
        return _DequeIter[forward=False](len(self), Pointer.address_of(self))

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __bool__(self) -> Bool:
        """Checks whether the deque has any elements or not.

        Returns:
            `False` if the deque is empty, `True` if there is at least one element.
        """
        return self.head != self.tail

    @always_inline
    fn __len__(self) -> Int:
        """Gets the number of elements in the deque.

        Returns:
            The number of elements in the deque.
        """
        return (self.tail - self.head) & (self.capacity - 1)

    fn __getitem__(
        ref [_]self, idx: Int
    ) -> ref [__lifetime_of(self)] ElementType:
        """Gets the deque element at the given index.

        Args:
            idx: The index of the element.

        Returns:
            A reference to the element at the given index.
        """
        normalized_idx = idx

        debug_assert(
            -len(self) <= normalized_idx < len(self),
            "index: ",
            normalized_idx,
            " is out of bounds for `Deque` of size: ",
            len(self),
        )

        if normalized_idx < 0:
            normalized_idx += len(self)

        offset = (self.head + normalized_idx) & (self.capacity - 1)
        return (self.data + offset)[]

    @no_inline
    fn format_to[
        RepresentableElementType: RepresentableCollectionElement, //
    ](self: Deque[RepresentableElementType], inout writer: Formatter):
        """Writes `my_deque.__str__()` to a `Formatter`.

        Parameters:
            RepresentableElementType: The type of the Deque elements.
                Must implement the trait `RepresentableCollectionElement`.

        Args:
            writer: The formatter to write to.
        """
        writer.write("Deque(")
        for i in range(len(self)):
            offset = (self.head + i) & (self.capacity - 1)
            writer.write(repr((self.data + offset)[]))
            if i < len(self) - 1:
                writer.write(", ")
        writer.write(")")

    @no_inline
    fn __str__[
        RepresentableElementType: RepresentableCollectionElement, //
    ](self: Deque[RepresentableElementType]) -> String:
        """Returns a string representation of a `Deque`.

        Note that since we can't condition methods on a trait yet,
        the way to call this method is a bit special. Here is an example below:

        ```mojo
        my_deque = Deque[Int](1, 2, 3)
        print(my_deque.__str__())
        ```

        When the compiler supports conditional methods, then a simple `str(my_deque)` will
        be enough.

        The elements' type must implement the `__repr__()` method for this to work.

        Parameters:
            RepresentableElementType: The type of the elements in the deque.
                Must implement the trait `RepresentableCollectionElement`.

        Returns:
            A string representation of the deque.
        """
        output = String()
        writer = output._unsafe_to_formatter()
        self.format_to(writer)
        return output^

    @no_inline
    fn __repr__[
        RepresentableElementType: RepresentableCollectionElement, //
    ](self: Deque[RepresentableElementType]) -> String:
        """Returns a string representation of a `Deque`.

        Note that since we can't condition methods on a trait yet,
        the way to call this method is a bit special. Here is an example below:

        ```mojo
        my_deque = Deque[Int](1, 2, 3)
        print(my_deque.__repr__())
        ```

        When the compiler supports conditional methods, then a simple `repr(my_deque)` will
        be enough.

        The elements' type must implement the `__repr__()` for this to work.

        Parameters:
            RepresentableElementType: The type of the elements in the deque.
                Must implement the trait `RepresentableCollectionElement`.

        Returns:
            A string representation of the deque.
        """
        return self.__str__()

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    fn append(inout self, owned value: ElementType):
        """Appends a value to the right side of the deque.

        Args:
            value: The value to append.
        """
        if self.maxlen > 0 and len(self) + 1 > self.maxlen:
            (self.data + self.head).destroy_pointee()
            self.head = (self.head + 1) & (self.capacity - 1)

        (self.data + self.tail).init_pointee_move(value^)
        self.tail = (self.tail + 1) & (self.capacity - 1)

        if self.head == self.tail:
            self._realloc(self.capacity << 1)

    fn appendleft(inout self, owned value: ElementType):
        """Appends a value to the left side of the deque.

        Args:
            value: The value to append.
        """
        if self.maxlen > 0 and len(self) + 1 > self.maxlen:
            self.tail = (self.tail - 1) & (self.capacity - 1)
            (self.data + self.tail).destroy_pointee()

        self.head = (self.head - 1) & (self.capacity - 1)
        (self.data + self.head).init_pointee_move(value^)

        if self.head == self.tail:
            self._realloc(self.capacity << 1)

    fn clear(inout self):
        """Removes all elements from the deque leaving it with length 0.

        Resets the underlying storage capacity to `minlen`.
        """
        for i in range(len(self)):
            offset = (self.head + i) & (self.capacity - 1)
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
        count = 0
        for i in range(len(self)):
            offset = (self.head + i) & (self.capacity - 1)
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
        start_normalized = start

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

        for idx in range(start_normalized, stop_normalized):
            offset = (self.head + idx) & (self.capacity - 1)
            if (self.data + offset)[] == value:
                return idx
        raise "ValueError: Given element is not in deque"

    fn insert(inout self, idx: Int, owned value: ElementType) raises:
        """Inserts the `value` into the deque at position `idx`.

        Args:
            idx: The position to insert the value into.
            value: The value to insert.

        Raises:
            IndexError: If deque is already at its maximum size.
        """
        deque_len = len(self)

        if deque_len == self.maxlen:
            raise "IndexError: Deque is already at its maximum size"

        normalized_idx = idx

        if normalized_idx < -deque_len:
            normalized_idx = 0

        if normalized_idx > deque_len:
            normalized_idx = deque_len

        if normalized_idx < 0:
            normalized_idx += deque_len

        if normalized_idx <= deque_len // 2:
            for i in range(normalized_idx):
                src = (self.head + i) & (self.capacity - 1)
                dst = (src - 1) & (self.capacity - 1)
                (self.data + src).move_pointee_into(self.data + dst)
            self.head = (self.head - 1) & (self.capacity - 1)
        else:
            for i in range(deque_len - normalized_idx):
                dst = (self.tail - i) & (self.capacity - 1)
                src = (dst - 1) & (self.capacity - 1)
                (self.data + src).move_pointee_into(self.data + dst)
            self.tail = (self.tail + 1) & (self.capacity - 1)

        offset = (self.head + normalized_idx) & (self.capacity - 1)
        (self.data + offset).init_pointee_move(value^)

        if self.head == self.tail:
            self._realloc(self.capacity << 1)

    fn remove[
        EqualityElementType: EqualityComparableCollectionElement, //
    ](
        inout self: Deque[EqualityElementType],
        value: EqualityElementType,
    ) raises:
        """Removes the first occurrence of the `value`.

        Args:
            value: The value to remove.

        Raises:
            ValueError: If the value is not found in the deque.
        """
        deque_len = len(self)
        for idx in range(deque_len):
            offset = (self.head + idx) & (self.capacity - 1)
            if (self.data + offset)[] == value:
                (self.data + offset).destroy_pointee()

                if idx < deque_len // 2:
                    for i in reversed(range(idx)):
                        src = (self.head + i) & (self.capacity - 1)
                        dst = (src + 1) & (self.capacity - 1)
                        (self.data + src).move_pointee_into(self.data + dst)
                    self.head = (self.head + 1) & (self.capacity - 1)
                else:
                    for i in range(idx + 1, deque_len):
                        src = (self.head + i) & (self.capacity - 1)
                        dst = (src - 1) & (self.capacity - 1)
                        (self.data + src).move_pointee_into(self.data + dst)
                    self.tail = (self.tail - 1) & (self.capacity - 1)

                if (
                    self.shrink
                    and self.capacity > self.minlen
                    and self.capacity // 4 >= len(self)
                ):
                    self._realloc(self.capacity >> 1)

                return

        raise "ValueError: Given element is not in deque"

    fn peek(self) raises -> ElementType:
        """Inspect the last (rightmost) element of the deque without removing it.

        Returns:
            The the last (rightmost) element of the deque.

        Raises:
            IndexError: If the deque is empty.
        """
        if self.head == self.tail:
            raise "IndexError: Deque is empty"

        return (self.data + ((self.tail - 1) & (self.capacity - 1)))[]

    fn peekleft(self) raises -> ElementType:
        """Inspect the first (leftmost) element of the deque without removing it.

        Returns:
            The the first (leftmost) element of the deque.

        Raises:
            IndexError: If the deque is empty.
        """
        if self.head == self.tail:
            raise "IndexError: Deque is empty"

        return (self.data + self.head)[]

    fn pop(inout self) raises -> ElementType as element:
        """Removes and returns the element from the right side of the deque.

        Returns:
            The popped value.

        Raises:
            IndexError: If the deque is empty.
        """
        if self.head == self.tail:
            raise "IndexError: Deque is empty"

        self.tail = (self.tail - 1) & (self.capacity - 1)
        element = (self.data + self.tail).take_pointee()

        if (
            self.shrink
            and self.capacity > self.minlen
            and self.capacity // 4 >= len(self)
        ):
            self._realloc(self.capacity >> 1)

        return

    fn popleft(inout self) raises -> ElementType as element:
        """Removes and returns the element from the left side of the deque.

        Returns:
            The popped value.

        Raises:
            IndexError: If the deque is empty.
        """
        if self.head == self.tail:
            raise "IndexError: Deque is empty"

        element = (self.data + self.head).take_pointee()
        self.head = (self.head + 1) & (self.capacity - 1)

        if (
            self.shrink
            and self.capacity > self.minlen
            and self.capacity // 4 >= len(self)
        ):
            self._realloc(self.capacity >> 1)

        return

    fn reverse(inout self):
        """Reverses the elements of the deque in-place."""
        last = self.head + len(self) - 1
        for i in range(len(self) // 2):
            src = (self.head + i) & (self.capacity - 1)
            dst = (last - i) & (self.capacity - 1)
            tmp = (self.data + dst).take_pointee()
            (self.data + src).move_pointee_into(self.data + dst)
            (self.data + src).init_pointee_move(tmp^)

    fn rotate(inout self, n: Int = 1):
        """Rotates the deque by `n` steps.

        If `n` is positive, rotates to the right.
        If `n` is negative, rotates to the left.

        Args:
            n: Number of steps to rotate the deque
                (defaults to 1).
        """
        if n < 0:
            for _ in range(-n):
                (self.data + self.head).move_pointee_into(self.data + self.tail)
                self.tail = (self.tail + 1) & (self.capacity - 1)
                self.head = (self.head + 1) & (self.capacity - 1)
        else:
            for _ in range(n):
                self.tail = (self.tail - 1) & (self.capacity - 1)
                self.head = (self.head - 1) & (self.capacity - 1)
                (self.data + self.tail).move_pointee_into(self.data + self.head)

    fn _realloc(inout self, new_capacity: Int):
        """Relocates data to a new storage buffer.

        Args:
            new_capacity: The new capacity of the buffer.
        """
        deque_len = len(self) if self else self.capacity

        tail_len = self.tail
        head_len = self.capacity - self.head

        if head_len > deque_len:
            head_len = deque_len
            tail_len = 0

        new_data = UnsafePointer[ElementType].alloc(new_capacity)

        src = self.data + self.head
        dsc = new_data
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


@value
struct _DequeIter[
    deque_mutability: Bool, //,
    ElementType: CollectionElement,
    deque_lifetime: Lifetime[deque_mutability].type,
    forward: Bool = True,
]:
    """Iterator for Deque.

    Parameters:
        deque_mutability: Whether the reference to the deque is mutable.
        ElementType: The type of the elements in the deque.
        deque_lifetime: The lifetime of the Deque.
        forward: The iteration direction. `False` is backwards.
    """

    alias deque_type = Deque[ElementType]

    var index: Int
    var src: Pointer[Self.deque_type, deque_lifetime]

    fn __iter__(self) -> Self:
        return self

    fn __next__(inout self) -> Pointer[ElementType, deque_lifetime]:
        @parameter
        if forward:
            self.index += 1
            return Pointer.address_of(self.src[][self.index - 1])
        else:
            self.index -= 1
            return Pointer.address_of(self.src[][self.index])

    fn __len__(self) -> Int:
        @parameter
        if forward:
            return len(self.src[]) - self.index
        else:
            return self.index

    @always_inline
    fn __hasmore__(self) -> Bool:
        return self.__len__() > 0


fn _clip(value: Int, start: Int, end: Int) -> Int:
    return max(start, min(value, end))
