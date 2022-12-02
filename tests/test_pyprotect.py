#!/usr/bin/python

import sys
sys.dont_write_bytecode = True
import unittest
import warnings
warnings.simplefilter("ignore")
del warnings
from obj_utils import data_vars
from obj_utils import dunder_vars
from obj_utils import hidden_private_vars
from obj_utils import method_vars
from obj_utils import nested_obj
from obj_utils import ro_private_vars
from obj_utils import visible_is_readable
from obj_utils import writeable_in_python

from test_utils import (
    PROT_ATTR,
    compare_readable_attrs,
    compare_writeable_attrs,
    writeable_attrs,
)

from protected_wrapper import protected    # noqa: F401
from protected import (
    freeze,
    isfrozen,
    isimmutable,
    immutable_builtin_attributes,
    isreadonly,
    private,
    protect,
    wrap,
    id_protected,
    isinstance_protected,
)

if sys.version_info.major > 2:
    builtin_module = sys.modules['builtins']
else:
    builtin_module = sys.modules['__builtin__']
builtin_module_immutable_attributes = immutable_builtin_attributes()


# ------------------------------------------------------------------------
# Test objects
# ------------------------------------------------------------------------

class TestObj(object):
    def __init__(self, x=1, y=2):
        # Initialization parameters, setting private mangled attributes

        self.__x = x        # private mangled var exposed as RO property
        self.__y = y        # private mangled var exposed as RW property
        self.__private = 1  # private mangled var exposed (RO) via method
        self._ro = 2        # private RO attribute
        self.rw = 1         # public RW attribute

        # d is a self-referential dict
        d = {}
        d['self'] = d

        self.tuple_mutable = (
            # Public tuple attribute with some elements that are immutable
            1,
            {'a': 1, 'b': 2},
            (1, 2, 3),
            ['a', 'b', 'c'],
            # Self-referential attribute
            (self),
            # Instance method
            self.ro_inc,
            # Unbound method
            TestObj.rw_access_hidden_pvt,
            # Property
            TestObj.x_ro,
            # Method from python C extension module
            isfrozen,
            # Self-referential dict
            d,
            # very deep object
            # nested_obj(depth=200)
        )

    def getattr(self, a):
        if a == '__x':
            return self.__x
        return object.__getattribute__(self, a)

    @property
    def x_ro(self):
        # RO property accesses private mangled var
        return self.__x

    @property
    def y_rw(self):
        # RW property accesses private mangled var
        return self.__y

    @y_rw.setter
    def y_rw(self, val):
        # RW property accesses private mangled var
        self.__y = val

    def ro_inc(self):
        # Public method modifies private RO var
        self._ro += 1

    def ro_access_hidden_pvt(self):
        # Public method accesses private mangled var
        return self.__private

    def rw_access_hidden_pvt(self, val):
        # Public method modifies private mangled var
        self.__private = val

    def __eq__(self, other):
        if self is other:
            return True
        if id(self) == id(other):
            return True
        return False

    def __repr__(self):
        return 'Custom __repr__' + object.__repr__(self)

    def __str__(self):
        return 'Custom __str__' + object.__str__(self)


class SlotsObj(object):
    __slots__ = ['a1', 'a2']

    def __init__(self):
        self.a1 = 1
        self.a2 = 2


# ------------------------------------------------------------------------
# End of Test objects
# ------------------------------------------------------------------------


def get_builtin_obj(s):
    '''
    s-->str: attribute name in builtin_module
    Returns-->object
    '''
    return getattr(builtin_module, s)


overridden_always = set((
    '__getattribute__', '__setattr__', '__delattr__',
    '__reduce__', '__reduce_ex__',
))
special_attributes = set((
    PROT_ATTR,
))
never_writeable = set((
    '__class__', '__dict__', '__slots__'
))


def test_builtin_module():
    '''
    Tests all attributes in builtin_module_immutable_attributes
    Returns-->bool
    '''
    ret = True
    for a in builtin_module_immutable_attributes:
        if not isimmutable(a):
            print('DEBUG: %s is not immutable' % (a,))
            ret = False
    return ret


def special_attributes_immutable(o):
    for a in dir(o):
        if a in special_attributes:
            if a in writeable_attrs(o):
                return False
    return True


