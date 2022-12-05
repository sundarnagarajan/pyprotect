#
# ------------------------------------------------------------------------
# All of following to implement isimmutable() to avoid freezing immutables
# Looks complex, but it is computed only once, while COMPILING
# ------------------------------------------------------------------------

import sys
cdef object builtin_module
cdef list builtin_names
cdef list basic_data_names
cdef list basic_mutable_data_names
cdef list basic_immutable_data_names
cdef list basic_data_types
cdef list basic_mutable_data_types
cdef list basic_immutable_data_types
cdef list mapping_types
cdef list list_types
cdef list tuple_types
cdef list set_types
cdef list sequence_types
cdef list mutable_mapping_types
cdef list mutable_sequence_types
cdef list mutable_set_types
cdef list immutable_mapping_types
cdef list immutable_sequence_ytpes
cdef list immutable_set_types

cdef list immutable_types
cdef set builtins_ids
cdef frozenset builtin_module_immutable_attributes


if sys.version_info.major > 2:
    import collections.abc
    builtin_module = sys.modules['builtins']
else:
    import collections
    builtin_module = sys.modules['__builtin__']

builtin_names = dir(builtin_module)

cdef get_builtin_obj(s):
    '''
    s-->str: attribute name in builtin_module
    Returns-->object
    '''
    return getattr(builtin_module, s)

basic_data_names = [
    'bool', 'bytearray', 'bytes', 'complex',
    'dict', 'float', 'frozenset', 'int', 'list', 'object', 'set', 'str',
    'tuple', 'basestring', 'unichr', 'unicode', 'long'
]
basic_mutable_data_names = ['bytearray', 'dict', 'list']
basic_immutable_data_names = [
    'bool', 'bytes', 'complex', 'float',
    'frozenset', 'int', 'set', 'str', 'tuple', 'basestring', 'unichr',
    'unicode', 'long'
]

basic_data_names = [x for x in basic_data_names if x in builtin_names]

basic_mutable_data_names = [
    x for x in basic_mutable_data_names if
    x in builtin_names
]
basic_immutable_data_names = [
    x for x in basic_immutable_data_names if
    x in builtin_names
]

basic_data_types = [get_builtin_obj(x) for x in basic_data_names]
basic_mutable_data_types = [
    get_builtin_obj(x) for x in basic_mutable_data_names
]
basic_immutable_data_types = [
    get_builtin_obj(x) for x in basic_immutable_data_names
]


if sys.version_info.major > 2:
    mapping_types = [collections.abc.MutableMapping, collections.abc.Mapping]
    list_types = [collections.abc.MutableSequence]
    tuple_types = [collections.abc.Sequence]
    set_types = [collections.abc.Set, collections.abc.MutableSet]
else:
    mapping_types = [dict, collections.MutableMapping, collections.Mapping]
    list_types = [list, collections.MutableSequence]
    tuple_types = [tuple, collections.Sequence]
    set_types = [set, collections.Set, collections.MutableSet]

sequence_types = tuple_types + list_types

mutable_sequence_types = list_types
if sys.version_info.major > 2:
    mutable_mapping_types = [dict, collections.abc.MutableMapping]
    mutable_set_types = [set, collections.abc.MutableSet]
else:
    mutable_mapping_types = [dict, collections.MutableMapping]
    mutable_set_types = [set, collections.MutableSet]

immutable_mapping_types = [
    x for x in mapping_types if
    x not in mutable_mapping_types
]
immutable_sequence_ytpes = [
    x for x in sequence_types if
    x not in mutable_sequence_types
]
immutable_set_types = [x for x in set_types if x not in mutable_set_types]

immutable_types = list(set(
    basic_immutable_data_types +
    immutable_mapping_types +
    immutable_sequence_ytpes +
    immutable_set_types
))
immutable_types = [x for x in immutable_types if isinstance(x, type)]
cdef frozenset immutable_types_set
immutable_types_set = frozenset(immutable_types)

# Since builtin_module is by default writeable in Python and attributes
# in builtin_module can be overwritten, we only track attributes
# that do not allow __class__ attribute to be overwritten (crude test)
s = set()
test_attr_name = '__class__'
for a in builtin_names:
    try:
        x = getattr(builtin_module, a)
        try:
            setattr(x, test_attr_name, getattr(x, test_attr_name))
            continue
        except:
            s.add(a)
    except:
        continue
builtin_module_immutable_attributes = frozenset(s)

builtins_ids = set([
    id(getattr(builtin_module, a)) for a in builtin_names
    if a in builtin_module_immutable_attributes
])

# Avoid locals and imports leaking into module namespace
del x
del s
del test_attr_name
del a
del sys
del collections

# ------------------------------------------------------------------------
# Only the following 3 attributes are used after this
#   immutable_types_set
#   builtin_module_immutable_attributes
#   builtins_ids
# ------------------------------------------------------------------------

# The ONLY place where the name of the special attribute is defined / used
cdef str PROT_ATTR_NAME = '_Protected_____'
cdef str ENV_VAR = PROT_ATTR_NAME
cdef str PROT_ATTR_SHORTEST_SUFFIX = '_____'
# Can override by setting env var '_Protected_____'
# Value of env var '_Protected_____' will be fixed to have exactly
# one leading underscore and at least 5 trailing underscores
import os
x = os.environ.get(ENV_VAR, None)
if x is not None:
    if x.startswith('_'):
        x = x.lstrip('_') + '_'
    if not x.endswith(PROT_ATTR_SHORTEST_SUFFIX):
        x = x.rstrip('_') + PROT_ATTR_SHORTEST_SUFFIX
    PROT_ATTR_NAME = x
del x, os


def attribute_protected():
    return PROT_ATTR_NAME

# ------------------------------------------------------------------------
# Methods to query metadata on wrapped object
# ------------------------------------------------------------------------

def id_protected(o: object) -> int:
    '''
    id_protected(o: object) -> int:
    id of wrapped object if wrapped; id of 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).id
    return id(o)


def hash_protected(o: object) -> int:
    '''
    hash_protected(o: object) -> int:
    hash of wrapped object if wrapped; hash of 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).hash()
    return hash(o)


def isinstance_protected(o: object, c: type) -> bool:
    '''
    isinstance_protected(o: object, c: type) -> bool:
    Returns-->True IFF isinstance(object_wrapped_by_o, c)
    Similar to isinstance, but object o can be an object returned
    by freeze(), private() or protect()
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).isinstance(c)
    return isinstance(o, c)


def issubclass_protected(o: type, c: type) -> bool:
    '''
    issubclass_protected(o: type, c: type) -> bool:
    Returns-->True IFF issubclass(object_wrapped_by_o, c)
    Similar to issubclass, but object o can be an object returned
    by freeze(), private() or protect()
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).issubclass(c)
    return issubclass(o, c)


