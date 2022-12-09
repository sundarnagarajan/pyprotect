'''
Utilities used in unit tests that need pyprotect
'''

import sys
sys.dont_write_bytecode = True
PY2 = False
if sys.version_info.major == 2:
    PY2 = True
import re
import types
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    attribute_protected,
    id_protected,
    iswrapped,
    isprivate,
    isprotected,
    isfrozen,
    isimmutable,
)


oldstyle_private_attr = re.compile(
    '^_[a-zA-Z][a-zA-Z0-9]*__[^_].*?[^_][_]{0,1}$'
)
unmangled_private_attr = re.compile('^__[^_].*?[^_][_]{0,1}$')
PROT_ATTR = attribute_protected()
pickle_attributes = set([
    '__reduce__', '__reduce_ex__',
])
special_attributes = set((
    PROT_ATTR,
))
always_frozen = frozenset([
    '__dict__', '__slots__', '__class__',
    '__module__',
])
# Following are not used (yet)
'''
always_delegated = frozenset([
    '__doc__', '__hash__', '__weakref__',
])
overridden_always = set((
    '__getattribute__', '__setattr__', '__delattr__',
))
'''


def get_readable(o):
    '''get_readable(o: object) -> set'''
    s = set()
    for a in dir(o):
        try:
            getattr(o, a)
            s.add(a)
        except:
            continue
    if hasattr(o, '__dict__'):
        try:
            d = getattr(o, '__dict__')
            for a in d.keys():
                try:
                    getattr(o, a)
                    s.add(a)
                except:
                    continue
        except:
            pass
    return s


def get_writeable(o):
    '''get_writeable(o: object) -> set'''
    r = get_readable(o)
    s = set()
    for a in r:
        try:
            setattr(o, a, getattr(o, a))
            s.add(a)
        except:
            continue
    return s


