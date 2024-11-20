from testing import assert_equal, assert_false, assert_true, assert_raises

from datastructs import MinMaxHeap

# ===----------------------------------------------------------------------===#
# Implementation tests
# ===----------------------------------------------------------------------===#


# ===----------------------------------------------------------------------===#
# API Interface tests
# ===----------------------------------------------------------------------===#


fn test_init_default() raises:
    heap = MinMaxHeap[Int]()

    assert_equal(heap._capacity, heap.default_capacity)
    assert_equal(heap._size, 0)


fn test_init_capacity() raises:
    heap = MinMaxHeap[Int](capacity=-10)
    assert_equal(heap._capacity, heap.default_capacity)

    heap = MinMaxHeap[Int](capacity=0)
    assert_equal(heap._capacity, heap.default_capacity)

    heap = MinMaxHeap[Int](capacity=10)
    assert_equal(heap._capacity, 10)


fn test_init_variadic() raises:
    heap = MinMaxHeap(1, 3, 2, 4)

    assert_equal(heap._size, 4)
    assert_equal(heap._capacity, heap.default_capacity)
    # Check min-max heap property
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 4)


fn test_init_elements() raises:
    heap = MinMaxHeap(elements=List(1, 3, 2, 4))

    assert_equal(heap._size, 4)
    assert_equal(heap._capacity, heap.default_capacity)
    # Check min-max heap property
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 4)


fn test_len() raises:
    heap = MinMaxHeap[Int]()
    assert_equal(len(heap), 0)

    heap.push(1)
    assert_equal(len(heap), 1)

    heap.push(2)
    assert_equal(len(heap), 2)


fn test_bool() raises:
    heap = MinMaxHeap[Int]()
    assert_false(heap)

    heap.push(1)
    assert_true(heap)


fn test_push() raises:
    heap = MinMaxHeap[Int]()

    heap.push(3)
    assert_equal(heap._size, 1)
    assert_equal(heap.get_min(), 3)
    assert_equal(heap.get_max(), 3)

    heap.push(1)
    assert_equal(heap._size, 2)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 3)

    heap.push(4)
    assert_equal(heap._size, 3)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 4)

    heap.push(2)
    assert_equal(heap._size, 4)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 4)


fn test_pop_min() raises:
    heap = MinMaxHeap[Int]()

    with assert_raises():
        _ = heap.pop_min()

    heap.push(3)
    heap.push(1)
    heap.push(4)
    heap.push(2)

    assert_equal(heap.pop_min(), 1)
    assert_equal(heap._size, 3)
    assert_equal(heap.get_min(), 2)
    assert_equal(heap.get_max(), 4)

    assert_equal(heap.pop_min(), 2)
    assert_equal(heap._size, 2)
    assert_equal(heap.get_min(), 3)
    assert_equal(heap.get_max(), 4)


fn test_pop_max() raises:
    heap = MinMaxHeap[Int]()

    with assert_raises():
        _ = heap.pop_max()

    heap.push(3)
    heap.push(1)
    heap.push(4)
    heap.push(2)

    assert_equal(heap.pop_max(), 4)
    assert_equal(heap._size, 3)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 3)

    assert_equal(heap.pop_max(), 3)
    assert_equal(heap._size, 2)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 2)


fn test_get_min() raises:
    heap = MinMaxHeap[Int]()

    with assert_raises():
        _ = heap.get_min()

    heap.push(3)
    assert_equal(heap.get_min(), 3)

    heap.push(1)
    assert_equal(heap.get_min(), 1)

    heap.push(4)
    assert_equal(heap.get_min(), 1)


fn test_get_max() raises:
    heap = MinMaxHeap[Int]()

    with assert_raises():
        _ = heap.get_max()

    heap.push(3)
    assert_equal(heap.get_max(), 3)

    heap.push(1)
    assert_equal(heap.get_max(), 3)

    heap.push(4)
    assert_equal(heap.get_max(), 4)


