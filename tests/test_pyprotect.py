#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
from math import ceil, floor, trunc
from functools import partial
import pickle
from itertools import permutations
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
    isfrozen, isprotected, isprivate, isimmutable,
)
import platform
PYPY = (platform.python_implementation() == 'PyPy')
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    freeze, private, protect, wrap,
    iswrapped,
)
from testcases import gen_test_objects
from cls_gen import generate


# In PY2, this is a 'new style class', and will behave just like
# classes in PY3 when wrapped
# In test_05_private_vs_wrapped instantiating NewStyleClassInPY2
# using:
#   o = NewStyleClassInPY2()
# fails ONLY in PYPY2 and ONLY when instantiation is NOT at the
# module scope (within a function)
# Exception message is:
# TypeError: unbound method __new__() must be called with
# NewStyleClassInPY2 instance as first argument (got type instance
# instead)
#
# See also:
# https://github.com/gevent/gevent/issues/1709#issuecomment-735290530
class NewStyleClassInPY2(object):
    __pvt = 1
    _ShouldBeVisible__abc = 2
    _ShouldBeVisible__def_ = 3
    _ro = 4
    a = 5


_inst_NewStyleClassInPY2 = NewStyleClassInPY2()


def protected_merge_kwargs(kw1, kw2):
    '''
    Merges kw1 and kw2 to return dict with most restrictive options
    kw1, kw2: dict
    Returns: dict
    Called once by protect() before Protected class initialization
    '''
    (kw1, kw2) = (dict(kw1), dict(kw2))
    d = {}
    # Permissive bool options - must be 'and-ed'
    # dynamic defaults to True
    a = 'dynamic'
    d[a] = (kw1.get(a, True) and kw2.get(a, True))

    # Restrictive bool options must be 'or-ed'
    for a in (
        'frozen', 'hide_private', 'ro_data', 'ro_method',
    ):
        d[a] = (kw1.get(a, False) or kw2.get(a, False))

    # Restrictive lists (non-bool) are unioned
    for a in (
        'ro', 'hide',
    ):
        s1 = set(list(kw1.get(a, [])))
        s2 = set(list(kw2.get(a, [])))
        d[a] = list(
            s1.union(s2)
        )
    # Permissive lists (non-bool) are intersected
    for a in (
        'rw',
    ):
        s1 = set(list(kw1.get(a, [])))
        s2 = set(list(kw2.get(a, [])))
        d[a] = list(
            s1.intersection(s2)
        )
    return d


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

    def test_05_private_vs_wrapped(self):
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
        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            s2.difference(s1), set([
                '_ShouldBeVisible__abc',
                # But NOT _ShouldBeVisible__def_ (ends in '_')
                '_ro',
            ]).union(frozen_present)
        )
        # Now test wrapping INSTANCE of the class
        #
        # Fixing TEST here with a PYPY-specific "hack"
        if PY2 and PYPY:
            o = _inst_NewStyleClassInPY2
        else:
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
        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            s2.difference(s1), set([
                '_ShouldBeVisible__abc',
                # But NOT _ShouldBeVisible__def_ (ends in '_')
                '_ro',
            ]).union(frozen_present)
        )

    def test_06_private_vs_wrapped_py2_oldstyle(self):
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
        frozen_present = dp['w']['readable'].intersection(always_frozen)
        if PY2:
            self.assertSetEqual(
                s2.difference(s1), set([
                    '_ro',
                ]).union(frozen_present)
            )
        else:
            self.assertSetEqual(
                s2.difference(s1), set([
                    '_ShouldBeVisible__abc',
                    # But NOT _ShouldBeVisible__def_ (ends in '_')
                    '_ro',
                ]).union(frozen_present)
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
        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            s2.difference(s1), set([
                '_ShouldBeVisible__abc',
                # But NOT _ShouldBeVisible__def_ (ends in '_')
                '_ro',
            ]).union(frozen_present)
        )

    def test_07_protected_options(self):
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

        pickle_present = dp['o']['readable'].intersection(pickle_attributes)
        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                pickle_present,
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

        pickle_present = dp['o']['readable'].intersection(pickle_attributes)
        self.assertSetEqual(
            set().union(
                pickle_present,
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

        pickle_present = dp['o']['readable'].intersection(pickle_attributes)
        self.assertSetEqual(
            set().union(
                pickle_present,
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

        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                methods,
                # special_attributes in 'addl_visible' and in 'addl_ro'
                frozen_present,
            ),
            dp['predictions']['addl_ro']
        )
        #  --------------- ro_data only ---------------
        p = protect(o, ro_method=False, ro_data=True)
        cp = CheckPredictions(o, p)
        dp = cp.get_predictions()

        # Run standard checks
        cp.check(dp)

        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                attrs,
                # special_attributes in 'addl_visible' and in 'addl_ro'
                frozen_present,
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

        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            set().union(
                d['props']['ro_attr'],
                # special_attributes in 'addl_visible' and in 'addl_ro'
                d['props']['normal_attr_ro'],
                d['props']['dunder_inst_methods_ro'],
                frozen_present,
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

        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            set().union(
                methods,
                attrs,
                d['props']['normal_attr_ro'],
                d['props']['dunder_inst_methods_ro'],
                d['props']['ro_attr'],
                # special_attributes part of ro_data
                frozen_present,
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

        frozen_present = dp['w']['readable'].intersection(always_frozen)
        self.assertSetEqual(
            set().union(
                methods,
                attrs,
                d['props']['normal_attr_ro'],
                d['props']['dunder_inst_methods_ro'],
                d['props']['ro_attr'],
                # special_attributes part of ro_data
                frozen_present,
            ).difference(set().union(
                d['props']['normal_attr_rw_over'],
                d['props']['dunder_inst_methods_rw_over'],
            )),
            dp['predictions']['addl_ro']
        )

    def test_08_protect_frozen_functions(self):
        class C(object):
            def instfn(self):
                def inner1():
                    def inner2():
                        return C

                    return inner2

                return inner1

            @classmethod
            def clsfn(cls):
                def inner1():
                    def inner2():
                        return C

                    return inner2

                return inner1

        # First test the INSTANCE of C
        o = C()
        w1 = protect(o, ro_method=False, ro=['instfn', 'clsfn'])
        x = w1.instfn
        assert(isfrozen(x))
        x = x()    # inner1
        assert(isfrozen(x))
        x = x()    # inner2
        assert(isfrozen(x))
        x = x()    # C
        assert(isfrozen(x))

        # First test wrapping the class C
        w1 = protect(C, ro_method=False, ro=['instfn', 'clsfn'])
        x = w1.clsfn
        assert(isfrozen(x))
        x = x()    # inner1
        assert(isfrozen(x))
        x = x()    # inner2
        assert(isfrozen(x))
        x = x()    # C
        assert(isfrozen(x))

    def test_09_pickling_disabled(self):
        o = [1, 2, 3]
        # Show that pickling works for 'o'
        pb = pickle.dumps(o)
        po = pickle.loads(pb)
        assert(o == po)

        for op in wrap, freeze, private, protect:
            w = op(o)
            with self.assertRaises(pickle.PicklingError):
                pb = pickle.dumps(w)

    def test_10_str_repr(self):
        for o in gen_test_objects():
            for op in (wrap, freeze, private, protect):
                '''
                We assume that __str__ or __repr__ of wrapped object MAY
                raise an exception (perhaps too deeply nested ....
                '''
                w = op(o)

                exc1 = None
                r1 = None
                s1 = None
                try:
                    r1 = repr(o)
                    s1 = str(o)
                except:
                    exc1 = True

                exc2 = None
                r2 = None
                s2 = None
                try:
                    r2 = repr(w)
                    s2 = str(w)
                except:
                    exc2 = True

                assert(exc1 == exc2)
                assert(r1 == r2)
                assert(s1 == s2)

    def test_11_hashable_if_wrapped_is(self):
        # non-objtect-derived, no __hash__
        class C1:
            pass

        class C2(object):
            pass

        class C3:
            def __init__(self):
                self.__a = 1

            def __hash__(self):
                return hash(self.__a)

        class C4(object):
            def __init__(self):
                self.__a = 1

            def __hash__(self):
                return hash(self.__a)

        hashable_tuple = (1, 2, 3)
        unhashable_list = [1, 2, 3]
        unhashable_dict = {'a': 1, 'b': 2}
        unhashable_set = set([1, 2, 3])
        hashable_frozenset = frozenset(unhashable_set)

        for o in gen_test_objects():
            for op in (wrap, freeze, private, protect):
                w = op(o)

                exc1 = None
                exc2 = None
                try:
                    hash(o)
                except:
                    exc1 = True
                try:
                    hash(w)
                except:
                    exc2 = True
                assert(exc1 == exc2)

        for o in (
            C1, C2, C3, C4, C1(), C2(), C3(), C4(),
            hashable_tuple,
            unhashable_list, unhashable_dict, unhashable_set,
            hashable_frozenset,
        ):
            for op in (wrap, freeze, private, protect):
                w = op(o)

                exc1 = None
                exc2 = None
                try:
                    hash(o)
                except:
                    exc1 = True
                try:
                    hash(w)
                except:
                    exc2 = True
                assert(exc1 == exc2)

    def test_12_multiwrap_explicit(self):
        # Test rewrap logic explicitly
        class C1(object):
            __pvt1 = 1
            _ro1 = 2
            a = 3

            def __init__(self):
                self.__pvt2 = 4
                self.__ro2 = 5
                self.b = 6

        o1 = C1()

        test_objects = (
            1,                     # immutable
            frozenset([1, 2, 3]),  # immutable
            [1, 2, 3],             # mutable
            C1, o1
        )

        ops = [wrap, freeze, private, protect]
        seqs = permutations(ops, r=2)

        for (op1, op2) in seqs:
            for o in test_objects:
                w1 = op1(o)
                w2 = op2(w1)

                if op1 == op2:
                    assert(w1 is w2)
                if freeze in (op1, op2):
                    if isimmutable(o):
                        if op1 is freeze:
                            assert(w1 is o)
                        if (op1, op2) == (freeze, freeze):
                            assert(w2 is o)
                    else:
                        if op1 is freeze:
                            assert(isfrozen(w1))
                            assert(isfrozen(w2))
                        else:
                            assert(isfrozen(w2))
                elif protect in (op1, op2):
                    assert(isprotected(w2))
                elif private in (op1, op2):
                    assert(isprivate(w2))
                else:
                    assert(iswrapped(w2))
                    assert(w1 is w2)

    def test_13_wrapping_module(self):

        def local_test_m_o(_m, _o, _b):
            if _b:
                assert(isimmutable(_m._module_ro) is _b)
            else:
                assert(isfrozen(_m._module_ro) is _b)
            assert(isfrozen(_m.C) is _b)
            assert(isfrozen(_m.module_meth_return_cls) is _b)
            assert(isfrozen(_m.module_meth_return_cls_meth) is _b)
            assert(isfrozen(_m.module_meth_return_inst_meth) is _b)
            assert(isfrozen(_m.C.clsfn) is _b)
            assert(isfrozen(_m.C.clsfn()) is _b)
            assert(isfrozen(_m.C.clsfn()()) is _b)
            assert(isfrozen(_m.C.clsfn()()()) is _b)

            assert(isfrozen(_o) is _b)
            assert(isfrozen(_o.instfn) is _b)
            assert(isfrozen(_o.instfn()) is _b)
            assert(isfrozen(_o.instfn()()) is _b)
            assert(isfrozen(_o.instfn()()()) is _b)

        # --------------- wrap      ---------------
        try:
            del sys.modules['test_module']
        except KeyError:
            pass
        import test_module
        t = wrap(test_module)
        sys.modules['t'] = t
        del test_module
        del t
        import t

        # Hidden private attrs visible
        # Hidden private attrs and RO private attrs can be modified
        a = '__module_private_invisible'
        t.__dict__[a]
        t.__dict__[a] = t.__dict__[a]
        t._module_ro = t._module_ro
        # Attributes not in dir(mod) can be accessed and set
        t.module_attr_not_in_dir = t.module_attr_not_in_dir
        t.meth_not_in_dir = t.meth_not_in_dir

        # --------------- freeze    ---------------
        try:
            del sys.modules['test_module']
        except KeyError:
            pass
        import test_module
        t = freeze(test_module)
        del test_module
        sys.modules['t'] = t

        # Hidden private attrs visible
        # Hidden private attrs and RO private attrs can be accessed but not set
        a = '__module_private_invisible'
        t.__dict__[a]
        t._module_ro
        t.module_attr_not_in_dir
        t.meth_not_in_dir
        with self.assertRaises(Exception):
            t.__dict__[a] = t.__dict__[a]
        with self.assertRaises(Exception):
            t._module_ro = t._module_ro
        # Attributes not in dir(mod) can be accessed but not set
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir = t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir = t.meth_not_in_dir

        # Objects from frozen module are NOT frozen
        assert(isfrozen(t.module_attr_not_in_dir) is False)
        assert(isfrozen(t.meth_not_in_dir) is False)
        local_test_m_o(t, t.C(), False)
        # mod.__dict__ IS frozen, but may not be present in PY2 modules
        if hasattr(t, '__dict__'):
            assert(isfrozen(t.__dict__))

        # --------------- private (not frozen) ----
        try:
            del sys.modules['test_module']
        except KeyError:
            pass
        import test_module
        t = private(test_module, frozen=False)
        del test_module
        sys.modules['t'] = t

        # Hidden private attrs are NOT visible and CANNOT be set
        a = '__module_private_invisible'
        with self.assertRaises(Exception):
            t.__dict__[a]
        with self.assertRaises(Exception):
            t.__dict__[a] = t.__dict__[a]
        # Private single '_' attributes can be accessed but not set
        t._module_ro
        with self.assertRaises(Exception):
            t._module_ro = t._module_ro
        # Attributes not in dir(mod) are not visible and CANNOT be set
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir = t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir = t.meth_not_in_dir

        # Objects from frozen module are NOT frozen
        local_test_m_o(t, t.C(), False)
        # mod.__dict__ IS frozen, but may not be present in PY2 modules
        if hasattr(t, '__dict__'):
            assert(isfrozen(t.__dict__))

        # --------------- protect (not frozen) ----
        try:
            del sys.modules['test_module']
        except KeyError:
            pass
        import test_module
        t = protect(test_module, ro_method=False, frozen=False)
        del test_module
        sys.modules['t'] = t

        # Hidden private attrs are NOT visible and CANNOT be set
        a = '__module_private_invisible'
        with self.assertRaises(Exception):
            t.__dict__[a]
        with self.assertRaises(Exception):
            t.__dict__[a] = t.__dict__[a]
        # Private single '_' attributes can be accessed but not set
        t._module_ro
        with self.assertRaises(Exception):
            t._module_ro = t._module_ro
        # Attributes not in dir(mod) are not visible and CANNOT be set
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir = t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir = t.meth_not_in_dir

        # Objects from frozen module are NOT frozen
        local_test_m_o(t, t.C(), False)
        # mod.__dict__ IS frozen, but may not be present in PY2 modules
        if hasattr(t, '__dict__'):
            assert(isfrozen(t.__dict__))

        # --------------- private frozen ----------
        try:
            del sys.modules['test_module']
        except KeyError:
            pass
        import test_module
        t = private(test_module, frozen=True)
        del test_module
        sys.modules['t'] = t

        # Hidden private attrs are NOT visible and CANNOT be set
        a = '__module_private_invisible'
        with self.assertRaises(Exception):
            t.__dict__[a]
        with self.assertRaises(Exception):
            t.__dict__[a] = t.__dict__[a]
        # Private single '_' attributes can be accessed but not set
        t._module_ro
        with self.assertRaises(Exception):
            t._module_ro = t._module_ro
        # Attributes not in dir(mod) are not visible and CANNOT be set
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir = t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir = t.meth_not_in_dir

        # Objects from frozen module are NOT frozen
        local_test_m_o(t, t.C(), False)
        # mod.__dict__ IS frozen, but may not be present in PY2 modules
        if hasattr(t, '__dict__'):
            assert(isfrozen(t.__dict__))

        # --------------- protect frozen ----------
        try:
            del sys.modules['test_module']
        except KeyError:
            pass
        import test_module
        t = protect(test_module, ro_method=False, frozen=True)
        del test_module
        sys.modules['t'] = t

        # Hidden private attrs are NOT visible and CANNOT be set
        a = '__module_private_invisible'
        with self.assertRaises(Exception):
            t.__dict__[a]
        with self.assertRaises(Exception):
            t.__dict__[a] = t.__dict__[a]
        # Private single '_' attributes can be accessed but not set
        t._module_ro
        with self.assertRaises(Exception):
            t._module_ro = t._module_ro
        # Attributes not in dir(mod) are not visible and CANNOT be set
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir
        with self.assertRaises(Exception):
            t.module_attr_not_in_dir = t.module_attr_not_in_dir
        with self.assertRaises(Exception):
            t.meth_not_in_dir = t.meth_not_in_dir

        # Objects from frozen module ARE frozen
        local_test_m_o(t, t.C(), True)
        # mod.__dict__ IS frozen, but may not be present in PY2 modules
        if hasattr(t, '__dict__'):
            assert(isfrozen(t.__dict__))

    def test_30_help(self):
        for o in gen_test_objects():
            for op in (wrap, freeze, private, protect):
                w = op(o)
                if not iswrapped(w):
                    continue
                h1 = get_pydoc(o)
                p = getattr(w, PROT_ATTR)
                h2 = p.help_str()
                assert(h1 == h2)

    def test_51_numeric_ops_int(self):
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

        for op in (wrap, freeze, private, protect):
            # Unary numeric operations - __neg__, __pos__, abs, bool, ~
            # __invert__ is just ~ (not)
            n1 = CI(1)
            n2 = CI(0)
            n3 = CI(-3)
            w1 = op(n1)
            w2 = op(n2)
            w3 = op(n3)

            assert(-w1 == -n1)
            assert(+w1 == +n1)
            assert(abs(w1) == abs(n1))
            assert(bool(w1) == bool(n1))
            assert(~w1 == ~n1)

            assert(-w2 == -n2)
            assert(+w2 == +n2)
            assert(abs(w2) == abs(n2))
            assert(bool(w2) == bool(n2))
            assert(~w2 == ~n2)

            assert(-w3 == -n3)
            assert(+w3 == +n3)
            assert(abs(w3) == abs(n3))
            assert(bool(w3) == bool(n3))
            assert(~w3 == ~n3)

            # pow, divmod
            n1 = CI(2)
            n2 = CI(3)
            n3 = CI(25)
            w1 = op(n1)
            w2 = op(n2)
            w3 = op(n3)
            assert(pow(w1, n2) == pow(n1, n2))
            assert(divmod(w3, n2) == divmod(n3, n2))

            # Now __format__
            n1 = CI(170)
            w1 = op(n1)
            assert(format(w1, '02x') == format(n1, '02x'))

    def test_52_numeric_ops_float(self):
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

        for op in (wrap, freeze, private, protect):
            # Unary numeric operations - __neg__, __pos__, abs, bool
            n1 = CF(2.52167)
            n2 = CF(0)
            n3 = CF(-3.75167)
            w1 = op(n1)
            w2 = op(n2)
            w3 = op(n3)

            assert(-w1 == -n1)
            assert(+w1 == +n1)
            assert(abs(w1) == abs(n1))
            assert(bool(w1) == bool(n1))
            assert(format(w1, '.2f') == format(n1, '.2f'))

            assert(-w2 == -n2)
            assert(+w2 == +n2)
            assert(abs(w2) == abs(n2))
            assert(bool(w2) == bool(n2))
            assert(format(w2, '.2f') == format(n2, '.2f'))

            assert(-w3 == -n3)
            assert(+w3 == +n3)
            assert(abs(w3) == abs(n3))
            assert(bool(w3) == bool(n3))
            assert(format(w3, '.2f') == format(n3, '.2f'))

    def test_53_mutating_numeric_ops_int(self):
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

    def test_54_mutating_numeric_ops_float(self):
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

    def test_55_mutating_numeric_ops_int_frozen(self):
        class CI(int):
            pass

        n1 = CI(100)
        i1 = 10
        i2 = 30
        w1 = freeze(n1)

        with self.assertRaises(Exception):
            w1 += i1
        with self.assertRaises(Exception):
            w1 -= i1
        with self.assertRaises(Exception):
            w1 *= i1
        with self.assertRaises(Exception):
            w1 //= i1
        with self.assertRaises(Exception):
            w1 %= i2
        # PY2 does not have truediv
        if not PY2:
            with self.assertRaises(Exception):
                w1 /= i1

    def test_56_logical_ops(self):
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

    def test_57_mutating_logical_ops(self):
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

    def test_58_mutating_logical_ops_frozen(self):
        class CI(int):
            pass

        op = freeze
        n2 = CI(0b01010101)

        n1 = CI(0b10101010)
        w = op(n1)

        with self.assertRaises(Exception):
            w &= n2
        with self.assertRaises(Exception):
            w |= n2
        with self.assertRaises(Exception):
            w ^= n2

    def test_59_containers(self):
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

            self.assertSetEqual(
                # with op == 'freeze', w.items() returns Frozen, not tuple
                set([(x[0], x[1]) for x in w.items()]),
                set(d1.items())
            )

            # Test __len__ and __contains
            w = op(l1)
            assert(len(w) == len(l1))
            for item in [1, 4]:
                assert((item in w) == (item in l1))
            w = op(s1)
            assert(len(w) == len(s1))
            for item in [1, 4]:
                assert((item in w) == (item in s1))
            w = op(d1)
            assert(len(w) == len(d1))
            for item in ['a', 'c']:
                assert((item in w) == (item in d1))

    def test_60_mutating_containers(self):
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

    def test_61_mutating_containers_frozen(self):
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

            with self.assertRaises(Exception):
                w += l2
            with self.assertRaises(Exception):
                del w[1]
            with self.assertRaises(Exception):
                w *= 3
            with self.assertRaises(Exception):
                # pop(ind) pops out item at pos -ind
                w.pop(1)
            with self.assertRaises(Exception):
                w.remove(3)
            with self.assertRaises(Exception):
                w.reverse()
            with self.assertRaises(Exception):
                w.sort()

            w = op(s1)
            with self.assertRaises(Exception):
                w &= s2
            with self.assertRaises(Exception):
                w |= s2
            with self.assertRaises(Exception):
                w ^= s2

            w = op({'a': 1, 'b': 2})
            with self.assertRaises(Exception):
                w.clear()
            with self.assertRaises(Exception):
                w.pop('a')
            with self.assertRaises(Exception):
                w.update(d2)
            with self.assertRaises(Exception):
                w.popitem()
            with self.assertRaises(Exception):
                w.setdefault('c', None)
            with self.assertRaises(Exception):
                w.setdefault('d', 4)
            with self.assertRaises(Exception):
                w.setdefault('d')

    def test_62_matmul(self):
        # __matmul__ came in PEP 465 dated 20-Feb-2014 only for python 3.5+
        # https://peps.python.org/pep-0465/
        if PY2 or (
            sys.version_info.major == 3 and sys.version_info.minor < 5
        ):
            return

        # Test __matmul__ without requiring numpy
        class MatMul:
            def __init__(self, l):
                self.__l = l

            def __matmul_impl(self, a, b):
                # From: https://stackoverflow.com/a/10508239
                zip_b = list(zip(*b))
                return [
                    [
                        sum(
                            ele_a * ele_b for ele_a, ele_b in zip(row_a, col_b)
                        )
                        for col_b in zip_b
                    ] for row_a in a
                ]

            def __matmul__(self, other):
                return self.__matmul_impl(self.__l, other)

            def __rmatmul__(self, other):
                return self.__matmul_impl(other, self.__l)

        l1 = [[1, 2], [3, 5]]
        l2 = [[7, 11], [13, 17], [19, 23]]
        o = MatMul(l1)
        for op in wrap, freeze, private, protect:
            w = op(o)
            assert(w.__matmul__(l2) == o.__matmul__(l2))
            assert(w.__rmatmul__(l2) == o.__rmatmul__(l2))
            # The '@' operator generates a syntax error in python2
            assert(eval('w @ l2') == eval('o @ l2'))
            assert(eval('l2 @ w') == eval('l2 @ o'))

    def test_63_complex(self):
        class CN(object):
            def __complex__(self):
                return 1 + 2j

        o = CN()

        for op in wrap, freeze, private, protect:
            w = op(o)
            # Run standard checks
            cp = CheckPredictions(o, w)
            dp = cp.get_predictions()
            cp.check(dp)
            assert(type(complex(w)) is complex)


if __name__ == '__main__':
    unittest.main(verbosity=1)
