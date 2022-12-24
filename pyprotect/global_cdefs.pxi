
cdef frozenset immutable_types_set
cdef frozenset builtins_ids
cdef frozenset builtin_module_immutable_attributes
# The module only uses PROT_ATTR_NAME, never '_Protected_____' 
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
    '__getattribute__', '__delattr__', '__setattr__',
    '__hash__',
])
cdef object pickle_attributes = frozenset([
    '__reduce__', '__reduce_ex__',
    '__getsate__', '__setstate__',
])
cdef object special_attributes = frozenset([
    PROT_ATTR_NAME,
])
cdef object always_delegated = frozenset([
    '__doc__',
    '__weakref__',
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
# These attributes of FunctionType are writable only in PY2
py2_function_attrs_rw = frozenset([
    '__doc__', '__name__', '__module__',
    '__defaults__', '__code__', '__dict__',
])