class TestProtectedClass(unittest.TestCase):
    def test_01_builtin_module(self):
        for a in builtin_module_immutable_attributes:
            if hasattr(builtin_module, a):
                self.assertEqual(isimmutable(getattr(builtin_module, a)), True)

    # ---------- wrap ----------------------------------------------------

    def test_02_wrap_01_basic(self):
        o1 = TestObj()
        p1 = wrap(o1)
        self.assertTrue(visible_is_readable(o1))
        self.assertTrue(visible_is_readable(p1))
        self.assertTrue(special_attributes_immutable(o1))
        self.assertTrue(special_attributes_immutable(p1))
        # Test _Protected.id
        self.assertEqual(id(o1), getattr(p1, PROT_ATTR).id)
        self.assertEqual(id(o1), id_protected(p1))
        # Test _Protected.isinstance
        self.assertEqual(
            getattr(p1, PROT_ATTR).isinstance(o1.__class__),
            True
        )
        self.assertEqual(
            isinstance_protected(p1, o1.__class__),
            True
        )

        self.assertEqual(compare_readable_attrs(o1, p1), ([], []))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        # Only diff is overridden_always is not writeable in wrap(o)
        self.assertEqual(set(l1), overridden_always)
        self.assertEqual(l2, [])
        # never_writeable are also writeable in wrap
        # special_attributes are not writeable even in wrap(o)
        for a in never_writeable:
            if a == '__slots__':
                # SlotsObj
                o2 = SlotsObj()
                p2 = wrap(o2)
                p2.__slots__.append('b')
            elif a == PROT_ATTR:
                continue
            else:
                if a in dir(p1):
                    setattr(p1, a, getattr(p1, a))
                # Add an attribute not present
                x = 'junk_____'
                while hasattr(p1, x):
                    x += '_'
                setattr(p1, x, 1)

    def test_02_wrap_02_equality(self):
        o1 = TestObj()
        p1 = wrap(o1)
        # Equality checks
        p1_identical = wrap(o1)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_identical),
            id_protected(p1_identical),
            getattr(p1_identical, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)
        o2 = TestObj()
        p1_different = wrap(o2)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_different),
            id_protected(p1_different),
            getattr(p1_different, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertNotEqual(t1, t2)

    def test_02_wrap_03_multiwrap(self):
        o1 = TestObj()
        p1 = wrap(o1)
        # multi-wrap
        p1_multi = wrap(p1)
        # rewrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_multi),
            id_protected(p1_multi),
            getattr(p1_multi, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)

    def test_02_wrap_04_call(self):
        o1 = TestObj()
        p1 = wrap(o1.__class__)
        o2 = p1()
        self.assertEqual(type(o2) is type(o1), True)
        p2 = wrap(int)
        # Do not use 'is'
        self.assertEqual(p2(1) == 1, True)

    # ---------- freeze --------------------------------------------------

    def test_03_freeze_01_basic(self):
        o1 = TestObj()
        p1 = freeze(o1)
        self.assertTrue(visible_is_readable(o1))
        self.assertTrue(visible_is_readable(p1))
        # Test _Protected_____.id
        self.assertEqual(id(o1), getattr(p1, PROT_ATTR).id)
        self.assertEqual(id(o1), id_protected(p1))
        # Test _Protected_____.isinstance
        self.assertEqual(
            getattr(p1, PROT_ATTR).isinstance(o1.__class__),
            True
        )
        self.assertEqual(
            isinstance_protected(p1, o1.__class__),
            True
        )

        (l1, l2) = compare_writeable_attrs(o1, p1)
        self.assertEqual(
            set(l1),
            set([
                x for x in dir(o1)
                if writeable_in_python(o1, x)
            ])
        )
        self.assertEqual(l2, [])

    def test_03_freeze_02_equality(self):
        o1 = TestObj()
        p1 = freeze(o1)
        # Equality checks
        p1_identical = freeze(o1)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_identical),
            id_protected(p1_identical),
            getattr(p1_identical, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)
        o2 = TestObj()
        p1_different = freeze(o2)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_different),
            id_protected(p1_different),
            getattr(p1_different, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertNotEqual(t1, t2)

    def test_03_freeze_03_multiwrap(self):
        o1 = TestObj()
        p1 = freeze(o1)
        # multi-wrap
        p1_multi = freeze(p1)
        # rewrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_multi),
            id_protected(p1_multi),
            getattr(p1_multi, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)

    def test_03_freeze_04_builtins(self):
        # all attributes of builtin_module should be immutable
        # and freezing the atribute itself should return it unchanged
        for a in builtin_module_immutable_attributes:
            if hasattr(builtin_module, a):
                x = getattr(builtin_module, a)
                p1 = freeze(x)
                self.assertEqual(p1 is x, True)
        # Test just a few representative classes from builtin_module
        # that create immutable instances

        # int
        p1 = freeze(int)
        res = p1(1)
        self.assertEqual(isinstance(res, int), True)
        self.assertEqual(res == 1, True)
        # str
        p1 = freeze(str)
        res = p1('a')
        self.assertEqual(isinstance(res, str), True)
        self.assertEqual(res == 'a', True)

    # ---------- private -------------------------------------------------

    def test_04_private_01_basic(self):
        o1 = TestObj()
        p1 = private(o1)
        self.assertTrue(visible_is_readable(o1))
        self.assertTrue(visible_is_readable(p1))
        self.assertTrue(special_attributes_immutable(o1))
        self.assertTrue(special_attributes_immutable(p1))
        # Test _Protected_____.id
        self.assertEqual(id(o1), getattr(p1, PROT_ATTR).id)
        self.assertEqual(id(o1), id_protected(p1))
        # Test _Protected_____.isinstance
        self.assertEqual(
            getattr(p1, PROT_ATTR).isinstance(o1.__class__),
            True
        )
        self.assertEqual(
            isinstance_protected(p1, o1.__class__),
            True
        )

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        '''
        # Need better 'expectations'
        (l1, l2) = compare_writeable_attrs(o1, p1)
        l1 = [
            x for x in l1
            if x in dir(p1) and
            x not in never_writeable
        ]
        self.assertEqual(set(l1), ro_private_vars(o1))
        '''
        # never_writeable are not writeable in private
        for a in never_writeable:
            if a in dir(p1):
                if a == '__slots__':
                    # SlotsObj
                    o2 = SlotsObj()
                    p2 = wrap(o2)
                    with self.assertRaises(Exception):
                        p2.__slots__.append('b')
                else:
                    with self.assertRaises(Exception):
                        setattr(p1, a, getattr(p1, a))
                # Add an attribute not present
                x1 = 'junk_____'
                while hasattr(p1, x1):
                    x1 += '_'
                x2 = getattr(p1, a)
                with self.assertRaises(Exception):
                    setattr(x2, x1, 1)

    def test_04_private_02_equality(self):
        o1 = TestObj()
        p1 = private(o1)
        # Equality checks
        p1_identical = private(o1)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_identical),
            id_protected(p1_identical),
            getattr(p1_identical, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)
        o2 = TestObj()
        p1_different = private(o2)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_different),
            id_protected(p1_different),
            getattr(p1_different, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertNotEqual(t1, t2)

    def test_04_private_03_multiwrap(self):
        o1 = TestObj()
        p1 = private(o1)
        # multi-wrap
        p1_multi = private(p1)
        # rewrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        # self.assertEqual(p1_multi is p1, True)
        t1 = (
            type(p1_multi),
            id_protected(p1_multi),
            getattr(p1_multi, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)

    def test_04_private_04_testop_r(self):
        o1 = TestObj()
        p1 = private(o1)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if getattr(p1, PROT_ATTR).testop(a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_04_private_05_testop_w(self):
        o1 = TestObj()
        p1 = private(o1)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if getattr(p1, PROT_ATTR).testop(a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (
                (not isimmutable(p1) and
                 getattr(p1, PROT_ATTR).testop(a, 'w'))
            )
            y = not isreadonly(p1, a)
            self.assertEqual(x, y)

    # ---------- private_frozen ------------------------------------------

    def test_05_private_frozen_01_basic(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        self.assertTrue(visible_is_readable(o1))
        self.assertTrue(visible_is_readable(p1))
        self.assertTrue(special_attributes_immutable(o1))
        self.assertTrue(special_attributes_immutable(p1))
        # Test _Protected_____.id
        self.assertEqual(id(o1), getattr(p1, PROT_ATTR).id)
        self.assertEqual(id(o1), id_protected(p1))

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        self.assertEqual(l2, [])

    def test_05_private_frozen_02_equality(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        # Equality checks
        p1_identical = private(o1, frozen=True)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_identical),
            id_protected(p1_identical),
            getattr(p1_identical, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)
        o2 = TestObj()
        p1_different = private(o2, frozen=True)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_different),
            id_protected(p1_different),
            getattr(p1_different, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertNotEqual(t1, t2)

    def test_05_private_frozen_03_multiwrap(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        # multi-wrap
        p1_multi = private(p1, frozen=True)
        # rewrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        # self.assertEqual(p1_multi is p1, True)
        t1 = (
            type(p1_multi),
            id_protected(p1_multi),
            getattr(p1_multi, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertEqual(t1, t2)

    def test_05_private_frozen_04_testop_r(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if getattr(p1, PROT_ATTR).testop(a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_05_private_frozen_05_testop_w(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if getattr(p1, PROT_ATTR).testop(a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (
                (not isimmutable(p1) and
                 getattr(p1, PROT_ATTR).testop(a, 'w'))
            )
            y = not isreadonly(p1, a)
            self.assertEqual(x, y)

    # ---------- protect_basic -------------------------------------------

    def test_06_protect_basic_01_basic(self):
        # Should behave identical to private
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)

        self.assertTrue(visible_is_readable(o1))
        self.assertTrue(visible_is_readable(p1))
        self.assertTrue(special_attributes_immutable(o1))
        self.assertTrue(special_attributes_immutable(p1))
        # Test _Protected_____.id
        self.assertEqual(id(o1), getattr(p1, PROT_ATTR).id)
        self.assertEqual(id(o1), id_protected(p1))
        # Test _Protected_isinstance_____
        self.assertEqual(
            getattr(p1, PROT_ATTR).isinstance(o1.__class__),
            True
        )
        self.assertEqual(
            isinstance_protected(p1, o1.__class__),
            True
        )

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        # Nothing additional is writeable in p1 over 01
        self.assertEqual(l2, [])
        '''
        # Need better 'expectations'
        l1 = [
            x for x in l1
            if x in dir(p1) and
            x not in never_writeable
        ]
        self.assertEqual(set(l1), ro_private_vars(o1))
        '''
        # never_writeable are not writeable in protect
        for a in never_writeable:
            if a in dir(p1):
                if a == '__slots__':
                    # SlotsObj
                    o2 = SlotsObj()
                    p2 = wrap(o2)
                    with self.assertRaises(Exception):
                        p2.__slots__.append('b')
                else:
                    with self.assertRaises(Exception):
                        setattr(p1, a, getattr(p1, a))
                # Add an attribute not present
                x1 = 'junk_____'
                while hasattr(p1, x1):
                    x1 += '_'
                x2 = getattr(p1, a)
                with self.assertRaises(Exception):
                    setattr(x2, x1, 1)

    def test_06_protect_basic_02_equality(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        # Equality checks
        p1_identical = protect(o1, ro_dunder=False, ro_method=False)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_identical),
            id_protected(p1_identical),
            dict(getattr(p1_identical, PROT_ATTR).rules)
        )
        t2 = (
            type(p1),
            id_protected(p1),
            dict(getattr(p1, PROT_ATTR).rules)
        )
        try:
            del t1[2]['kwargs']
        except KeyError:
            pass
        try:
            del t2[2]['kwargs']
        except KeyError:
            pass
        self.assertEqual(type(p1_identical), type(p1))
        self.assertEqual(id_protected(p1_identical), id_protected(p1))
        self.assertEqual(t1, t2)
        o2 = TestObj()
        p1_different = protect(o2, ro_dunder=False, ro_method=False)
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_different),
            id_protected(p1_identical),
            getattr(p1_different, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertNotEqual(t1, t2)

    def test_06_protect_basic_03_multiwrap(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        # multi-wrap
        p1_multi = protect(p1, ro_dunder=False, ro_method=False)
        # rewrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_multi),
            id_protected(p1_multi),
            dict(getattr(p1_multi, PROT_ATTR).rules)
        )
        t2 = (
            type(p1),
            id_protected(p1),
            dict(getattr(p1, PROT_ATTR).rules)
        )
        try:
            del t1[2]['kwargs']
        except KeyError:
            pass
        try:
            del t2[2]['kwargs']
        except KeyError:
            pass
        self.assertEqual(t1, t2)

    def test_06_protect_basic_04_testop_r(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=False)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if getattr(p1, PROT_ATTR).testop(a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_06_protect_basic_05_testop_w(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=False)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if getattr(p1, PROT_ATTR).testop(a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (
                (not isimmutable(p1) and
                 getattr(p1, PROT_ATTR).testop(a, 'w'))
            )
            y = not isreadonly(p1, a)
            self.assertEqual(x, y)

    # ---------- protect_basic_frozen ------------------------------------

    def test_07_protect_basic_frozen_01_basic(self):
        # Should behave identical to FrozenPrivate
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=True)
        self.assertTrue(visible_is_readable(o1))
        self.assertTrue(visible_is_readable(p1))
        self.assertTrue(special_attributes_immutable(o1))
        self.assertTrue(special_attributes_immutable(p1))
        # Test _Protected_id_____
        self.assertEqual(id(o1), getattr(p1, PROT_ATTR).id)
        self.assertEqual(id(o1), id_protected(p1))

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        self.assertEqual(l2, [])

    def test_07_protect_basic_frozen_02_equality(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=True)
        # Equality checks
        p1_identical = protect(
            o1, ro_dunder=False, ro_method=False, frozen=True
        )
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_identical),
            id_protected(p1_identical),
            dict(getattr(p1_identical, PROT_ATTR).rules)
        )
        t2 = (
            type(p1),
            id_protected(p1),
            dict(getattr(p1, PROT_ATTR).rules)
        )
        try:
            del t1[2]['kwargs']
        except KeyError:
            pass
        try:
            del t2[2]['kwargs']
        except KeyError:
            pass
        self.assertEqual(t1, t2)
        o2 = TestObj()
        p1_different = protect(
            o2, ro_dunder=False, ro_method=False, frozen=True
        )
        # wrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_different),
            id_protected(p1_identical),
            getattr(p1_different, PROT_ATTR).rules
        )
        t2 = (
            type(p1),
            id_protected(p1),
            getattr(p1, PROT_ATTR).rules
        )
        self.assertNotEqual(t1, t2)

    def test_07_protect_basic_frozen_03_multiwrap(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=True)
        # multi-wrap
        p1_multi = protect(
            p1, ro_dunder=False, ro_method=False, frozen=True
        )
        # rewrapped objects need to be compared by comparing
        # type, id_protected and PROT_ATTR.rules
        t1 = (
            type(p1_multi),
            id_protected(p1_multi),
            dict(getattr(p1_multi, PROT_ATTR).rules)
        )
        t2 = (
            type(p1),
            id_protected(p1),
            dict(getattr(p1, PROT_ATTR).rules)
        )
        try:
            del t1[2]['kwargs']
        except KeyError:
            pass
        try:
            del t2[2]['kwargs']
        except KeyError:
            pass
        self.assertEqual(t1, t2)

    def test_07_protect_frozen_04_testop_r(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if getattr(p1, PROT_ATTR).testop(a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_07_protect_frozen_05_testop_w(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if getattr(p1, PROT_ATTR).testop(a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (
                (not isimmutable(p1) and
                 getattr(p1, PROT_ATTR).testop(a, 'w'))
            )
            y = not isreadonly(p1, a)
            self.assertEqual(x, y)

    # ---------- protect_ext ---------------------------------------------

    def test_08_protect_ext_01_hide_all(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, hide_all=True)
        always_seen = special_attributes.union(
            set(['__class__', '__dict__'])
        )
        s1 = always_seen
        self.assertEqual(s1, set(dir(p1)))

        show = set(['__doc__'])
        s1 = s1.union(show)
        p2 = protect(
            o1, ro_dunder=False, ro_method=False, hide_all=True, show=show
        )
        self.assertEqual(s1, set(dir(p2)))

    def test_08_protect_ext_02_hide_private(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        p2 = protect(o1, ro_dunder=False, ro_method=False, hide_private=True)
        s1 = set(dir(p1)) - set(dir(p2))
        self.assertEqual(s1, set(ro_private_vars(p1)))

        show = set(['_ro'])
        p3 = protect(
            o1, ro_dunder=False, ro_method=False,
            hide_private=True, show=show
        )
        self.assertEqual(set(ro_private_vars(p3)), show)

    def test_08_protect_ext_03_hide_method(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        p2 = protect(o1, ro_dunder=False, ro_method=False, hide_method=True)
        s1 = set(dir(p1)) - set(dir(p2))
        self.assertEqual(
            s1,
            set(method_vars(p1)) -
            overridden_always -
            never_writeable - special_attributes
        )

        show = set(['ro_inc'])
        p3 = protect(
            o1, ro_dunder=False, ro_method=False,
            hide_method=True, show=show
        )
        self.assertEqual(
            set(method_vars(p3)) -
            overridden_always -
            never_writeable - special_attributes,
            show
        )

    def test_08_protect_ext_04_hide_dunder(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        p2 = protect(o1, ro_dunder=False, ro_method=False, hide_dunder=True)
        s1 = set(dir(p1)) - set(dir(p2))
        self.assertEqual(
            s1,
            set(dunder_vars(p1)) -
            overridden_always -
            never_writeable - special_attributes
        )

        show = set(['__doc__'])
        p3 = protect(
            o1, ro_dunder=False, ro_method=False,
            hide_dunder=True, show=show
        )
        self.assertEqual(
            set(dunder_vars(p3)) -
            overridden_always -
            never_writeable - special_attributes,
            show
        )

    def test_08_protect_ext_05_hide_data(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        p2 = protect(o1, ro_dunder=False, ro_method=False, hide_data=True)
        s1 = set(dir(p1)) - set(dir(p2))
        self.assertEqual(
            s1,
            set(data_vars(p1)) -
            overridden_always -
            never_writeable - special_attributes
        )

        show = set(['rw'])
        p3 = protect(
            o1, ro_dunder=False, ro_method=False,
            hide_data=True, show=show
        )
        self.assertEqual(
            set(data_vars(p3)) -
            overridden_always -
            never_writeable - special_attributes,
            show
        )

    def test_08_protect_ext_06_hide_hide(self):
        o1 = TestObj()
        p1 = protect(o1)
        always_seen = special_attributes.union(
            set(['__class__', '__dict__'])
        )
        s1 = set(dir(p1))

        hide = set(['rw'])
        p2 = protect(o1, hide=hide)
        s2 = set(dir(p2))
        self.assertEqual(s1 - s2 - always_seen, hide)

    def test_08_protect_ext_07_ro_all(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, ro_all=True)
        l1 = writeable_attrs(p1)
        self.assertEqual(l1, [])

        rw = set(['__doc__'])
        p2 = protect(
            o1, ro_dunder=False, ro_method=False, ro_all=True, rw=rw
        )
        l2 = writeable_attrs(p2)
        self.assertEqual(set(l2), rw)

    def test_08_protect_ext_08_ro_dunder(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        p2 = protect(o1, ro_method=False, ro_dunder=True)
        s1 = set(writeable_attrs(p1))
        s2 = set(writeable_attrs(p2))
        dv = set([
            x for x in dunder_vars(p1)
            if writeable_in_python(p1, x)
        ]) - never_writeable
        self.assertEqual(s1 - s2, dv)

        rw = set(['__doc__'])
        p3 = protect(
            o1, ro_dunder=True, ro_method=False, rw=rw
        )
        s3 = set(writeable_attrs(p3))
        self.assertEqual((s1 - s3).union(rw), dv)

    def test_08_protect_ext_09_ro_method(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=True)
        s1 = set(writeable_attrs(p1)).intersection(method_vars(p1))

        self.assertEqual(s1, set())

        rw = set(['ro_inc'])
        p2 = protect(
            o1, ro_dunder=False, ro_method=True,
            rw=rw
        )
        s2 = set(writeable_attrs(p2)).intersection(method_vars(p2))
        self.assertEqual(
            s2, s1.union(rw)
        )

    def test_08_protect_ext_10_ro_data(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_data=True)
        s1 = set(writeable_attrs(p1)).intersection(data_vars(p1))

        self.assertEqual(s1, set())

        rw = set(['rw'])
        p2 = protect(
            o1, ro_dunder=False, ro_data=True,
            rw=rw
        )
        s2 = set(writeable_attrs(p2)).intersection(data_vars(p2))
        self.assertEqual(
            s2, s1.union(rw)
        )

    def test_08_protect_ext_11_ro_ro(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        s1 = set(writeable_attrs(p1))

        ro = set(['rw'])
        p2 = protect(
            o1, ro_dunder=False, ro_method=False, ro=ro
        )
        s2 = set(writeable_attrs(p2))
        self.assertEqual(s1 - s2, ro)


if __name__ == '__main__':
    unittest.main()
