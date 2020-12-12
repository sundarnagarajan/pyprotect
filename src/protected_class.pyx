'''
Building:
    Python3:
        cython3 private.pyx
        gcc -shared -pthread -fPIC -fwrapv -O2 -Wall -fno-strict-aliasing
                -I/usr/include/python3.6 -o private.so private.c

    Python2:
        cython3 private.pyx
        gcc -shared -pthread -fPIC -fwrapv -O2 -Wall -fno-strict-aliasing
                -I/usr/include/python2.7 -o private.so private.c

'''
import sys
import re
from cpython.object cimport (
    Py_LT, Py_EQ, Py_GT, Py_LE, Py_NE, Py_GE,
)
cimport cython


cdef class __Object(object):
    pass


cdef dict hidden_always
hidden_always = dict.fromkeys([
    '__dict__', '__delattr__', '__setattr__', '__slots__',
    '__getattribute__',
])
# Use compiled regex - no function call, no str operations
cdef object ro_private_attr
ro_private_attr = re.compile('^_[^_].*?(?<!_)$')
cdef object dunder_attr
dunder_attr = re.compile('^__.*?__$')

# Python 2 str does not have isidentifier() method
cdef object attr_identifier
attr_identifier = re.compile('^[_a-zA-Z][a-zA-Z0-9_]*$')