def help_protected(o: object) -> None:
    '''
    help_protected(o: object) -> None:
    help for wrapped object if wrapped; help for 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return o.getattr(o, PROT_ATTR_NAME)()
    return help(o)


def contains(p: object, o: object):
    '''
    contains(p: object, o: object):
    Returns--whether 'p' wraps 'o'
    '''
    if isinstance(p, Wrapped):
        return getattr(p, PROT_ATTR_NAME).id == id(o)
    return False


# ------------------------------------------------------------------------
# End of methods to query metadata on wrapped object
# ------------------------------------------------------------------------

def immutable_builtin_attributes():
    '''
    Returns-->set of str: attributes in builtins that are immutable
    Used in unit tests
    '''
    return builtin_module_immutable_attributes


def isimmutable(o: object) -> bool:
    '''
    isimmutable(o: object) -> bool:
    'o' is KNOWN to be immutable
    '''
    # Import locally to avoid leaking into module namespace
    import sys
    if sys.version_info.major > 2:
        import collections.abc as CollectionsABC
    else:
        import collections as CollectionsABC

    # Everything in builtin module is immutable
    if id(o) in builtins_ids:
        return True
    if type(o) in builtins_ids:
        return True
    # None and NotImplemented are immutable
    if o is None or o is NotImplemented:
        return True
    '''
    # Instances of classes DERIVED from str (or other types
    # in immutable_types_set) cannot be considered immutable

    # str and basestring are immutable, THOUGH they are Containers
    if isinstance(o, (str, basestring)):
        return True
    '''
    if isfrozen(o):
        return True
    if type(o) in immutable_types_set:
        return True
    '''
    if iswrapped(o):
        return False
    if isinstance(o, CollectionsABC.Container):
        return False
    return isinstance(o, tuple(immutable_types))
    '''
    return False


def iswrapped(o: object) -> bool:
    '''
    iswrapped(o: object) -> bool:
    'o' was created using wrap / freeze / private / protect
    '''
    return isinstance(o, Wrapped)


def isfrozen(o: object) -> bool:
    '''
    isfrozen(o: object) -> bool:
    'o' was created using freeze()
    '''
    return isinstance(o, (
        Frozen, FrozenPrivate, FrozenPrivacyDict, FrozenProtected,
    ))


def isprivate(o: object) -> bool:
    '''
    isprivate(o: object) -> bool:
    'o' was created using private()
    '''
    return isinstance(o, (
        Private,
        FrozenPrivate,
    ))


def isprotected(o: object) -> bool:
    '''
    isprotected(o: object) -> bool:
    'o' was created using protect()
    '''
    return isinstance(o, (
        Protected,
        FrozenProtected,
    ))


def isreadonly(o: object, a: str) -> bool:
    '''
    isreadonly(o: object, a: str) -> bool:
    Returns-->bool: True IFF 'o' is wrapped AND 'o' makes arribute 'a'
        read-only if present in wrapped object
    This represents RULE of wrapped object - does not guarantee
    that WRAPPED OBJECT has attribute 'a' or that setting attribute
    'a' in object 'o' will not raise any exception
    '''
    try:
        if isimmutable(o):
            return True
    except:
        pass
    if isprivate(o) or isprotected(o):
        return not getattr(o, PROT_ATTR_NAME).testop(a, 'w')
    else:
        return False


def wrap(o: object) -> object:
    '''
    wrap(o: object) -> object:
    Wrapped:
        - Should behave just like the wrapped object, except
          following attributes cannot be modified:
            'getattr, __getattribute__',
            '__delattr__', '__setattr__', '__slots__',
        - Explicitly does NOT support pickling, and will raise
          ProtectionError
        - Does NOT protect CLASS of wrapped object from modification
        - Does NOT protect __dict__ or __slots__

    Useful for testing if wrapping is failing for a particular type of object
    '''
    if iswrapped(o):
        # Do not wrap twice
        return o
    return Wrapped(o, frozen=False)


def freeze(o: object) -> object:
    '''
    freeze(o: object) -> object:
    Frozen object prevents modification of ANY attribute
        - Does not hide traditionally 'private' mangled python attributes
    '''
    if isfrozen(o):
        # Never freeze twice
        return o
    elif isimmutable(o):
        # Object is KNOWN to be immutable - return as-is
        return o
    # Must freeze
    # TODO specifically in case of ModuleType, make resultant
    # object behave closest to a python module:
    #   Module object ITSELF is frozen, but objects returned
    #   FROM the module by methods, classes are not
    #   This is 'ftlo' (freeze top level only)
    # TODO: Optionally, allow ADDING attributes but not
    #   deleting or changing EXISTING attributes
    # TODO: Optionally, allow deleting only ADDED attributes
    # import types
    # Module: types.ModuleType

    # If Wrapped, avoid double wrapping
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).freeze()
    return Frozen(o)


def private(o: object, frozen: bool = False) -> object:
    '''
    private(o: object, frozen: bool = False) -> object:
    FrozenPrivate instance if frozen; Private instance otherwise

    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object

    FrozenPrivate:
        Features of Private PLUS prevents modification of ANY attribute

    '''
    # Avoid double-wrapping
    if frozen or isfrozen(o):
        frozen = True
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).private(frozen)
    else:
        if frozen:
            return FrozenPrivate(o)
        else:
            return Private(o)


cdef get_visibility_rules(kwargs):
    '''
    kwargs-->dict
    Returns-->dict
    Called once by protect() before Protected class initialization
    '''
    hide_method = bool(kwargs.get('hide_method', False))
    hide_data = bool(kwargs.get('hide_data', False))
    ro_method = bool(kwargs.get('ro_method', False))
    ro_data = bool(kwargs.get('ro_data', False))

    ro = [
        x for x in list(kwargs.get('ro', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]
    rw = [
        x for x in list(kwargs.get('rw', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]
    hide = [
        x for x in list(kwargs.get('hide', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]
    show = [
        x for x in list(kwargs.get('show', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]

    ro = frozenset(ro)
    rw = frozenset(rw)
    hide = frozenset(hide)
    show = frozenset(show)

    # Build regexes

    hide_dunder = kwargs.get('hide_dunder', False)
    hide_private = kwargs.get('hide_private', False)
    hide_all = kwargs.get('hide_all', False)
    ro_dunder = kwargs.get('ro_dunder', False)
    ro_all = kwargs.get('ro_all', False)

    # ---------- hide_regex ----------
    regex_list = []
    if hide_dunder:
        regex_list += ['^__.*?__$']
    if hide_private:
        regex_list += ['^_[^_].*?(?<!_)$']
    if hide_all:
        regex_list += ['^.*?$']
    if hide:
        for x in hide:
            if not isinstance(x, str):
                continue
            if attr_identifier.match(x):
                regex_list += ['^%s$' % (x,)]

    hide_regex = ''
    for x in regex_list:
        if hide_regex:
            hide_regex = hide_regex + '|' + x
        else:
            hide_regex = x

    # ---------- ro_regex ----------
    regex_list = []
    if ro_dunder:
        regex_list += ['^__.*?__$']
    if ro_all:
        regex_list += ['^.*?$']
    if ro:
        for x in ro:
            if not isinstance(x, str):
                continue
            if attr_identifier.match(x):
                regex_list += ['^%s$' % (x,)]

    ro_regex = ''
    for x in regex_list:
        if ro_regex:
            ro_regex = hide_regex + '|' + x
        else:
            ro_regex = x

    # ---------- show_regex ----------
    regex_list = []
    if show:
        for x in show:
            if not isinstance(x, str):
                continue
            if attr_identifier.match(x):
                regex_list += ['^%s$' % (x,)]

    show_regex = ''
    for x in regex_list:
        if show_regex:
            show_regex = hide_regex + '|' + x
        else:
            show_regex = x

    # ---------- rw_regex ----------
    regex_list = []
    if rw:
        for x in rw:
            if not isinstance(x, str):
                continue
            if attr_identifier.match(x):
                regex_list += ['^%s$' % (x,)]

    rw_regex = ''
    for x in regex_list:
        if rw_regex:
            rw_regex = hide_regex + '|' + x
        else:
            rw_regex = x
    d = {
        'hide_regex': hide_regex,
        'show_regex': show_regex,
        'ro_regex': ro_regex,
        'rw_regex': rw_regex,
        'hide_method': hide_method,
        'hide_data': hide_data,
        'ro_method': ro_method,
        'ro_data': ro_data,
    }
    d['dynamic'] = kwargs.get('dynamic', False)
    d['frozen'] = bool(kwargs.get('frozen', False))
    d['add_allowed'] = bool(kwargs.get('add', False))
    d['kwargs'] = kwargs

    return d

cdef merge_kwargs(kw1: dict, kw2: dict):
    '''
    Merges kw1 and kw2 to return dict with most restrictive options
    kw1, kw2: dict
    Returns: dict
    '''
    (kw1, kw2) = (dict(kw1), dict(kw2))
    d = {}
    # Permissive options - must be 'and-ed'
    # dynamic defaults to True while add defaults to False
    a = 'dynamic'
    d[a] = (kw1.get(a, True) and kw2.get(a, True))
    a = 'add'
    d[a] = (kw1.get(a, False) and kw2.get(a, False))

    # Restrictive options must be 'or-ed'
    for a in (
        'frozen', 'hide_all', 'hide_data', 'hide_method',
        'hide_private', 'hide_dunder',
        'ro_all', 'ro_data', 'ro_method', 'ro_dunder',
    ):
        d[a] = (kw1.get(a, False) or kw2.get(a, False))

    # Permissive lists are intersected
    for a in (
        'rw', 'show',
    ):
        d[a] = list(
            set(list(kw1.get(a, []))).intersection(set(list(kw2.get(a, []))))
        )
    # Restrictive lists are unioned
    for a in (
        'ro', 'hide',
    ):
        d[a] = list(
            set(list(kw1.get(a, []))).union(set(list(kw2.get(a, []))))
        )
    return d

def protect(
    o: object,
    frozen: bool = False, add: bool = False, dynamic: bool = True,
    hide_all: bool = False, hide_data: bool = False,
    hide_method: bool = False, hide_private: bool = False,
    hide_dunder: bool = False, ro_all: bool = False, ro_data: bool = False,
    ro_method: bool = True, ro_dunder: bool = True,
    ro=[], rw=[],
    hide=[], show=[],
):
    '''
    o-->object to be wrapped
    frozen-->bool: No attribute can be modified. Default: False
        - Overrides 'add'
    add-->bool: Whether attributes can be ADDED. Default: False
        Automatically set to False if 'dynamic' is True
        Only attributes added through the wrapper can be deleted through
            the wrapper
    dynamic-->bool: Attribute additions, deletions, type changes in wrapped
        object are automatically visible
        If True, 'add' is automatically set to False
        Default: True

    TODO:
        - Following do not make sense because hiding special methods
          will change the behavior of the wrapped object:
              - hide_all
              - hide_method
              - hide_dunder
          Can still hide special methods using 'hide'

        - hide_data will mostly not make sense, and will probably
          cripple usage of the object. Specific uses can still be
          achieved (better) by explicitly using 'hide'

        - ro_dunder seems to be redundant with ro_method. We want
          people to write idiomatic Python classes, where 'dunder'
          attributes are almost invariably methods - so can use 
          'ro_method'. In exceptional cases 'ro' can be used.

        - ro_all is redundant, since 'frozen' can be used instead

        - 'add' does not align with 'idiomatic python' - should not be
          adding attributes from outside the class

        - 'show' is unnecessary. By default all attributes are visible,
          unless hidden by 'hide_private' or 'hide'

        - Only 'meta' options left are:
            - ro_data - needs callable() check if 'dynamic'
            - ro_method - needs callable() check if 'dynamic'
            - hide_private - regex match

        This leaves (only) the following, reducing testing load:
            - Visibility:
                - hide_private
                - hide
            - Mutability:
                - ro_data
                - ro_method
                - ro
                - rw
                - frozen
            - Behavior:
                - dynamic

    hide_all-->bool: All attributes will be hidden. Default: False
    hide_data-->bool: Data attributes will be hidden. Default: False
    hide_method-->bool: Method attributes will be hidden. Default: False
    hide_private-->bool: Private vars (_var) will be hidden. Default: False
    hide_dunder-->bool: 'dunder-vars' will be hidden. Default: False

    ro_all-->bool: All attributes will be read-only. Default: False
    ro_data-->bool: Data attributes will be read-only. Default: False
    ro_method-->bool: Method attributes will be read-only. Default: True
    ro_dunder-->bool: 'dunder-vars' will be  read-only. Default: True

    ro-->list of str: attributes that will be read-only. Default: []
    rw-->list of str: attributes that will be read-write. Default: []
        Overrides 'ro_*'

    hide-->list of str: attributes that will be hidden. Default: []
    show-->list of str: attributes that will be visible. Default: []
        Overrides 'hide_*'
    Returns-->Instance of FrozenProtected if frozen; Instance of Protected otherwise

    Protected:
        Features of Private PLUS allows customization of:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE

    FrozenProtected:
        Features of Protected PLUS prevents modification of ANY attribute

    Default settings:
    Features of Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
        - TODO: Cannot access any attribute not exported by dir(pvt_o)
    - dynamic == True
      Attribute additions, deletions, type changes automatically visible
    - ro_dunder == True: 'dunder-vars' will be  read-only
    - ro_method == True: Method attributes will be read-only
    - All other non-dunder non-private data attributes are read-write
    '''
    kwargs = {
        'frozen': frozen,
        'add': add,
        'hide_all': hide_all,
        'hide_data': hide_data,
        'hide_method': hide_method,
        'hide_private': hide_private,
        'hide_dunder': hide_dunder,
        'ro_all': ro_all,
        'ro_data': ro_data,
        'ro_method': ro_method,
        'ro_dunder': ro_dunder,
        'ro': ro,
        'rw': rw,
        'hide': hide,
        'show': show,
        'dynamic': dynamic,
    }

    # Avoid double-wrapping
    if isprotected(o):
        kw1 = dict(getattr(o, PROT_ATTR_NAME).rules.get('kwargs', {}))
        kw2 = dict(kwargs)
        kwargs = merge_kwargs(kw1, kw2)
        assert(isinstance(kwargs, dict))
    rules = dict(get_visibility_rules(kwargs))
    assert(isinstance(rules, dict))
    want_frozen = bool(rules.get('frozen', False)) or isfrozen(o)
    if want_frozen and not isfrozen(o):
        # Frozen objects remain frozen
        rules['frozen'] = True
    # if iswrapped(o):
    #     # (Only) this causes RecursionError in __getattribute__ and aclcheck
    #     return getattr(o, PROT_ATTR_NAME).protect(rules)
    # else:
    #     return Protected(o, rules)
    return Protected(o, rules)

    '''

    rules = dict(get_visibility_rules(kwargs))
    want_frozen = bool(rules.get('frozen', False))

    if want_frozen:
        if isinstance(o, FrozenProtected):
            d = dict(getattr(o, PROT_ATTR_NAME).rules)
            if rules == d:
                # Protected object with the SAME visibility rules
                return o
        return FrozenProtected(o, rules)
    else:    # not requesting frozen
        # If inner can be frozen, whether outer is frozen or not
        if isinstance(o, (Protected, FrozenProtected)):
            d = dict(getattr(o, PROT_ATTR_NAME).rules)
            # Don't care about frozen in comparison
            d['frozen'] = want_frozen
            if rules == d:
                # Protected object with the SAME visibility rules
                return o
        return Protected(o, rules)
    '''

__all__ = [
    'contains', 'freeze', 'id_protected', 'immutable_builtin_attributes',
    'isfrozen', 'isimmutable', 'isinstance_protected', 'isprivate',
    'isprotected', 'isreadonly', 'iswrapped', 'private', 'protect', 'wrap',
    'help_protected', 'attribute_protected',
]

def __dir__():
    return __all__


# ------------------------------------------------------------------------


cimport cython
from cpython.object cimport (
    Py_LT, Py_EQ, Py_GT, Py_LE, Py_NE, Py_GE,
)
cdef object overridden_always = frozenset([
    '__getattr__', '__getattribute__', '__delattr__', '__setattr__',
])


import re
# Use compiled regex - no function call, no str operations
cdef object dunder_attr = re.compile('^__[^_].*?[^_]__$')
# ro_private_attr: Start with single _, ending n non-underscore
cdef object ro_private_attr = re.compile('^_[^_].*?(?<!_)$')
# unmangled_private_attr: Start with double _, end in non-underscore or single _
cdef object unmangled_private_attr = re.compile('^__[^_].*?[^_][_]{0,1}$')

# Python 2 str does not have isidentifier() method
cdef object attr_identifier = re.compile('^[_a-zA-Z][a-zA-Z0-9_]*$')
del re

# ------------------------------------------------------------------------
# Globals related to special methods
# ------------------------------------------------------------------------
import sys
if sys.version_info.major > 2:
    import collections.abc as CollectionsABC
else:
    import collections as CollectionsABC
import types
# From: https://docs.python.org/3/reference/datamodel.html

# m_compare, m_numeric and m_block are not USED anywhere
# Uncommented members of m_numeric, m_block # are implemented in Wrapped
# Type-specific methods im m_block_d are blocked based on self.frozen
# in Wrapped.__getattribute__. These methods are not implemented in
# Wrapped, but __getattribute__ delegates to wrapped object if
# access is not blocked

cdef set m_compare = set([
    # Comparisons - non-mutating, returning immutable bool
    '__lt__', '__le__', '__eq__', '__ne__', '__gt__', '__ge__',
    # Python2 only - returns negative int / 0 / positive int (immutable)
    '__cmp__',
])
cdef set m_numeric = set([
    # Emulating numeric types - return immutable
    '__add__', '__mul__', '__sub__', '__matmul__',
     '__truediv__', '__floordiv__', '__mod__', '__divmod__', '__pow__',
     '__lshift__', '__rshift__', '__and__', '__or__', '__xor__',
    # Emulating numeric types - reflected (swapped) operands
    # Return immutable
     '__radd__', '__rmul__', '__rsub__', '__rmatmul__',
     '__rtruediv__', '__rfloordiv__', '__rmod__', '__rdivmod__', '__rpow__',
     '__rlshift__', '__rrshift__', '__rand__', '__ror__', '__rxor__',
    # Other numeric operations - return immutable
    '__neg__', '__pos__', '__abs__', '__invert__',
    '__complex__', '__int__', '__float__', '__index__',
    '__round__', '__trunc__', '__floor__', '__ceil__',
])
# These definitely do not mutate. If present, pass to wrapped
cdef set m_safe = set([
    # Representations - return immutable
    '__format__',
    # Truth value testing - non-mutating, returning immutable bool
    '__bool__',
    # Emulating container types - non-mutating
    '__contains__', '__len__', '__length_hint__',
    # Just pass to wrapped
    '__instancecheck__', '__subclasscheck__',
    # Return None - pass to wrapped object
    '__init_subclass__', '__set_name__', '__prepare__',
    # Coroutine objects - intrinsic behavior - pass to wrapped
    'send', 'throw', 'close',
    # Context managers - intrinsic behavior - pass to wrapped
    '__enter__', '__exit__',
    # Async context managers - intrinsic behavior - pass to wrapped
    '__aenter__', '__aexit__',
    # Customizing positional arguments in class pattern matching
    # Returns tuple of strings (immutable) - pass to wrapped
    '__match_args__',
])
'''
'''
cdef set m_block = set([
    # If MutableMapping:
    '__setitem__', '__delitem__',
    # Numeric types - augmented assignments - mutating
    '__iadd__', '__imul__', '__isub__', '__imatmul__',
    '__itruediv__', '__ifloordiv__', '__imod__', '__ipow__',
    '__ilshift__', '__irshift__', '__iand__', '__ior__', '__ixor__',
    # Implementing descriptors - mutate object - block if frozen
    '__set__', '__delete__',
])
'''
'''
# Methods which may be mutating depending on type
cdef dict m_block_d =  {
    CollectionsABC.MutableMapping: set([
        'clear', 'setdefault', 'pop', 'popitem', 'update',
    ]),
    CollectionsABC.MutableSequence: set([
        'append', 'extend', 'insert', 'pop', 'remove', 'reverse', 'sort',
    ]),
    CollectionsABC.MutableSet: set([
        '__isub__',
        'add', 'clear', 'discard', 'pop', 'remove',
    ]),
    types.FrameType: set([
        'clear',
    ])
}
# These attributes of FunctionType are writable only in PY2
if sys.version_info.major == 2:
    m_block_d[types.FunctionType] = set([
        '__doc__', '__name__', '__module__',
        '__defaults__', '__code__', '__dict__',
    ])
del sys, types, CollectionsABC


# ------------------------------------------------------------------------
# End of globals related to special methods
# ------------------------------------------------------------------------

# Use special exception class for pyprotect-specific exceptions
# Cannot subclass from builtin exceptions other than Exception
# See: https://github.com/cython/cython/issues/1416
# But you CAN cdef intermediate classes and derive from them

@cython.internal
cdef class TypeError(Exception):
    pass

'''
@cython.internal
cdef class AttributeError(Exception):
    pass
