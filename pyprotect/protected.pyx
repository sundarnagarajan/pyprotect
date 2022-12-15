
'''
Module with methods to wrap an object controlling visibility
and mutability of attributes

VISIBILITY or READABILITY: Whether the attribute VALUE can be read

- Applies to wrapped object - NOT original object
- Should not be affected when using wrap()
- IS affected if you use private / protect
- Objects wrapped with private / protect do not expose getattr,
  __getattribute__, __setattr__ or __delattr__

MUTABILITY: Ability to CHANGE or DELETE an attribute

- Protected object will not allow CHANGING OR DELETING an attribute
  that is not VISIBLE
- Objects wrapped with private / protect do not allow modification
  of __class__, __dict__ or __slots attributes
- When using protect(o, **kwargs), writeability depends on kwargs

What kind of python objects can be wrapped?

- Any object that supports getattr, setattri, delattr and __class__
- Python2 'old-style' classes (without '__class__' attribute) are
  not supported. INSTANCES of such classes CAN be wrapped.
- Pickling / unpickling of wrapped objects is not supported
    Even if / when enabled, after a pickle-unpickle cycle,
    - Frozen objects will no longer be frozen
    - Private objects will no longer have visibility / mutability
      restrictions
    - Protected objects will no longer have custom protections

Can I wrap an object from a python C extension?
YES. See answer to 'What kind of python objects can be wrapped?'

Check if a wrapped object is frozen (immutable):
Use 'isimmutable(o)'.  Also works on objects that are not wrapped

Freeze an object only if it is mutable:
Just use 'freeze'. 'freeze' already checks, and wraps only if mutable

Will wrapper detect attributes that my object adds, changes or deletes
at RUN-TIME?

wrap / freeze / private: YES !

protect:
    If 'dynamic' is True (default): YES !

    If 'dynamic' is False, dir(wrapped_object) will not
    accurately reflect attributes added or deleted at run-time

    Note that the above caveats are UNAFFECTED by 'frozen'
    'frozen' only controls whether object can be modified from OUTSIDE
    the wrapped object

Will I need to change the code for my object / class?
ONLY in the following cases fnd ONLY if wrapped using private / protect:

- If your object DEPENDS on external visibility of traditionally
  'private' mangled object attributes, you will need to change
  the names of those attributes - this is a basic objective of
  private / protect
- If your object DEPENDS on external writeability of traditionally
  'private' attributes of the form '_var', you will need to change
  the names of those attributes - this is a basic objective of
  private / protect
- If your object DEPENDS on EXTERNAL modifability of __class__,
  __dict__ or __slots__, you will need to change the behavior
  of your object (change the code) - since this contradicts the
  basic objective of private / protect.

Code changes required when USING a wrapped object vs. using original object:
Pickling / unpickling of wrapped objects is not supported

If 'o' is your original object, and 'w' is the wrapped object:
One difference across wrap / freeze / private / protect:
dir(w) will necessarily be different from dir(o):
  Additional attributes in 'w': '_Protected_____'
  'private':
      Traditionally 'private' mangled attributes will not appear
  'protect':
      Traditionally 'private' mangled attributes will not appear
      Further differences depending on keyword arguments to 'protect'

Following applies only to wrapping with wrap / private / protect:
- Change calls to w.__getattribute__(a) to getattr(w, a)
- Change calls to w.__delattr__ to delattr(w, a)
- Change calls to w.__setattr(a, val) to setattr(w, a, val)
- Change isinstance(w, Mytypes) to isinstance_protected(w, MyTypes)
    isinstance_protected can also be used transparently on objects
    that have NOT been wrapped
    Can also (even) alias isinstance to isinstance_protected
- Change id(w) to id_protected(w). id_protected can also be used
    transparently on objects that have NOT been wrapped
    Can also (even) alias id to id_protected
- Change 'w is x' to id_protected(w) == id_protected(x)
- Change type(w) to w.__class__ if you want to use the CLASS of w
    but safely - not allowing class modifications
- Getting interactive help on an object
    Instead of help(o), use help_protected(o)
    Can also (even) alias help to help_protected

Object equality:
Two objects returned by wrap / freeze / private / protect are equal
IF AND ONLY IF all the following conditions are met:
- They wrap the SAME object - id(o1) == id(o2)
- They were wrapped using the same method
- For private: both were wrapped with the same value for 'frozen'
- For protect: the EFFECTIVE visibility and writeability implied
  by keyword arguments provided to 'protect' for the two objects
  is identical


Can a Frozen / Private / Protected class instance be wrapped again
using freeze / private / protect?
YES ! Objects are guaranteed to end up being wrapped at most once.

Checking at run-time whether an attribute is visible:
Assuming 'o' is the object, whether wrapped or not and 'a is attribute:
Just use hasattr(o, a).  Works on any object, wrapped or not

Checking at run-time whether an attribute is writeable:
Assuming 'o' is the object, whether wrapped or not and you want to set
attribute 'a' to value 'val':

Pythonic way - optimistic - try and handle exception

try:
    setattr(o, a, val)
except Exception:
    # Do something if attribute cannot be set
    # Should (hopefully) work on any object, wrapped or not
    pass

Non-pythonic way - 'check and hope'
if isreadonly(o, a):
    # Do something if attribute is read-only
    pass
else:
    # Do something else if attribute is writeable
    pass

Checking at run-time whether an attribute can be deleted:
Assuming 'o' is the object, whether wrapped or not and you want to delete
attribute 'a':

try:
    delattr(o, a)
except Exception:
    # Do something if attribute cannot be deleted
    # Should (hopefully) work on any object, wrapped or not
    pass

'''

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
import os
import re
import types
import functools
import pydoc

# ------------------------------------------------------------------------
# Methods to query metadata on wrapped object
# ------------------------------------------------------------------------

def attribute_protected():
    '''Returns: str: name of special attribute in Wrapped objects'''
    return PROT_ATTR_NAME

def id_protected(o: object) -> int:
    '''
    id_protected(o: object) -> int:
    id of wrapped object if iswrapped(o); id of 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).id
    return id(o)


def hash_protected(o: object) -> int:
    '''
    hash_protected(o: object) -> int:
    hash of wrapped object if iswrapped(o); hash of 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).hash()
    return hash(o)