fn test_clear() raises:
    heap = MinMaxHeap[Int](1, 2, 3)
    assert_equal(heap._size, 3)

    heap.clear()
    assert_equal(heap._size, 0)
    assert_false(heap)


fn test_copy() raises:
    heap = MinMaxHeap(1, 3, 2, 4)

    copy = MinMaxHeap(heap)
    assert_equal(len(copy), len(heap))
    assert_equal(copy.get_min(), heap.get_min())
    assert_equal(copy.get_max(), heap.get_max())

    copy.push(5)
    assert_equal(len(copy), len(heap) + 1)
    assert_equal(heap.get_max(), 4)
    assert_equal(copy.get_max(), 5)


fn test_move() raises:
    heap = MinMaxHeap(1, 3, 2, 4)

    moved = heap^
    assert_equal(len(moved), 4)
    assert_equal(moved.get_min(), 1)
    assert_equal(moved.get_max(), 4)


fn test_heap_property() raises:
    heap = MinMaxHeap[Int]()

    heap.push(5)
    heap.push(3)
    heap.push(7)
    heap.push(1)
    heap.push(9)
    heap.push(4)

    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 9)


fn test_comprehensive() raises:
    """Tests a comprehensive sequence of operations."""
    heap = MinMaxHeap[Int]()

    # Test empty heap
    assert_false(heap)
    assert_equal(len(heap), 0)

    # Test insertions
    numbers = List(5, 3, 7, 1, 9, 4, 6, 8, 2)
    for num in numbers:
        heap.push(num[])

    assert_true(heap)
    assert_equal(len(heap), 9)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 9)

    # Test alternating min/max removals
    assert_equal(heap.pop_min(), 1)
    assert_equal(heap.pop_max(), 9)
    assert_equal(heap.pop_min(), 2)
    assert_equal(heap.pop_max(), 8)

    assert_equal(len(heap), 5)
    assert_equal(heap.get_min(), 3)
    assert_equal(heap.get_max(), 7)

    # Test clear
    heap.clear()
    assert_false(heap)
    assert_equal(len(heap), 0)

    with assert_raises():
        _ = heap.get_min()
    with assert_raises():
        _ = heap.get_max()


fn test_edge_cases() raises:
    heap = MinMaxHeap[Int]()

    # Test single element
    heap.push(1)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 1)

    # Test duplicate elements
    heap.push(1)
    heap.push(1)
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 1)
    assert_equal(len(heap), 3)

    # Test removing all elements
    _ = heap.pop_min()
    _ = heap.pop_min()
    _ = heap.pop_min()
    assert_false(heap)

    # Test capacity growth
    initial_capacity = heap._capacity
    for i in range(initial_capacity + 1):
        heap.push(i)
    assert_true(heap._capacity > initial_capacity)


fn test_larger_heap() raises:
    lst = List(5, 1, 7, 2, 9, 0, 2, 3, 4, 8, 7, 1, 3, 0, 9, 6, 8, 6, 5, 4)

    heap = MinMaxHeap(elements=lst)
    result = List[Int]()
    while heap:
        result.append(heap.pop_min())
    assert_equal(
        result, List(0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9)
    )

    heap = MinMaxHeap(elements=lst)
    result = List[Int]()
    while heap:
        result.append(heap.pop_max())
    assert_equal(
        result, List(9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0)
    )

    heap = MinMaxHeap(elements=lst)
    result = List[Int]()
    while heap:
        result.append(heap.pop_min())
        result.append(heap.pop_max())
    assert_equal(
        result, List(0, 9, 0, 9, 1, 8, 1, 8, 2, 7, 2, 7, 3, 6, 3, 6, 4, 5, 4, 5)
    )

    assert_equal(heap._capacity, 20)
    heap = MinMaxHeap[Int]()
    assert_equal(heap._capacity, 16)
    for e in lst:
        heap.push(e[])
    assert_equal(heap._capacity, 32)
    assert_equal(heap.get_min(), 0)
    assert_equal(heap.get_max(), 9)