class CheckPredictions:
    def __init__(self, uti, o, w):
        '''
        uti: unittest.TestCase instance
        o: object
        w: wrapped object (wrapping 'o')

        Here we ASSUME that multi-wrap never happens - iswrapped(o) = False
        So we always (only) compare non-wrapped object with a wrapped object

        ONLY readable / writeable properties of 'o' are observed at the start
        predict*() methods make predictions based on type of 'w' and
        whether 'w' is frozen or not and rules (in case of Protected)
        These predictions are in terms of:
            - Attributes ADDITIONALLY hidden in 'w'
            - Attributes ADDITIONALLY read-only in 'w'
            - Attributes ADDITIONALLY visible in 'w'
        These predictions are check in check() vs. actual tests on 'w'
        '''
        assert(iswrapped(o) is False)
        assert(iswrapped(w) is True)
        assert(id_protected(w) == id(o))
        self.uti = uti
        self.__o = o
        self.__w = w
        self.oldstyle_class = False
        self.__o_readable = get_readable(o)
        self.__o_writeable = get_writeable(o)
        # Note that readablity / writeability of w is checked only in check()
        if type(o) is type:
            self.cn = o.__name__
        else:
            if not PY2:
                self.cn = str(o.__class__.__name__)
            else:
                # Hack for PY2 'old-style' classes
                if hasattr(o, '__class__'):
                    self.cn = str(o.__class__.__name__)
                else:
                    self.cn = 'Unknown_OldStyleClass'
                    self.oldstyle_class = True
        self.hidden_private_attr = re.compile('^_%s__.*?(?<!__)$' % (self.cn,))

        d = self.predict()
        self.check(d)

    def check(self, d):
        '''
        d: key: str, values: set(str)
            addl_hide: set(str): attrs that should be invisible in w
            addl_ro: set(str): attrs that should NOT be writeable in w
                addl_ro will always be superset of addl_hide
            addl_visible: set(str): should always be exactly special_attributes
        '''
        uti = self.uti

        # Note that readablity / writeability of w is checked only in check()
        self.__w_readable = get_readable(self.__w)
        self.__w_writeable = get_writeable(self.__w)

        if isfrozen(self.__w):
            uti.assertEqual(self.__w_writeable, set())

        # EXACTLY and ONLY one extra attribute is added
        uti.assertEqual(
            d['addl_visible'], special_attributes
        )

        # Make exact prediction on visibility
        # Originally readable - predicted hidden + added attribute
        w_r = (self.__o_readable - d['addl_hide']).union(
            special_attributes
        )
        uti.assertEqual(self.__w_readable, w_r)

        # Make exact prediction on mutability
        # None of addl_ro are writeable
        w_w = d['addl_ro'].intersection(self.__w_writeable)
        uti.assertEqual(w_w, set())

        # Check the special module hack - if o is a module, when it is frozen
        # none of the attributes must be frozen
        if isinstance(self.__o, types.ModuleType):
            if isfrozen(self.__w):
                for a in self.__w_readable:
                    # Single '_' attributes are always RO, even in modules
                    if a.startswith('_') and not a.endswith('_'):
                        continue
                    x = getattr(self.__w, a)
                    assert(isfrozen(x) is False)

        # Check always_frozen for Private
        if isprivate(self.__w):
            for a in self.__w_readable:
                x = getattr(self.__w, a)
                if a in always_frozen:
                    assert(isfrozen(x) or isimmutable(x))

    def predict(self):
        '''
        Returned dict key: str, values: set(str)
            addl_hide: set(str): attrs that should be invisible in w
            addl_ro: set(str): attrs that should NOT be writeable in w
                addl_ro will always be superset of addl_hide
            addl_visible: set(str): should always be exactly special_attributes
        '''
        if isprotected(self.__w):
            return self.predict_protect()
        elif isprivate(self.__w) and not isprotected(self.__w):
            return self.predict_private()
        elif iswrapped(self.__w) and not isprivate(self.__w):
            return self.predict_wrap()

    def predict_wrap(self):
        '''
        Returns dict: key: str, values: set(str)
            addl_hide: set(str): attrs that should be invisible in w
            addl_ro: set(str): attrs that should NOT be writeable in w
                addl_ro will always be superset of addl_hide
            addl_visible: set(str): should always be exactly special_attributes
        '''
        d = {
            'addl_hide': set(),
            'addl_ro': set(),
            'addl_visible': set(),
        }
        # All existing attributes are visible, except pickle_attributes
        for a in self.__o_readable:
            if a in pickle_attributes:
                d['addl_hide'].add(a)

        # All attributes are writeable, unless frozen or 'o' is a module
        if isfrozen(self.__w):
            # No additional read-only attrs if 'o' is a module
            if not isinstance(self.__o, types.ModuleType):
                d['addl_ro'] = self.__o_readable
        else:
            d['addl_ro'] = set()

        # Only special_attributes are added
        d['addl_visible'] = special_attributes
        return d

    def predict_private(self):
        '''
        Returns dict: key: str, values: set(str)
            addl_hide: set(str): attrs that should be invisible in w
            addl_ro: set(str): attrs that should NOT be writeable in w
                addl_ro will always be superset of addl_hide
            addl_visible: set(str): should always be exactly special_attributes
        '''
        # Behavior added ON TOP OF Wrapped behavior
        d = self.predict_wrap()

        # Mangled and unmangled private attrs are hidden
        for a in self.__o_readable:
            if unmangled_private_attr.match(a):
                d['addl_hide'].add(a)
            if self.oldstyle_class:
                if oldstyle_private_attr.match(a):
                    d['addl_hide'].add(a)
            if self.hidden_private_attr.match(a):
                d['addl_hide'].add(a)

        # Single '_' attributes are read-only
        for a in self.__o_readable:
            if a.startswith('_') and not a.endswith('_'):
                d['addl_ro'].add(a)
        return d

    def predict_protect(self):
        '''
        Returns dict: key: str, values: set(str)
            addl_hide: set(str): attrs that should be invisible in w
            addl_ro: set(str): attrs that should NOT be writeable in w
                addl_ro will always be superset of addl_hide
            addl_visible: set(str): should always be exactly special_attributes
        '''
        # Behavior added ON TOP OF Private behavior
        d = self.predict_private()

        rules = dict(getattr(self.__w, PROT_ATTR).rules)
        kwargs = rules.get('kwargs', {})

        # Single '_' attrs are hidden based on hide_private
        for a in self.__o_readable:
            if bool(kwargs.get('hide_private', False)):
                for a in self.__o_readable:
                    if a.startswith('_') and not a.endswith('_'):
                        d['addl_hide'].add(a)
            for a in kwargs.get('hide', []):
                d['addl_hide'].add(a)

        # Single '_' attributes are read-only
        # Anything in ro_method / ro_data / ro are read-only
        # UNLESS they are rw
        ro_method = bool(kwargs.get('ro_method', True))
        ro_data = bool(kwargs.get('ro_data', False))
        ro = kwargs.get('ro', [])
        rw = kwargs.get('rw', [])
        for a in self.__o_readable:
            x = getattr(self.__o, a)
            if callable(x):
                # ro_method
                if ro_method and a not in rw:
                    d['addl_ro'].add(a)
            else:
                # ro_data
                if ro_data and a not in rw:
                    d['addl_ro'].add(a)
            if a in ro and a not in rw:
                d['addl_ro'].add(a)
        return d

