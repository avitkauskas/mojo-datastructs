from testing import assert_equal, assert_false, assert_true, assert_raises

from datastructs import Deque

# ===----------------------------------------------------------------------===#
# Implementation tests
# ===----------------------------------------------------------------------===#


fn test_impl_init_default() raises:
    var q = Deque[Int]()

    assert_equal(q.capacity, q.default_capacity)
    assert_equal(q.minlen, q.default_capacity)
    assert_equal(q.maxlen, -1)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 0)
    assert_equal(q.shrinking, True)


fn test_impl_init_capacity() raises:
    var q: Deque[Int]

    q = Deque[Int](capacity=-10)
    assert_equal(q.capacity, q.default_capacity)
    assert_equal(q.minlen, q.default_capacity)

    q = Deque[Int](capacity=0)
    assert_equal(q.capacity, q.default_capacity)
    assert_equal(q.minlen, q.default_capacity)

    q = Deque[Int](capacity=10)
    assert_equal(q.capacity, 16)
    assert_equal(q.minlen, q.default_capacity)

    q = Deque[Int](capacity=100)
    assert_equal(q.capacity, 128)
    assert_equal(q.minlen, q.default_capacity)


fn test_impl_init_minlen() raises:
    var q: Deque[Int]

    q = Deque[Int](minlen=-10)
    assert_equal(q.minlen, q.default_capacity)
    assert_equal(q.capacity, q.default_capacity)

    q = Deque[Int](minlen=0)
    assert_equal(q.minlen, q.default_capacity)
    assert_equal(q.capacity, q.default_capacity)

    q = Deque[Int](minlen=10)
    assert_equal(q.minlen, 16)
    assert_equal(q.capacity, q.default_capacity)

    q = Deque[Int](minlen=100)
    assert_equal(q.minlen, 128)
    assert_equal(q.capacity, q.default_capacity)


fn test_impl_init_maxlen() raises:
    var q: Deque[Int]

    q = Deque[Int](maxlen=-10)
    assert_equal(q.maxlen, -1)
    assert_equal(q.capacity, q.default_capacity)

    q = Deque[Int](maxlen=0)
    assert_equal(q.maxlen, -1)
    assert_equal(q.capacity, q.default_capacity)

    q = Deque[Int](maxlen=10)
    assert_equal(q.maxlen, 10)
    assert_equal(q.capacity, 16)

    q = Deque[Int](maxlen=100)
    assert_equal(q.maxlen, 100)
    assert_equal(q.capacity, q.default_capacity)


fn test_impl_init_shrinking() raises:
    var q: Deque[Int]

    q = Deque[Int](shrinking=False)
    assert_equal(q.shrinking, False)
    assert_equal(q.capacity, q.default_capacity)


fn test_impl_init_variadic() raises:
    var q = Deque(0, 1, 2)

    assert_equal(q.head, 0)
    assert_equal(q.tail, 3)
    assert_equal(q.capacity, q.default_capacity)
    assert_equal((q.data + 0)[], 0)
    assert_equal((q.data + 1)[], 1)
    assert_equal((q.data + 2)[], 2)


fn test_impl_len() raises:
    var q = Deque[Int]()

    q.head = 0
    q.tail = 10
    assert_equal(len(q), 10)

    q.head = q.default_capacity - 5
    q.tail = 5
    assert_equal(len(q), 10)


fn test_impl_bool() raises:
    var q = Deque[Int]()
    assert_false(q)

    q.tail = 1
    assert_true(q)


fn test_impl_append() raises:
    var q = Deque[Int](capacity=2)

    q.append(0)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 1)
    assert_equal(q.capacity, 2)
    assert_equal((q.data + 0)[], 0)

    q.append(1)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 2)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 0)[], 0)
    assert_equal((q.data + 1)[], 1)

    q.append(2)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 3)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 0)[], 0)
    assert_equal((q.data + 1)[], 1)
    assert_equal((q.data + 2)[], 2)

    # simulate popleft()
    q.head += 1
    q.append(3)
    assert_equal(q.head, 1)
    # tail wrapped to the front
    assert_equal(q.tail, 0)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 1)[], 1)
    assert_equal((q.data + 2)[], 2)
    assert_equal((q.data + 3)[], 3)

    q.append(4)
    # re-allocated buffer and moved all elements
    assert_equal(q.head, 0)
    assert_equal(q.tail, 4)
    assert_equal(q.capacity, 8)
    assert_equal((q.data + 0)[], 1)
    assert_equal((q.data + 1)[], 2)
    assert_equal((q.data + 2)[], 3)
    assert_equal((q.data + 3)[], 4)


