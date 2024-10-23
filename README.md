# Some missing data structures for Mojo

> Last tested on the Mojo nightly build: `mojo 2024.10.2319 (7120c0a4)`

### Instructions

To use the package, just copy the `datastructs.📦` from the `package` directory to your packages location or copy the `datastructs` directory and use it as a module. Then in your source code import what you need:
```mojo
from datastructs import Deque
```

To make a package from source:
```
mojo package datastructs -o package/datastructs.📦
```

To run all the tests:
```
mojo test -I . test
```

## Deque (Double-Ended Queue)

This implementation provides a double-ended queue (deque), built on a dynamically resizing circular buffer.
It supports efficient pushing and popping from both ends in O(1) time, as well as O(1) access to any element at any position in the deque.

As Mojo is designed to be a superset of Python, this Deque implementation supports the full Python `collections.deque` API,
along with additional methods and options for enhanced performance and flexibility.

### Supported Python API

The following Python `deque` methods are all implemented:\
`append`, `appendleft`, `clear`, `count`, `extend`, `extendleft`, `index`,\
`insert`, `remove`, `pop`, `popleft`, `reverse`, `rotate`.

Deque also supports equality comparisons and can be treated as a boolean value, where an empty deque evaluates to `False`,
and a non-empty deque evaluates to `True`.\
Membership tests `if element in deque` and iteration `for element in deque` work as expected.

In general, the Deque should function just like the Python deque.
If you're unfamiliar with the Python implementation, refer to the Python documentation for more details:\
[Python Collections Documentation](https://docs.python.org/3/library/collections.html#collections.deque).

### Additional Features

In addition to the Python API, Deque provides two convenience methods:
- `peek()`: Returns the last element without removing it.
- `peekleft()`: Returns the first element without removing it.

### Constructor Options for Optimization

Beyond Python’s `maxlen` argument, this Deque offers additional constructor options: `capacity`, `minlen`, and `shrink`.
These allow you to fine-tune the deque’s behavior for speed or memory usage based on your application’s needs.

By default, the deque allocates memory for 64 elements and adjusts its size automatically as needed.
However, if you want to optimize performance and reduce buffer reallocations, these additional options can be helpful:

- `capacity`: sets the initial size of the deque when created.
- `minlen`: ensures the buffer will retain memory for at least this many elements,\
even if the deque's actual size drops below that number.
- `shrink`: disables shrinking entirely when set to `shrink=False`.\
This ensures that the buffer only grows as needed but never shrinks, optimizing for performance at the cost of memory usage.

For example, if you expect your deque to quickly grow to 10'000 elements but rarely drop below 5'000,
you can initialize it with `Deque(capacity=10000, minlen=5000)`. This will reduce expensive buffer reallocations and improve performance.
Alternatively, if speed is the priority and memory usage is less of a concern, you can use `Deque(capacity=10000, shrink=False)`,
which allocates memory for 10'000 elements upfront and prevents shrinking altogether, anticipating future growth.