'''

@cython.internal
cdef class ProtectionError(TypeError):
    pass

@cython.internal
cdef class ReadonlyTypeError(TypeError):
    pass

@cython.internal
cdef class HiddenAttributeError(Exception):
    pass

# ------------------------------------------------------------------------


@cython.final
@cython.internal
cdef class _ProtectionData(object):
    '''
    Attributes:
        id: int
        hash: method (no args) -> int
        isinstance: method: isinstance(o, x)
            identical to standard isinstance
        issubclass: method: issubclass(o, x)
            identical to standard issubclass
        help: method (no args)
        help_str: method (no args) -> str
        testop: method: testop(a: str, op: str) -> bool
        rules: dict
        freeze: method (no args) -> Wrapped
        private: method (no args) -> Private
        multiwrapped: method (no args) -> bool
    '''
    cdef public object id
    cdef public object hash
    cdef public object isinstance
    cdef public object issubclass
    cdef public object help
    cdef public object help_str
    cdef public object testop
    cdef public object rules
    cdef public object freeze
    cdef public object private
    cdef public object protect
    cdef public object multiwrapped
    cdef object attributes_map

    def __init__(
        self,
        id_val,
        hash_val,
        isinstance_val,
        issubclass_val,
        help_val,
        help_str,
        testop,
        rules,
        freeze,
        private,
        protect,
        multiwrapped,
    ):
        self.id = id_val
        self.hash = hash_val
        self.isinstance = isinstance_val
        self.issubclass = issubclass_val
        self.help = help_val
        self.help_str = help_str
        self.testop = testop
        self.rules = rules
        self.freeze = freeze
        self.multiwrapped = multiwrapped
        self.private = private
        self.protect = protect

        self.attributes_map = {
            'id': self.id,
            'hash': self.hash,
            'isinstance': self.isinstance,
            'issubclass': self.issubclass,
            'help': self.help,
            'help_str': self.help_str,
            'testop': self.testop,
            'rules': self.rules,
            'freeze': self.freeze,
            'private': self.private,
            'protect': self.protect,
            'multiwrapped': self.multiwrapped,
            '__class__': _ProtectionData,
        }

    def __getattribute__(self, a):
        if a in self.attributes_map:
            return self.attributes_map.get(a)
        missing_msg = "Object '%s' has no attribute '%s'" % (
            '_ProtectionData',
            str(a)
        )
        raise AttributeError(missing_msg)

    def __setattr__(self, a, val):
        raise ProtectionError('Object is read-only')

    def __delattr__(self, a):
        raise ProtectionError('Object is read-only')

    def __dir__(self):
        return list(self.attributes_map.keys())


cdef privatedict(o, cn, frozen=False):
    '''
    o-->Mapping (to be wrapped)
    Returns-->FrozenPrivacyDict if frozen; Privacybject otherwise
    '''
    if frozen:
        if isinstance (o, FrozenPrivacyDict):
            return o
        return FrozenPrivacyDict(o, cn)
    else:
        if isinstance (o, FrozenPrivacyDict):
            # Underlying already frozen
            return o
        elif isinstance(o, PrivacyDict):
            return o
        return PrivacyDict(o, cn)


@cython.internal
cdef class Wrapped(object):
    '''
    This is an object wrapper / proxy that adds the 'frozen' parameter
    If frozen is False, should behave just like the wrapped object, except
    following attributes cannot be modified:
        '__getattr__', '__getattribute__',
        '__delattr__', '__setattr__', '__slots__',
    If frozen is True, prevents modification of ANY attribute
    WITHOUT frozen == True:
        - Does NOT protect CLASS of wrapped object from modification
        - Does NOT protect __dict__ or __slots__
    Implements all known special methods for classes under collections etc
    The one difference is that a Wrapped instance explicitly does NOT
    support pickling, and will raise a ProtectionError
    '''
    cdef object pvt_o
    cdef bint frozen
    cdef Exception frozen_error
    cdef _ProtectionData protected_attribute
    cdef str cn
    cdef set pickle_attributes
    cdef dict rules
    cdef set special_attributes

    def __init__(self, o, frozen=False):
        '''
        o-->object to be wrapped
        frozen--bool: If True, no attribute can be modified
        '''
        from functools import partial

        self.pvt_o = o
        self.cn = o.__class__.__name__
        self.frozen = bool(frozen)
        self.frozen_error = ProtectionError('Object is read-only')
        self.pickle_attributes = set([
            '__reduce__', '__reduce_ex__',
            '__getsate__', '__setstate__',
        ])
        self.special_attributes = set([
            PROT_ATTR_NAME,
        ])

        # In case o is already wrapped, use _protectionData from o
        # This can happen if:
        # - protected module is frozen
        # - a non-frozen wrapped object is frozen with freeze
        if isinstance(o, Wrapped):
            # Keep the rules, testop of outer Wrapped
            p = getattr(o, PROT_ATTR_NAME)
            self.protected_attribute = _ProtectionData(
                id_val=p.id,
                hash_val=p.hash,
                isinstance_val=p.isinstance,
                issubclass_val=p.issubclass,
                help_val=p.help,
                help_str=p.help_str,
                testop=partial(self.testop, self),
                rules=dict(self.get_rules()),
                freeze=partial(self.freeze, self),
                private=partial(private, self.pvt_o),
                protect=partial(Protected, self.pvt_o),
                multiwrapped=partial(self.multiwrapped, self),
            )
        else:
            self.protected_attribute = _ProtectionData(
                id_val=id(self.pvt_o),
                hash_val=partial(self.hash_protected, self),
                isinstance_val=partial(self.isinstance_protected, self),
                issubclass_val=partial(self.issubclass_protected, self),
                help_val=partial(self.help_protected, self),
                help_str=partial(self.help_str_protected, self),
                testop=partial(self.testop, self),
                rules=dict(self.get_rules()),
                freeze=partial(self.freeze, self),
                private=partial(private, self.pvt_o),
                protect=partial(Protected, self.pvt_o),
                multiwrapped=partial(self.multiwrapped, self),
            )

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    cdef fif(self, o):
        '''
        fif = Freeze If Frozen
        o-->object
        Returns-->o or Frozen(o)
        '''
        if self.frozen:
            return freeze(o)
        return o

    cdef freeze(self):
        '''Smartly avoid double wrapping when freezing a Wrapped object'''
        if self.frozen:
            return self
        if isinstance(self, Protected):
            if self.rules.get('frozen', False):
                return self
            d = {}
            d.update(self.rules)
            d['frozen'] = True
            return Protected(self.pvt_o, d)
        elif isinstance(self, Private):
            return private(self.pvt_o, frozen=True)
        if isinstance(self, PrivacyDict):
            return privatedict(self.pvt_o, cn=self.cn, frozen=True)
        else:
            return freeze(self.pvt_o)

    cdef multiwrapped(self):
        '''For testing'''
        return isinstance(self.pvt_o, Wrapped)

    cdef id_protected(self):
        return id(self.pvt_o)

    cdef hash_protected(self):
        return hash(self.pvt_o)

    cdef isinstance_protected(self, c):
        return isinstance(self.pvt_o, c)

    cdef issubclass_protected(self, c):
        return issubclass(self.pvt_o.__class__, c)

    cdef help_protected(self):
        return help(self.pvt_o)

    cdef help_str_protected(self):
        '''
        We do not care about covering all possibilities, since this
        is mainly used for unit tests
        '''
        import pydoc
        import types
        if callable(self.pvt_o):
            return pydoc.text.document(self.pvt_o)
        elif isinstance(
            self.pvt_o,
            (
                type,
                property,
                types.ModuleType,
                types.ClassMethodDescriptorType,
                types.GetSetDescriptorType,
                types.MemberDescriptorType,
                types.MethodDescriptorType,
                types.MethodWrapperType,
                types.WrapperDescriptorType,
            )
        ):
            return pydoc.text.document(self.pvt_o)
        else:
            return pydoc.text.document(self.pvt_o.__class__)

    cdef testop(self, a, op):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w')
        Returns-->bool
        '''
        if op == 'r':
            return hasattr(self, a)
        elif op == 'w':
            return not self.frozen
        return False

    cdef get_rules(self):
        return dict()

    cdef comparator(self, other, op):
        '''
        Operations:
            Py_LT, Py_EQ, Py_GT, Py_LE, Py_NE, Py_GE,

        As in regular python, equality is not the same as having the
        same hash() or id()

        THIS object IS a wrapped object
        If the OTHER object is also a wrapped object:
          Equality means:
              - The other object has the same ID as the wrapped object
                id_protected(self.__class__) == id_protected(other.__class__)
              - The BEHAVIOR of THIS object is the same as the behavior
                of the OTHER object: type(self) == type(other)

            This is the SAME for Frozen, Private, FrozenPrivate
            For Protected, the rules should also be the same

          Inequality is just not(equal)

          Numeric comparisons are not supported - neither object can
            access object wrapped by the other

        If the OTHER object is NOT a wrapped object:
          All comparisons are passed to the wrapped object

        '''
        def pass_to_wrapped():
            '''Trap RecursionError if object is too deeply nested'''
            if op == Py_LT:
                try:
                    return self.pvt_o < other
                except RecursionError:
                    return NotImplemented
            elif op == Py_EQ:
                try:
                    return self.pvt_o == other
                except RecursionError:
                    return NotImplemented
            elif op == Py_GT:
                try:
                    return self.pvt_o > other
                except RecursionError:
                    return NotImplemented
            elif op == Py_LE:
                try:
                    return self.pvt_o <= other
                except RecursionError:
                    return NotImplemented
            elif op == Py_NE:
                try:
                    return self.pvt_o != other
                except RecursionError:
                    return NotImplemented
            elif op == Py_GE:
                try:
                    return self.pvt_o >= other
                except RecursionError:
                    return NotImplemented
            else:
                return NotImplemented

        if not iswrapped(other):
            return pass_to_wrapped()
        # If we got here, other is Wrapped
        # Only equality / inequality are supported. Neither object
        # can access object wrapped by the other for other comparisons.
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        res = (
            type(self) == type(other) and
            id_protected(self) == id_protected(other)
        )
        if not isprotected(self):
            if op == Py_EQ:
                return res
            elif op == Py_NE:
                return not res
        else:
            # Protected
            d1 = dict(self.rules)
            d2 = dict(getattr(other, PROT_ATTR_NAME).rules)
            try:
                del d1['kwargs']
            except KeyError:
                pass
            try:
                del d2['kwargs']
            except KeyError:
                pass
            res = res and d1 == d2
            if op == Py_EQ:
                return res
            elif op == Py_NE:
                return not res

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        from functools import partial
        # protected_attribute
        if a == PROT_ATTR_NAME:
            return self.protected_attribute
        if a in overridden_always:
            return partial(getattr(Wrapped, a), self)
        # PREVENT pickling
        if a in self.pickle_attributes:
            raise ProtectionError('Wrapped object cannot be pickled')
        delegated = getattr(self.pvt_o, a, None)
        # Special methods are all callables
        if delegated and callable(delegated):
            if a in m_numeric:
                return delegated
            # Check type-specific blocking
            for (ancestors, attr_set) in m_block_d.items():
                if isinstance(self.pvt_o, ancestors):
                    if a in attr_set:
                        if self.frozen:
                            raise self.frozen_error
                        else:
                            return delegated
        # Any non-method or missing attribute or special callable method
        # that is not delegated or blocked
        if delegated is None:
            if a in set([
                '__doc__', '__hash__', '__weakref__',
            ]):
                return delegated
            raise AttributeError(
                "Object Wrapped('%s') has no attribute '%s'" % (self.cn, a)
            )
        # If frozen, freeze all the way down
        if self.frozen:
            delegated = freeze(delegated)
        return delegated

    def __setattr__(self, a, val):
        if self.frozen:
            raise self.frozen_error
        if a in overridden_always:
            raise ProtectionError('Cannot modify attribute: %s' % (a,))
        if a in self.special_attributes:
            raise ProtectionError('Cannot modify attribute: %s' % (a,))
        setattr(self.pvt_o, a, val)

    def __delattr__(self, a):
        if self.frozen:
            raise self.frozen_error
        if a in overridden_always:
            raise ProtectionError('Cannot delete attribute: %s' % (a,))
        if a in self.special_attributes:
            raise ProtectionError('Cannot delete attribute: %s' % (a,))
        delattr(self.pvt_o, a)

    def __dir__(self):
        res_set = self.special_attributes
        delegated = set(dir(self.pvt_o))
        res_set = res_set.union(delegated)
        res_set = res_set.difference(self.pickle_attributes)
        return list(res_set)

    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)

    # Needs to be class-specific
    def __hash__(self):
        return hash((
            id(self.__class__),
            str(self.get_rules()),
            id(self.pvt_o),
            hash(self.pvt_o)
        ))

    # __repr__, __str__ and __bytes__:
    # We do not want the default cython implementations of Wrapped
    def __repr__(self):
        return repr(self.pvt_o)

    def __str__(self):
        return str(self.pvt_o)

    def __bytes__(self):
        return bytes(self.pvt_o)

    # --------------------------------------------------------------------
    # Unfortunately, Cython class needs to IMPLEMENT special methods
    # for them to work !
    # CPython looks in the CLASS, rather than dir(instance), apparently
    #
    # From: https://docs.python.org/3/reference/datamodel.html
    # --------------------------------------------------------------------

    def __call__(self, *args, **kwargs):
        x = self.pvt_o(*args, **kwargs)
        if self.frozen:
            x = freeze(x)
        return x

    def __iter__(self):
        for x in iter(self.pvt_o):
            if self.frozen:
                x = freeze(x)
            yield x

    # Representations - return immutable
    def __format__(self, val):
        return self.pvt_o.__format__(val)

    # Truth value testing - non-mutating, returning immutable bool
    def __bool__(self):
        return bool(self.pvt_o)

    # Emulating container types - non-mutating
    def __getitem__(self, key):
        x = self.pvt_o.__getitem__(key)
        if self.frozen:
            x = freeze(x)
        return x

    def __contains__(self, val):
        return self.pvt_o.__contains__(val)

    def __len__(self):
        return self.pvt_o.__len__()

    def __length_hint__(self):
        return self.pvt_o.__length_hint__()

    # Numeric types - return immutable
    def __add__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__radd__', None)):
                return val.__radd__(self)
            else:
                return NotImplemented
        return self.__add__(val)

    def __mul__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rmul__', None)):
                return val.__rmul__(self)
            else:
                return NotImplemented
        return self.__mul__(val)

    def __sub__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rsub__', None)):
                return val.__rsub__(self)
            else:
                return NotImplemented
        return self.__sub__(val)

    def __matmul__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rmatmul__', None)):
                return val.__rmatmul__(self)
            else:
                return NotImplemented
        return self.__matmul__(val)

    def __truediv__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rtruediv__', None)):
                return val.__rtruediv__(self)
            else:
                return NotImplemented
        return self.__truediv__(val)

    def __floordiv__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rtruediv__', None)):
                return val.__rtruediv__(self)
            else:
                return NotImplemented
        return self.__floordiv__(val)

    def __mod__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rmod__', None)):
                return val.__rmod__(self)
            else:
                return NotImplemented
        return self.__mod__(val)

    def __divmod__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rdivmod__', None)):
                return val.__rdivmod__(self)
            else:
                return NotImplemented
        return self.__divmod__(val)

    def __pow__(self, val, mod):
        return self.__pow__(val, mod)

    def __lshift__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rlshift__', None)):
                return val.__rlshift__(self)
            else:
                return NotImplemented
        return self.__lshift__(val)

    def __rshift__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rrshift__', None)):
                return val.__rrshift__(self)
            else:
                return NotImplemented
        return self.__rshift__(val)

    def __and__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rand__', None)):
                return val.__rand__(self)
            else:
                return NotImplemented
        return self.__and__(val)

    def __or__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__ror__', None)):
                return val.__ror__(self)
            else:
                return NotImplemented
        return self.__or__(val)

    def __xor__(self, val):
        if not isinstance(self, Wrapped):
            if callable(getattr(val, '__rxor__', None)):
                return val.__rxor__(self)
            else:
                return NotImplemented
        return self.__xor__(val)

    # Numeric types - return immutable
    def __radd__(self, val):
        return self.__radd__(val)

    def __rmul__(self, val):
        return self.__rmul__(val)

    def __rsub__(self, val):
        return self.__rsub__(val)

    def __rmatmul__(self, val):
        return self.__rmatmul__(val)

    def __rtruediv__(self, val):
        return self.__rtruediv__(val)

    def __rfloordiv__(self, val):
        return self.__rfloordiv__(val)

    def __rmod__(self, val):
        return self.__rmod__(val)

    def __rdivmod__(self, val):
        return self.__rdivmod__(val)

    def __rpow__(self, val, mod):
        return self.__rpow__(val, mod)

    def __rlshift__(self, val):
        return self.__rlshift__(val)

    def __rrshift__(self, val):
        return self.__rrshift__(val)

    def __rand__(self, val):
        return self.__rand__(val)

    def __ror__(self, val):
        return self.__ror__(val)

    def __rxor__(self, val):
        return self.__rxor__(val)



    # Other numeric operations - return immutable
    def __neg__(self):
        return self.pvt_o.__neg__()

    def __pos__(self):
        return self.pvt_o.__pos__()

    def __abs__(self):
        return self.pvt_o.__abs__()

    def __invert__(self):
        return self.pvt_o.__invert__()

    def __complex__(self):
        return self.pvt_o.__complex__()

    def __int__(self):
        return self.pvt_o.__int__()

    def __float__(self):
        return self.pvt_o.__float__()

    def __index__(self):
        return self.pvt_o.__index__()

    def __round__(self):
        return self.pvt_o.__round__()

    def __trunc__(self):
        return self.pvt_o.__trunc__()

    def __floor__(self):
        return self.pvt_o.__floor__()

    def __ceil__(self):
        return self.pvt_o.__ceil__()

    # Just pass to wrapped
    def __instancecheck__(self, inst):
        return self.pvt_o.__instancecheck__(inst)

    def __subclasscheck__(self, subclass):
        return self.pvt_o.__subclasscheck__(subclass)

    # Coroutine objects - intrinsic behavior - pass to wrapped
    def send(self, value):
        import sys
        if sys.version_info.major > 2:
            import types
            if isinstance(self.pvt_o, types.coroutine):
                return self.pvt_o.send(value)

        # Otherwise
        missing_msg = "Object '%s' has no attribute '%s'" % (self.cn, 'send')
        raise AttributeError(missing_msg)

    def throw(self, value):
        import sys
        if sys.version_info.major > 2:
            import types
            if isinstance(self.pvt_o, types.coroutine):
                return self.pvt_o.throw(value)

        # Otherwise
        missing_msg = "Object '%s' has no attribute '%s'" % (self.cn, 'throw')
        raise AttributeError(missing_msg)

    # Context managers - intrinsic behavior - pass to wrapped
    def __enter__(self):
        return self.pvt_o.__enter__()

    def __exit__(self, exc_type, exc_value, tb):
        return self.pvt_o.__exit(exc_type, exc_value, tb)

    # Async context managers - intrinsic behavior - pass to wrapped
    def __aenter__(self):
        return self.pvt_o.__aenter__()

    def __aexit__(self, exc_type, exc_value, tb):
        return self.pvt_o.__aexit(exc_type, exc_value, tb)

    # Customizing positional arguments in class pattern matching
    # Returns tuple of strings (immutable) - pass to wrapped
    def __match_args__(self):
        return self.pvt_o.__match_args__()

    def __setitem__(self, key, val):
        import sys
        if sys.version_info.major > 2:
            import collections.abc as CollectionsABC
        else:
            import collections as CollectionsABC
        if isinstance(self.pvt_o, CollectionsABC.MutableMapping):
            if self.frozen:
                raise self.frozen_error
            self.pvt_o.__setitem__(key, val)

    def __delitem__(self, key):
        import sys
        if sys.version_info.major > 2:
            import collections.abc as CollectionsABC
        else:
            import collections as CollectionsABC
        if isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableMapping,
                CollectionsABC.MutableSequence,
            )
        ):
            if self.frozen:
                raise self.frozen_error
            self.pvt_o.__delitem__(key)

    # Numeric types - augmented assignments - mutating
    def __iadd__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o += val
        return self

    def __imul__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o *= val
        return self

    def __isub__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o -= val
        return self

    def __imod__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o  %= val
        return self

    def __ilshift__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o <<= val
        return self

    def __irshift__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o >>= val
        return self

    def __iand__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o &= val
        return self

    def __ior__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o |= val
        return self

    def __ixor__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o ^= val
        return self

    def __ipow__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o **= val
        return self

    def __itruediv__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o /= val
        return self

    def __ifloordiv__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o //= val
        return self

    def __imatmul__(self, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.__imatmul__(val)
        return self

    # Implementing descriptors - mutate object
    def __set__(self, inst, val):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.__set__(inst, val)

    def __delete__(self, inst):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.__delete__(inst)

    # --------------------------------------------------------------------
    # End of special methods proxies
    # --------------------------------------------------------------------


@cython.internal
@cython.final
cdef class Frozen(Wrapped):
    '''
    Subclass of Wrapped that is automatically frozen
    '''
    def __init__(self, o):
        '''o-->object to be wrapped'''
        Wrapped.__init__(self, o, frozen=True)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)

