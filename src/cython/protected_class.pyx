'''
VISIBILITY versus READABILITY:
    VISIBILITY: using object.__dir__(original_object)
        - Never affected by Protected class
        - Note: dir(wrapped_object) IS affected if you use private / protect
    READABILITY: Whether the attribute VALUE can be read
        - Applies to wrapped object - NOT original object
        - IS affected if you use private / protect
        - Objects wrapped with private / protect do not expose getattr,
          __getattribute__, __setattr__ or __delattr__

MUTABILITY: Ability to CHANGE or DELETE an attribute
    - Protected object will not allow CHANGING OR DELETING an attribute
      that is not VISIBLE
    - Objects wrapped with private / protect do not allow modification
      of __class__, __dict__ or __slots attributes
    - When using protect(o, **kwargs), writeability depends on kwargs

freeze(o) --> Frozen object
    Frozen object prevents modification of ANY attribute
        - Does not hide traditionally 'private' mangled python attributes

private(o, frozen=True) --> FrozenPrivate if frozen; Private otherwise

    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - The following attributes of wrapped object are NEVER modifiable:
            '__class__', '__dict__', '__slots__',
            '__getattr__', '__getattribute__', '__delattr__', '__setattr__',

    FrozenPrivate:
        All features of Private PLUS prevents modification of ANY attribute

protect(
        o,
        frozen=False, add=False, dynamic=True,
        hide_all=False, hide_data=False, hide_method=False,
        hide_private=False, hide_dunder=False,
        ro_all=False, ro_data=False, ro_method=True, ro_dunder=True,
        ro=[], rw=[], hide=[], show=[],
    ) --> FrozenProtected if frozen; Protected otherwise

    Protected:
        Features of Private PLUS allows customization of:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE
            - Attributes cannot BE deleted UNLESS they were added at run-time
            - If an attribute cannot be read, it cannot be written or deleted

    FrozenProtected:
        All features of Protected PLUS prevents modification of ANY attribute

What kind of python objects can be wrapped?
    Any object that supports getattr, setattr and delattr
    Pickling / unpickling of wrapped objects is not supported (yet)

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

        If 'dynamic' is False and you do NOT use any of the followng in kwargs:
            hide_data
            hide_method
            ro_data
            ro_method
        then: YES !

        If 'dynamic' is False and you use any of the followng in kwargs:
            hide_data
            hide_method
            ro_data
            ro_method
        the run-time behavior will NOT be as expected if the wrapped
        object adds attributes or changes the type of attributes at run-time

        Also, if 'dynamic' is False, dir(wrapped_object) will not
        accurately reflect attributes added or deleted at run-time

        Note that the above caveats are UNAFFECTED by 'add' or 'frozen'
        kwargs:
            'add' controls whether attributes can be added from OUTSIDE
                the wrapped object
            add = True is required to add attributes from OUTSIDE the
                wrapped object
            Deleting attributes ONLY works if both conditions below are met:
                - 'add' is True
                - Attribute was added at run-time from OUTSIDE wrapped object
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
    Pickling / unpickling of wrapped objects is not supported (yet)

    If 'o' is your original object, and 'w' is the wrapped object:
    One difference across wrap / freeze / private / protect:
        - dir(w) will necessarily be different from dir(o):
            'wrap' / 'freeze' / 'private' / 'protect':
                Additional attributes in 'w':
                    _Protected_id_____
                    _Protected_isinstance_____
            'private':
                One more additional attribute in 'w':
                    _Protected_testop_____
                    Used in unit tests for protected_class
                Traditionally 'private' mangled attributes will not appear

            'protect':
                One more additional attribute in 'w':
                    _Protected_rules_____
                    Used to avoid redundant multiple wraps when using 'protect'
                Traditionally 'private' mangled attributes will not appear
                Further differences depending on keyword arguments to 'protect'

    Following applies only to wrapping with private / protect (not wrap):
        - Change calls to w.__getattribute__(a) to getattr(w, a)
        - Change calls to w.__delattr__ to delattr(w, a)
        - Change calls to w.__setattr(a, val) to setattr(w, a, val)
        - Change isinstance(w, Mytypes) to isinstance_protected(w, MyTypes)
            isinstance_protected can also be used transparently on objects
            that have NOT been wrapped
        - Change id(w) to id_protected(w). id_protected can also be used
            transparently on objects that have NOT been wrapped
        - Change 'w is x' to id_protected(w) == id_protected(x)
        - Change type(w) to w.__class__ if you want to use the CLASS of w
            but safely - not allowing class modifications

Object equality:
    Two objects returned by wrap / freeze / private / protect are equal
    IF AND ONLY IF all the following conditions are met:
        - They wrap the SAME object - id(o1) == id(o2)
        - They were wrapped using the same method
        - For private: bothe were wrapped with the same value for 'frozen'
        - For protect: the EFFECTIVE visibility and writeability implied
          by keyword arguments provided to 'protect' for the two objects
          is identical


Can a Frozen / Private / Protected class instance be wrapped again
using freeze / private / protect?
    YES !

    To avoid unnecessarily wrapping multiple times and impacting performance
    while guaranteeing the behavior intended by calling wrap / freeze /
    private / protect, the following optimizations are done:

    wrap(o): if 'o' was already created using 'wrap', returns 'o'

    private(o, frozen):
        If 'o' was already created using 'private' AND with the SAME value for
        frozen, returns 'o'

    protect(o, **kwargs):
        If 'o' was already created using 'protect' AND the EFFECTIVE
        visibility and writeability of 'o' is identical to visibility
        and writeability implied by kwargs, returns 'o

    freeze(o): If 'o' is already known to be immutable, returns 'o'
        This means that when using

        w = freeze(o)

        you should check

        isimmutable(w)

        rather than

        isfrozen(w)

        since, for an immutable 'o' (like o=10)

        freeze(o) will return o

        and isfrozen(freeze(10)) will return False
        but isimmutable(freeze(10)) will return True

Checking at run-time whether an attribute is visible:
    Assuming 'o' is the object, whether wrapped or not and 'a is attribute:
    Just use hasattr(o, a).  Works on any object, wrapped or not

Checking at run-time whether an attribute is writeable:
    Assuming 'o' is the object, whether wrapped or not and you waht to set
    attribute 'a' to value 'val':

    Pythonic way - optimistic - try and handle exception

        from protected_class import ProtectionError

        try:
            setattr(o, a, val)
        except (TypeError|ProtectionError):
            # Do something if attribute cannot be set
            # Should (hopefully) work on any object, wrapped or not

    Non-pythonic way - 'check and hope'
    if isreadonly(o, a):
        # Do something if attribute is read-only
        pass
    else:
        # Do something else if attribute is writeable
        pass

Checking at run-time whether an attribute can be deleted:
    Assuming 'o' is the object, whether wrapped or not and you waht to delete
    attribute 'a':

    Pythonic way - optimistic - try and handle exception

        from protected_class import ProtectionError

        try:
            delattr(o, a)
        except (TypeError|ProtectionError):
            # Do something if attribute cannot be deleted
            # Should (hopefully) work on any object, wrapped or not
'''