fn test_impl_append_with_maxlen() raises:
    q = Deque[Int](maxlen=3)

    assert_equal(q.maxlen, 3)
    assert_equal(q.capacity, 4)

    q.append(0)
    q.append(1)
    q.append(2)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 3)

    q.append(3)
    # first popped the leftmost element
    # so there was no re-allocation of buffer
    assert_equal(q.head, 1)
    assert_equal(q.tail, 0)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 1)[], 1)
    assert_equal((q.data + 2)[], 2)
    assert_equal((q.data + 3)[], 3)


fn test_impl_appendleft() raises:
    var q = Deque[Int](capacity=2)

    q.appendleft(0)
    # head wrapped to the end of the buffer
    assert_equal(q.head, 1)
    assert_equal(q.tail, 0)
    assert_equal(q.capacity, 2)
    assert_equal((q.data + 1)[], 0)

    q.appendleft(1)
    # re-allocated buffer and moved all elements
    assert_equal(q.head, 0)
    assert_equal(q.tail, 2)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 0)[], 1)
    assert_equal((q.data + 1)[], 0)

    q.appendleft(2)
    # head wrapped to the end of the buffer
    assert_equal(q.head, 3)
    assert_equal(q.tail, 2)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 3)[], 2)
    assert_equal((q.data + 0)[], 1)
    assert_equal((q.data + 1)[], 0)

    # simulate pop()
    q.tail -= 1
    q.appendleft(3)
    assert_equal(q.head, 2)
    assert_equal(q.tail, 1)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 2)[], 3)
    assert_equal((q.data + 3)[], 2)
    assert_equal((q.data + 0)[], 1)

    q.appendleft(4)
    # re-allocated buffer and moved all elements
    assert_equal(q.head, 0)
    assert_equal(q.tail, 4)
    assert_equal(q.capacity, 8)
    assert_equal((q.data + 0)[], 4)
    assert_equal((q.data + 1)[], 3)
    assert_equal((q.data + 2)[], 2)
    assert_equal((q.data + 3)[], 1)


fn test_impl_appendleft_with_maxlen() raises:
    q = Deque[Int](maxlen=3)

    assert_equal(q.maxlen, 3)
    assert_equal(q.capacity, 4)

    q.appendleft(0)
    q.appendleft(1)
    q.appendleft(2)
    assert_equal(q.head, 1)
    assert_equal(q.tail, 0)

    q.appendleft(3)
    # first popped the rightmost element
    # so there was no re-allocation of buffer
    assert_equal(q.head, 0)
    assert_equal(q.tail, 3)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 0)[], 3)
    assert_equal((q.data + 1)[], 2)
    assert_equal((q.data + 2)[], 1)


fn test_impl_extend() raises:
    var q = Deque[Int](maxlen=4)
    var lst = List[Int](0, 1, 2)

    q.extend(lst)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 3)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 0)[], 0)
    assert_equal((q.data + 1)[], 1)
    assert_equal((q.data + 2)[], 2)

    q.extend(lst)
    # re-allocated buffer after the first append
    # then poppedleft the first 2 elements
    assert_equal(q.capacity, 8)
    assert_equal(q.head, 2)
    assert_equal(q.tail, 6)
    assert_equal((q.data + 2)[], 2)
    assert_equal((q.data + 3)[], 0)
    assert_equal((q.data + 4)[], 1)
    assert_equal((q.data + 5)[], 2)


fn test_impl_extendleft() raises:
    var q = Deque[Int](maxlen=4)
    var lst = List[Int](0, 1, 2)

    q.extendleft(lst)
    # head wrapped to the end of then buffer
    assert_equal(q.head, 1)
    assert_equal(q.tail, 0)
    assert_equal(q.capacity, 4)
    assert_equal((q.data + 1)[], 2)
    assert_equal((q.data + 2)[], 1)
    assert_equal((q.data + 3)[], 0)

    q.extendleft(lst)
    # re-allocated buffer after the first appendlef
    # then popped the last 2 elements
    # head wrapped to the end of then buffer
    assert_equal(q.capacity, 8)
    assert_equal(q.head, 6)
    assert_equal(q.tail, 2)
    assert_equal((q.data + 6)[], 2)
    assert_equal((q.data + 7)[], 1)
    assert_equal((q.data + 0)[], 0)
    assert_equal((q.data + 1)[], 2)


