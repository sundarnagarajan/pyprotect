#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
import re
import unittest
import warnings
warnings.simplefilter("ignore")
del warnings

from test_utils import (
    CheckPredictions,
)
from cls_gen import generate
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    freeze,
    private,
    protect,
    wrap,
)


class C:
    pass


class CI(int):
    pass


class CF(float):
    pass


nested_obj = generate(nested=True, depth=1000, no_cycles=False)['class']()

test_objects = [
    1, [1, 2, 3], {'a': 1, 'b': 2},
    C(), CI(10), CF(101.89), nested_obj, re
]


class TestProtectedClass(unittest.TestCase):
    def test_01_wrap_objects(self):
        # Wrap a variety pf objects
        for o in test_objects:
            w = wrap(o)
            CheckPredictions(self, o, w)
            f = freeze(w)
            CheckPredictions(self, o, f)

    def test_02_private_objects(self):
        # Wrap a variety pf objects
        for o in test_objects:
            w = private(o)
            CheckPredictions(self, o, w)
            f = freeze(w)
            CheckPredictions(self, o, f)

    def test_03_protect_objects(self):
        # Wrap a variety pf objects
        for o in test_objects:
            w = protect(o, ro_method=False)
            CheckPredictions(self, o, w)
            f = freeze(w)
            CheckPredictions(self, o, f)


if __name__ == '__main__':
    unittest.main()