import re
import collections
from cpython.object cimport (
    Py_LT, Py_EQ, Py_GT, Py_LE, Py_NE, Py_GE,
)
cimport cython

cdef object overridden_always
overridden_always = frozenset([
    '__getattr__', '__getattribute__', '__delattr__', '__setattr__',
    # '__slots__',
])


# Use compiled regex - no function call, no str operations
cdef object ro_private_attr
ro_private_attr = re.compile('^_[^_].*?(?<!_)$')
cdef object dunder_attr
dunder_attr = re.compile('^__.*?__$')

# Python 2 str does not have isidentifier() method
cdef object attr_identifier
attr_identifier = re.compile('^[_a-zA-Z][a-zA-Z0-9_]*$')

# Use special exception class for protected_class-specific exceptions
# Cannot subclass from builtin exceptions other than Exception
# See: https://github.com/cython/cython/issues/1416
class ProtectionError(TypeError):
    pass

class HiddenAttributeError(AttributeError):
    pass

class ReadonlyTypeError(TypeError):
    pass

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
cdef set builtin_module_immutable_attributes


if sys.version_info.major > 2:
    import collections.abc
    builtin_module = sys.modules['builtins']
else:
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

# builtin module itself is writeable by default in python, so we need
# a set of attributes which are KNOWN ot be immutable in the builtin module
# For python3 this will (may) be a moving target
# Can safely keep adding to this - since attribute is used ONLY if
# it is actually present in builtin_module
# This is only used in isimmutable()
# This is the UNION of attributes present in python 2.7 and python 3.6.9

