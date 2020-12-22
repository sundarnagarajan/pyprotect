#!/usr/bin/python

import sys
import re
import unittest

import warnings
warnings.simplefilter("ignore")
from protected_class import isimmutable
from protected_class import id_protected
from protected_class import isreadonly
from protected_class import iswrapped
from protected_class import isfrozen
from protected_class import isprivate
from protected_class import wrap
from protected_class import freeze
from protected_class import private
from protected_class import protect
from protected_class import immutable_builtin_attributes
del warnings


if sys.version_info.major > 2:
    builtin_module = sys.modules['builtins']
else:
    builtin_module = sys.modules['__builtin__']
builtin_module_immutable_attributes = immutable_builtin_attributes()
builtins_ids = set([
    id(getattr(builtin_module, a)) for a in builtin_module_immutable_attributes
])


# ------------------------------------------------------------------------
# Test objects
# ------------------------------------------------------------------------

def nested_obj(
    depth, no_cycles=False, json_compatible=False, custom_obj=True
):
    '''
    depth-->int
    no_cycles-->bool
    json_compatible--:bool: If True, convert sets to lists, tuples to lists
    custom_obj-->bool: If True, adds custom objects
    Generates a deeply nested object with depth 'depth'
    '''
    width = 5
    if json_compatible:
        custom_obj = False
        no_cycles = True

    class CustomObj(object):
        pass

    class MyList(list):
        pass

    class MyTuple(tuple):
        pass

    class MyDict(dict):
        pass

    class MySet(set):
        pass

    def gen_dict():
        d = dict.fromkeys([
            'dict', 'list', 'tuple', 'set', 'cycle'
        ])
        if custom_obj:
            d['obj'] = None
        return d

    obj = gen_dict()
    top_obj = obj
    for x in range(depth):
        obj['dict'] = gen_dict()
        obj['list'] = [a for a in range(width)]
        if json_compatible:
            obj['tuple'] = list(tuple([a for a in range(width)]))
            obj['set'] = list(set([a for a in range(width)]))
        else:
            obj['tuple'] = tuple([a for a in range(width)])
            obj['set'] = set([a for a in range(width)])
        if not no_cycles:
            obj['cycle'] = top_obj
        if custom_obj:
            obj['obj'] = CustomObj()
            obj['mylist'] = MyList([a for a in range(width)])
            obj['mytuple'] = MyTuple([a for a in range(width)])
            obj['mydict'] = MyDict(obj['dict'])
            if not json_compatible:
                obj['myset'] = MySet([a for a in range(width)])
        obj = obj['dict']
    return top_obj


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
            nested_obj(depth=200)
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
))
special_attributes = set((
    '_Protected_id_____', '_Protected_isinstance_____',
    '_Protected_testop_____', '_Protected_rules_____',
))
never_writeable = set((
    '__class__', '__dict__', '__slots__',
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


def isproperty(o, a):
    '''Returns-->bool'''
    try:
        x = getattr(o.__class__, a)
        return isinstance(x, property)
    except:
        pass
    return False


def writeable_in_python(o, a):
    '''
    o-->object
    a-->str: attribute name
    Returns-->bool
    Some attributes are readonly in python
    '''
    if a == '__weakref__':
        return False
    if isproperty(o, a):
        return False
    return True


def dunder_vars(o):
    '''
    Returns-->set of str: dunder attribute names in o
    '''
    ret = set()
    for a in dir(o):
        if a.startswith('__') and a.endswith('__'):
            ret.add(a)
    return ret


def hidden_private_vars(o):
    '''
    Returns-->set of str: traditionally private mangled adttribute names
    '''
    ret = set()
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    for a in dir(o):
        if h1_regex.match(a):
            ret.add(a)
    return ret


def ro_private_vars(o):
    '''
    Returns-->set of str: attribute names of the form _var
    '''
    ret = set()
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    for a in dir(o):
        if h1_regex.match(a):
            continue
        if a.startswith('_') and not a.endswith('_'):
            ret.add(a)
    return ret


def method_vars(o):
    '''
    Returns-->set of str: attribute names of method attributes
    '''
    ret = set()
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    for a in dir(o):
        if h1_regex.match(a):
            continue
        if callable(getattr(o, a)):
            ret.add(a)
    return ret


def data_vars(o):
    '''
    Returns-->set of str: attribute names of data attributes
    '''
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    ret = set()
    for a in dir(o):
        if h1_regex.match(a):
            continue
        if callable(getattr(o, a)):
            continue
        ret.add(a)
    return ret


def identical_in_both(a, o1, o2):
    '''
    a-->str: attribute name
    o1, o2-->object
    Returns-->bool
    '''
    try:
        a1 = getattr(o1, a)
        a2 = getattr(o2, a)
        return id_protected(a1) == id_protected(a2)
    except:
        return False


def visible_is_readable(o):
    # a in dir(o) ==> getattr(o, a) works without exception
    for a in dir(o):
        try:
            getattr(o, a)
        except:
            print('Attribute %s of object(%s) not readable' % (
                a, str(type(o)),
            ))
            return False
    return True


def compare_readable_attrs(o1, o2, flexible=True):
    '''
    Returns-->(
        list of str-->attributes only in o1,
        list of str-->attributes only in o2,
    ASSUMES visible_is_readable(o1) and visible_is_readable(o2)
    '''
    def get_dir(o):
        ret = set()
        for a in dir(o):
            if a in overridden_always:
                continue
            if iswrapped(o) and a in special_attributes:
                continue
            ret.add(a)
        return ret

    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o1.__class__.__name__))
    h2_regex = re.compile('^_%s__.*?(?<!__)$' % (o2.__class__.__name__))

    s1 = get_dir(o1)
    s2 = get_dir(o2)

    only_in_1 = []
    only_in_2 = []

    for a in s1:
        if flexible and (not isprivate(o1)) and h1_regex.match(a):
            continue
        if a not in s2:
            only_in_1.append(a)
    for a in s2:
        if flexible and (not isprivate(o2)) and h2_regex.match(a):
            continue
        if a not in s1:
            only_in_2.append(a)
    return (only_in_1, only_in_2)


