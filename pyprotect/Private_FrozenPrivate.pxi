
# @cython.internal
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
        # Special case for PY2 that does not seem to obey __dir__ for modules
        # Also applies to PY3 < 3.7
        if (
            isinstance(self.pvt_o, types.ModuleType) and
            (
                PY2 or (sys.version_info.major, sys.version_info.minor) < (3, 7)
            )
        ):
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


# @cython.internal
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