builtin_module_immutable_attributes = set([
    'ArithmeticError', 'AssertionError', 'AttributeError', 'BaseException',
    'BlockingIOError', 'BrokenPipeError', 'BufferError', 'BytesWarning',
    'ChildProcessError', 'ConnectionAbortedError', 'ConnectionError',
    'ConnectionRefusedError', 'ConnectionResetError', 'DeprecationWarning',
    'EOFError', 'Ellipsis', 'EnvironmentError', 'Exception', 'False',
    'FileExistsError', 'FileNotFoundError', 'FloatingPointError',
    'FutureWarning', 'GeneratorExit', 'IOError', 'ImportError',
    'ImportWarning', 'IndentationError', 'IndexError', 'InterruptedError',
    'IsADirectoryError', 'KeyError', 'KeyboardInterrupt', 'LookupError',
    'MemoryError', 'ModuleNotFoundError', 'NameError', 'None',
    'NotADirectoryError', 'NotImplemented', 'NotImplementedError', 'OSError',
    'OverflowError', 'PendingDeprecationWarning', 'PermissionError',
    'ProcessLookupError', 'RecursionError', 'ReferenceError',
    'ResourceWarning', 'RuntimeError', 'RuntimeWarning', 'StandardError',
    'StopAsyncIteration', 'StopIteration', 'SyntaxError', 'SyntaxWarning',
    'SystemError', 'SystemExit', 'TabError', 'TimeoutError', 'True',
    'TypeError', 'UnboundLocalError', 'UnicodeDecodeError',
    'UnicodeEncodeError', 'UnicodeError', 'UnicodeTranslateError',
    'UnicodeWarning', 'UserWarning', 'ValueError', 'Warning',
    'ZeroDivisionError', '__build_class__', '__debug__', '__doc__',
    '__import__', '__loader__', '__name__', '__package__', '__spec__', 'abs',
    'all', 'any', 'apply', 'ascii', 'basestring', 'bin', 'bool', 'buffer',
    'bytearray', 'bytes', 'callable', 'chr', 'classmethod', 'cmp', 'coerce',
    'compile', 'complex', 'copyright', 'credits', 'delattr', 'dict', 'dir',
    'divmod', 'enumerate', 'eval', 'exec', 'execfile', 'exit', 'file',
    'filter', 'float', 'format', 'frozenset', 'getattr', 'globals', 'hasattr',
    'hash', 'help', 'hex', 'id', 'input', 'int', 'intern', 'isinstance',
    'issubclass', 'iter', 'len', 'license', 'list', 'locals', 'long', 'map',
    'max', 'memoryview', 'min', 'next', 'object', 'oct', 'open', 'ord', 'pow',
    'print', 'property', 'quit', 'range', 'raw_input', 'reduce', 'reload',
    'repr', 'reversed', 'round', 'set', 'setattr', 'slice', 'sorted',
    'staticmethod', 'str', 'sum', 'super', 'tuple', 'type', 'unichr',
    'unicode', 'vars', 'xrange', 'zip'
])
# Since builtin_module is by default writeable in Python and attributes
# in builtin_module can be overwritten, we only list those attributes
# that do not allow __class__ attribute to be overwritten (crude test)
s = set()
test_attr_name = '__class__'
for a in builtin_module_immutable_attributes:
    try:
        x = getattr(builtin_module, a)
        try:
            setattr(x, test_attr_name, getattr(x, test_attr_name))
            continue
        except:
            s.add(a)
    except:
        continue
builtin_module_immutable_attributes = s

builtins_ids = set([
    id(getattr(builtin_module, a)) for a in builtin_names
    if a in builtin_module_immutable_attributes
])

# End of stuff for isimmutable()
# ------------------------------------------------------------------------

# Avoid locals and imports leaking into module namespace
del x
del s
del test_attr_name
del a
del sys
del re
del collections

# ------------------------------------------------------------------------
# Python-visible methods
# ------------------------------------------------------------------------

def immutable_builtin_attributes():
    '''
    Returns-->set of str: attributes in builtins that are immutable
    Used in unit tests
    Note that this is a UNION of immutable attributes in Python 2 and 3
    So there is no guarantee that these attributes are actually present
    in the builtin module, but IF present, SHOULD be immutable
    '''
    return builtin_module_immutable_attributes


