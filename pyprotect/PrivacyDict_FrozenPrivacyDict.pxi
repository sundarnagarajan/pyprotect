
# @cython.internal
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
            return __HiddenPartial(getattr(PrivacyDict, a), self)
        if a in set([
            'keys', 'items', 'values', 'copy',
        ]):
            py2_map = {
                'keys': __HiddenPartial(getattr(PrivacyDict, 'keys_py2'), self),
                'items': __HiddenPartial(getattr(PrivacyDict, 'items_py2'), self),
                'values': __HiddenPartial(getattr(PrivacyDict, 'values_py2'), self),
            }
            if PY2 and a in py2_map:
                return py2_map[a]
            return __HiddenPartial(getattr(PrivacyDict, a), self)

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


# @cython.internal
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

