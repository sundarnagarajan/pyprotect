#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
from math import ceil, floor, trunc
import unittest
import warnings
warnings.simplefilter("ignore")
del warnings

from test_utils import (
    PY2,
    check_predictions,
    MultiWrap,
)
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    freeze, private, protect, wrap,
)
from testcases import gen_test_objects


class test_pyprotect(unittest.TestCase):
    def test_01_multiwrap_1300_tests(self):
        # 1300 sequences of freeze, wrap, private, protect for each 'o'
        for o in gen_test_objects():
            MultiWrap(o)

    def test_02_wrap_objects(self):
        # wrap() on a variety pf objects
        for o in gen_test_objects():
            w = wrap(o)
            check_predictions(o, w)
            f = freeze(w)
            check_predictions(o, f)

    def test_03_private_objects(self):
        # private() on a variety pf objects
        for o in gen_test_objects():
            w = private(o)
            check_predictions(o, w)
            f = freeze(w)
            check_predictions(o, f)
            w = private(o, frozen=True)
            check_predictions(o, w)

    def test_04_protect_objects(self):
        # protect() on a variety pf objects
        for o in gen_test_objects():
            w = protect(o, ro_method=False)
            check_predictions(o, w)
            f = freeze(w)
            check_predictions(o, f)
            w = protect(o)
            check_predictions(o, w)
            w = protect(o, frozen=True)
            check_predictions(o, w)

    def test_05_numeric_ops_int(self):
        class CI(int):
            pass

        n1 = CI(100)
        n2 = CI(100)
        i1 = 10
        i2 = 200
        i3 = 30
        for op in (wrap, freeze, private, protect):
            w1 = op(n1)
            w2 = op(n1)
            w3 = op(n2)

            # Equality works wrapped to wrapped
            assert(w1 == n1)
            assert(n1 == w1)
            assert(w1 == w2)
            # id(wrapped object) is not the same
            assert(w1 != w3)

            # For inequalities one of the objects must not be wrapped
            assert(i1 < w1)
            assert(i1 <= w1)
            assert(w1 > i1)
            assert(w1 >= i1)

            # For numeric operations, one of the operands must not be wrapped
            assert((i1 + w1) == 110)
            assert((w1 + i1) == 110)
            assert((w1 - i1) == 90)
            assert((i2 - w1) == 100)
            assert((i1 * w1) == 1000)
            assert((w1 * i1) == 1000)
            assert((w1 // i3) == 3)
            assert((w1 % i3) == 10)

            assert(ceil(w1) == 100)
            assert(floor(w1) == 100)
            assert(trunc(w1) == 100)
            assert(round(w1) == 100)

    def test_06_numeric_ops_float(self):
        class CF(float):
            pass

        n1 = CF(100.89)
        n2 = CF(100.89)
        f1 = 10.5
        f2 = 200.6
        i3 = 30
        for op in (wrap, freeze, private, protect):
            w1 = op(n1)
            w2 = op(n1)
            w3 = op(n2)

            # Equality works wrapped to wrapped
            assert(w1 == n1)
            assert(n1 == w1)
            assert(w1 == w2)
            # id(wrapped object) is not the same
            assert(w1 != w3)

            # For inequalities one of the objects must not be wrapped
            assert(f1 < w1)
            assert(f1 <= w1)
            assert(w1 > f1)
            assert(w1 >= f1)

            # For numeric operations, one of the operands must not be wrapped
            assert((f1 + w1) == 111.39)
            assert((w1 + f1) == 111.39)
            assert((w1 - f1) == 90.39)
            assert((f2 - w1) == 99.71)
            assert((f1 * w1) == 1059.345)
            assert((w1 * f1) == 1059.345)
            assert((w1 // i3) == 3.0)
            assert((w1 % i3) == 10.89)

            assert(ceil(w1) == 101)
            assert(floor(w1) == 100)
            assert(trunc(w1) == 100)
            assert(round(w1) == 101)
            # PY2 does not have truediv
            if not PY2:
                assert((w1 / i3) == 3.363)

    def test_07_mutating_numeric_ops_int(self):
        '''
        Mutates wrapped object. This TC does not use freeze - all
        operations should succeed
        '''

        class CI(int):
            pass

        n1 = CI(100)
        i1 = 10
        i2 = 30
        for op in (wrap, private, protect):
            w1 = op(n1)

            w1 += i1
            assert(w1 == (n1 + i1))
            w1 -= i1
            assert(w1 == n1)
            w1 *= i1
            assert(w1 == (n1 * i1))
            w1 //= i1
            assert(w1 == n1)
            w1 *= i1
            # PY2 does not have truediv
            if not PY2:
                w1 /= i1
                assert(w1 == n1)
            w1 %= i2
            assert(w1 == 10)

    def test_08_mutating_numeric_ops_float(self):
        '''
        Mutates wrapped object. This TC does not use freeze - all
        operations should succeed
        '''

        class CF(float):
            pass

        n1 = CF(100.0)
        i1 = 10.0
        i2 = 30.0
        for op in (wrap, private, protect):
            w1 = op(n1)

            w1 += i1
            assert(w1 == (n1 + i1))
            w1 -= i1
            assert(w1 == n1)
            w1 *= i1
            assert(w1 == (n1 * i1))
            w1 //= i1
            assert(w1 == n1)
            w1 *= i1
            # PY2 does not have truediv
            if not PY2:
                w1 /= i1
                assert(w1 == n1)
            w1 %= i2
            assert(w1 == 10)

    def test_08_mutating_numeric_ops_int_frozen(self):
        '''
        Mutates wrapped object. This TC uses use freeze - all
        operations should FAIL
        '''

        class MissingExceptionError(Exception):
            pass

        class CI(int):
            pass

        n1 = CI(100)
        i1 = 10
        i2 = 30
        w1 = freeze(n1)

        try:
            w1 += i1
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

        try:
            w1 -= i1
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

        try:
            w1 *= i1
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

        try:
            w1 //= i1
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

        # PY2 does not have truediv
        if not PY2:
            try:
                w1 /= i1
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

        try:
            w1 %= i2
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

    def test_09_logical_ops(self):
        class CI(int):
            pass

        n1 = CI(0b10101010)
        n2 = CI(0b01010101)
        for op in (wrap, freeze, private, protect):
            w = op(n1)
            assert((w & n2) == 0)
            assert((w | n2) == 255)
            assert((w ^ n2) == 255)
            assert((w ^ n1) == 0)

            assert((n2 & w) == 0)
            assert((n2 | w) == 255)
            assert((n2 ^ w) == 255)
            assert((n1 ^ w) == 0)

    def test_10_mutating_logical_ops(self):
        '''
        Mutates wrapped object. This TC does not use freeze - all
        operations should succeed
        '''
        class CI(int):
            pass

        n2 = CI(0b01010101)
        for op in (wrap, private, protect):

            n1 = CI(0b10101010)
            w = op(n1)
            w &= n2
            assert(w == 0)

            n1 = CI(0b10101010)
            w = op(n1)
            w |= n2
            assert(w == 255)

            n1 = CI(0b10101010)
            w = op(n1)
            w ^= n2
            assert(w == 255)

            n1 = CI(0b10101010)
            w = op(n1)
            w ^= n1
            assert(w == 0)

    def test_10_mutating_logical_ops_frozen(self):
        '''
        Mutates wrapped object. This TC uses use freeze - all
        operations should FAIL
        '''

        class MissingExceptionError(Exception):
            pass

        class CI(int):
            pass

        op = freeze
        n2 = CI(0b01010101)

        n1 = CI(0b10101010)
        w = op(n1)
        try:
            w &= n2
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

        n1 = CI(0b10101010)
        w = op(n1)
        try:
            w |= n2
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

        n1 = CI(0b10101010)
        w = op(n1)
        try:
            w ^= n2
            raise MissingExceptionError('Expected Exception not raised')
        except MissingExceptionError:
            raise
        except:
            pass

    def test_12_mutating_containers(self):
        pass


if __name__ == '__main__':
    unittest.main(verbosity=2)