def isimmutable(o):
    '''
    isimmutable(o) --> bool: object class is KNOWN to be immutable
    o-->object
    '''
    # Import locally to avoid re leaking into module namespace
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
    # str and basestring are immutable, THOUGH they are Containers
    if isinstance(o, (str, basestring)):
        return True
    if isfrozen(o):
        return True
    if iswrapped(o):
        return False
    if isinstance(o, CollectionsABC.Container):
        return False
    return isinstance(o, tuple(immutable_types))


def id_protected(o):
    '''
    id(o)
    o-->object: wrapped or not
    Returns-->int: id of wrapped object if wrapped; id of o otherwise
    '''
    if isinstance(o, Wrapped):
        return o._Protected_id_____
    return id(o)


def isinstance_protected(o, c):
    '''
    isinstance_protected(o, c)
    o-->object
    c-->type
    Similar to isinstance, but object o can be an object returned
    by freeze(), private() or protect()
    Returns True IFF isinstance(object_wrapped_by_o, c)
    '''
    if isinstance(o, Wrapped):
        return o._Protected_isinstance_____(o, c)
    return isinstance(o, c)


def isreadonly(o, a):
    '''
    isreadonly(o, a) --> bool: whether attribute 'a' of object 'o' is read-only
    o-->object
    a-->str: attribute
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
        return not o._Protected_testop_____(o, a, 'w')
    else:
        return False


def contains(p, o):
    '''
    p-->object created with freeze / private / protect
    o-->any object
    Returns-->bool: whether p wraps o
    '''
    if isinstance(p, Wrapped):
        return p._Protected_id_____ == id(o)
    return False


def iswrapped(o):
    '''
    iswrapped(o)
    o-->object
    Returns-->bool: object was created using wrap / freeze / private / protect
    '''
    return isinstance(o, Wrapped)


def isfrozen(o):
    '''
    isfrozen(o)
    o-->object
    Returns-->bool: object was created using freeze()
    '''
    return isinstance(o, (
        Frozen, FrozenPrivate, FrozenPrivacyDict, FrozenProtected,
    ))


def isprivate(o):
    '''
    isprivate(o)
    o-->object
    Returns-->bool: object was created using private()
    '''
    return isinstance(o, (
        Private,
        FrozenPrivate,
    ))


def isprotected(o):
    '''
    isprotected(o)
    o-->object
    Returns-->bool: object was created using protect()
    '''
    return isinstance(o, (
        Protected,
        FrozenProtected,
    ))


def wrap(o):
    '''
    wrap(o) --> Wrapped object
    o-->Object to be wrapped

    Wrapped:
        - Should behave just like the wrapped object, except
          following attributes cannot be modified:
            'getattr, __getattribute__',
            '__delattr__', '__setattr__', '__slots__',
        - Does NOT protect CLASS of wrapped object from modification
        - Does NOT protect __dict__ or __slots__

    Useful for testing if wrapping is failing for a particular type of object
    '''
    if iswrapped(o):
        # Do not wrap twice
        return o
    return Wrapped(o, frozen=False)


def freeze(o):
    '''
    freeze(o) --> Frozen object
    o-->Object to be wrapped

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
    return Frozen(o)


def private(o, frozen=False):
    '''
    private(o, frozen=True) --> FrozenPrivate if frozen; Private otherwise
    o-->Object to be wrapped

    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object

    FrozenPrivate:
        Features of Private PLUS prevents modification of ANY attribute

    '''
    if frozen:
        if isprivate(o) and isfrozen(o):
            return o
        return FrozenPrivate(o)
    else:
        if isinstance (o, FrozenPrivate):
            # Underlying is already FrozenPrivate
            return o
        elif isinstance(o, Private):
            return o
        return Private(o)