def writeable_attrs(o):
    '''
    Returns-->list of str: attribute names that could be written
    If o is NOT wrapped, we use immutable()
    '''
    ret = []
    if not iswrapped(o):
        if isimmutable(o):
            return ret
    for a in dir(o):
        # Some properties are not writeable due to python protection
        if not writeable_in_python(o, a):
            continue
        old_val = getattr(o, a)
        try:
            setattr(o, a, old_val)
            ret.append(a)
        except:
            continue
    return ret


def compare_writeable_attrs(o1, o2):
    '''
    Returns-->(
        list of str-->attributes writeable only in o1,
        list of str-->attributes writeable only in o2,

        if o1 or o2 is wrapped, filters out special_attributes
        that are NEVER writeable
    '''
    w1 = writeable_attrs(o1)
    w2 = writeable_attrs(o2)

    only_in_1 = [x for x in w1 if x not in w2]
    only_in_2 = [x for x in w2 if x not in w1]
    return (only_in_1, only_in_2)


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
        # Test _Protected_id_____
        self.assertEqual(id(o1), p1._Protected_id_____)
        # Test _Protected_isinstance_____
        self.assertEqual(
            p1._Protected_isinstance_____(p1, o1.__class__),
            True
        )

        self.assertEqual(compare_readable_attrs(o1, p1), ([], []))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        # Only diff is overridden_always is not writeable in wrap(o)
        self.assertEqual(set(l1), overridden_always)
        self.assertEqual(l2, [])
        # never_writeable are also writeable in wrap
        for a in never_writeable:
            if a == '__slots__':
                # SlotsObj
                o2 = SlotsObj()
                p2 = wrap(o2)
                p2.__slots__.append('b')
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
        self.assertEqual(p1, p1_identical)
        o2 = TestObj()
        p1_different = wrap(o2)
        self.assertNotEqual(p1, p1_different)

    def test_02_wrap_03_multiwrap(self):
        o1 = TestObj()
        p1 = wrap(o1)
        # multi-wrap
        p1_multi = wrap(p1)
        self.assertEqual(p1_multi is p1, True)

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
        # Test _Protected_id_____
        self.assertEqual(id(o1), p1._Protected_id_____)
        # Test _Protected_isinstance_____
        self.assertEqual(
            p1._Protected_isinstance_____(p1, o1.__class__),
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
        self.assertEqual(p1, p1_identical)
        o2 = TestObj()
        p1_different = freeze(o2)
        self.assertNotEqual(p1, p1_different)

    def test_03_freeze_03_multiwrap(self):
        o1 = TestObj()
        p1 = freeze(o1)
        # multi-wrap
        p1_multi = freeze(p1)
        self.assertEqual(p1_multi is p1, True)

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
        # Test _Protected_id_____
        self.assertEqual(id(o1), p1._Protected_id_____)
        # Test _Protected_isinstance_____
        self.assertEqual(
            p1._Protected_isinstance_____(p1, o1.__class__),
            True
        )

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        l1 = [
            x for x in l1
            if x in dir(p1) and
            x not in never_writeable
        ]
        self.assertEqual(set(l1), ro_private_vars(o1))
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
        self.assertEqual(p1, p1_identical)
        o2 = TestObj()
        p1_different = private(o2)
        self.assertNotEqual(p1, p1_different)

    def test_04_private_03_multiwrap(self):
        o1 = TestObj()
        p1 = private(o1)
        # multi-wrap
        p1_multi = private(p1)
        self.assertEqual(p1_multi is p1, True)

    def test_04_private_04_testop_r(self):
        o1 = TestObj()
        p1 = private(o1)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if p1._Protected_testop_____(p1, a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_04_private_05_testop_w(self):
        o1 = TestObj()
        p1 = private(o1)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if p1._Protected_testop_____(p1, a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (not isimmutable(p1) and p1._Protected_testop_____(p1, a, 'w'))
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
        # Test _Protected_id_____
        self.assertEqual(id(o1), p1._Protected_id_____)

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        self.assertEqual(l2, [])

    def test_05_private_frozen_02_equality(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        # Equality checks
        p1_identical = private(o1, frozen=True)
        self.assertEqual(p1, p1_identical)
        o2 = TestObj()
        p1_different = private(o2, frozen=True)
        self.assertNotEqual(p1, p1_different)

    def test_05_private_frozen_03_multiwrap(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        # multi-wrap
        p1_multi = private(p1, frozen=True)
        self.assertEqual(p1_multi is p1, True)

    def test_05_private_frozen_04_testop_r(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if p1._Protected_testop_____(p1, a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_05_private_frozen_05_testop_w(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if p1._Protected_testop_____(p1, a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (not isimmutable(p1) and p1._Protected_testop_____(p1, a, 'w'))
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
        # Test _Protected_id_____
        self.assertEqual(id(o1), p1._Protected_id_____)
        # Test _Protected_isinstance_____
        self.assertEqual(
            p1._Protected_isinstance_____(p1, o1.__class__),
            True
        )

        (l1, l2) = compare_readable_attrs(o1, p1, flexible=False)
        self.assertEqual(set(l1), hidden_private_vars(o1))
        (l1, l2) = compare_writeable_attrs(o1, p1)
        l1 = [
            x for x in l1
            if x in dir(p1) and
            x not in never_writeable
        ]
        self.assertEqual(set(l1), ro_private_vars(o1))
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
        self.assertEqual(p1, p1_identical)
        o2 = TestObj()
        p1_different = protect(o2, ro_dunder=False, ro_method=False)
        self.assertNotEqual(p1, p1_different)

    def test_06_protect_basic_03_multiwrap(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False)
        # multi-wrap
        p1_multi = protect(p1, ro_dunder=False, ro_method=False)
        self.assertEqual(p1_multi is p1, True)

    def test_06_protect_basic_04_testop_r(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=False)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if p1._Protected_testop_____(p1, a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_06_protect_basic_05_testop_w(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=False)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if p1._Protected_testop_____(p1, a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (not isimmutable(p1) and p1._Protected_testop_____(p1, a, 'w'))
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
        self.assertEqual(id(o1), p1._Protected_id_____)

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
        self.assertEqual(p1, p1_identical)
        o2 = TestObj()
        p1_different = protect(
            o2, ro_dunder=False, ro_method=False, frozen=True
        )
        self.assertNotEqual(p1, p1_different)

    def test_07_protect_basic_frozen_03_multiwrap(self):
        o1 = TestObj()
        p1 = protect(o1, ro_dunder=False, ro_method=False, frozen=True)
        # multi-wrap
        p1_multi = protect(
            p1, ro_dunder=False, ro_method=False, frozen=True
        )
        self.assertEqual(p1_multi is p1, True)

    def test_07_protect_frozen_04_testop_r(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(dir(p1))
        s2 = set()
        for a in dir(p1):
            if p1._Protected_testop_____(p1, a, 'r'):
                s2.add(a)
        self.assertEqual(s1, s2)

    def test_07_protect_frozen_05_testop_w(self):
        o1 = TestObj()
        p1 = private(o1, frozen=True)
        s1 = set(writeable_attrs(p1))
        s2 = set()
        if not isimmutable(p1):
            for a in dir(p1):
                if p1._Protected_testop_____(p1, a, 'w'):
                    if not writeable_in_python(p1, a):
                        continue
                    if a in never_writeable:
                        continue
                    s2.add(a)
        self.assertEqual(s1, s2)
        # Test isreadonly versus testop
        for a in dir(p1):
            x = (not isimmutable(p1) and p1._Protected_testop_____(p1, a, 'w'))
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
