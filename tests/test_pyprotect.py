#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
import re
import unittest
import warnings
warnings.simplefilter("ignore")
del warnings

from test_utils import (
    check_predictions,
    MultiWrap,
)
from cls_gen import generate
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    freeze, private, protect, wrap,
)


def gen_test_objects():
    '''generator'''
    class C:
        pass

    class CI(int):
        pass

    class CF(float):
        pass

    cls_obj = generate(obj_derived=True)['class']
    cls_obj_nested = generate(
        obj_derived=True,
        nested=True, depth=1000, no_cycles=False,
    )['class']
    cls_nonobj = generate(obj_derived=False)['class']
    cls_nonobj_nested = generate(
        obj_derived=False,
        nested=True, depth=1000, no_cycles=False,
    )['class']

    l = [
        1, [1, 2, 3], {'a': 1, 'b': 2},
        C(),
        CI, CF,
        CI(10), CF(101.89),
        cls_obj,
        cls_nonobj,
        cls_obj_nested,
        cls_nonobj_nested,
        cls_obj(),
        cls_nonobj(),
        cls_obj_nested(),
        cls_nonobj_nested(),
        re,
    ]
    for o in l:
        yield o


test_objects = gen_test_objects()


class test_pyprotect(unittest.TestCase):
    def test_01_multiwrap_1300_tests(self):
        # 1300 sequences of freeze, wrap, private, protect for each 'o'
        for o in test_objects:
            MultiWrap(o)

    def test_02_wrap_objects(self):
        # wrap() on a variety pf objects
        for o in test_objects:
            w = wrap(o)
            check_predictions(o, w)
            f = freeze(w)
            check_predictions(o, f)

    def test_03_private_objects(self):
        # private() on a variety pf objects
        for o in test_objects:
            w = private(o)
            check_predictions(o, w)
            f = freeze(w)
            check_predictions(o, f)
            w = private(o, frozen=True)
            check_predictions(o, w)

    def test_04_protect_objects(self):
        # protect() on a variety pf objects
        for o in test_objects:
            w = protect(o, ro_method=False)
            check_predictions(o, w)
            f = freeze(w)
            check_predictions(o, f)
            w = protect(o)
            check_predictions(o, w)
            w = protect(o, frozen=True)
            check_predictions(o, w)


if __name__ == '__main__':
    unittest.main()