def protect(
        o,
        frozen=False, add=False, dynamic=True,
        hide_all=False, hide_data=False, hide_method=False,
        hide_private=False, hide_dunder=False,
        ro_all=False, ro_data=False, ro_method=True, ro_dunder=True,
        ro=[], rw=[], hide=[], show=[],
):
    '''
    protect(
        o,
        frozen=False, add=False, dynamic=True,
        hide_all=False, hide_data=False, hide_method=False,
        hide_private=False, hide_dunder=False,
        ro_all=False, ro_data=False, ro_method=True, ro_dunder=True,
        ro=[], rw=[], hide=[], show=[],
    ) --> FrozenProtected if frozen; Protected otherwise
    Protected:
        Features of Private PLUS allows customization of:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE

    FrozenProtected:
        Features of Protected PLUS prevents modification of ANY attribute

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

    Default settings:
    Features of Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
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

    rules = get_visibility_rules(kwargs)
    frozen = bool(rules.get('frozen', False))

    if frozen:
        if isinstance(o, FrozenProtected):
            if hasattr(o, '_Protected_rules_____'):
                if rules == o._Protected_rules_____:
                    # Protected object with the SAME visibility rules
                    return o
        return FrozenProtected(o, rules)
    else:    # not frozen
        # If inner is frozen, whether outer is frozen or not
        if isinstance(o, (Protected, FrozenProtected)):
            if hasattr(o, '_Protected_rules_____'):
                d = dict(o._Protected_rules_____)
                # Don't care about frozen in comparison
                d['frozen'] = frozen
                if rules == d:
                    # Protected object with the SAME visibility rules
                    return o
        return Protected(o, rules)


# ------------------------------------------------------------------------
# End of python-visible methods
# ------------------------------------------------------------------------



# Not visible to python
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


# Not visible to python (or outside this module ?)
@cython.internal
cdef class Wrapped(object):
    '''
    This is an object wrapper / proxy that adds the 'frozen' parameter
    If frozen is False, should behave just like the wrapped object, except
    following attributes cannot be modified:
        '__getattr__', '__getattribute__',
        '__delattr__', '__setattr__', '__slots__',
    If frozen is True, prevents modification of ANY attribute
    Does NOT protect CLASS of wrapped object from modification
    Does NOT protect __dict__ or __slots__
    Implements all known special methods for classes under collections etc
    '''
    cdef object pvt_o
    cdef object cn
    cdef bint frozen
    cdef object frozen_error
    cdef object special_attributes
    cdef object _Protected_id_____

    def __init__(self, o, frozen=False):
        '''
        o-->object to be wrapped
        frozen--bool: If True, no attribute can be modified
        '''
        self.pvt_o = o
        self._Protected_id_____ = id(o)
        self.cn = o.__class__.__name__
        self.frozen = bool(frozen)
        self.frozen_error = ProtectionError('Object is read-only')
        self.special_attributes = set([
            '_Protected_isinstance_____',
            '_Protected_id_____',
        ])

    cdef fif(self, o):
        '''
        fif = Freeze If Frozen
        o-->object
        Returns-->o or Frozen(o)
        '''
        if self.frozen:
            return freeze(o)
        return o

    cdef public _Protected_isinstance_____(self, c):
        return isinstance(self.pvt_o, c)

    '''
    def __getattr__(self, a):
        return self.get_attribute(a)
    '''

    def __getattribute__(self, a):
        # Import locally to avoid re leaking into module namespace
        import sys
        if sys.version_info.major > 2:
            import collections.abc as CollectionsABC
        else:
            import collections as CollectionsABC
        from functools import partial

        missing_msg = "Object '%s' has no attribute '%s'" % (self.cn, str(a))
        if a in overridden_always:
            return partial(getattr(Wrapped, a), self)
        if a == '_Protected_isinstance_____':
            return self._Protected_isinstance_____
        elif a == '_Protected_id_____':
            return self._Protected_id_____
        if self.frozen:
            if isinstance(self.pvt_o, CollectionsABC.Mapping):
                if a in ('pop', 'popitem', 'clear'):
                    raise self.frozen_error
            if isinstance(self.pvt_o, CollectionsABC.MutableSequence):
                if a in ('add', 'insert', 'discard'):
                    raise self.frozen_error
        # If frozen, freeze all the way down
        x = getattr(self.pvt_o, a)
        if self.frozen:
            return freeze(x)
        return x

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
        l1 = dir(self.pvt_o)
        l2 = [x for x in self.special_attributes if x not in l1]
        return sorted(l1 + l2)

    def __repr__(self):
        return repr(self.pvt_o)

    def __str__(self):
        return str(self.pvt_o)

    # Can only offer equality / inequality check for wrapped object
    def __richcmp__(self, other, int op):
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            res = (
                isinstance(other, Wrapped) and
                id_protected(self) == id_protected(other)
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)

    # ------------------------------------------------------------------------
    # The rest of the methods are implementations of abstract methods to
    # proxy different types of objects from collections module
    # ------------------------------------------------------------------------

    # Sequence

    def __reversed__(self):
        if self.frozen:
            raise self.frozen_error
        return self.pvt_o.__reversed__()

    # MutableMapping:

    def __getitem__(self, key):
        return self.fif(self.pvt_o.__getitem__(key))

    def __delitem__(self, key):
        if self.frozen:
            raise self.frozen_error
        try:
            self.pvt_o.__delitem__(key)
        except AttributeError:
            raise ReadonlyTypeError(
                "'%s' object does not support item deletion" % (self.cn,)
            )

    def __setitem__(self, key, val):
        if self.frozen:
            raise self.frozen_error
        try:
            self.pvt_o.__setitem__(key, val)
        except AttributeError:
            raise ReadonlyTypeError(
                "'%s' object does not support item assignment" % (self.cn,)
            )

    def __iter__(self):
        for x in iter(self.pvt_o):
            yield self.fif(x)

    def __len__(self):
        return self.pvt_o.__len__()

    # MutableSequence:

    def add(self, *args, **kwargs):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.add(*args, **kwargs)

    def insert(self, *args, **kwargs):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.insert(*args, **kwargs)

    def discard(self, *args, **kwargs):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.discard(*args, **kwargs)

    # MutableSet
    def update(self, *args, **kwargs):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.update(*args, **kwargs)

    def remove(self, *args, **kwargs):
        if self.frozen:
            raise self.frozen_error
        self.pvt_o.remove(*args, **kwargs)

    # Generator

    def send(self, *args, **kwargs):
        self.pvt_o.send(*args, **kwargs)

    def throw(self, *args, **kwargs):
        self.pvt_o.throw(*args, **kwargs)

    # Hashable

    def __hash__(self):
        return hash(str(id(self.__class__)) + '_' + str(self._Protected_id_____))

    # Iterator

    def next(self, *args, **kwargs):
        yield self.fif(self.pvt_o.next(*args, **kwargs))

    # Callable objects

    def __call__(self, *args, **kwargs):
        return self.fif(self.pvt_o(*args, **kwargs))


# Not visible to python (or outside this module ?)
@cython.internal
@cython.final
cdef class Frozen(Wrapped):
    '''
    Wrapped which is automatically frozen
    '''
    def __init__(self, o):
        '''o-->object to be wrapped'''
        Wrapped.__init__(self, o, frozen=True)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            res = (
                isinstance(other, Frozen) and
                id_protected(self) == id_protected(other)
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)

# Not visible to python (or outside this module ?)
@cython.internal
cdef class PrivacyDict(Wrapped):
    '''
    Like types.MappingProxyType - with following additional functionality:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
    '''
    cdef object hidden_private_attr

    def __init__(self, o, cn, frozen=False):
        '''
        o-->dict (any Mapping or MutableMapping type)
        cn-->str: class name
        '''
        # Import locally to avoid re leaking into module namespace
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
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            res = (
                isinstance(other, PrivacyDict) and
                id_protected(self) == id_protected(other)
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)


# Not visible to python (or outside this module ?)
@cython.internal
@cython.final
cdef class FrozenPrivacyDict(PrivacyDict):
    '''
    PrivacyDict that is automatically frozen
    '''
    def __init__(self, o, cn):
        '''o-->object to be wrapped'''
        PrivacyDict.__init__(self, o, cn, frozen=True)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            res = (
                isinstance(other, FrozenPrivacyDict) and
                id_protected(self) == id_protected(other)
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)


# Not visible to python (or outside this module ?)
@cython.internal
cdef class Private(Wrapped):
    '''
    Wrapped with following additional functionality:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ or __slots__ of wrapped object
    '''
    cdef object hidden_private_attr

    cdef public _Protected_testop_____(self, a, op):
        '''
        self-->Private instance
        a-->str: attribute name
        op-->str: one of ('r', 'w')
        Returns-->bool
        '''
        if op == 'r':
            return self.visible(a)
        elif op == 'w':
            return self.writeable(a)
        return False

    def __init__(self, o, frozen=False):
        '''
        o-->object to be wrapped
        frozen--bool: If True, no direct attribute can be modified
        '''
        # Import locally to avoid re leaking into module namespace
        import re

        Wrapped.__init__(self, o, frozen=frozen)
        # Use compiled regex - no function call, no str operations
        self.hidden_private_attr = re.compile('^_%s__.*?(?<!__)$' % (self.cn,))
        self.special_attributes.add('_Protected_testop_____')

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

    def __getattribute__(self, a):
        missing_msg = "Object '%s' has no attribute '%s'" % (self.cn, str(a))
        if a == '_Protected_testop_____':
            return self._Protected_testop_____
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
        return sorted(l1 + l2)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            res = (
                isinstance(other, Private) and
                id_protected(self) == id_protected(other)
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)


# Not visible to python (or outside this module ?)
@cython.internal
@cython.final
cdef class FrozenPrivate(Private):
    '''
    Private that is automatically frozen
    '''
    def __init__(self, o):
        '''o-->object to be wrapped'''
        Private.__init__(self, o, frozen=True)

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            res = (
                isinstance(other, FrozenPrivate) and
                id_protected(self) == id_protected(other)
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)


# Not visible to python (or outside this module ?)
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

    return d



# Not visible to python (or outside this module ?)
@cython.internal
cdef class Protected(Private):
    '''
    Private that allows customization of:
        - Which attributes are VISIBLE
        - Which attributes are WRITEABLE
    '''
    # Public read-only instance var to avoid re-wrapping most of the time
    cdef readonly object _Protected_rules_____

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
        Private.__init__(self, o, frozen=self.frozen)
        self.special_attributes.add('_Protected_rules_____')
        self.process_rules(rules)

    cdef process_rules(self, rules):
        '''
        rules-->dict
        Called once at object wrapping time
        '''
        # Import locally to avoid re leaking into module namespace
        import re

        self.attr_type_check = False
        for kw in ('hide_method', 'hide_data', 'ro_method', 'ro_data'):
            if bool(rules.get(kw, False)):
                self.attr_type_check = True

        self.dynamic = rules.get('dynamic', False)
        self.frozen = bool(rules.get('frozen', False))
        self.add_allowed = bool(rules.get('add', False))
        self.orig_attrs = frozenset(dir(self.pvt_o))
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
            self.dir_out = sorted(
                [
                    k for (k, v) in self.acl_cache.items()
                    if v.get('r', False)
                ]
            )

        self._Protected_rules_____ = rules


    cdef build_cache(self):
        '''
        rules-->dict
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
        if not Private.visible(self, a):
            return False
        return self.check_1_op(a=a, op='r', use_cache=use_cache)


    cdef writeable(self, a, use_cache=True):
        '''
        a-->str: attribute name
        use_cache-->bool
        Returns--bool

        Needs to be FAST - called in __getattribute__, __setattr__, __delattr__
        '''
        if not Private.writeable(self, a):
            return False
        # NEVER writeable if not visible
        if not self.visible(a):
            return False
        return self.check_1_op(a=a, op='w', use_cache=use_cache)


    cdef aclcheck(self, a, op):
        '''
        a-->str: attribute name
        op-->str: one of ('r', 'w', 'd')
        Returns--bool

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

    def __getattribute__(self, a):
        if a == '_Protected_rules_____':
            return dict(self._Protected_rules_____)
        self.aclcheck(a=a, op='r')
        x = Private.__getattribute__(self, a)
        try:
            self.aclcheck(a=a, op='w')
            return x
        except:   # not writeable for any reason
            return freeze(x)

    def __setattr__(self, a, val):
        self.aclcheck(a=a, op='w')
        setattr(self.pvt_o, a, val)
        if a in self.orig_attrs:
            return
        else:    # Adding new attribute
            noadd_msg = 'Cannot add attribute: %s' % (a,)
            if not self.add_allowed:
                raise ProtectionError(noadd_msg)
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
            return sorted(l1 + l2)
        else:
            return self.dir_out

    # Python / cython does not automatically use parent __hash__
    def __hash__(self):
        return Wrapped.__hash__(self)

    # __richcmp__ needs to be class-specific
    def __richcmp__(self, other, int op):
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            d1 = self._Protected_rules_____
            d2 = dict(other._Protected_rules_____)
            res = (
                isinstance(other, Protected) and
                id_protected(self) == id_protected(other) and
                d1 == d2
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)


# Not visible to python (or outside this module ?)
@cython.internal
cdef class FrozenProtected(Protected):
    '''
    Protected that is automatically frozen
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
        if op not in (Py_NE, Py_EQ):
            return NotImplemented
        try:
            d1 = self._Protected_rules_____
            d2 = dict(other._Protected_rules_____)
            res = (
                isinstance(other, FrozenProtected) and
                id_protected(self) == id_protected(other) and
                d1 == d2
            )
        except:
            return NotImplemented
        if op == Py_EQ:
            return res
        if op == Py_NE:
            return (not res)
