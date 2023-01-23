
import sys
cdef bint PY2
cdef object builtin_module
if sys.version_info.major > 2:
    PY2 = False
    builtin_module = sys.modules['builtins']
    import collections.abc as CollectionsABC
else:
    PY2 = True
    builtin_module = sys.modules['__builtin__']
    import collections as CollectionsABC
import platform
PYPY = (platform.python_implementation() == 'PyPy')
del platform
import os
import re
import types
import functools
import pydoc
import math
if PYPY and PY2:
    int = long