@cython.internal
cdef class PrivacyDict(Wrapped):
    '''
    Like types.MappingProxyType - with following additional functionality:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - TODO: Cannot access any attribute not exported by dir(pvt_o)
    '''
    cdef object hidden_private_attr

    def __init__(self, o, cn, frozen=False):
        '''
        o-->dict (any Mapping or MutableMapping type)
        cn-->str: class name
        '''
        # Import locally to avoid leaking into module namespace
        import re
        import sys
        if sys.version_info.major > 2:
            import collections.abc as CollectionsABC
        else:
            import collections as CollectionsABC

        if not isinstance(o, CollectionsABC.Mapping):
            raise TypeError('o: Invalid type: %s' % (o.__class__.__name__,))
        self.cn = str(cn)
        # Use compiled regex - no function call, no str operations
        self.hidden_private_attr = re.compile('^_%s__.*?(?<!__)$' % (self.cn,))
        Wrapped.__init__(self, o=o, frozen=frozen)

    def __getattribute__(self, a):
        if self.hidden_private_attr.match(a):
            raise KeyError(a)
        # Cannot modify CLASS of wrapped object
        if a == '__class__':
            return freeze(self.pvt_o.__class__)
        # If frozen, freeze all the way down
        x = object.__getattribute__(self.pvt_o, a)
        return self.fif(x)

    # dict methods - the iter* and view* methods are for Python2 (only)
    # The reason for needing to re-implement these methods in PrivacyDict 
    # rather than # inheriting from Wrapped is not due to Dict but due to
    # Privacy - need to exclude keys / key-value pairs that match the
    #'private' keys to be excluded as part of PrivacyDict behavior

    def __getitem__(self, key):
        if self.hidden_private_attr.match(key):
            raise KeyError(key)
        return self.fif(self.pvt_o.__getitem__(key))

    def __delitem__(self, key):
        if self.hidden_private_attr.match(key):
            raise KeyError(key)
        Wrapped.__delitem__(self, key)

    def __setitem__(self, key, val):
        nopvt_msg = 'Cannot set private attribute: %s.%s' % (self.cn, str(key))

        if self.hidden_private_attr.match(key):
            raise ProtectionError(nopvt_msg)
        if ro_private_attr.match(key):
            raise ProtectionError(nopvt_msg)
        Wrapped.__setitem__(self, key, val)

    def __repr__(self):
        d = {}
        for (k, v) in self.pvt_o.items():
            if self.hidden_private_attr.match(k):
                continue
            d[k] = v
        return repr(d)

    def __str__(self):
        d = {}
        for (k, v) in self.pvt_o.items():
            if self.hidden_private_attr.match(k):
                continue
            d[k] = v
        return str(d)

    def items(self):
        return self.fif([
            (k, v) for (k, v) in self.pvt_o.items()
            if not self.hidden_private_attr.match(k)
        ])
    def values(self):
        return self.fif([
            v for (k, v) in self.pvt_o.items()
            if not self.hidden_private_attr.match(k)
        ])

    def keys(self):
        return self.fif([
            k for (k, v) in self.pvt_o.items()
            if not self.hidden_private_attr.match(k)
        ])

    def iteritems(self):
        for (k, v) in self.pvt_o.iteritems():
            if not self.hidden_private_attr.match(k):
                yield (k, v)

    def iterkeys(self):
        for k in self.pvt_o.iterkeys():
            if not self.hidden_private_attr.match(k):
                yield k

    def itervalues(self):
        for (k, v) in self.pvt_o.iteritems():
            if not self.hidden_private_attr.match(k):
                yield v

    def viewitems(self):
        return self.fif(set(self.items()))

    def viewvalues(self):
        return self.fif(set(self.values()))

    def viewkeys(self):
        return self.fif(set(self.keys()))


    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)