def isinstance_protected(o: object, c: type) -> bool:
    '''
    isinstance_protected(o: object, c: type) -> bool:
    Returns: isinstance(wrapped_object, c) if iswrapped(o)
        isinstance(o, c) otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).isinstance(c)
    return isinstance(o, c)


def issubclass_protected(o: type, c: type) -> bool:
    '''
    Returns: issubclass(wrapped_object, c) if iswrapped(o);
        issubclass(o, c) otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).issubclass(c)
    return issubclass(o, c)


def help_protected(o: object) -> None:
    '''
    Calls help(wrapped_object) if iswrapped(o); help(o) otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).help()
    return help(o)


def contains(p: object, o: object):
    '''
    contains(p: object, o: object): bool: whether 'p' wraps 'o'
    '''
    if isinstance(p, Wrapped):
        return getattr(p, PROT_ATTR_NAME).id == id(o)
    return False


# ------------------------------------------------------------------------
# Boolean checks on (potentially) wrapped object
# ------------------------------------------------------------------------


def isimmutable(o: object) -> bool:
    '''
    isimmutable(o: object) -> bool: 'o' is KNOWN to be immutable
    '''
    # Everything in builtin module is immutable
    if id(o) in builtins_ids:
        return True
    # None and NotImplemented are immutable
    if o is None or o is NotImplemented:
        return True
    if isfrozen(o):
        return True
    if type(o) in immutable_types_set:
        return True
    return False


def iswrapped(o: object) -> bool:
    '''
    iswrapped(o: object) -> bool:
    'o' was created using wrap / freeze / private / protect
    '''
    return isinstance(o, Wrapped)


def isfrozen(o: object) -> bool:
    '''
    isfrozen(o: object) -> bool: 'o' was created using freeze()
    '''
    return isinstance(o, (
        Frozen, FrozenPrivate, FrozenPrivacyDict, FrozenProtected,
    ))


def isprivate(o: object) -> bool:
    '''
    isprivate(o: object) -> bool: 'o' was created using private()
    '''
    return isinstance(o, (
        Private,
        FrozenPrivate,
    ))


def isprotected(o: object) -> bool:
    '''
    isprotected(o: object) -> bool: 'o' was created using protect()
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


# ------------------------------------------------------------------------
# Methods to created Wrapped objects
# ------------------------------------------------------------------------


def wrap(o: object) -> object:
    '''
    wrap(o: object) -> object:
    Returns: instance of Wrapped

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
    Returns: Instance of Frozen | FrozenPrivacyDict | FrozenPrivate |
        FrozenProtected, depending on what 'o' is

    Object returned prevents modification of ANY attribute
    '''
    if isfrozen(o):
        # Never freeze twice
        return o
    elif isimmutable(o):
        # Object is KNOWN to be immutable - return as-is
        return o
    # Must freeze

    # If Wrapped, avoid double wrapping
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).freeze()
    return Frozen(o)


def private(o: object, frozen: bool = False) -> object:
    '''
    private(o: object, frozen: bool = False) -> object:
        Returns: Instance of FrozenPrivate if frozen; Private otherwise

    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot access any attribute not exported by dir(o)
        - Cannot access any unmangled double '_' attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify __class__ of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
        - Cannot add or delete attributes

    FrozenPrivate:
        Features of Private PLUS prevents modification of ANY attribute

    '''
    # Avoid double-wrapping
    if frozen or isfrozen(o):
        frozen = True
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).private()
    else:
        if frozen:
            return FrozenPrivate(o)
        else:
            return Private(o)


def protect(
    o: object,
    frozen: bool = False, dynamic: bool = True,
    hide_private: bool = False,
    ro_data: bool = False, ro_method: bool = True,
    ro=[], rw=[], hide=[],
):
    '''
    protect(
        o: object,
        frozen: bool = False, dynamic: bool = True,
        hide_private: bool = False,
        ro_data: bool = False, ro_method: bool = True,
        ro=[], rw=[], hide=[],
    ):

    o: object to be wrapped
    frozen: bool: No attribute can be modified
        PLUS: if 'o' is NOT a module, results returned by methods,
        including __call__ will be frozen
    dynamic: bool: Attribute additions, deletions, type changes in wrapped
        object are automatically considered by hide_private, ro_data,
        ro_method, ro, rw, hide
        If dynamic is False, it is a pledge that attributes of wrapped
        object will not change, and visibility and mutability rules of
        WRAPPING object use a cache to make them faster.
        Rules imposed by Private() are always dynamic
    hide_private: bool: Private vars (_var) will be hidden
    ro_data: bool: Data attributes cannot be deleted or assigned to
    ro_method: bool: Method attributes cannot be deleted or assigned to
    ro: list of str: attributes that will be read-only
    rw: list of str: attributes that will be read-write
        Overrides 'ro_*'
    hide: list of str: attributes that will be hidden

    Returns-->Instance of FrozenProtected if frozen; Protected otherwise

    Protected:
        Features of Private PLUS additional restrictions on:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE

    FrozenProtected:
        Features of Protected PLUS prevents modification of ANY attribute

    Default settings:
    Features of Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot access any attribute not exported by dir(o)
        - Cannot access any unmangled double '_' attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify __class__ of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
        - Cannot add or delete attributes
    PLUS:
        - Methods are readonly - cannot be deleted or assigned to
    '''
    kwargs = {
        'frozen': frozen,
        'hide_private': hide_private,
        'ro_data': ro_data,
        'ro_method': ro_method,
        'ro': ro,
        'rw': rw,
        'hide': hide,
        'dynamic': dynamic,
    }

    # Avoid double-wrapping
    if isprotected(o):
        kw1 = getattr(o, PROT_ATTR_NAME).rules.get('kwargs', {})
        d = {}
        for (k, v) in kw1.items():
            d[k] = v
        kw1 = d
        kw2 = dict(kwargs)
        kwargs = protected_merge_kwargs(kw1, kw2)
        assert(isinstance(kwargs, dict))
    rules = dict(protected_rules_from_kwargs(kwargs))
    assert(isinstance(rules, dict))
    want_frozen = bool(rules.get('frozen', False)) or isfrozen(o)
    if want_frozen and not isfrozen(o):
        # Frozen objects remain frozen
        rules['frozen'] = True
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).protect(rules)
    else:
        if want_frozen:
            return FrozenProtected(o, rules)
        else:
            return Protected(o, rules)


# ------------------------------------------------------------------------
# Other python-accesssible attributes
# ------------------------------------------------------------------------


def immutable_builtin_attributes():
    '''
    Returns: frozenset of str: attributes in builtins that are immutable
    '''
    return builtin_module_immutable_attributes