@cython.final
cdef class Protected(object):
    '''
    VISIBILITY versus READABILITY:
        VISIBILITY: appears in dir(object)
            - Never affected by Protected class
            - Note: visibility in Protected object IS controlled by PermsDict
        READABILITY: Whether the attribute VALUE can be read
            - Applies to Protected object - NOT original wrapped object
            - IS controled by Protected clsas
            - Affects getattr, hasattr, object.__getattribute__ etc

    MUTABILITY: Ability to CHANGE or DELETE an attribute
        - Protected class will not allow CHANGING OR DELETING an attribute
          that is not VISIBLE - per rules of Protected class

    Python rules for attributes of type 'property':
        - Properties are defined in the CLASS, and cannot be changed
            in the object INSTANCE
        - Properties cannot be DELETED
        - Properties cannot be WRITTEN to unless property has a 'setter' method
            defined in the CLASS
        - These rules are implemented by the python language (interpreter)
            and Protected class does not enforce or check

    Notes on non-overrideable behaviors of Protected class:
        1. Traditional python 'private' vars - start with '__' but do not
           end with '__' - can never be read, written or deleted
        2. If an attribute cannot be read, it cannot be written or deleted
        3. Attributes can NEVER be DELETED UNLESS they were added at run-time
        4. Attributes that are properties are ALWAYS visible AND WRITABLE
            - Properties indicate an intention of class author to expose them
            - Whether they are actually writable depends on whether class
              author implemented property.setter
        5. The following attributes of wrapped object are NEVER visible:
             '__dict__', '__delattr__', '__setattr__', '__slots__',
             '__getattribute__'
        6. Subclassing from Protected class
            - Protected class is only for wrapping a python object INSTANCE
            - Subclassing is possible, but MOST things will not work:
                - Overriding methods of Protected class is
                  not possible - since Protected is implemented in C
                - Overriding attributes of wrapped object is not possible,
                  since the original object is wrapped inside ProtectedC
                  and all accesses are mediated
                - New attributes defined in sub-class will not be accessible,
                  since attribute access is mediated by ProtectedC class
            - Because of this, Protected class PREVENTS sub-classing
            - Subclass your python object BEFORE wrapping with Protected

    What kind of python objects can be wrapped?
        - Pretty much anything. Protected only mediates attribute access
          using object.__getattribute__, object.__setattr__ and
          object.__delatr__. If these methods work on your object,
          your object can be wrapped

    Can a Protected class instance be wrapped again using Protected?
        YES !

    Some run-time behaviors to AVOID in wrapped objects:
        - Creating attribute at run-time - these will not be detected
          once the object instance is wrapped in Protected
        - Deleting attributes at run-time - these will still appear
          to be part of the wrapped object when accessing through the
          wrapping Protected class. Actual access will result in
          AttributeError as expected
        - Change attribute TYPE - from method to DATA or vice-versa
            - This will cause predictable effects if Protected
              instance was created using any of the following options:
                  hide_method
                  hide_data
                  ro_method
                  ro_data
        - None of the above run-time behaviors should be common or
          recommended - especially when wanting to expose a wrapped
          interface with visibility and/or mutability protections
    '''

    # Constructor parameters
    cdef object pvt_o
    cdef bint frozen
    cdef bint add
    cdef bint protect_class
    cdef bint hide_all
    cdef bint hide_data
    cdef bint hide_method
    cdef bint hide_private
    cdef bint hide_dunder
    cdef bint ro_all
    cdef bint ro_data
    cdef bint ro_method
    cdef bint ro_dunder
    cdef dict ro
    cdef dict rw
    cdef dict hide
    cdef dict show

    cdef str cn
    cdef dict attr_acl
    cdef dict attr_props
    cdef object hidden_private_attr
    # Track attributes added at run-time
    cdef dict added_attrs
    # Cache dir() output
    cdef list dir_out

    def __init__(
        self, o,
        frozen=False,
        add=True,
        protect_class=True,
        hide_all=False, hide_data=False, hide_method=False,
        hide_private=False, hide_dunder=False,
        ro_all=False, ro_data=False, ro_method=True, ro_dunder=True,
        ro=[], rw=[], hide=[], show=[],
    ):
        '''
        o-->object to be wrapped
        frozen-->bool: If True, no attributes can be CHANGED or ADDED
            - Overrides 'add'
            - Default: False
        add-->bool: Whether attributes can be ADDED - Default: True
        protect_class-->bool: Prevents modification of CLASS of wrapped object
            - __class__ attribute returns a COPY of actual __class__
            - Doesn't PREVENT modification, but modification has no effect
            - Default: True
        hide_all-->bool: All attributes will be hidden
            - Default: False
            - Can override selectively with 'show'
        hide_data-->bool: Data (non-method) attributes will be hidden
            - Default: False
        hide_method-->bool: Method attributes will be hidden
            - Default: False
        hide_private-->bool: Private vars (form _var) will be hidden
            - Default: False
        hide_dunder-->bool: 'dunder-vars' will be hidden
            - Default: False

        ro_all-->bool: All attributes will be read-only
            - Default: False
            - Can override selectively with 'rw'
        ro_data-->bool: Data (non-method) attributes will be read-only
            - Default: False
        ro_method-->bool: Method attributes will be read-only
            - Default: True
        ro_dunder-->bool: 'dunder-vars' will be  read-only
            - Default: True

        ro-->list of str: attributes that will be read-only
        rw-->list of str: attributes that will be read-write
            Overrides 'ro', ro_all, 'ro_data', 'ro_method', 'ro_dunder'

        hide-->list of str: attributes that will be hidden
        show-->list of str: attributes that will be visible
            Overrides 'hide', hide_all', 'hide_data', 'hide_method',
            'hide_dunder'

        Default settings:
        - Traditional (mangled) Python private vars are ALWAYS hidden
            - CANNOT be overridden
        - Private vars (form _var) will be read-only
            - Can use hide_private to hide them
            - They CANNOT be made read-write
        - add == True: New attributes can be added (Python philosophy)
        - ro_dunder == True: 'dunder-vars' will be  read-only
        - ro_method == True: Method attributes will be read-only
        - All other non-dunder non-private data attributes are read-write
        '''
        self.pvt_o = o
        self.frozen = bool(frozen)
        self.add = bool(add)
        self.protect_class = bool(protect_class)
        self.hide_all = bool(hide_all)
        self.hide_data = bool(hide_data)
        self.hide_method = bool(hide_method)
        self.hide_private = bool(hide_private)
        self.hide_dunder = bool(hide_dunder)
        self.ro_all = bool(ro_all)
        self.ro_data = bool(ro_data)
        self.ro_method = bool(ro_method)
        self.ro_dunder = bool(ro_dunder)

        ro = [
            x for x in list(ro)
            if isinstance(x, str) and attr_identifier.match(x)
        ]
        rw = [
            x for x in list(rw)
            if isinstance(x, str) and attr_identifier.match(x)
        ]
        hide = [
            x for x in list(hide)
            if isinstance(x, str) and attr_identifier.match(x)
        ]
        show = [
            x for x in list(show)
            if isinstance(x, str) and attr_identifier.match(x)
        ]

        self.ro = dict.fromkeys(ro)
        self.rw = dict.fromkeys(rw)
        self.hide = dict.fromkeys(hide)
        self.show = dict.fromkeys(show)

        self.cn = o.__class__.__name__
        self.attr_acl = {}
        self.attr_props = {}
        # Use compiled regex - no function call, no str operations
        self.hidden_private_attr = re.compile('^_%s__.*?(?<!__)$' % (self.cn,))
        self.added_attrs = {}
        # Make dir() pre-computed
        self.dir_out = []

        self.set_attr_acl()

    cdef set_attr_acl(self):
        '''
        Called only once at wrapping time
        Most of the real work is done in set_1_attr_acl
        '''
        d = self.attr_acl
        o = self.pvt_o

        # Mark properties
        for a in dir(o):
            if hasattr(o.__class__, a):
                if isinstance(getattr(o.__class__, a), property):
                    self.attr_props[a] = None

        for a in dir(o):
            # Ignore (hide) traditional (mangled) python private vars
            if self.hidden_private_attr.match(a):
                continue
            if a in hidden_always:
                continue
            self.set_1_attr_acl(a)

        self.dir_out = sorted(
            [x for x in self.attr_acl.keys() if
             self.attr_acl[x].get('r', False)
            ]
        )

    cdef set_1_attr_acl(self, a, added=False):
        '''
        a-->str: attribute name
        added-->bool: True if adding new attribute at run-time
        Returns-->Nothing. Sets self.attr_acl[a]
        This is the routine that considers constructor parameters

        code path when added == True NEEDS to be as fast as possible - called
        whenever a new attribute is added
        '''
        # Make run-time operation as fast as possible
        if added:
            # Added at run-time - can always read, change and delete
            self.attr_acl[a] = {'r': True, 'w': True}
            self.added_attrs[a] = None
            self.dir_out = sorted(
                [x for x in self.attr_acl.keys() if
                 self.attr_acl[x].get('r', False)
                ]
            )
            return

        # Rest is called only once at wrapping time

        o = self.pvt_o
        def_ret = True
        d = {'r': def_ret, 'w': def_ret}

        # For properties, only frozen option is important
        if a in self.attr_props:
            if self.frozen:
                d['w'] = False
            self.attr_acl[a] = d
            return

        attr = getattr(self.pvt_o, a)
        if self.hide_all:
            d['r'] = False
        if self.ro_all:
            d['w'] = False
        if callable(attr):     # METHOD
            if self.hide_method:
                d['r'] = False
            if self.ro_method:
                d['w'] = False
        else:                  # DATA
            if self.hide_data:
                d['r'] = False
            if self.ro_data:
                d['w'] = False
        if dunder_attr.match(a):
            if self.hide_dunder:
                d['r'] = False
            if self.ro_dunder:
                d['w'] = False
        if a in self.ro:
            d['w'] = False
        # rw overrides ro
        if a in self.rw:
            d['w'] = True
        if a in self.hide:
            d['r'] = False
        # show overrides hide
        if a in self.show:
            d['r'] = True

        if not d['r']:
            d['w'] = False

        # Private vars are ALWAYS read-only
        if ro_private_attr.match(a):
            if self.hide_private:
                d['r'] = False
            d['w'] = False

        # Frozen overrides rw
        if self.frozen:
            d['w'] = False
        self.attr_acl[a] = d


    cdef get_1_acl(self, a, op):
        '''
        op-->one of ['r', 'w']
        Returns-->bool
        NEEDS to be as fast as possible - called for every attribute lookup
        '''
        # Follow python rules for properties to speed up
        if a in self.attr_props and op == 'w':
            return False
        # if frozen, can only read (if at all)
        if self.frozen and op != 'r':
            return False
        if a not in self.attr_acl:
            return False

        return self.attr_acl.get(a).get(op)

    cdef aclcheck(self, a, op):
        '''
        op-->one of ['r', 'w', 'd']
        Returns-->Nothing: raises exception on errors
        NEEDS to be as fast as possible - called for every attribute lookup
        '''
        invalid_ident = 'Invalid identifier: %s' % (repr(a))
        missing_msg = "Object '%s' has no attribute '%s'" % (self.cn, str(a))
        ro_msg = 'Read-only attribute: %s.%s' % (self.cn, str(a))
        nodel_msg = 'Cannot delete attribute: %s.%s' % (self.cn, str(a))
        nopvt_msg = 'Cannot add private attribute: %s.%s' % (self.cn, str(a))
        noadd_msg = 'Cannot add attribute: %s.%s' % (self.cn, str(a))
        frozen_msg = 'Cannot add attribute: Read-only object: %s' % (self.cn)

        if not isinstance(a, str):
            raise AttributeError(invalid_ident)
        if not attr_identifier.match(a):
            raise AttributeError(invalid_ident)

        if op == 'w' and self.frozen:
            raise AttributeError(frozen_msg)

        ret = self.get_1_acl(a=a, op=op)

        if op == 'r':
            if not ret:
                raise AttributeError(missing_msg)
        elif op == 'w':
            if a in self.attr_acl:     # Existing attribute
                if not ret:
                    raise AttributeError(ro_msg)
                return
            # New attribute creation
            if not self.add:
                raise AttributeError(noadd_msg)
            if self.hidden_private_attr.match(a):
                raise AttributeError(nopvt_msg)
            if ro_private_attr.match(a):
                raise AttributeError(nopvt_msg)
        elif op == 'd':
            # Can NEVER delete attributes UNLESS added at run-time
            if a not in self.added_attrs:
                if a in self.attr_acl:
                    raise AttributeError(nodel_msg)
                else:
                    raise AttributeError(missing_msg)

    def __getattribute__(self, a):
        if a == 'pvt_o':
            return self.pvt_o
        self.aclcheck(a=a, op='r')
        # Protect CLASS of wrapped object
        if a == '__class__' and self.protect_class:
            x = getattr(self.pvt_o, a)
            return type(x.__name__, x.__bases__, dict(x.__dict__))
        return getattr(self.pvt_o, a)

    def __setattr__(self, a, val):
        self.aclcheck(a=a, op='w')
        if a in self.attr_acl:
            setattr(self.pvt_o, a, val)
        else:    # Adding new attribute
            setattr(self.pvt_o, a, val)
            # Add to self.attr_acl
            if hasattr(self.pvt_o, a):
                self.set_1_attr_acl(a, added=True)

    def __delattr__(self, a):
        self.aclcheck(a=a, op='d')
        delattr(self.pvt_o, a)
        if a in self.added_attrs:
            del self.added_attrs[a]
        if a in self.attr_acl:
            del self.attr_acl[a]

    def __dir__(self):
        # We __COULD__ just return object.__dir__(self.pvt_o)
        # This is just aesthetic so that output of dir(wrapped_obj)
        # reflects attributes that can be read FROM the wrapped object
        return self.dir_out

    def __repr__(self):
        return repr(self.pvt_o)

    def __str__(self):
        return str(self.pvt_o)

    def __richcmp__(self, other, int op):
        fn_map = {
            Py_LT: '__lt__', Py_LE: '__le__', Py_EQ: '__eq__',
            Py_NE: '__ne__', Py_GE: '__ge__', Py_GT: '__gt__',
        }
        m = fn_map.get(op, NotImplemented)
        if not hasattr(self.pvt_o, m):
            return NotImplemented
        return getattr(self.pvt_o, m)(other)
