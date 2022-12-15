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
import itertools
import pydoc
from pyprotect_finder import pyprotect    # noqa: F401
from pyprotect import (
    attribute_protected,
    id_protected,
    iswrapped,
    isprivate,
    isprotected,
    isfrozen,
    isimmutable,
    wrap, freeze, private, protect,
)


unmangled_private_attr = re.compile('^__[^_].*?[^_][_]{0,1}$')
mangled_private_attr_classname_regex = '[a-zA-Z][a-zA-Z0-9]*'
mangled_private_attr_regex_fmt = '^_%s__[^_](.*?[^_]|)[_]{0,1}$'
PROT_ATTR = attribute_protected()
pickle_attributes = set([
    '__reduce__', '__reduce_ex__',
])
special_attributes = set((
    PROT_ATTR,
))
# Used (only) in CheckPredictions.check()
always_frozen = frozenset([
    '__dict__', '__slots__', '__class__',
    '__module__',
])
# Used (only) in predict_wrap()
always_delegated = frozenset([
    '__doc__',
    '__weakref__',
])
# Used (only) in predict_wrap()
overridden_always = set((
    '__getattribute__', '__setattr__', '__delattr__',
))


def get_pydoc(o):
    return '\n'.join(
        pydoc.render_doc(o).splitlines()[2:]
    ).rstrip('\n') + '\n'


def get_readable(o, refer=None):
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
    # Try harder using refer and object.__getattribute__
    if refer is not None:
        for a in dir(refer):
            try:
                getattr(o, a)
                s.add(a)
            except:
                continue
            try:
                # overridden_always accessible using object.__getattribute__
                # but mangled private attributes cannot be accessed
                object.__getattribute__(o, a)
                s.add(a)
            except:
                continue
    return s


def get_writeable(o, refer=None):
    '''get_writeable(o: object) -> set'''
    r = get_readable(o)
    s = set()
    for a in r:
        try:
            setattr(o, a, getattr(o, a))
            s.add(a)
        except:
            continue
    # Try harder using refer and object.__setattr__, object.__delattr__
    if refer is not None:
        for a in dir(refer):
            try:
                setattr(o, a, getattr(o, a))
                s.add(a)
            except:
                continue
            try:
                object.__setattr__(o, a, getattr(o, a))
                s.add(a)
            except:
                continue
            try:
                object.__delattr__(o, a)
                s.add(a)
            except:
                continue
    return s


def check_predictions(o, w):
    cp = CheckPredictions(o, w)
    d = cp.get_predictions()
    cp.check(d)


def ro_props(o):
    '''ro_props(o: object) -> set(str)'''
    if not isinstance(o, type):
        o = type(o)
    r = get_readable(o)
    s = set()
    for a in r:
        x = getattr(o, a)
        if isinstance(x, property):
            if x.fset is None:
                s.add(a)
    return s


def rw_props(o):
    '''rw_props(o: object) -> set(str)'''
    if not isinstance(o, type):
        o = type(o)
    r = get_readable(o)
    s = set()
    for a in r:
        x = getattr(o, a)
        if isinstance(x, property):
            if x.fset is not None:
                s.add(a)
    return s


