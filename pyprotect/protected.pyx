'''
Module with methods to wrap an object controlling visibility
and mutability of attributes

VISIBILITY or READABILITY: Whether the attribute VALUE can be read

- Applies to wrapped object - NOT original object
- Visibility Should not be affected when using wrap()
- Visibility IS affected if you use private / protect
- Objects wrapped with private / protect do not allow following
  special methods to be set or deleted:
  __getattribute__, __setattr__ or __delattr__

MUTABILITY: Ability to CHANGE or DELETE an attribute

- Protected object will not allow CHANGING OR DELETING an attribute
  that is not VISIBLE
- Objects wrapped with private / protect do not allow modification
  of __class__, __dict__ or __slots attributes
- When using protect(o, **kwargs), writeability depends on kwargs

Key methods in the module API:

freeze(o: object) -> object:
    Returns: Instance of Frozen | FrozenPrivacyDict | FrozenPrivate |
        FrozenProtected, depending on what 'o' is

    Object returned prevents modification of ANY attribute

private(o: object, frozen: bool = False) -> object:
    Returns: Instance of FrozenPrivate if frozen; Private otherwise

    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot access any attribute not exported by dir(o)
        - Cannot access any unmangled double '_' attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify __class__ of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
        - Cannot add or delete attributes

   FrozenPrivate:
        Features of Private PLUS prevents modification of ANY attribute

protect(
    o: object,
    frozen: bool = False, dynamic: bool = True,
    hide_private: bool = False,
    ro_data: bool = False, ro_method: bool = True,
    ro=[], rw=[], hide=[],
):
    o: object to be wrapped
    frozen: bool: No attribute can be modified
        PLUS: if 'o' is NOT a module, results returned by methods,
        including __call__ will be frozen
    dynamic: bool: Attribute additions, deletions, type changes in wrapped
        object are automatically considered by hide_private, ro_data,
        ro_method, ro, rw, hide
        If dynamic is False, it is a pledge that attributes of wrapped
        object will not change, and visibility and mutability rules of
        WRAPPING object use a cache to make them faster.
        Rules imposed by Private() are always dynamic
    hide_private: bool: Private vars (_var) will be hidden
    ro_data: bool: Data attributes cannot be deleted or assigned to
    ro_method: bool: Method attributes cannot be deleted or assigned to
    ro: list of str: attributes that will be read-only
    rw: list of str: attributes that will be read-write
        Overrides 'ro_*'
    hide: list of str: attributes that will be hidden

    Returns-->Instance of FrozenProtected if frozen; Protected otherwise

    Protected:
        Features of Private PLUS additional restrictions on:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE

    FrozenProtected:
        Features of Protected PLUS prevents modification of ANY attribute

    Default settings:
    Features of Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot access any attribute not exported by dir(o)
        - Cannot access any unmangled double '_' attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify __class__ of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
        - Cannot add or delete attributes
    PLUS:
        - Methods are readonly - cannot be deleted or assigned to


What kind of python objects can be wrapped?

- Any object that supports getattr, setattr, delattr and __class__
- Pickling / unpickling of wrapped objects is not supported
    Even if / when enabled, after a pickle-unpickle cycle,
    - Frozen objects will no longer be frozen
    - Private objects will no longer have visibility / mutability
      restrictions
    - Protected objects will no longer have custom protections

Can I wrap an object from a python C extension?
YES. See answer to 'What kind of python objects can be wrapped?'

Check if a wrapped object is frozen (immutable):
Use 'isimmutable(o)'.  Also works on objects that are not wrapped

Freeze an object only if it is mutable:
Just use 'freeze'. 'freeze' already checks, and wraps only if mutable

Will wrapper detect attributes that my object adds, changes or deletes
at RUN-TIME?

wrap / freeze / private: YES !

protect:
    If 'dynamic' is True (default): YES !

    If 'dynamic' is False, dir(wrapped_object) will not
    accurately reflect attributes added or deleted at run-time

    Note that the above caveats are UNAFFECTED by 'frozen'
    'frozen' only controls whether object can be modified from OUTSIDE
    the wrapped object

Will I need to change the code for my object / class?
ONLY in the following cases fnd ONLY if wrapped using private / protect:

- If your object DEPENDS on external visibility of traditionally
  'private' mangled object attributes, you will need to change
  the names of those attributes - this is a basic objective of
  private / protect
- If your object DEPENDS on external writeability of traditionally
  'private' attributes of the form '_var', you will need to change
  the names of those attributes - this is a basic objective of
  private / protect
- If your object DEPENDS on EXTERNAL modifability of __class__,
  __dict__ or __slots__, you will need to change the behavior
  of your object (change the code) - since this contradicts the
  basic objective of private / protect.

Code changes required when USING a wrapped object vs. using original object:
Pickling / unpickling of wrapped objects is not supported

If 'o' is your original object, and 'w' is the wrapped object:
One difference across wrap / freeze / private / protect:
dir(w) will necessarily be different from dir(o):
  Additional attributes in 'w': '_Protected_____'
  'private':
      Traditionally 'private' mangled attributes will not appear
  'protect':
      Traditionally 'private' mangled attributes will not appear
      Further differences depending on keyword arguments to 'protect'

Following applies only to wrapping with wrap / private / protect:
- Change calls to w.__getattribute__(a) to getattr(w, a)
- Change calls to w.__delattr__ to delattr(w, a)
- Change calls to w.__setattr(a, val) to setattr(w, a, val)
- Change isinstance(w, Mytypes) to isinstance_protected(w, MyTypes)
    isinstance_protected can also be used transparently on objects
    that have NOT been wrapped
    Can also (even) alias isinstance to isinstance_protected
- Change id(w) to id_protected(w). id_protected can also be used
    transparently on objects that have NOT been wrapped
    Can also (even) alias id to id_protected
- Change 'w is x' to id_protected(w) == id_protected(x)
- Change type(w) to w.__class__ if you want to use the CLASS of w
    but safely - not allowing class modifications
- Getting interactive help on an object
    Instead of help(o), use help_protected(o)
    Can also (even) alias help to help_protected

Object equality:
Two objects returned by wrap / freeze / private / protect are equal
IF AND ONLY IF all the following conditions are met:
- They wrap the SAME object - id(o1) == id(o2)
- They were wrapped using the same method
- For private: both were wrapped with the same value for 'frozen'
- For protect: the EFFECTIVE visibility and writeability implied
  by keyword arguments provided to 'protect' for the two objects
  is identical


Can a Frozen / Private / Protected class instance be wrapped again
using freeze / private / protect?

YES ! Objects are guaranteed to end up being wrapped AT MOST ONCE.

==============================================================================================
Wrap operation ----->   wrap        freeze      private     private     protect     protect
Starting with                                               + frozen                + frozen
==============================================================================================

wrap                    UNCH        freeze      private     private     protect     protect
                        [2]         [2]                     + frozen                + frozen
----------------------------------------------------------------------------------------------
freeze                  wrap        UNCH        private     private     protect     protect
                        [2]         [2]         + frozen    + frozen    + frozen    + frozen
----------------------------------------------------------------------------------------------
private                 private     private     private     private     protect     protect
                                    +frozen                 + frozen                + frozen
----------------------------------------------------------------------------------------------
protect                 protect     protect     protect     protect     protect     protect
                                    + frozen                + frozen    [1]         + frozen
                                                                                    [1]
----------------------------------------------------------------------------------------------
protect                 protect     protect     protect     protect     protect     protect
+ frozen                + frozen    + frozen    + frozen    + frozen    + frozen    + frozen
                                                                        [1]         [1]
==============================================================================================
[1]: protect applied twice, will merge the protect() rules, enforcing the most restrictive
     combination among the two sets of protect() options:
     - 'hide' and 'hide_private' are OR-ed
     - 'ro_method', 'ro_data' and 'ro' are OR-ed
     - 'rw' is AND-ed, but 'rw' of second protect overrides 'ro_*' of SECOND protect
       but not the first protect.

    In short, by calling protect() a second time (or multiple times):
        - Additoinal attributes can be hidden
        - Additional attributes can be made read-only
    but:
        - No hidden attribute will become visible
        - No read-only attribute will become mutable

[2]: If 'x' is an immutable object (e.g. int, str ...) having isimmutable(x) is True,
     freeze(x) returns x and iswrappedfreeze(x) will be False.
     For such an 'x', wrap(x) will return Wrapped object with iswrapped(wrap(x)) == True
     but freeze(wrapx)) will return x unchanged, because wrap(x) does not add any behavior.
     These cases are depicted with 'UNCH' in the table above

     For all other objects 'x', having isimmutable(x) == False, freeze(x) will return
     a Frozen object having iswrapped(freeze(x)) == True, and freeze(wrap(x)) will also
     return a Frozen object having iswrapped(freeze(wrap(x))) == True.

    For all other wrapped objects 'w', created with private(x) or protect(x), freeze(w)
    will always return a Wrapped object with iswrapped(w) == True, because private and
    protect impose additional behavior.

Checking at run-time whether an attribute is visible:

Assuming 'o' is the object, whether wrapped or not and 'a is attribute:
Just use hasattr(o, a).  Works on any object, wrapped or not.
Can also use isvisible(w, a) if 'w' is a wrapped object and 'a' is an attribute.
'isvisible' return value (ONLY) represents whether type of wrapping imposes
specific visibility rules (i.e. hides visibility). 

Checking at run-time whether an attribute is writeable:

Assuming 'o' is the object, whether wrapped or not and you want to set
attribute 'a' to value 'val':
Can use isreadonly(w, a) if 'w' is a wrapped object and 'a' is an attribute.
'isreadonly' return value (ONLY) represents whether type of wrapping imposes
specific mutability rules (i.e. limits mutabiity).

Checking at run-time whether an attribute can be deleted:

Assuming 'o' is the object, whether wrapped or not and you want to delete
attribute 'a':

Can use isreadonly(w, a) if 'w' is a wrapped object and 'a' is an attribute.
'isreadonly' return value (ONLY) represents whether type of wrapping imposes
specific mutability rules (i.e. limits mutabiity).
'''

import sys
cdef bint PY2
cdef object builtin_module
if sys.version_info.major > 2:
    PY2 = False
    builtin_module = sys.modules['builtins']
    import collections.abc as CollectionsABC
else:
    PY2 = True
    builtin_module = sys.modules['__builtin__']
    import collections as CollectionsABC
import os
import re
import types
import functools
import pydoc

include "python_visible.pxi"
include "global_cdefs.pxi"
include "global_c_functions.pxi"
include "ProtectionData.pxi"
include "Wrapped_Frozen.pxi"
include "PrivacyDict_FrozenPrivacyDict.pxi"
include "Private_FrozenPrivate.pxi"
include "Protected_FrozenProtected.pxi"