@cython.internal
@cython.final
cdef class FrozenPrivacyDict(PrivacyDict):
    '''
    Subclass of PrivacyDict that is automatically frozen
    '''
    def __init__(self, o, cn):
        '''o-->object to be wrapped'''
        PrivacyDict.__init__(self, o, cn, frozen=True)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)


@cython.internal
cdef class Private(Wrapped):
    '''
    Subclass of Wrapped with following additional functionality:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ or __slots__ of wrapped object
        - TODO: Cannot access any attribute not exported by dir(pvt_o)
    '''
    cdef object hidden_private_attr

    def __init__(self, o, frozen=False):
        '''
        o-->object to be wrapped
        frozen--bool: If True, no direct attribute can be modified
        '''
        Wrapped.__init__(self, o, frozen=frozen)
        # Import locally to avoid leaking into module namespace
        import re

        # Use compiled regex - no function call, no str operations
        self.hidden_private_attr = re.compile('^_%s__.*?(?<!__)$' % (self.cn,))

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    cdef testop(self, a, op):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w')
        Returns-->bool
        '''
        if op == 'r':
            return self.visible(a)
        elif op == 'w':
            return self.writeable(a)
        return False

    cdef visible(self, a):
        if a in overridden_always:
            return False
        if self.hidden_private_attr.match(a):
            return False
        return True

    cdef writeable(self, a):
        # NEVER writeable if not visible
        if not self.visible(a):
            return False
        if ro_private_attr.match(a):
            return False
        if a in self.special_attributes:
            return False
        return True

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        missing_msg = "Object '%s' has no attribute '%s'" % (self.cn, str(a))
        if a == '__dict__':
            # Can SEE but not CHANGE __dict__ - EVEN if not frozen
            d = getattr(self.pvt_o, a)
            return privatedict(d, self.cn, frozen=True)
        elif a == '__slots__':
            # Can SEE but not CHANGE __slots__ - EVEN if not frozen
            return freeze(getattr(self.pvt_o, a))
        elif a == '__class__':
            # Cannot modify CLASS of wrapped object - EVEN if not frozen
            return freeze(self.pvt_o.__class__)
        elif a == '__module__':
            # Cannot modify MODULE of wrapped object - EVEN if not frozen
            return freeze(self.pvt_o.__module__)
        if not self.visible(a):
            raise HiddenAttributeError(missing_msg)
        return Wrapped.__getattribute__(self, a)

    def __setattr__(self, a, val):
        nopvt_msg = 'Cannot set private attribute: %s.%s' % (self.cn, str(a))
        if not self.writeable(a):
            raise ProtectionError(nopvt_msg)
        if self.frozen:
            raise self.frozen_error
        setattr(self.pvt_o, a, val)

    def __delattr__(self, a):
        nopvt_msg = 'Cannot delete private attribute: %s.%s' % (self.cn, str(a))
        if not hasattr(self.pvt_o, a):
            raise AttributeError(a)
        if not self.writeable(a):
            raise ProtectionError(nopvt_msg)
        if self.hidden_private_attr.match(a):
            raise ProtectionError(nopvt_msg)
        if ro_private_attr.match(a):
            raise ProtectionError(nopvt_msg)
        delattr(self.pvt_o, a)

    def __dir__(self):
        l1 = [
            x for x in Wrapped.__dir__(self)
            if not self.hidden_private_attr.match(x) and
            self.visible(x)
        ]
        l2 = [x for x in self.special_attributes if x not in l1]
        return l1 + l2

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)


@cython.internal
@cython.final
cdef class FrozenPrivate(Private):
    '''
    Subclass of Private that is automatically frozen
    '''
    def __init__(self, o):
        '''o-->object to be wrapped'''
        Private.__init__(self, o, frozen=True)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)


@cython.internal
cdef class Protected(Private):
    '''
    Subclass of Private that allows customization of:
        - Which attributes are VISIBLE
        - Which attributes are WRITEABLE
    '''
    # Constructor parameters
    cdef bint add_allowed
    cdef bint attr_type_check
    cdef bint dynamic
    cdef bint hide_data
    cdef bint hide_method
    cdef bint ro_data
    cdef bint ro_method
    cdef object dynamic_attr
    cdef object hide_regex
    cdef object show_regex
    cdef object ro_regex
    cdef object rw_regex
    cdef dict acl_cache
    # Track attributes added at run-time
    cdef object orig_attrs
    cdef dict added_attrs
    # Cache dir() output
    cdef list dir_out

    def __init__(self, o, rules):
        '''
        o-->object to be wrapped
        rules-->dict: returned by get_visibility_rules
        '''
        self.frozen = bool(rules.get('frozen', False))
        # Import locally to avoid leaking into module namespace
        import re
        # Use compiled regex - no function call, no str operations
        self.hidden_private_attr = re.compile('^_%s__.*?(?<!__)$' % (self.cn,))
        self.special_attributes = set([
            PROT_ATTR_NAME,
        ])
        self.frozen_error = ProtectionError('Object is read-only')

        self.process_rules(rules)
        Private.__init__(self, o, frozen=self.frozen)
        self.orig_attrs = frozenset(dir(self.pvt_o))

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    cdef get_rules(self):
        return self.rules

    cdef process_rules(self, rules):
        '''
        rules-->dict
        Called once at object wrapping time
        '''
        # Import locally to avoid leaking into module namespace
        import re

        self.attr_type_check = False
        for kw in ('hide_method', 'hide_data', 'ro_method', 'ro_data'):
            if bool(rules.get(kw, False)):
                self.attr_type_check = True

        self.dynamic = rules.get('dynamic', False)
        self.frozen = bool(rules.get('frozen', False))
        self.add_allowed = bool(rules.get('add', False))
        self.added_attrs = {}

        # frozen does NOT override dynamic
        # dynamic forces 'add' to False
        if self.dynamic:
            self.add_allowed = False
            self.acl_cache = None
        else:
            self.acl_cache = {}

        self.hide_method = bool(rules.get('hide_method', False))
        self.hide_data = bool(rules.get('hide_data', False))
        self.ro_method = bool(rules.get('ro_method', False))
        self.ro_data = bool(rules.get('ro_data', False))


        self.hide_regex = re.compile(rules.get('hide_regex', ''))
        self.show_regex = re.compile(rules.get('show_regex', ''))
        self.ro_regex = re.compile(rules.get('ro_regex', ''))
        self.rw_regex = re.compile(rules.get('rw_regex', ''))

        self.build_cache()

        self.dir_out = []
        if not self.dynamic:
            # Make dir() pre-computed
            self.dir_out = [
                    k for (k, v) in self.acl_cache.items()
                    if v.get('r', False)
            ]

        self.rules = rules

    cdef build_cache(self):
        '''
        Called once at object wrapping time
        '''
        if self.acl_cache is None:
            return
        d = self.acl_cache

        hidden_d = {'r': False, 'w': False}

        for a in dir(self.pvt_o):
            if self.hidden_private_attr.match(a):
                self.acl_cache[a] = hidden_d
                continue
            d = {
                'r': self.visible(a, use_cache=False),
                'w': self.writeable(a, use_cache=False),
            }
            self.acl_cache[a] = d
            continue

    cdef check_1_op(self, a, op, use_cache=True):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w')
        use_cache-->bool
        Returns--bool

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        if op not in ('r', 'w'):
            return False

        if use_cache and self.acl_cache is not None:
            def_d = {'r': True, 'w': True}
            d = self.acl_cache.get(a, def_d)
            return d[op]

        # If we got here, we need DYNAMIC lookup
        # Either use_cache is False (in build_cache) or
        # self.acl_cache is None (self.dynamic is True)

        # Enforce hiding of private mangled attributes
        if self.hidden_private_attr.match(a):
            return False

        if op == 'r':
            # special_attributes always visible
            if a in self.special_attributes:
                return True
            # __class__, __dict__, __slots__ always visible - we wrap anyway
            if a in ('__class__', '__dict__', '__slots__'):
                return True

            # show overrides hide_*
            if self.show_regex.pattern:
                if self.show_regex.match(a):
                    return True

            if self.hide_regex.pattern:
                if self.hide_regex.match(a):
                    return False
        elif op == 'w':
            # special_attributes never writeable
            if a in self.special_attributes:
                return False
            if ro_private_attr.match(a):
                return False
            # rw overrides ro_*
            if self.rw_regex.pattern:
                if self.rw_regex.match(a):
                    return True
            if self.ro_regex.pattern:
                if self.ro_regex.match(a):
                    return False

        if self.attr_type_check is True:
            bMethod = callable(getattr(self.pvt_o, a))
            if bMethod:
                if op == 'r':
                    if self.hide_method:
                        return False
                elif op == 'w':
                    if self.ro_method:
                        return False
            else:
                if op == 'r':
                    if self.hide_data:
                        return False
                elif op == 'w':
                    if self.ro_data:
                        return False

        return True

    cdef visible(self, a, use_cache=True):
        '''
        a-->str: attribute name
        use_cache-->bool
        Returns--bool

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        if a in overridden_always:
            return False
        if self.hidden_private_attr.match(a):
            return False
        return self.check_1_op(a=a, op='r', use_cache=use_cache)

    cdef writeable(self, a, use_cache=True):
        '''
        a-->str: attribute name
        use_cache-->bool
        Returns--bool

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        # NEVER writeable if not visible
        if not self.visible(a):
            return False
        if ro_private_attr.match(a):
            return False
        if a in self.special_attributes:
            return False
        return self.check_1_op(a=a, op='w', use_cache=use_cache)

    cdef aclcheck(self, a, op):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w', 'd')
        Returns--None: Raises exceptions

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        ro_msg = 'Read only attribute: %s' % (a,)
        missing_msg = 'Attribute not found: %s' % (a,)
        nodel_msg = 'Cannot delete attribute: %s' % (a,)
        noadd_msg = 'Cannot add attribute: %s' % (a,)

        if a in self.added_attrs:
            # All perms on externally added attributes
            return    # OK
        if self.frozen and op in ('w', 'd'):
            raise self.frozen_error
        if op == 'r':
            if not self.visible(a):
                raise HiddenAttributeError(missing_msg)
            return     # OK
        elif op == 'w':
            if a in self.special_attributes:
                raise ProtectionError(ro_msg)
            if a in self.orig_attrs:
                if not self.writeable(a):
                    raise ProtectionError(ro_msg)
            else:   # new attribute
                if not self.add_allowed:
                    raise ProtectionError(noadd_msg)
            return   # OK
        elif op == 'd':
            raise ProtectionError(nodel_msg)

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        if a == 'frozen_error':
            return self.frozen_error
        self.aclcheck(a=a, op='r')
        x = Private.__getattribute__(self, a)
        try:
            self.aclcheck(a=a, op='w')
            return x
        except:   # not writeable for any reason
            return freeze(x)

    def __setattr__(self, a, val):
        self.aclcheck(a=a, op='w')
        if a in self.orig_attrs:
            setattr(self.pvt_o, a, val)
            return
        else:    # Adding new attribute
            noadd_msg = 'Cannot add attribute: %s' % (a,)
            if not self.add_allowed:
                raise ProtectionError(noadd_msg)
            setattr(self.pvt_o, a, val)
            # Mark as added externally
            self.added_attrs[a] = None

    def __delattr__(self, a):
        # Can always delete (ONLY) what was added externally
        if not hasattr(self.pvt_o, a):
            raise AttributeError(a)
        if a in self.added_attrs:
            delattr(self.pvt_o, a)
            del self.added_attrs[a]
            return
        nodel_msg = 'Cannot delete attribute: %s' % (a,)
        raise ProtectionError(nodel_msg)

    def __dir__(self):
        if self.dynamic:
            l1 = [
                x for x in Private.__dir__(self)
                if self.visible(x)
            ]
            l2 = [x for x in self.special_attributes if x not in l1]
            return l1 + l2
        else:
            return self.dir_out

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)


@cython.internal
cdef class FrozenProtected(Protected):
    '''
    Subclass of Protected that is automatically frozen
    '''
    def __init__(self, o, rules):
        '''
        o-->object to be wrapped
        rules-->dict: returned by get_visibility_rules
        '''
        rules['frozen'] = True
        Protected.__init__(self, o, rules)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)