__all__ = [
    'contains', 'freeze', 'id_protected', 'immutable_builtin_attributes',
    'isfrozen', 'isimmutable', 'isinstance_protected', 'isprivate',
    'isprotected', 'isreadonly', 'iswrapped', 'private', 'protect', 'wrap',
    'help_protected', 'attribute_protected',
    '__file__',
]


def __dir__():
    return __all__


# ------------------------------------------------------------------------
# End of python-accesssible methods
# ------------------------------------------------------------------------


cdef frozenset immutable_types_set
cdef frozenset builtins_ids
cdef frozenset builtin_module_immutable_attributes
# The module only uses PROT_ATTR_NAME, never '_protected_____' 
# PROT_ATTR_NAME is set ONLY in get_protected_attr_name()
cdef str PROT_ATTR_NAME = get_protected_attr_name()
cdef Exception frozen_error = ProtectionError('Object is read-only')
(
    immutable_types_set,
    builtin_module_immutable_attributes,
    builtins_ids
) = get_immutables()
cimport cython
from cpython.object cimport (
    Py_LT, Py_EQ, Py_GT, Py_LE, Py_NE, Py_GE,
)
cdef object overridden_always = frozenset([
    '__getattr__', '__getattribute__', '__delattr__', '__setattr__',
])
cdef object pickle_attributes = frozenset([
    '__reduce__', '__reduce_ex__',
    '__getsate__', '__setstate__',
])
cdef object special_attributes = frozenset([
    PROT_ATTR_NAME,
])
cdef object always_delegated = frozenset([
    '__doc__', '__hash__', '__weakref__',
    '__package__', 
])
cdef object always_frozen = frozenset([
    '__dict__', '__slots__', '__class__',
    '__module__',
])

# Use compiled regex - no function call, no str operations
# Python 2 str does not have isidentifier() method
cdef object attr_identifier = re.compile('^[_a-zA-Z][a-zA-Z0-9_]*$')
# ro_private_attr: Start with single _, ending n non-underscore
cdef object ro_private_attr = re.compile('^_[^_].*?(?<!_)$')
# unmangled_private_attr: Start with double _, end in non-underscore or single _
cdef object unmangled_private_attr = re.compile('^__[^_].*?[^_][_]{0,1}$')
# PY2 'Old style' CLASSES (not INSTANCES of such classes) do not have
# __class__ attribute, so Private wrappers around such classes will hide
# ALL similar looking attributes
cdef object mangled_private_attr_classname_regex = '[a-zA-Z][a-zA-Z0-9]*'
cdef object mangled_private_attr_regex_fmt = '^_%s__[^_](.*?[^_]|)[_]{0,1}$'

# ------------------------------------------------------------------------
# Globals related to special methods
# ------------------------------------------------------------------------
# From: https://docs.python.org/3/reference/datamodel.html

# Members of m_safe, m_numeric, m_block are implemented in Wrapped

# m_block used in Wrapped.wrapped_getattr and Protected.protected_getattr
cdef set m_block = set([
    # If MutableMapping:
    '__setitem__', '__delitem__',
    # Numeric types - augmented assignments - mutating
    '__iadd__', '__imul__', '__isub__', '__imatmul__',
    '__itruediv__', '__ifloordiv__', '__imod__', '__ipow__',
    '__ilshift__', '__irshift__', '__iand__', '__ior__', '__ixor__',
    # Implementing descriptors - mutate object - block if frozen
    '__set__', '__delete__',
    # Type-specific mutating methods (containers)
    'add', 'append', 'clear', 'discard', 'popitem', 'insert', 'pop',
    'remove', 'reverse', 'setdefault', 'sort', 'update',
])
#

cdef set m_numeric = set([
    # Emulating numeric types - return immutable
    '__add__', '__mul__', '__sub__', '__matmul__',
     '__truediv__', '__floordiv__', '__mod__', '__divmod__', '__pow__',
     '__lshift__', '__rshift__', '__and__', '__or__', '__xor__',
    # Emulating numeric types - reflected (swapped) operands - Return immutable
     '__radd__', '__rmul__', '__rsub__', '__rmatmul__',
     '__rtruediv__', '__rfloordiv__', '__rmod__', '__rdivmod__', '__rpow__',
     '__rlshift__', '__rrshift__', '__rand__', '__ror__', '__rxor__',
    # Other numeric operations - return immutable
    '__neg__', '__pos__', '__abs__', '__invert__',
    '__complex__', '__int__', '__float__', '__index__',
    '__round__', '__trunc__', '__floor__', '__ceil__',
])

# m_compare not used anywhere
cdef set m_compare = set([
    # Comparisons - non-mutating, returning immutable bool
    # These are automatically implemented by Cython because we
    # implement __richcmp__
    '__lt__', '__le__', '__eq__', '__ne__', '__gt__', '__ge__',
    # Python2 only - returns negative int / 0 / positive int (immutable)
    '__cmp__',
])

# m_safe not used anywhere
# m_safe definitely do not mutate. If present, pass to wrapped
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
# Methods which may be mutating depending on type
cdef dict m_block_d =  {
}
# These attributes of FunctionType are writable only in PY2
# TODO: Make such objects read-only in Private/Protected
if PY2:
    m_block_d[types.FunctionType] = set([
        '__doc__', '__name__', '__module__',
        '__defaults__', '__code__', '__dict__',
    ])
# ------------------------------------------------------------------------
# End of globals related to special methods
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Use special exception class for pyprotect-specific exceptions
# Cannot subclass from builtin exceptions other than Exception
# See: https://github.com/cython/cython/issues/1416
# But you CAN cdef intermediate classes and derive from them
# ------------------------------------------------------------------------
@cython.internal
cdef class ProtectionError(Exception):
    pass
# ------------------------------------------------------------------------


cdef get_protected_attr_name():
    '''Returns: str'''
    # The ONLY place where the name of the special attribute is set
    cdef str LOCAL_PROT_ATTR_NAME = '_Protected_____'
    cdef str ENV_VAR = LOCAL_PROT_ATTR_NAME
    cdef str PROT_ATTR_SHORTEST_SUFFIX = '_____'
    # Can override by setting env var '_Protected_____'
    # Value of env var '_Protected_____' will be fixed to have EXACTLY
    # ONE leading underscore and AT LEAST 5 trailing underscores
    x = os.environ.get(ENV_VAR, None)
    if x is not None:
        if x.startswith('_'):
            x = x.lstrip('_') + '_'
        if not x.endswith(PROT_ATTR_SHORTEST_SUFFIX):
            x = x.rstrip('_') + PROT_ATTR_SHORTEST_SUFFIX
        return x
    return LOCAL_PROT_ATTR_NAME

