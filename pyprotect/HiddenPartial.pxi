
# @cython.internal
cdef class __HiddenPartial(object):
    '''
    This is an object wrapper / proxy for functools.partial
    '''
    cdef object args
    cdef object kwargs

    def __init__(self, *args, **kwargs):
        '''
        args, kwargs: passed to functools.partial
        '''
        self.args = args
        self.kwargs = kwargs

    cdef wrapped_getattr(self, a):
        if a in ['__call__']:
            return functools.partial(getattr(Wrapped, a), self)
        raise AttributeError(
            "Object __HiddenPartial has no attribute '%s'" % (a,)
        )

    # --------------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------------

    def __getattribute__(self, a):
        return self.wrapped_getattr(a)

    def __setattr__(self, a, val):
        raise ProtectionError('Cannot modify attribute: %s' % (a,))

    def __delattr__(self, a):
        raise ProtectionError('Cannot delete attribute: %s' % (a,))

    def __dir__(self):
        return ['__call__']

    # Needs to be class-specific
    def __hash__(self):
        return hash((
            hash(self.args),
            str(self.kwargs),
        ))

    # __repr__, __str__ and __bytes__:
    # We do not want the default cython implementations
    def __repr__(self):
        return repr(type(functools.partial))

    def __str__(self):
        return str(type(functools.partial))

    def __bytes__(self):
        return bytes(type(functools.partial))

    def __call__(self, *args, **kwargs):
        f = functools.partial(*self.args, **self.kwargs)
        return f(*args, **kwargs)
