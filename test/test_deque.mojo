from testing import assert_equal, assert_false, assert_true, assert_raises

from datastructs import Deque


fn test_init_default_empty() raises:
    var q = Deque[Int]()

    assert_equal(q.capacity_mask, q.default_capacity - 1)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 0)
    assert_equal(q.minlen, q.default_capacity)
    assert_equal(q.maxlen, -1)


fn test_init_minlen_empty() raises:
    var q = Deque[Int](minlen=2)

    assert_equal(q.capacity_mask, 1)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 0)
    assert_equal(q.minlen, 2)
    assert_equal(q.maxlen, -1)


fn test_init_variadic() raises:
    var q = Deque(0, 1, 2)
    assert_equal(q[0], 0)
    assert_equal(q[2], 2)


fn test_init_variadic_list() raises:
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


fn test_append_no_realloc() raises:
    var q = Deque[Int]()

    q.append(1)
    assert_equal(len(q), 1)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 1)
    assert_equal(q.capacity_mask, q.default_capacity - 1)
    assert_equal(q[0], 1)

    q.append(2)
    assert_equal(len(q), 2)
    assert_equal(q.head, 0)
    assert_equal(q.tail, 2)
    assert_equal(q[1], 2)


fn test_append_with_realloc() raises:
    var q = Deque[Int](minlen=2)

    q.append(1)
    assert_equal(q.capacity_mask, 1)
    assert_equal(q[0], 1)

    q.append(2)
    assert_equal(q.capacity_mask, 3)
    assert_equal(len(q), 2)
    assert_equal(q[0], 1)
    assert_equal(q[1], 2)

    q.append(3)
    assert_equal(q.capacity_mask, 3)
    assert_equal(len(q), 3)
    assert_equal(q[2], 3)

    q.append(4)
    assert_equal(q.capacity_mask, 7)
    assert_equal(len(q), 4)
    assert_equal(q[3], 4)


fn test_append_with_maxlen() raises:
    q = Deque[Int](maxlen=3)

    assert_equal(q.maxlen, 3)
    assert_equal(q.capacity_mask, 3)

    q.append(1)
    q.append(2)
    q.append(3)
    assert_equal(len(q), 3)

    q.append(4)
    assert_equal(len(q), 3)
    assert_equal(q.capacity_mask, 7)
    assert_equal(q[0], 2)
    assert_equal(q[2], 4)


fn test_extend() raises:
    var q = Deque[Int](maxlen=4)
    var lst = List[Int](1, 2, 3)
    assert_equal(len(q), 0)

    q.extend(lst)
    assert_equal(len(q), 3)
    assert_equal(q[0], 1)
    assert_equal(q[2], 3)

    q.extend(lst)
    assert_equal(len(q), 4)
    assert_equal(q[0], 3)
    assert_equal(q[3], 3)


fn test_appendleft_no_realloc() raises:
    var q = Deque[Int]()

    q.appendleft(1)
    assert_equal(len(q), 1)
    assert_equal(q.head, q.capacity_mask)
    assert_equal(q.tail, 0)
    assert_equal(q.capacity_mask, q.default_capacity - 1)
    assert_equal(q[0], 1)

    q.appendleft(2)
    assert_equal(len(q), 2)
    assert_equal(q.head, q.capacity_mask - 1)
    assert_equal(q.tail, 0)
    assert_equal(q[0], 2)


fn test_appendleft_with_realloc() raises:
    var q = Deque[Int](minlen=2)

    q.appendleft(1)
    assert_equal(q.capacity_mask, 1)
    assert_equal(q[0], 1)

    q.appendleft(2)
    assert_equal(q.capacity_mask, 3)
    assert_equal(len(q), 2)
    assert_equal(q[0], 2)
    assert_equal(q[1], 1)

    q.appendleft(3)
    assert_equal(q.capacity_mask, 3)
    assert_equal(len(q), 3)
    assert_equal(q[0], 3)

    q.appendleft(4)
    assert_equal(q.capacity_mask, 7)
    assert_equal(len(q), 4)
    assert_equal(q[0], 4)


