
# @cython.internal
cdef class Wrapped(Proxy):
    '''
    This is an object wrapper / proxy that adds the 'frozen' parameter
    If frozen is False, should behave just like the wrapped object, except
    following attributes cannot be modified:
        '__getattribute__', '__delattr__', '__setattr__', '__slots__',
    If frozen is True, prevents modification of ANY attribute
    WITHOUT frozen == True:
        - Does NOT protect CLASS of wrapped object from modification
        - Does NOT protect __dict__ or __slots__
    Implements all known special methods for classes under collections etc
    The one difference is that a Wrapped instance explicitly does NOT
    support pickling, and will raise a ProtectionError
    '''
    cdef __ProtectionData protected_attribute
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
            # When such CLASSES (not INSTANCES of such classes) are wrapped
            # with Private, the class name cannot be used to identify mangled
            # private attributes to hide, so ALL attributes of the form _CCC__YYYz
            # where z is '' or '_' are hidden. If it is an old style PY2 CLASS,
            # CCC is a REGEX, otherwise # CCC is self.cn
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
        if isinstance(self.pvt_o, type):
            id_class = id(self.pvt_o)
        else:
            id_class = id(type(self.pvt_o))

        self.protected_attribute = __ProtectionData(
            id_val=id(self.pvt_o),
            id_class=id_class,
            hash_val=__HiddenPartial(self.hash_protected, self),
            isinstance_val=__HiddenPartial(self.isinstance_protected, self),
            issubclass_val=__HiddenPartial(self.issubclass_protected, self),
            instanceof=__HiddenPartial(self.instanceof_protected, self),
            subclassof=__HiddenPartial(self.subclassof_protected, self),
            help_val=__HiddenPartial(self.help_protected, self),
            help_str=__HiddenPartial(self.help_str_protected, self),
            testop=__HiddenPartial(self.testop, self),
            rules=rules,
            freeze=__HiddenPartial(self.freeze, self),
            private=__HiddenPartial(private_class, self.pvt_o),
            protect=__HiddenPartial(protect_class, self.pvt_o),
            multiwrapped=__HiddenPartial(self.multiwrapped, self),
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
        if isinstance(self.pvt_o, type):
            return issubclass(self.pvt_o, c)
        else:
            return issubclass(type(self.pvt_o), c)

    cdef instanceof_protected(self, c):
        if isinstance(self.pvt_o, type):
            return isinstance(c, self.pvt_o)
        else:
            return isinstance(c, type(self.pvt_o))

    cdef subclassof_protected(self, c):
        if isinstance(self.pvt_o, type):
            return issubclass(c, self.pvt_o)
        else:
            return issubclass(c, type(self.pvt_o))

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
        if a in special_attributes or a in overridden_always:
            return False
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
            return __HiddenPartial(getattr(Wrapped, a), self)

        # PREVENT pickling - doesn't work even if methods are implemented,
        if a in pickle_attributes:
            raise AttributeError('Wrapped object cannot be pickled')

        delegated = getattr(self.pvt_o, a, None)
        if a in always_delegated:
            return delegated

        # Container mutating methods - implemented and selectively blocked
        if a in m_block and hasattr(Wrapped, a):
            return __HiddenPartial(getattr(Wrapped, a), self)
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
            # However module's __dict__ is still frozen
            if a == '__dict__' or not isinstance(self.pvt_o, types.ModuleType):
                delegated = freeze(delegated)
        return delegated

    cdef wrapped_check_setattr(self, a, val):
        if self.frozen:
            raise frozen_error
        if a in overridden_always or a in special_attributes:
            raise ProtectionError('Cannot modify attribute: %s' % (a,))

    cdef wrapped_check_delattr(self, a):
        if self.frozen:
            raise frozen_error
        if a in overridden_always or a in special_attributes:
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
    # Depends on pvt_o being hashable
    def __hash__(self):
        return hash((
            id(type(self)),
            str(self.get_rules()),
            id(self.pvt_o),
            hash(self.pvt_o)
        ))


# @cython.internal
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