fn test_impl_pop() raises:
    var q = Deque[Int](capacity=2, minlen=2, shrinking=True)
    with assert_raises():
        _ = q.pop()

    q.append(1)
    q.appendleft(2)
    assert_equal(q.capacity, 4)
    assert_equal(q.pop(), 1)
    assert_equal(len(q), 1)
    assert_equal(q[0], 2)
    assert_equal(q.capacity, 2)


fn test_popleft() raises:
    var q = Deque[Int](capacity=2, minlen=2, shrinking=True)
    assert_equal(q.capacity, 2)
    with assert_raises():
        _ = q.popleft()

    q.appendleft(1)
    q.append(2)
    assert_equal(q.capacity, 4)
    assert_equal(q.popleft(), 1)
    assert_equal(len(q), 1)
    assert_equal(q[0], 2)
    assert_equal(q.capacity, 2)


fn test_impl_clear() raises:
    var q = Deque[Int](capacity=2)
    q.append(1)
    assert_equal(q.tail, 1)

    q.clear()
    assert_equal(q.head, 0)
    assert_equal(q.tail, 0)
    assert_equal(q.capacity, q.minlen)


# ===----------------------------------------------------------------------===#
# API Interface tests
# ===----------------------------------------------------------------------===#


fn test_impl_init_variadic_list() raises:
    lst1 = List(0, 1)
    lst2 = List(2, 3)

    var q = Deque(lst1, lst2)
    assert_equal(q[0], lst1)
    assert_equal(q[1], lst2)

    lst1[0] = 4
    assert_equal(q[0], List(0, 1))

    var p = Deque(lst1^, lst2^)
    assert_equal(p[0], List(4, 1))
    assert_equal(p[1], List(2, 3))


fn test_copy_trivial() raises:
    var q = Deque(1, 2, 3)

    var p = q
    assert_equal(p[0], q[0])

    p[0] = 3
    assert_equal(p[0], 3)
    assert_equal(q[0], 1)


fn test_copy_list() raises:
    var q = Deque[List[Int]]()
    var lst1 = List(1, 2, 3)
    var lst2 = List(4, 5, 6)
    q.append(lst1)
    q.append(lst2)
    assert_equal(q[0], lst1)

    lst1[0] = 7
    assert_equal(q[0], List(1, 2, 3))

    var p = q
    assert_equal(p[0], q[0])

    p[0][0] = 7
    assert_equal(p[0], List(7, 2, 3))
    assert_equal(q[0], List(1, 2, 3))


fn test_move_list() raises:
    var q = Deque[List[Int]]()
    var lst1 = List(1, 2, 3)
    var lst2 = List(4, 5, 6)
    q.append(lst1)
    q.append(lst2)
    assert_equal(q[0], lst1)

    var p = q^
    assert_equal(p[0], lst1)

    lst1[0] = 7
    assert_equal(lst1[0], 7)
    assert_equal(p[0], List(1, 2, 3))


fn test_getitem() raises:
    var q = Deque(1, 2)
    assert_equal(q[0], 1)
    assert_equal(q[1], 2)
    assert_equal(q[-1], 2)
    assert_equal(q[-2], 1)


fn test_setitem() raises:
    var q = Deque(1, 2)
    assert_equal(q[0], 1)

    q[0] = 3
    assert_equal(q[0], 3)

    q[-1] = 4
    assert_equal(q[1], 4)


fn test_eq() raises:
    var q = Deque[Int](1, 2, 3)
    var p = Deque[Int](1, 2, 3)

    assert_true(q == p)

    var r = Deque[Int](0, 1, 2, 3)
    q.appendleft(0)
    assert_true(q == r)


fn test_ne() raises:
    var q = Deque[Int](1, 2, 3)
    var p = Deque[Int](3, 2, 1)

    assert_true(q != p)

    q.appendleft(0)
    p.append(0)
    assert_true(q != p)


