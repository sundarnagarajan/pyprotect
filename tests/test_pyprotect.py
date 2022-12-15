#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
from math import ceil, floor, trunc
from functools import partial
import unittest
import warnings
warnings.simplefilter("ignore")
del warnings

from test_utils import (
    PY2,
    check_predictions,
    MultiWrap,
    get_pydoc,
    PROT_ATTR,
    CheckPredictions,
    pickle_attributes,
    always_delegated,
    always_frozen,
)
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    freeze, private, protect, wrap,
    iswrapped,
)
from testcases import gen_test_objects
from cls_gen import generate


class MissingExceptionError(Exception):
    pass


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

    def test_09_mutating_numeric_ops_int_frozen(self):
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

    def test_10_logical_ops(self):
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

    def test_11_mutating_logical_ops(self):
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

    def test_12_mutating_logical_ops_frozen(self):
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

    def test_13_containers(self):
        l1 = [1, 2, 3]
        l2 = [3, 4, 5]
        s1 = set(l1)
        s2 = set(l2)
        d1 = {'a': 1, 'b': 2}

        for op in (wrap, private, protect, freeze):
            w = op(l1)
            assert(list(w + l2) == [1, 2, 3, 3, 4, 5])
            assert(w[1] == 2)
            assert(w[1:] == [2, 3])
            assert(w[:-1] == [1, 2])
            assert(w[-2:] == [2, 3])

            w = op(s1)
            assert(w.union(s2) == s1.union(s2))
            assert(w.intersection(s2) == s1.intersection(s2))
            assert(w.symmetric_difference(s2) == s1.symmetric_difference(s2))
            assert((w & s2) == (s1 & s2))
            assert((w | s2) == (s1 | s2))
            assert((w ^ s2) == (s1 ^ s2))
            assert((set(w & s2)) == set(w.intersection(s2)))
            assert(set(w | s2) == set(w.union(s2)))
            assert(set(w ^ s2) == set(w.symmetric_difference(s2)))

            w = op(d1)
            assert(w['a'] == 1)

            assert(
                set(list(w.items())) == set([
                    ('a', 1), ('b', 2),
                ])
            )

    def test_14_mutating_containers(self):
        l1 = [1, 2, 3]
        l2 = [3, 4, 5]
        s1 = set(l1)
        s2 = set(l2)
        d2 = {'b': 20, 'c': 3}

        for op in (wrap, private, protect):
            # Mutating operations
            w = op([1, 2, 3])
            w += l2
            assert(w == [1, 2, 3, 3, 4, 5])

            w = op([1, 2, 3])
            del w[1]
            assert(list(w) == [1, 3])

            w = op([1, 2, 3])
            w *= 3
            assert(w == [1, 2, 3, 1, 2, 3, 1, 2, 3])

            w = op([1, 2, 3])
            # pop(ind) pops out item at pos -ind
            w.pop(1)
            assert(list(w) == [1, 3])

            w = op([1, 2, 3])
            w.remove(3)
            assert(list(w) == [1, 2])

            w = op([1, 2, 3])
            w.reverse()
            assert(w == [3, 2, 1])

            w = op([1, 2, 3])
            w.sort()
            assert(w == [1, 2, 3])

            w = op(set([1, 2, 3]))
            w &= s2
            assert(w == (s1 & s2))

            w = op(set([1, 2, 3]))
            w |= s2
            assert(w == (s1 | s2))

            w = op(set([1, 2, 3]))
            w ^= s2

            w = op({'a': 1, 'b': 2})
            w.clear()
            assert(w == {})

            w = op({'a': 1, 'b': 2})
            assert(w.pop('a') == 1)

            w = op({'a': 1, 'b': 2})
            w.update(d2)
            assert(w == {'a': 1, 'b': 20, 'c': 3})

            w = op({'a': 1, 'b': 2})
            x = w.popitem()
            # popitem is non-deterministic in PY2 (like dict order)
            if PY2:
                assert(len(x) == 2)
            else:
                assert(x == ('b', 2))

            w = op({'a': 1, 'b': 2})
            assert(w.setdefault('c', None) is None)

            x = w.setdefault('d', 4)
            assert(x == 4)
            x = w.setdefault('d')
            assert(x == 4)

    def test_15_mutating_containers_frozen(self):
        l1 = [1, 2, 3]
        l2 = [3, 4, 5]
        s1 = set(l1)
        s2 = set(l2)
        d2 = {'b': 20, 'c': 3}

        ops = (
            freeze,
            partial(private, frozen=True),
            partial(protect, frozen=True),
        )
        for op in ops:
            # Mutating operations
            w = op([1, 2, 3])
            try:
                w += l2
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                del w[1]
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w *= 3
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                # pop(ind) pops out item at pos -ind
                w.pop(1)
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.remove(3)
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.reverse()
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.sort()
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            w = op(s1)
            try:
                w &= s2
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w |= s2
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w ^= s2
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            w = op({'a': 1, 'b': 2})
            try:
                w.clear()
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.pop('a')
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.update(d2)
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.popitem()
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.setdefault('c', None)
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.setdefault('d', 4)
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

            try:
                w.setdefault('d')
                raise MissingExceptionError('Expected Exception not raised')
            except MissingExceptionError:
                raise
            except:
                pass

    def test_16_private_vs_wrapped(self):
        # In PY2, this is a 'new style class', and will behave just like
        # classes in PY3 when wrapped
        class NewStyleClassInPY2(object):
            __pvt = 1
            _ShouldBeVisible__abc = 2
            _ShouldBeVisible__def_ = 3
            _ro = 4
            a = 5

        # ---------- NewStyleClassInPY2 identical in PY2 | PY3 ---------------
        # Test wrapping CLASS itself
        o = NewStyleClassInPY2
        w = wrap(o)
        p = private(o)

        cpw = CheckPredictions(o, w)
        dw = cpw.get_predictions()

        cpp = CheckPredictions(o, p)
        dp = cpp.get_predictions()

        # Run standard checks
        cpw.check(dw)
        cpp.check(dp)

        # Check the Private-related predictions
        s1 = dw['predictions']['addl_hide']
        s2 = dp['predictions']['addl_hide']
        self.assertSetEqual(
            s2.difference(s1),
            set().union(
                set([
                    '_NewStyleClassInPY2__pvt',
                ]),
            )
        )
        s1 = dw['predictions']['addl_ro']
        s2 = dp['predictions']['addl_ro']
        self.assertSetEqual(
            s2.difference(s1), set([
                '_ShouldBeVisible__abc',
                # But NOT _ShouldBeVisible__def_ (ends in '_')
                '_ro',
            ])
        )
        # Now test wrapping INSTANCE of the class
        o = NewStyleClassInPY2()
        w = wrap(o)
        p = private(o)

        cpw = CheckPredictions(o, w)
        dw = cpw.get_predictions()

        cpp = CheckPredictions(o, p)
        dp = cpp.get_predictions()

        # Run standard checks
        cpw.check(dw)
        cpp.check(dp)

        # Check the Private-related predictions
        s1 = dw['predictions']['addl_hide']
        s2 = dp['predictions']['addl_hide']
        self.assertSetEqual(
            s2.difference(s1),
            set().union(
                set([
                    '_NewStyleClassInPY2__pvt',
                ]),
            )
        )

        s1 = dw['predictions']['addl_ro']
        s2 = dp['predictions']['addl_ro']
        self.assertSetEqual(
            s2.difference(s1), set([
                '_ShouldBeVisible__abc',
                # But NOT _ShouldBeVisible__def_ (ends in '_')
                '_ro',
            ])
        )

    def test_17_private_vs_wrapped_py2_oldstyle(self):
        # In PY3, this class behaves as usual when wrapped
        # In PY2 INSTANCES of this class behave as usual
        class OldStyleClassInPY2:
            __pvt = 1
            _ShouldBeVisible__abc = 2
            _ShouldBeVisible__def_ = 3
            _ro = 4
            a = 5

        # ---------- OldStyleClassInPY2 DIFFERENT in PY2 | PY3 ---------------
        # Test wrapping CLASS itself
        o = OldStyleClassInPY2
        w = wrap(o)
        p = private(o)

        cpw = CheckPredictions(o, w)
        dw = cpw.get_predictions()

        cpp = CheckPredictions(o, p)
        dp = cpp.get_predictions()

        # Run standard checks
        cpw.check(dw)
        cpp.check(dp)

        # Check the Private-related predictions
        s1 = dw['predictions']['addl_hide']
        s2 = dp['predictions']['addl_hide']
        if PY2:
            self.assertSetEqual(
                s2.difference(s1), set().union(
                    set([
                        '_OldStyleClassInPY2__pvt',
                        # Following additionally hidden in old-style CLASSES
                        # (not INSTANCES of old-style classes) in PY2
                        '_ShouldBeVisible__abc',
                        '_ShouldBeVisible__def_',
                    ]),
                )
            )
        else:
            self.assertSetEqual(
                s2.difference(s1), set().union(
                    set([
                        '_OldStyleClassInPY2__pvt',
                    ]),
                )
            )
        s1 = dw['predictions']['addl_ro']
        s2 = dp['predictions']['addl_ro']
        if PY2:
            self.assertSetEqual(
                s2.difference(s1), set([
                    '_ro',
                ])
            )
        else:
            self.assertSetEqual(
                s2.difference(s1), set([
                    '_ShouldBeVisible__abc',
                    # But NOT _ShouldBeVisible__def_ (ends in '_')
                    '_ro',
                ])
            )
        # Now test wrapping INSTANCE of the class
        # Behavior should be the SAME in PY2, PY3
        o = OldStyleClassInPY2()
        w = wrap(o)
        p = private(o)

        cpw = CheckPredictions(o, w)
        dw = cpw.get_predictions()

        cpp = CheckPredictions(o, p)
        dp = cpp.get_predictions()

        # Run standard checks
        cpw.check(dw)
        cpp.check(dp)

        # Check the Private-related predictions
        s1 = dw['predictions']['addl_hide']
        s2 = dp['predictions']['addl_hide']
        if PY2:
            self.assertSetEqual(
                s2.difference(s1), set().union(
                    set([
                        '_OldStyleClassInPY2__pvt',
                    ]),
                )
            )
        else:
            self.assertSetEqual(
                s2.difference(s1), set().union(
                    set([
                        '_OldStyleClassInPY2__pvt',
                    ]),
                )
            )
        s1 = dw['predictions']['addl_ro']
        s2 = dp['predictions']['addl_ro']
        self.assertSetEqual(
            s2.difference(s1), set([
                '_ShouldBeVisible__abc',
                # But NOT _ShouldBeVisible__def_ (ends in '_')
                '_ro',
            ])
        )

    def test_18_protected_options(self):
        d = generate(obj_derived=True, nested=False)
        cls = d['class']
        o = cls()

        '''
        Parameters to test:
            - hide_private
            - hide
            - ro_data
            - ro_method
            - ro
            - rw
        '''
        #  --------------- protect equivalent to private ---------------
        p1 = private(o)
        p2 = protect(o, ro_method=False)
        cp1 = CheckPredictions(o, p1)
        cp2 = CheckPredictions(o, p2)
        dp1 = cp1.get_predictions()
        dp2 = cp2.get_predictions()
        # hp: hidden private attr
        hp = [x for x in d['props']['pvt_attr']][0]
        hp = hp.replace('__', '_%s__' % d['class'].__name__)
        hp = set([hp])
        methods = set()
        attrs = set()
        for a in dir(o):
            if hasattr(cls, a):
                x = getattr(cls, a)
                if isinstance(x, property):
                    continue
            if callable(getattr(o, a)):
                methods.add(a)
            else:
                if a in always_delegated:
                    continue
                attrs.add(a)

        # Run standard checks
        cp1.check(dp1)
        cp2.check(dp2)

        self.assertSetEqual(
            dp1['predictions']['addl_hide'],
            dp2['predictions']['addl_hide'],
        )
        self.assertSetEqual(
            dp1['predictions']['addl_ro'],
            dp2['predictions']['addl_ro'],
        )

        #  --------------- hide_private ---------------
        p = protect(o, hide_private=True, ro_method=False)
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                pickle_attributes,
                hp,
            ),
            dp['predictions']['addl_hide']
        )

        #  --------------- hide only ------------------
        p = protect(o, ro_method=False, hide=list(d['props']['normal_attr']))
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                pickle_attributes,
                hp,
                set(d['props']['normal_attr']),
            ),
            dp['predictions']['addl_hide']
        )

        #  --------------- hide_private + hide --------
        p = protect(
            o,
            ro_method=False,
            hide_private=True,
            hide=list(d['props']['normal_attr'])
        )
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                pickle_attributes,
                hp,
                set(d['props']['normal_attr']),
                d['props']['ro_attr'],
            ),
            dp['predictions']['addl_hide']
        )

        #  --------------- ro_method only -------------
        p = protect(o, ro_method=True)
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                methods,
                # special_attributes in 'addl_visible' and in 'addl_ro'
                # TODO: Why not always_frozen?
                # always_frozen,
            ),
            dp['predictions']['addl_ro']
        )
        #  --------------- ro_data only ---------------
        p = protect(o, ro_method=False, ro_data=True)
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                attrs,
                # special_attributes in 'addl_visible' and in 'addl_ro'
                # TODO: Why not always_frozen?
                # always_frozen,
            ),
            dp['predictions']['addl_ro']
        )

        #  --------------- ro only --------------------
        p = protect(
            o, ro_method=False, ro_data=False,
            ro=list(
                set().union(
                    d['props']['normal_attr_ro'],
                    d['props']['dunder_inst_methods_ro'],
                )
            )
        )
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                # special_attributes in 'addl_visible' and in 'addl_ro'
                # TODO: Why not always_frozen?
                d['props']['normal_attr_ro'],
                d['props']['dunder_inst_methods_ro'],
                # TODO: Why not always_frozen?
                # always_frozen,
            ),
            dp['predictions']['addl_ro']
        )

        #  ---------- ro_data, ro_method, ro ----------
        p = protect(
            o, ro_method=True, ro_data=True,
            ro=list(
                set().union(
                    d['props']['normal_attr_ro'],
                    d['props']['dunder_inst_methods_ro'],
                )
            )
        )
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                methods,
                attrs,
                d['props']['normal_attr_ro'],
                d['props']['dunder_inst_methods_ro'],
                d['props']['ro_attr'],
                # special_attributes part of ro_data
                # TODO: Why not always_frozen?
                # always_frozen,
            ),
            dp['predictions']['addl_ro']
        )

        #  ---------- ro_data, ro_method, ro PLUS rw ----------
        p = protect(
            o, ro_method=True, ro_data=True,
            ro=list(
                set().union(
                    d['props']['normal_attr_ro'],
                    d['props']['dunder_inst_methods_ro'],
                )
            ),
            rw=list(
                set().union(
                    d['props']['normal_attr_rw_over'],
                    d['props']['dunder_inst_methods_rw_over'],
                )
            )
        )
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        self.assertSetEqual(
            set().union(
                methods,
                attrs,
                d['props']['normal_attr_ro'],
                d['props']['dunder_inst_methods_ro'],
                d['props']['ro_attr'],
                # special_attributes part of ro_data
                # TODO: Why not always_frozen?
                # always_frozen,
            ).difference(set().union(
                d['props']['normal_attr_rw_over'],
                d['props']['dunder_inst_methods_rw_over'],
            )),
            dp['predictions']['addl_ro']
        )

    def test_19_help(self):
        for o in gen_test_objects():
            for op in (wrap, freeze, private, protect):
                w = op(o)
                if not iswrapped(w):
                    continue
                h1 = get_pydoc(o)
                p = getattr(w, PROT_ATTR)
                h2 = p.help_str()
                assert(h1 == h2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