class CheckPredictions:
    def __init__(self, o, w):
        '''
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
        self.__o = o
        self.__w = w
        self.oldstyle_class = False
        self.__o_readable = get_readable(o)
        self.__o_ro_props = ro_props(self.__o)
        self.__o_rw_props = rw_props(self.__o)
        # Notes:
        #   - Predictions do not need to test writeability of 'o'
        #   - get_writeable(self.__o) is only called in get_predictions()
        #   - 'w' readability / writeability checked only in get_predictions()
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

    def get_predictions(self):
        '''
        Returns: dict:
            o: dict
                readable: set
                writeable: set
                ro_props: set
                rw_props: set
            w: dict
                readable: set
                writeable: set
            predictions: dict
                addl_hide: set(str): attrs that should be invisible in w
                addl_ro: set(str): attrs that should NOT be writeable in w
                    addl_ro will always be superset of addl_hide
                addl_visible: set(str): should be exactly special_attributes
        '''
        d = {
            'o': {
                'readable': set(),
                'writeable': set(),
            },
            'w': {
                'readable': set(),
                'writeable': set(),
            },
            'predictions': {
                'addl_hide': set(),
                'addl_ro': set(),
                'addl_visible': set(),
            }
        }
        d['o']['readable'] = self.__o_readable
        d['o']['writeable'] = get_writeable(self.__o)
        d['o']['ro_props'] = self.__o_ro_props
        d['o']['rw_props'] = self.__o_rw_props
        d['w']['readable'] = get_readable(self.__w, refer=self.__o)
        d['w']['writeable'] = get_writeable(self.__w, refer=self.__o)
        d['predictions'] = self.predict()
        return d

    def check(self, d):
        '''
        d: key: str, values: set(str)
            o: dict
                readable: set
                writeable: set
                ro_props: set
                rw_props: set
            w: dict
                readable: set
                writeable: set
            predictions: dict
                addl_hide: set(str): attrs that should be invisible in w
                addl_ro: set(str): attrs that should NOT be writeable in w
                    addl_ro will always be superset of addl_hide
                addl_visible: set(str): should be exactly special_attributes

        check() is DECLARATIVE - predictions are checked based on
        'promises' and known special 'hacks' for PY2, module objects etc

        w_readable and w_writeable are ONLY used in asserts
        '''
        o_readable = d['o']['readable']
        # o_writeable = d['o']['writeable']
        w_readable = d['w']['readable']
        w_writeable = d['w']['writeable']

        if isfrozen(self.__w):
            assert(w_writeable == set())

        # EXACTLY and ONLY one extra attribute is added
        assert(d['predictions']['addl_visible'] == special_attributes)

        # Make exact prediction on visibility
        # Originally readable - predicted hidden + added attribute
        w_r = (o_readable - d['predictions']['addl_hide']).union(
            special_attributes
        )
        try:
            assert(w_readable == w_r)
        except AssertionError:
            print(
                'DEBUG: ',
                w_readable.difference(w_r),
                w_r.difference(w_readable),
            )

        # Make exact prediction on mutability
        # None of addl_ro are writeable
        w_w = d['predictions']['addl_ro'].intersection(w_writeable)
        assert(w_w == set())

        # Check the special module hack - if o is a module, when it is frozen
        # none of the attributes must be frozen
        # This specifically is not appplied in Protected class - to allow
        # full freezing of module is desired
        if isinstance(self.__o, types.ModuleType):
            if isfrozen(self.__w):
                for a in w_readable:
                    # Single '_' attributes are always RO, even in modules
                    if a.startswith('_') and not a.endswith('_'):
                        continue
                    x = getattr(self.__w, a)
                    if not isprotected(self.__w):
                        try:
                            assert(isfrozen(x) is False)
                        except AssertionError:
                            print(
                                type(self.__o), a, type(x),
                                type(self.__w),
                            )
                            raise

        # Check always_frozen for Private
        if isprivate(self.__w):
            for a in w_readable:
                x = getattr(self.__w, a)
                if a in always_frozen:
                    assert(isfrozen(x) or isimmutable(x))
            for a in always_frozen:
                assert(a not in w_writeable)

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
            if self.hidden_private_attr.match(a):
                d['addl_hide'].add(a)

        for a in self.__o_readable:
            # Hidden attributes are not read-only
            if a not in d['addl_hide']:
                # Single '_' attributes are read-only
                if a.startswith('_') and not a.endswith('_'):
                    d['addl_ro'].add(a)
                if a in always_frozen:
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

        for a in self.__o_readable:
            # Single '_' attrs are hidden based on hide_private
            if bool(kwargs.get('hide_private', False)):
                for a in self.__o_readable:
                    if a.startswith('_') and not a.endswith('_'):
                        d['addl_hide'].add(a)
            # Attributes in 'hide' are hidden
            for a in kwargs.get('hide', []):
                d['addl_hide'].add(a)

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
                if (
                    ro_data and
                    (
                        a not in rw and
                        a not in self.__o_rw_props
                    ) and
                    a not in self.__o_ro_props
                ):
                    d['addl_ro'].add(a)
            if (
                a in ro and
                (
                    a not in rw and
                    a not in self.__o_rw_props
                ) and
                a not in self.__o_ro_props
            ):
                d['addl_ro'].add(a)
            # always_delegated are delegate without control so
            # they cannot be in addl_ro
            d['addl_ro'] = d['addl_ro'].difference(always_delegated)
        return d


class MultiWrap:
    def __init__(self, o):
        self.__o = o
        assert(iswrapped(o) is False)
        self.run()

    def run(self):
        NOOP = "NONE"
        ops_map = {
            "freeze": freeze,
            "wrap": wrap,
            "private": private,
            "protect": protect,
            NOOP: None,
        }
        op_names = list(ops_map.keys())
        op_sequences = []
        for r in range(1, (len(op_names) + 1)):
            for p in itertools.permutations(op_names, r=r):
                for start_op in ("freeze", NOOP):
                    for end_op in ("freeze", NOOP):
                        op_sequences.append((start_op,) + p + (end_op,))

        frozen = False
        w = None
        for seq in op_sequences:
            for op in seq:
                if op == NOOP:
                    continue
                if w is None:
                    w = ops_map[op](self.__o)
                else:
                    w = ops_map[op](w)
                if op == "freeze":
                    # May not always be frozen - e.g. if 'o' is immutable
                    if isfrozen(w):
                        frozen = True

                # Now the checks
                assert(isfrozen(w) == frozen)
                assert(id_protected(w) == id(self.__o))
                if iswrapped(w):
                    # May not always be - if 'o' is immutable and op == freeze
                    PROT_ATTR = attribute_protected()
                    assert(
                        getattr(w, PROT_ATTR).multiwrapped() is False
                    )
