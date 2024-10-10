# Some missing data structures for mojo

> Tested on the Mojo nightly build `mojo 2024.10.1005 (512c2f1c)`

## Deque (double-ended queue)

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
