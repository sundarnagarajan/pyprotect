#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
import unittest
import warnings
warnings.simplefilter("ignore")
del warnings

from test_utils import (
    CheckPredictions,
)

from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    freeze,
    private,
    protect,
    wrap,
)
import re


class C:
    pass


class CI(int):
    pass


class CF(float):
    pass


test_objects = [
    1, [1, 2, 3], {'a': 1, 'b': 2},
    re, C(), CI(10), CF(101.89),
]


class TestProtectedClass(unittest.TestCase):
    def test_01_wrap_objects(self):
        # Wrap a variety pf objects
        for o in test_objects:
            w = wrap(o)
            CheckPredictions(self, o, w)

    def test_02_private_objects(self):
        # Wrap a variety pf objects
        for o in test_objects:
            w = private(o)
            CheckPredictions(self, o, w)

    def test_03_protect_objects(self):
        # Wrap a variety pf objects
        for o in test_objects:
            w = protect(o)
            CheckPredictions(self, o, w)


if __name__ == '__main__':
    unittest.main()