fn test_appendleft_with_maxlen() raises:
    q = Deque[Int](maxlen=3)
    assert_equal(q.maxlen, 3)
    assert_equal(q.capacity_mask, 3)

    q.appendleft(1)
    q.appendleft(2)
    q.appendleft(3)
    assert_equal(len(q), 3)

    q.appendleft(4)
    assert_equal(len(q), 3)
    assert_equal(q.capacity_mask, 7)
    assert_equal(q[0], 4)
    assert_equal(q[2], 2)


fn test_extendleft() raises:
    var q = Deque[Int](maxlen=4)
    var lst = List[Int](1, 2, 3)
    assert_equal(len(q), 0)

    q.extendleft(lst)
    assert_equal(len(q), 3)
    assert_equal(q[0], 3)
    assert_equal(q[2], 1)

    q.extendleft(lst)
    assert_equal(len(q), 4)
    assert_equal(q[0], 3)
    assert_equal(q[3], 3)


fn test_pop() raises:
    var q = Deque[Int](minlen=2, shrinking=True)
    assert_equal(q.capacity_mask, 1)
    with assert_raises():
        _ = q.pop()

    q.append(1)
    q.appendleft(2)
    assert_equal(q.capacity_mask, 3)
    assert_equal(q.pop(), 1)
    assert_equal(len(q), 1)
    assert_equal(q[0], 2)
    assert_equal(q.capacity_mask, 1)


fn test_popleft() raises:
    var q = Deque[Int](minlen=2, shrinking=True)
    assert_equal(q.capacity_mask, 1)
    with assert_raises():
        _ = q.popleft()

    q.appendleft(1)
    q.append(2)
    assert_equal(q.capacity_mask, 3)
    assert_equal(q.popleft(), 1)
    assert_equal(len(q), 1)
    assert_equal(q[0], 2)
    assert_equal(q.capacity_mask, 1)


fn test_getitem() raises:
    var q = Deque(1, 2)
    assert_equal(q[0], 1)
    assert_equal(q[1], 2)
    assert_equal(q[-1], 2)
    assert_equal(q[-2], 1)
    with assert_raises():
        _ = q[2]
    with assert_raises():
        _ = q[-3]


fn test_setitem() raises:
    var q = Deque(1, 2)
    assert_equal(q[0], 1)

    q[0] = 3
    assert_equal(q[0], 3)

    q[-1] = 4
    assert_equal(q[1], 4)

    with assert_raises():
        q[2] = 5
    with assert_raises():
        q[-3] = 5


fn test_clear() raises:
    var q = Deque[Int]()

    q.append(1)
    assert_equal(len(q), 1)

    q.clear()
    assert_equal(len(q), 0)

    q.append(1)
    assert_equal(len(q), 1)
    assert_equal(q[0], 1)


fn test_reverse() raises:
    var q = Deque(0, 1, 2, 3)

    q.reverse()
    assert_equal(q[0], 3)
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


fn test_count() raises:
    var q = Deque(1, 2, 1, 2, 3, 1)

    assert_equal(q.count(1), 3)
    assert_equal(q.count(2), 2)
    assert_equal(q.count(3), 1)
    assert_equal(q.count(4), 0)

    q.appendleft(2)
    assert_equal(q.count(2), 3)


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


fn test_iter() raises:
    var q = Deque(1, 2, 3)

    var i = 0
    for e in q:
        assert_equal(e, q[i])
        i += 1
    assert_equal(i, len(q))


fn test_iter_list() raises:
    var q = Deque[List[Int]]()
    var lst1 = List(1, 2, 3)
    var lst2 = List(4, 5, 6)
    q.append(lst1)
    q.append(lst2)
    assert_equal(len(q), 2)
    
    var i = 0
    for e in q:
        assert_equal(e, q[i])
        i += 1
    assert_equal(i, len(q))

    for e in q:
        if e == lst1:
            e[0] = 7
    assert_equal(q[0], List(1, 2, 3))


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


fn test_len() raises:
    var q = Deque[Int]()
    assert_equal(len(q), 0)

    q.append(1)
    assert_equal(len(q), 1)


fn test_bool() raises:
    var q = Deque[Int]()
    assert_false(q)

    q.append(1)
    assert_true(q)
