# coding=utf8
'''
Module with methods to wrap an object and additionally restrict
visibility and mutability of attributes

VISIBILITY or READABILITY: Whether the attribute VALUE can be read

- Objects wrapped with private / protect do not allow following
  special methods to be set or deleted:
    __getattribute__
    __setattr__
    __delattr__

MUTABILITY or WRITEABILITY: Ability to CHANGE or DELETE an attribute

- Protected object will not allow CHANGING OR DELETING an attribute
  that is not VISIBLE
- Objects wrapped with private / protect do not allow modification
  of __class__, __dict__ or __slots attributes
- When using protect(o, **kwargs), writeability depends on kwargs

Classes
=======

These classes are not directly exported by the module so as to not
clutter the pydoc documentation for the module.

                                 Proxy
                                   │
                                   │
                                Wrapped
                                   │
                                   │
    ┌──────────────────────────────┴───────────┐
    │                                          │
    Frozen                                  Private
                                               │
                                               │
         ┌────────────────────────┬────────────┴───────────────┐
         │                        │                            │
    PrivacyDict                   │                        Protected
         │                        │                            │
         │                        │                            │
    FrozenPrivacyDict         FrozenPrivate            FrozenProtected


    Wrapped:
        - Visibility: No restrictions
        - Mutability: No restrictions

    Frozen: subclass of Wrapped
        - Visibility: No restrictions
        - Mutability: NO ATTRIBUTES can be changed or deleted

    Private: subclass of Wrapped
        - Visibility:
            - Cannot access traditionally 'private' mangled python attributes
            - Cannot access any unmangled double '_' attributes
            - Cannot access any attribute not exported by dir(o)
        - Mutability:
            - Cannot modify traditionally private attributes (form '_var')
            - Cannot modify __class__ of wrapped object
            - Cannot modify __dict__ of wrapped object
            - Cannot modify __slots__ of wrapped object
            - Cannot add or delete attributes

    FrozenPrivate: subclass of Private
        - Created by calling private(o, frozen=True) on an object 'o'
        - Also created by calling freeze(private(o, frozen=False))
          on an object 'o'
        - Features of Private PLUS prevents modification of ANY attribute
        - Visibility: Same as Private
        - Mutability: NO ATTRIBUTES can be changed or deleted

    Protected: subclass of Private
        - Created by calling protect(o, frozen=False) on an object 'o'
        - Features of Private PLUS additional restrictions on:
            - ADDITIONAL attributes that are NOT visible
            - ADDITIONAL attributes that are NOT writeable

    FrozenProtected: subclass of Protected
        - Created by calling protect(o, frozen=True) on an object 'o'
        - Also created by calling freeze(protect(o, frozen=False))
          on an object 'o'
        - Features of Protected PLUS prevents modification of ANY attribute
        - Mutability: NO ATTRIBUTES can be changed or deleted

    PrivacyDict: subclass of Private
        - Not created directly

    FrozenPrivacyDict: subclass of Private
        - Created internally when accessing 'dict' attribute of a
          Private object

Key methods in the module API:
=============================

wrap(o: object) -> Wrapped:

freeze(o: object) -> object:
    - If 'o' is immutable (e.g. int , string), returns 'o' UNCHANGED
    - If 'o' is Wrapped, returns 'o' UNCHANGED if object WRAPPPED INSIDE
      'o' is immutable, returns Frozen otherwise
    - If 'o' is Frozen, returns 'o UNCHANGED
    - If 'o' is FrozenPrivate, FrozenProtected or FrozenPrivacyDict,
      returns 'o' UNCHANGED
    - If 'o' is Private, returns FrozenPrivate
    - If 'o' is Protected, returns FrozenProtected
    - Otherwise, returns Frozen

    Object returned prevents modification of ANY attribute

private(o: object, frozen: bool = False) -> object:
    - If 'frozen' is False:
        - If 'o' is an instance of Private, returns 'o' UNCHANGED
        - If 'o' is an instance of Protected, returns 'o' UNCHANGED
    - If 'frozen' is True:
        - If 'o' is an instance of Private, returns freeze(o) --> FrozenPrivate
        - If 'o' is an instance of Protected, returns freeze(o) --> FrozenProtected
    - Otherwise:
        If frozen is True, returns FrozenPrivate; returns Private otherwise

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

    Default settings:
    Features of Private:
    PLUS:
        - Methods are readonly - cannot be deleted or assigned to

    If protect() is called on an object 'o' that is an instance of
    Protected:
        protect() will merge the protect() rules, enforcing the most restrictive
        combination among the two sets of protect() options:
         - 'hide' and 'hide_private' are OR-ed
         - 'ro_method', 'ro_data' and 'ro' are OR-ed
         - 'rw' is AND-ed, but 'rw' of second protect overrides 'ro_*' of SECOND protect
           but not the first protect.

        In short, by calling protect() a second time (or multiple times):
            - Additoinal attributes can be hidden
            - Additional attributes can be made read-only
        but:
            - No previously hidden attribute will become visible
            - No previously read-only attribute will become mutable


Calling wrap operations multiple times
======================================

In the table below, the left-most column shows starting state.
The top row shows operation applied to the starting state.
The intersecting cell shows the result.

═══════════════╤══════════════════════════════════════════════════════════════════════════════
Operation  🡆   │ wrap        freeze      private     private     protect     protect
🡇  with        │                                     + frozen                + frozen
═══════════════╪══════════════════════════════════════════════════════════════════════════════
Wrapped        │ UNCH        Frozen      Private     Frozen      Protected   FrozenProtected
               │ [2]         [2]                     Private
───────────────┼──────────────────────────────────────────────────────────────────────────────
Frozen         │ Wrapped     UNCH        Frozen      Frozen      Frozen      Frozen
               │ [2]         [2]         Private     Private     Protected   Protected
───────────────┼──────────────────────────────────────────────────────────────────────────────
Private        │ UNCH        Frozen      UNCH        Frozen      Protected   Frozen
               │             Private                 Private                 Protected
───────────────┼──────────────────────────────────────────────────────────────────────────────
FrozenPrivate  │ UNCH        UNCH        UNCH        UNCH        Frozen      FrozenProtected
               │                                                 Protected
───────────────┼──────────────────────────────────────────────────────────────────────────────
Protected      │ UNCH        Frozen      UNCH        Frozen      Protected   FrozenProtected
               │             Protected               Protected   [1]         [1]
───────────────┼──────────────────────────────────────────────────────────────────────────────
FrozenProtected│ UNCH        UNCH        UNCH        UNCH        Frozen      FrozenProtected
               │                                                 Protected   [1]
               │                                                 [1]
═══════════════╧══════════════════════════════════════════════════════════════════════════════

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
        - No previously hidden attribute will become visible
        - No previously read-only attribute will become mutable

[2]: If 'x' is an immutable object (e.g. int, str ...) having isimmutable(x) is True,
     freeze(x) returns x and iswrapped(freeze(x)) will be False.

     For all other objects 'x', having isimmutable(x) == False, freeze(x) will return
     a Frozen object having iswrapped(freeze(x)) == True

    For all other wrapped objects 'w', created with private(x) or protect(x), freeze(w)
    will always return a Wrapped object with iswrapped(w) == True

Checking whether an object is wrapped:
=====================================

iswrapped(w) -> bool: True IFF 'w' was was wrapped using
    wrap(), freeze(), private() or protect()
    See Note for output of freeze()

isfrozen(w) -> bool: True IFF 'w' is an instance of Frozen,
FrozenPrivate, ProzenPrivacyDict or FrozenProtected

isprivate(w) -> bool: True IFF 'w' is an instance of Private,
FrozenPrivate, Protected or FrozenProtected

isprotected(w) -> bool: True IFF 'w' is an instance of Protected,
FrozenProtected


What kind of python objects can be wrapped?
==========================================

- Any object that supports getattr, setattr, delattr and __class__
- Pickling / unpickling of wrapped objects is not supported
    Even if / when enabled, after a pickle-unpickle cycle,
    - Frozen objects will no longer be frozen
    - Private objects will no longer have visibility / mutability
      restrictions
    - Protected objects will no longer have custom protections

Can I wrap an object from a python C extension?
YES. See answer to 'What kind of python objects can be wrapped?'

Will wrapper detect attributes deleted, added or changed at RUN-TIME?
====================================================================
wrap / freeze / private: YES !

protect:
    If 'dynamic' is True (default): YES !

    If 'dynamic' is False, dir(wrapped_object) will not
    accurately reflect attributes added or deleted at run-time

    Note that the above caveats are UNAFFECTED by 'frozen'
    'frozen' only controls whether object can be modified from OUTSIDE
    the wrapped object

Will I need to change the code for my object / class?
====================================================
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

Code changes required when USING a wrapped object:
=================================================

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


Checking at run-time whether an attribute is visible:
====================================================

Assuming 'o' is the object, whether wrapped or not and 'a is attribute:
Just use hasattr(o, a).  Works on any object, wrapped or not.
Can also use isvisible(w, a) if 'w' is a wrapped object and 'a' is an attribute.
'isvisible' return value (ONLY) represents whether type of wrapping imposes
specific visibility rules (i.e. hides visibility). 

Checking at run-time whether an attribute is writeable:
======================================================

Assuming 'o' is the object, whether wrapped or not and you want to set
attribute 'a' to value 'val':
Can use isreadonly(w, a) if 'w' is a wrapped object and 'a' is an attribute.
'isreadonly' return value (ONLY) represents whether type of wrapping imposes
specific mutability rules (i.e. limits mutabiity).

Checking at run-time whether an attribute can be deleted:
========================================================

Assuming 'o' is the object, whether wrapped or not and you want to delete
attribute 'a':
Can use isreadonly(w, a) if 'w' is a wrapped object and 'a' is an attribute.
'isreadonly' return value (ONLY) represents whether type of wrapping imposes
specific mutability rules (i.e. limits mutabiity).


Viewing help for the classes:
============================
You can see the help for each of the classes below - EXCEPT
PrivacyDict as follows:

    Wrapped         : help(type(wrap(None)))
    Frozen          : help(type(freeze([])))
    Private         : help(type(private(None)))
    Protected       : help(type(protect(None)))
    FrozenPrivate   : help(type(private(None, frozen=True)))
    FrozenProtected : help(type(protect(None, frozen=True)))

To see help for FrozenPrivacyDict:
    class C(object):
        pass

    help(type(private(C()).__dict__))

Proxy and PrivacyDict are not exposed directly.
'''
include "imports.pxi"
include "python_visible.pxi"
include "global_cdefs.pxi"
include "global_c_functions.pxi"
include "ProtectionData.pxi"
include "Proxy.pxi"
include "Wrapped_Frozen.pxi"
include "PrivacyDict_FrozenPrivacyDict.pxi"
include "Private_FrozenPrivate.pxi"
include "Protected_FrozenProtected.pxi"
include "HiddenPartial.pxi"
