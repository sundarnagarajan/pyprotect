
# @cython.internal
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
            if self.frozen:
                return False
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


# @cython.internal
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