cdef get_builtin_obj(s):
    '''
    s-->str: attribute name in builtin_module
    Returns-->object
    '''
    return getattr(builtin_module, s)

cdef get_immutables():
    '''
    Returns: tuple of frozenset:
        immutable_types_set: frozenset(type)
        builtin_module_immutable_attributes : frozenset(str)
        builtins_ids: frozenset(int)
    '''
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

    cdef frozenset ret_immutable_types_set
    cdef frozenset ret_builtins_ids
    cdef frozenset ret_builtin_module_immutable_attributes


    builtin_names = dir(builtin_module)

    basic_data_names = [
        'bool', 'bytearray', 'bytes', 'complex',
        'dict', 'float', 'frozenset', 'int', 'list', 'object', 'set', 'str',
        'tuple', 'basestring', 'unichr', 'unicode', 'long'
    ]
    basic_mutable_data_names = ['bytearray', 'dict', 'list']
    basic_immutable_data_names = [
        'bool', 'bytes', 'complex', 'float',
        'frozenset', 'int', 'str', 'tuple', 'basestring', 'unichr',
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

    mapping_types = [dict, CollectionsABC.MutableMapping, CollectionsABC.Mapping]
    list_types = [list, CollectionsABC.MutableSequence]
    tuple_types = [tuple, CollectionsABC.Sequence]
    set_types = [set, CollectionsABC.Set, CollectionsABC.MutableSet]

    sequence_types = tuple_types + list_types

    mutable_sequence_types = list_types
    mutable_mapping_types = [dict, CollectionsABC.MutableMapping]
    mutable_set_types = [set, CollectionsABC.MutableSet]


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

    ret_immutable_types_set = frozenset(immutable_types)
    ret_builtin_module_immutable_attributes = frozenset(s)
    ret_builtins_ids = frozenset([
        id(getattr(builtin_module, a)) for a in builtin_names
        if a in ret_builtin_module_immutable_attributes
    ])

    return (
        ret_immutable_types_set,
        ret_builtin_module_immutable_attributes,
        ret_builtins_ids,
    )
# ------------------------------------------------------------------------


cdef protected_rules_from_kwargs(kwargs):
    '''
    kwargs-->dict
    Returns-->dict
    Called once by protect() before Protected class initialization
    '''
    def _build_regex(alist):
        _ret = ''
        _rl = []
        if not alist:
            return re.compile(_ret)
        for _x in alist:
            if not isinstance(_x, str):
                continue
            if attr_identifier.match(_x):
                _rl += ['^%s$' % (_x,)]
        for _x in _rl:
            if _ret:
                _ret = _ret + '|' + _x
            else:
                _ret = _x
        return re.compile(_ret)

    ro_method = bool(kwargs.get('ro_method', False))
    ro_data = bool(kwargs.get('ro_data', False))
    hide_private = kwargs.get('hide_private', False)

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
    ro = frozenset(ro)
    rw = frozenset(rw)
    hide = frozenset(hide)

    # Build regexes
    hide_regex = _build_regex(hide)
    ro_regex = _build_regex(ro)
    rw_regex = _build_regex(rw)

    d = {
        'hide_private': hide_private,
        'hide_regex': hide_regex,
        'ro_regex': ro_regex,
        'rw_regex': rw_regex,
        'ro_method': bool(ro_method),
        'ro_data': bool(ro_data),
    }
    d['dynamic'] = kwargs.get('dynamic', False)
    d['frozen'] = bool(kwargs.get('frozen', False))
    d['kwargs'] = kwargs

    d['attr_type_check'] = False
    for kw in ('ro_method', 'ro_data'):
        if bool(d.get(kw, False)):
            d['attr_type_check'] = True

    return d

cdef protected_merge_kwargs(kw1: dict, kw2: dict):
    '''
    Merges kw1 and kw2 to return dict with most restrictive options
    kw1, kw2: dict
    Returns: dict
    Called once by protect() before Protected class initialization
    '''
    (kw1, kw2) = (dict(kw1), dict(kw2))
    d = {}
    # Permissive options - must be 'and-ed'
    # dynamic defaults to True while add defaults to False
    a = 'dynamic'
    d[a] = (kw1.get(a, True) and kw2.get(a, True))

    # Restrictive options must be 'or-ed'
    for a in (
        'frozen', 'hide_private', 'ro_data', 'ro_method',
    ):
        d[a] = (kw1.get(a, False) or kw2.get(a, False))

    # Restrictive lists are unioned
    for a in (
        'ro', 'hide',
    ):
        d[a] = list(
            set(list(kw1.get(a, []))).union(set(list(kw2.get(a, []))))
        )
    return d


cdef privatedict(o, cn, frozen=False, oldstyle_class=None):
    '''
    o-->Mapping (to be wrapped)
    Returns-->FrozenPrivacyDict if frozen; Privacybject otherwise
    '''
    if frozen:
        if isinstance (o, FrozenPrivacyDict):
            return o
        return FrozenPrivacyDict(o, cn, oldstyle_class)
    else:
        if isinstance (o, FrozenPrivacyDict):
            # Underlying already frozen
            return o
        elif isinstance(o, PrivacyDict):
            return o
        return PrivacyDict(o, cn, oldstyle_class)


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
    cdef _ProtectionData protected_attribute
    cdef str cn
    cdef dict rules
    cdef bint oldstyle_class
    cdef object hidden_private_attr

    def __init__(self, o, frozen=False, rules=None, oldstyle_class=None):
        '''
        o: object to be wrapped
        frozen: bool: If True, no attribute can be modified
        rules: dict (if called from Protected.__init__) or None
        '''
        if isinstance(o, Wrapped):
            # We claim to be avoiding double-wrapping, so this exception
            # should never be raised
            raise RuntimeError('Double-wrapped!')

        self.pvt_o = o
        self.frozen = bool(frozen)
        if oldstyle_class is None:
            self.oldstyle_class = False
        else:
            self.oldstyle_class = oldstyle_class
        if PY2:
            # In PY2 old-style classes don't have __class__ attribute !
            # When such CLASSES (not INSTANCES of such classes) are
            # wrapped with Private, the class name cannot be used to
            # identify mangled private attributes to hide, so ALL
            # attributes of the form _CCC__YYYz where z is '' or '_'
            # are hidden.
            # If it is an old style PY2 CLASS, CCC is a REGEX, otherwise
            # CCC is self.cn
            # Instances of such classes CAN be wrapped normally.
            if hasattr(o, '__class__'):
                if type(o) is type:
                    if self.cn is None:
                        self.cn = o.__name__
                else:
                    if self.cn is None:
                        self.cn = str(o.__class__.__name__)
            else:
                if self.cn is None:
                    self.cn = 'Unknown_OldStyle_Class'
                if oldstyle_class is None:
                    self.oldstyle_class = True
        else:
            if type(o) is type:
                if self.cn is None:
                    self.cn = o.__name__
            else:
                if self.cn is None:
                    self.cn = str(o.__class__.__name__)

        # self.hidden_private_attr is set in Wrapped.__init__ but
        # only used in Private and descendants
        if self.oldstyle_class:
            self.hidden_private_attr = re.compile(
                mangled_private_attr_regex_fmt % (
                    mangled_private_attr_classname_regex,
                )
            )
        else:
            self.hidden_private_attr = re.compile(
                mangled_private_attr_regex_fmt % (
                    self.cn,
                )
            )

        # Special code to avoid double-wrapping of Protected
        if rules is None:
            rules = dict(self.get_rules())

        if self.frozen:
            protect_class = FrozenProtected
            private_class = FrozenPrivate
        else:
            protect_class = Protected
            private_class = Private

        self.protected_attribute = _ProtectionData(
            id_val=id(self.pvt_o),
            hash_val=functools.partial(self.hash_protected, self),
            isinstance_val=functools.partial(self.isinstance_protected, self),
            issubclass_val=functools.partial(self.issubclass_protected, self),
            help_val=functools.partial(self.help_protected, self),
            help_str=functools.partial(self.help_str_protected, self),
            testop=functools.partial(self.testop, self),
            rules=rules,
            freeze=functools.partial(self.freeze, self),
            private=functools.partial(private_class, self.pvt_o),
            protect=functools.partial(protect_class, self.pvt_o),
            multiwrapped=functools.partial(self.multiwrapped, self),
        )

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    cdef attr_hidden(self, attr):
        '''
        Central place where we decide if an attribute or key in a
        PrivacyDict is hidden
        '''
        if unmangled_private_attr.match(attr):
            return True
        if self.hidden_private_attr.match(attr):
            return True

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
            d = {}
            d.update(self.rules)
            d['frozen'] = True
            return FrozenProtected(self.pvt_o, d)
        elif isinstance(self, Private):
            return FrozenPrivate(self.pvt_o)
        if isinstance(self, PrivacyDict):
            return FrozenPrivacyDict(self.pvt_o, cn=self.cn)
        else:
            return Frozen(self.pvt_o)

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
        return '\n'.join(
            pydoc.render_doc(self.pvt_o).splitlines()[2:]
        ).rstrip('\n') + '\n'

    cdef visible(self, a):
        return True

    cdef writeable(self, a):
        # Needs to be FAST - called in __setattr__, __delattr__
        return not self.frozen

    cdef testop(self, a, op):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w')
        Returns-->bool
        '''
        if op == 'r':
            return hasattr(self, a)
        elif op == 'w':
            if not self.writeable(a):
                return False
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
            # Don't consider kwargs, just the rules
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

    cdef wrapped_getattr(self, a):
        # protected_attribute
        if a == PROT_ATTR_NAME:
            return self.protected_attribute
        if a in overridden_always:
            return functools.partial(getattr(Wrapped, a), self)

        # PREVENT pickling - doesn't work even if methods are implemented,
        if a in pickle_attributes:
            raise AttributeError('Wrapped object cannot be pickled')

        delegated = getattr(self.pvt_o, a, None)
        if a in always_delegated:
            return delegated

        # Container mutating methods - implemented and selectively blocked
        if a in m_block and hasattr(Wrapped, a):
            return functools.partial(getattr(Wrapped, a), self)
        # Any non-method or missing attribute or special callable method
        # that is not delegated or blocked
        if delegated is None:
            if delegated in dir(self.pvt_o):
                return delegated
            raise AttributeError(
                "Object Wrapped('%s') has no attribute '%s'" % (self.cn, a)
            )
        # If frozen, freeze all the way down
        if self.frozen:
            # Specifically in case of ModuleType, make resultant
            # object behave closest to a python module:
            #   Module object ITSELF is frozen, but objects returned
            #   FROM the module by methods, classes are not
            if not isinstance(self.pvt_o, types.ModuleType):
                delegated = freeze(delegated)
        return delegated

    cdef wrapped_check_setattr(self, a, val):
        if self.frozen:
            raise frozen_error
        if a in overridden_always:
            raise ProtectionError('Cannot modify attribute: %s' % (a,))
        if a in special_attributes:
            raise ProtectionError('Cannot modify attribute: %s' % (a,))

    cdef wrapped_check_delattr(self, a):
        if self.frozen:
            raise frozen_error
        if a in overridden_always:
            raise ProtectionError('Cannot delete attribute: %s' % (a,))
        if a in special_attributes:
            raise ProtectionError('Cannot delete attribute: %s' % (a,))
        if not hasattr(self.pvt_o, a) and a in self.__dir__():
            raise ProtectionError('Cannot delete attribute: %s' % (a,))

    cdef wrapped_dir(self):
        res_set = special_attributes
        delegated = set(dir(self.pvt_o))
        res_set = res_set.union(delegated)
        res_set = res_set.difference(pickle_attributes)
        return list(res_set)

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        return self.wrapped_getattr(a)

    def __setattr__(self, a, val):
        # Only checks and raises exceptions
        self.wrapped_check_setattr(a, val)
        setattr(self.pvt_o, a, val)

    def __delattr__(self, a):
        # Only checks and raises exceptions
        self.wrapped_check_delattr(a)
        delattr(self.pvt_o, a)

    def __dir__(self):
        return self.wrapped_dir()

    def __richcmp__(self, other, int op):
        '''Use common method for all Wrapped objects'''
        return self.comparator(other, op)

    # Needs to be class-specific
    # Depends on pbt_o being hashable
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
    # From: https://docs.python.org/3/reference/datamodel.html
    # --------------------------------------------------------------------

    def __call__(self, *args, **kwargs):
        if iswrapped(self.pvt_o):
            # We claim to be avoiding double-wrapping, so this code
            # should never be reached
            raise RuntimeError('Double-wrapped!')

        x = self.pvt_o(*args, **kwargs)
        if self.frozen:
            x = Frozen(x)
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

    # Unary numeric operations - return immutable
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

    # The numeric operations below - including the reversed versions
    # are not required for INT or FLOAT, but SOME (like __add__) ARE
    # required for sequences

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

    # Numeric types - reversed - - return immutable
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

    # Numeric types - augmented assignments - mutating
    def __iadd__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o += val
        return self

    def __imul__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o *= val
        return self

    def __isub__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o -= val
        return self

    def __imod__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o  %= val
        return self

    def __ilshift__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o <<= val
        return self

    def __irshift__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o >>= val
        return self

    def __iand__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o &= val
        return self

    def __ior__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o |= val
        return self

    def __ixor__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o ^= val
        return self

    def __ipow__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o **= val
        return self

    def __itruediv__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o /= val
        return self

    def __ifloordiv__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o //= val
        return self

    def __imatmul__(self, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o.__imatmul__(val)
        return self

    # Mutating methods of containers
    def __setitem__(self, key, val):
        if isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableMapping,
                CollectionsABC.MutableSequence,
            )
        ):
            if self.frozen:
                raise frozen_error
        self.pvt_o.__setitem__(key, val)

    def __delitem__(self, key):
        if isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableMapping,
                CollectionsABC.MutableSequence,
            )
        ):
            if self.frozen:
                raise frozen_error
        self.pvt_o.__delitem__(key)

    # Just pass to wrapped
    def __instancecheck__(self, inst):
        return self.pvt_o.__instancecheck__(inst)

    def __subclasscheck__(self, subclass):
        return self.pvt_o.__subclasscheck__(subclass)

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

    # Coroutine objects - intrinsic behavior - pass to wrapped
    def send(self, value):
        return self.pvt_o.send(value)

    def throw(self, value):
        return self.pvt_o.throw(value)

    # Implementing descriptors - mutate object
    def __set__(self, inst, val):
        if self.frozen:
            raise frozen_error
        self.pvt_o.__set__(inst, val)

    def __delete__(self, inst):
        if self.frozen:
            raise frozen_error
        self.pvt_o.__delete__(inst)

    # --------------------------------------------------------------------
    # End of special methods proxies
    # --------------------------------------------------------------------


    # --------------------------------------------------------------------
    # Mutating methods of containers
    # --------------------------------------------------------------------

    def clear(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableMapping,
                CollectionsABC.MutableSet,
                types.FrameType,
            )
        ):
            raise frozen_error
        return self.pvt_o.clear(*args, **kwargs)

    def setdefault(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o,CollectionsABC.MutableMapping
        ):
            raise frozen_error
        return self.pvt_o.setdefault(*args, **kwargs)

    def pop(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableMapping,
                CollectionsABC.MutableSequence,
                CollectionsABC.MutableSet,
            )
        ):
            raise frozen_error
        return self.pvt_o.pop(*args, **kwargs)

    def popitem(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableMapping
        ):
            raise frozen_error
        return self.pvt_o.popitem(*args, **kwargs)

    def update(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableMapping
        ):
            raise frozen_error
        return self.pvt_o.update(*args, **kwargs)


    def append(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableSequence
        ):
            raise frozen_error
        return self.pvt_o.append(*args, **kwargs)

    def extend(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableSequence
        ):
            raise frozen_error
        return self.pvt_o.extend(*args, **kwargs)

    def insert(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableSequence
        ):
            raise frozen_error
        return self.pvt_o.insert(*args, **kwargs)

    def sort(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableSequence
        ):
            raise frozen_error
        return self.pvt_o.sort(*args, **kwargs)

    def add(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableSet
        ):
            raise frozen_error
        return self.pvt_o.add(*args, **kwargs)

    def discard(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o, CollectionsABC.MutableSet
        ):
            raise frozen_error
        return self.pvt_o.discard(*args, **kwargs)

    def remove(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableSet,
                CollectionsABC.MutableSequence,
            )
        ):
            raise frozen_error
        return self.pvt_o.remove(*args, **kwargs)

    def reverse(self, *args, **kwargs):
        if self.frozen and isinstance(
            self.pvt_o,
            (
                CollectionsABC.MutableSequence,
            )
        ):
            raise frozen_error
        return self.pvt_o.reverse(*args, **kwargs)
    # --------------------------------------------------------------------
    # End of mutating methods of containers
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

    def __init__(self, o, cn, frozen=False, oldstyle_class=None):
        '''
        o-->dict (any Mapping or MutableMapping type)
        cn-->str: class name
        '''
        # In PY2 __dict__ is a dictproxy - not in types module and
        # not instance of dict or CollectionsABC.Mapping
        if PY2:
            class C(object):
                pass

            t = type(C.__dict__)
        else:
            t = CollectionsABC.Mapping
        if not isinstance(o, (t, dict)):
            raise TypeError('o: Invalid type: %s' % (o.__class__.__name__,))

        self.cn = str(cn)
        Wrapped.__init__(self, o=o, frozen=frozen, oldstyle_class=oldstyle_class)

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        if self.attr_hidden(a):
            raise KeyError(a)
        # Cannot modify CLASS of wrapped object
        if a == '__class__':
            return freeze(self.pvt_o.__class__)
        if a in set([
            '__getitem__', '__setitem__', '__delitem__',
            '__str__', '__repr__',
            'copy',
            'iterkeys', 'iteritems', 'itervalues',
            'viewkeys', 'viewitems', 'viewvalues',
        ]):
            return functools.partial(getattr(PrivacyDict, a), self)
        if a in set([
            'keys', 'items', 'values', 'copy',
        ]):
            py2_map = {
                'keys': functools.partial(getattr(PrivacyDict, 'keys_py2'), self),
                'items': functools.partial(getattr(PrivacyDict, 'items_py2'), self),
                'values': functools.partial(getattr(PrivacyDict, 'values_py2'), self),
            }
            if PY2 and a in py2_map:
                return py2_map[a]
            return functools.partial(getattr(PrivacyDict, a), self)

        # If frozen, freeze all the way down
        return self.wrapped_getattr(a)

    def __getitem__(self, key):
        if self.attr_hidden(key):
            raise KeyError(key)
        return self.fif(self.pvt_o.__getitem__(key))

    def __delitem__(self, key):
        if self.attr_hidden(key):
            raise KeyError(key)
        nodel_msg = 'Cannot delete private attribute: %s.%s' % (self.cn, str(key))
        if ro_private_attr.match(key):
            raise ProtectionError(nodel_msg)
        Wrapped.__delitem__(self, key)

    def __setitem__(self, key, val):
        nopvt_msg = 'Cannot set private attribute: %s.%s' % (self.cn, str(key))

        if self.attr_hidden(key):
            raise ProtectionError(nopvt_msg)
        if ro_private_attr.match(key):
            raise ProtectionError(nopvt_msg)
        Wrapped.__setitem__(self, key, val)

    def __repr__(self):
        ret = dict([x for x in self.items()])
        return repr(ret)

    def __str__(self):
        ret = dict([x for x in self.items()])
        return str(ret)

    def copy(self):
        # TODO: Something strange here: Just wrapping self.pvt_o and returning
        # as a new FrozenPrivacyDict doesn't seem to adopt all the behavior
        # of PrivacyDict!
        d = {}
        d.update(dict(self.items()))
        # return privatedict(d, self.cn, frozen=True, oldstyle_class=self.oldstyle_class)
        return privatedict(
            self.pvt_o, self.cn,
            frozen=True, oldstyle_class=self.oldstyle_class
        )

    # --------------------------------------------------------------------
    # PY3 only
    # --------------------------------------------------------------------

    def keys(self):
        for k in self.pvt_o.keys():
            if self.attr_hidden(k):
                continue
            yield k

    def items(self):
        for k in self.keys():
            v = self.pvt_o[k]
            yield self.fif((k, v))

    def values(self):
        for k in self.keys():
            v = self.pvt_o[k]
            yield self.fif(v)

    # --------------------------------------------------------------------
    # PY2 only
    # --------------------------------------------------------------------

    def keys_py2(self):
        # In PY2 returns list, in PY3, yields keys
        ret = []
        for k in self.pvt_o.iterkeys():
            if self.attr_hidden(k):
                continue
            ret.append(k)
        return ret

    def items_py2(self):
        # In PY2 returns list, in PY3, yields items
        ret = []
        for k in self.keys():
            v = self.pvt_o[k]
            ret.append((k, v))
        return self.fif(ret)

    def values_py2(self):
        # In PY2 returns list, in PY3, yields values
        ret = []
        for k in self.keys():
            v = self.pvt_o[k]
            ret.append(v)
        return self.fif(ret)

    def iterkeys(self):
        # PY2 only
        for k in self.pvt_o.keys():
            if self.attr_hidden(k):
                continue
            yield k

    def iteritems(self):
        # PY2 only
        for k in self.iterkeys():
            v = self.pvt_o[k]
            yield self.fif((k, v))

    def itervalues(self):
        # PY2 only
        for k in self.iterkeys():
            yield self.fif(self.pvt_o[k])

    def viewitems(self):
        return self.fif(set(self.items()))

    def viewvalues(self):
        return self.fif(set(self.values()))

    def viewkeys(self):
        return self.fif(set(self.keys()))

    # --------------------------------------------------------------------
    # End of PY2 only
    # --------------------------------------------------------------------


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
    def __init__(self, o, cn, oldstyle_class=None):
        '''o-->object to be wrapped'''
        PrivacyDict.__init__(
            self, o, cn, frozen=True, oldstyle_class=oldstyle_class
        )

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
        - DONE: Cannot access any attribute not exported by dir(pvt_o)
        - DONE: cannot access any unmangled double '_' attributes
        - DONE: Cannot add or delete attributes
    '''

    def __init__(self, o, frozen=False, rules=None):
        '''
        o-->object to be wrapped
        frozen--bool: If True, no direct attribute can be modified
        rules: dict (if called from Protected.__init__) or None
        '''
        Wrapped.__init__(self, o, frozen=frozen, rules=rules)

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    cdef private_visible(self, a):
        '''Share with Private-derived'''
        if a in special_attributes:
            return True
        if self.attr_hidden(a):
            return False
        if a not in dir(self.pvt_o):
            return False
        # Special hack for PY2 that does not seem to obey __dir__ for modules
        if PY2 and isinstance(self.pvt_o, types.ModuleType):
                if (
                    hasattr(self.pvt_o, '__dir__') and
                    callable(self.pvt_o.__dir__)
                ):
                    if a not in self.pvt_o.__dir__():
                        return False
        return True

    cdef private_writeable(self, a):
        # Shared with Private-derived
        # writeable implies visible. not visible implies not writeable
        if not self.visible(a):
            return False
        if ro_private_attr.match(a):
            return False
        if a in special_attributes:
            return False
        if a in always_frozen:
            return False
        return True

    cdef visible(self, a):
        # Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        return self.private_visible(a)

    cdef writeable(self, a):
        # Needs to be FAST - called in __setattr__, __delattr__
        return self.private_writeable(a)

    cdef private_getattr(self, a):
        # Cannot access any attribute not exported by dir(pvt_o)
        # cannot access any unmangled double '_' attributes
        if not self.visible(a):
            raise AttributeError(
                "Object Private('%s') has no attribute '%s'" % (self.cn, a)
            )
        if a in overridden_always:
            return functools.partial(getattr(Private, a), self)

        if a in always_frozen:
            x = getattr(self.pvt_o, a)
            if a == '__dict__':
                return privatedict(x, self.cn, frozen=True, oldstyle_class=self.oldstyle_class)
            else:
                return freeze(x)
        return self.wrapped_getattr(a)

    cdef private_check_setattr(self, a, val):
        nopvt_msg = 'Cannot set attribute: %s.%s' % (self.cn, str(a))
        noadd_msg = 'Cannot add attribute: %s.%s' % (self.cn, str(a))
        if not self.writeable(a):
            raise ProtectionError(nopvt_msg)
        if a not in dir(self.pvt_o):
            raise ProtectionError(noadd_msg)
        self.wrapped_check_setattr(a, val)

    cdef private_check_delattr(self, a):
        nodel_msg = 'Cannot delete attribute: %s.%s' % (self.cn, str(a))
        if not hasattr(self.pvt_o, a):
            raise AttributeError(
                "Object Private('%s') has no attribute '%s'" % (self.cn, a)
            )
        raise ProtectionError(nodel_msg)

    cdef private_dir(self):
        return [
            x for x in self.wrapped_dir()
            if self.private_visible(x)
        ]

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        return self.private_getattr(a)

    def __setattr__(self, a, val):
        # Only checks and raises exceptions
        self.private_check_setattr(a, val)
        setattr(self.pvt_o, a, val)

    def __delattr__(self, a):
        # Only checks and raises exceptions
        self.private_check_delattr(a)

    def __dir__(self):
        return self.private_dir()

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
    Subclass of Private that further restriction of:
        - Which attributes are VISIBLE
        - Which attributes are WRITEABLE
    '''
    cdef dict acl_cache
    # Cache dir() output
    cdef list dir_out

    def __init__(self, o, rules):
        '''
        o-->object to be wrapped
        rules-->dict: returned by protected_rules_from_kwargs
        '''
        self.rules = rules
        frozen = bool(rules.get('frozen', False))
        Private.__init__(self, o, frozen=frozen)
        self.frozen = frozen
        self.process_rules(rules)

    # --------------------------------------------------------------------
    # Private methods
    # --------------------------------------------------------------------

    cdef get_rules(self):
        if self.rules is None:
            return dict()
        return self.rules

    cdef process_rules(self, rules):
        '''
        rules-->dict
        Called once at object wrapping time
        '''
        self.dir_out = []
        # frozen does NOT override dynamic
        if bool(rules.get('dynamic', False)):
            self.acl_cache = None
        else:
            self.acl_cache = {}
            self.build_cache()
            # Make dir() pre-computed
            self.dir_out = [
                    k for (k, v) in self.acl_cache.items()
                    if v.get('r', False)
            ]

    cdef build_cache(self):
        '''
        Called once at object wrapping time
        '''
        if self.acl_cache is None:
            return
        d = self.acl_cache

        hidden_d = {'r': False, 'w': False}

        for a in dir(self.pvt_o):
            if self.attr_hidden(a):
                self.acl_cache[a] = hidden_d
                continue
            d = {
                'r': self.protected_visible(a, use_cache=False),
                'w': self.protected_writeable(a, use_cache=False),
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
        Only called from protected_visible() and protected_writeable()
        '''
        if op not in ('r', 'w'):
            return False

        d = self.rules
        attr_type_check = bool(d.get('attr_type_check', False))
        ro_method = bool(d.get('ro_method', False))
        ro_data = bool(d.get('ro_data', False))
        hide_private = bool(d.get('hide_private', False))

        if use_cache and self.acl_cache is not None:
            def_d = {'r': True, 'w': True}
            d = self.acl_cache.get(a, def_d)
            return d[op]

        # If we got here, we need DYNAMIC lookup
        # Either use_cache is False (in call to check_1_op)
        # or self.acl_cache is None (dynamic is True)

        # Enforce hiding of private mangled attributes
        # This is already done in Private !
        if self.attr_hidden(a):
            return False

        if op == 'r':
            # special_attributes always visible
            if a in special_attributes:
                return True
            # always_frozen are .... always frozen
            if a in always_frozen:
                return True

            if hide_private and ro_private_attr.match(a):
                return False
            if (
                'hide_regex' in d and
                d['hide_regex'].pattern and
                d['hide_regex'].match(a)
            ):
                return False
        elif op == 'w':
            # special_attributes never writeable
            if a in special_attributes:
                return False
            if ro_private_attr.match(a):
                return False
            # rw overrides ro_*
            if (
                'rw_regex' in d and
                d['rw_regex'].pattern and
                d['rw_regex'].match(a)
            ):
                return True
            if (
                'ro_regex' in d and
                d['ro_regex'].pattern and
                d['ro_regex'].match(a)
            ):
                return False

        if attr_type_check is True:
            if op == 'w' and (ro_method or ro_data):
                bMethod = callable(getattr(self.pvt_o, a))
                if ro_method:
                    return not bMethod
                elif ro_data:
                    return bMethod
        return True

    cdef protected_visible(self, a, use_cache=True):
        '''
        a-->str: attribute name
        use_cache-->bool
        Returns--bool
        Only called from visible()

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        if not self.private_visible(a):
            return False
        if self.acl_cache is None:
            use_cache = False
        return self.check_1_op(a=a, op='r', use_cache=use_cache)

    cdef protected_writeable(self, a, use_cache=True):
        '''
        a-->str: attribute name
        use_cache-->bool
        Returns--bool
        Only called from writeable()

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        if not self.private_writeable(a):
            return False
        if self.acl_cache is None:
            use_cache = False
        return self.check_1_op(a=a, op='w', use_cache=use_cache)

    cdef aclcheck(self, a, op):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w', 'd')
        Returns--None: Raises exceptions

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        ro_msg = 'Read only attribute: %s' % (a,)

        if self.frozen and op in ('w', 'd'):
            # Module hack
            if not isinstance(self.pvt_o, types.ModuleType):
                raise frozen_error
        if op == 'r':
            if not self.visible(a):
                raise AttributeError(
                    "Object Protected('%s') has no attribute '%s'" % (self.cn, a)
                )
            return     # OK
        elif op == 'w':
            if not self.writeable(a):
                raise ProtectionError(ro_msg)
            return   # OK
        elif op == 'd':
            return   # OK

    cdef protected_getattr(self, a):
        self.aclcheck(a=a, op='r')
        x = self.private_getattr(a)
        # Can always read PROT_ATTR_NAME, even with hide_private == True
        if a == PROT_ATTR_NAME:
            return x
        if a in m_block and hasattr(Wrapped, a):
            return x
        try:
            self.aclcheck(a=a, op='w')
            return x
        except:   # not writeable for any reason
            return freeze(x)

    cdef protected_check_setattr(self, a, val):
        self.aclcheck(a=a, op='w')
        self.private_check_setattr(a, val)

    cdef protected_check_delattr(self, a):
        self.aclcheck(a=a, op='d')
        self.private_check_delattr(a)

    cdef protected_dir(self):
        if bool(self.rules.get('dynamic', True)):
            return [
                x for x in self.private_dir()
                if self.visible(x)
            ]
        else:
            return self.dir_out

    cdef visible(self, a):
        # Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        return self.protected_visible(a)

    cdef writeable(self, a):
        # Needs to be FAST - called in __setattr__, __delattr__
        return self.protected_writeable(a)


    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        return self.protected_getattr(a)

    def __setattr__(self, a, val):
        # Only checks and raises exceptions
        self.protected_check_setattr(a, val)
        setattr(self.pvt_o, a, val)

    def __delattr__(self, a):
        # Only checks and raises exceptions
        self.protected_check_delattr(a)

    def __dir__(self):
        return self.protected_dir()

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
        rules-->dict: returned by protected_rules_from_kwargs
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

