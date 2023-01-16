
# @cython.internal
cdef class Proxy(object):
    '''
    This is an object wrapper / proxy that implements the Python
    special dunder methods
    '''
    cdef object pvt_o
    cdef bint frozen

    def __init__(self, o, frozen=False):
        '''
        o: object to be wrapped
        frozen: bool: If True, no attribute can be modified
        '''
        self.pvt_o = o
        self.frozen = bool(frozen)

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

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
        if self.frozen and not isimmutable(x):
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
        return math.floor(self.pvt_o)

    def __ceil__(self):
        return math.ceil(self.pvt_o)

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

