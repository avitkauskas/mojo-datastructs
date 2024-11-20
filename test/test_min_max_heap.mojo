from testing import assert_equal, assert_false, assert_true, assert_raises

from datastructs import MinMaxHeap

# ===----------------------------------------------------------------------===#
# Implementation tests
# ===----------------------------------------------------------------------===#


fn test_impl_init_default() raises:
    heap = MinMaxHeap[Int]()

    assert_equal(heap._capacity, heap.default_capacity)
    assert_equal(heap._size, 0)


fn test_impl_init_capacity() raises:
    heap = MinMaxHeap[Int](capacity=-10)
    assert_equal(heap._capacity, heap.default_capacity)

    heap = MinMaxHeap[Int](capacity=0)
    assert_equal(heap._capacity, heap.default_capacity)

    heap = MinMaxHeap[Int](capacity=10)
    assert_equal(heap._capacity, 10)


fn test_impl_init_variadic() raises:
    heap = MinMaxHeap(1, 3, 2, 4)

    assert_equal(heap._size, 4)
    assert_equal(heap._capacity, heap.default_capacity)
    # Check min-max heap property
    assert_equal(heap.get_min(), 1)
    assert_equal(heap.get_max(), 4)


fn test_impl_len() raises:
    heap = MinMaxHeap[Int]()
    assert_equal(len(heap), 0)

    heap.push(1)
    assert_equal(len(heap), 1)

    heap.push(2)
    assert_equal(len(heap), 2)


fn test_impl_bool() raises:
    heap = MinMaxHeap[Int]()
    assert_false(heap)

    heap.push(1)
    assert_true(heap)


fn test_impl_push() raises:
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


fn test_impl_pop_min() raises:
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


fn test_impl_pop_max() raises:
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


fn test_impl_get_min() raises:
    heap = MinMaxHeap[Int]()

    with assert_raises():
        _ = heap.get_min()

    heap.push(3)
    assert_equal(heap.get_min(), 3)

    heap.push(1)
    assert_equal(heap.get_min(), 1)

    heap.push(4)
    assert_equal(heap.get_min(), 1)


fn test_impl_get_max() raises:
    heap = MinMaxHeap[Int]()

    with assert_raises():
        _ = heap.get_max()

    heap.push(3)
    assert_equal(heap.get_max(), 3)

    heap.push(1)
    assert_equal(heap.get_max(), 3)

    heap.push(4)
    assert_equal(heap.get_max(), 4)


fn test_impl_clear() raises:
    heap = MinMaxHeap[Int]()
    heap.push(1)
    heap.push(2)
    heap.push(3)

    assert_equal(heap._size, 3)
    heap.clear()
    assert_equal(heap._size, 0)
    assert_false(heap)


# ===----------------------------------------------------------------------===#
# API Interface tests
# ===----------------------------------------------------------------------===#


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
    """Tests that the min-max heap property is maintained after operations."""
    heap = MinMaxHeap[Int]()

    heap.push(5)
    heap.push(3)
    heap.push(7)
    heap.push(1)
    heap.push(9)
    heap.push(4)

    assert_equal(heap.get_min(), 1)  # Root is smallest
    assert_equal(heap.get_max(), 9)  # Level 1 has largest


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