fn test_count() raises:
    var q = Deque(1, 2, 1, 2, 3, 1)

    assert_equal(q.count(1), 3)
    assert_equal(q.count(2), 2)
    assert_equal(q.count(3), 1)
    assert_equal(q.count(4), 0)

    q.appendleft(2)
    assert_equal(q.count(2), 3)


fn test_contains() raises:
    var q = Deque[Int](1, 2, 3)

    assert_true(1 in q)
    assert_false(4 in q)


fn test_index() raises:
    var q = Deque(1, 2, 1, 2, 3, 1)

    assert_equal(q.index(2), 1)
    assert_equal(q.index(2, 1), 1)
    assert_equal(q.index(2, 1, 3), 1)
    assert_equal(q.index(2, stop=4), 1)
    assert_equal(q.index(1, -12, 10), 0)
    assert_equal(q.index(1, -4), 2)
    assert_equal(q.index(1, -3), 5)
    with assert_raises():
        _ = q.index(4)


fn test_peek_and_peekleft() raises:
    var q = Deque[Int](capacity=4)
    assert_equal(q.capacity, 4)
    q.extend(List(1, 2, 3))
    assert_equal(q.peekleft(), 1)
    assert_equal(q.peek(), 3)

    _ = q.popleft()
    assert_equal(q.peekleft(), 2)
    assert_equal(q.peek(), 3)

    q.append(4)
    assert_equal(q.capacity, 4)
    assert_equal(q.peekleft(), 2)
    assert_equal(q.peek(), 4)

    q.append(5)
    assert_equal(q.capacity, 8)
    assert_equal(q.peekleft(), 2)
    assert_equal(q.peek(), 5)


fn test_reverse() raises:
    var q = Deque(0, 1, 2, 3)

    q.reverse()
    assert_equal(q[0], 3)
    assert_equal(q[1], 2)
    assert_equal(q[2], 1)
    assert_equal(q[3], 0)

    q.appendleft(4)
    q.reverse()
    assert_equal(q[0], 0)
    assert_equal(q[4], 4)


fn test_rotate() raises:
    var q = Deque(0, 1, 2, 3)

    q.rotate()
    assert_equal(q[0], 3)
    assert_equal(q[3], 2)

    q.rotate(-1)
    assert_equal(q[0], 0)
    assert_equal(q[3], 3)

    q.rotate(3)
    assert_equal(q[0], 1)
    assert_equal(q[3], 0)

    q.rotate(-3)
    assert_equal(q[0], 0)
    assert_equal(q[3], 3)


fn test_iter() raises:
    var q = Deque(1, 2, 3)

    var i = 0
    for e in q:
        assert_equal(e[], q[i])
        i += 1
    assert_equal(i, len(q))

    for e in q:
        if e[] == 1:
            e[] = 4
            assert_equal(e[], 4)
    assert_equal(q[0], 4)


fn test_iter_with_list() raises:
    var q = Deque[List[Int]]()
    var lst1 = List(1, 2, 3)
    var lst2 = List(4, 5, 6)
    q.append(lst1)
    q.append(lst2)
    assert_equal(len(q), 2)

    var i = 0
    for e in q:
        assert_equal(e[], q[i])
        i += 1
    assert_equal(i, len(q))

    for e in q:
        if e[] == lst1:
            e[][0] = 7
            assert_equal(e[], List(7, 2, 3))
    assert_equal(q[0], List(7, 2, 3))

    for e in q:
        if e[] == lst2:
            e[] = List(1, 2, 3)
            assert_equal(e[], List(1, 2, 3))
    assert_equal(q[1], List(1, 2, 3))


fn test_reversed_iter() raises:
    var q = Deque(1, 2, 3)

    var i = 0
    # change to reversed(q) when implemented in builtin for Deque
    for e in q.__reversed__():
        i -= 1
        assert_equal(e[], q[i])
    assert_equal(-i, len(q))


fn test_str_and_repr() raises:
    var q = Deque(1, 2, 3)

    assert_equal(q.__str__(), "Deque(1, 2, 3)")
    assert_equal(q.__repr__(), "Deque(1, 2, 3)")

    var s = Deque("a", "b", "c")

    assert_equal(s.__str__(), "Deque('a', 'b', 'c')")
    assert_equal(s.__repr__(), "Deque('a', 'b', 'c')")
