# cython: language_level=3
import sys
sys.dont_write_bytecode = True
del sys
'''
VISIBILITY: using object.__dir__(original_object)
    - Never affected by Protected class
    - Note: dir(wrapped_object) IS affected if you use private / protect

READABILITY: Whether the attribute VALUE can be read
    - Applies to wrapped object - NOT original object
    - IS affected if you use private / protect
    - Objects wrapped with private / protect do not expose getattr,
      __getattribute__, __setattr__ or __delattr__

MUTABILITY: Ability to CHANGE or DELETE an attribute
    - Protected object will not allow CHANGING OR DELETING an attribute
      that is not VISIBLE
    - Objects wrapped with private / protect do not allow modification
      of __class__, __dict__ or __slots attributes
    - When using protect(o, **kwargs), writeability depends on kwargs

freeze(o) --> Frozen object
    Frozen object prevents modification of ANY attribute
        - Does not hide traditionally 'private' mangled python attributes

private(o, frozen=True) --> FrozenPrivate if frozen; Private otherwise

    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - The following attributes of wrapped object are NEVER modifiable:
            '__class__', '__dict__', '__slots__',
            '__getattr__', '__getattribute__', '__delattr__', '__setattr__',

    FrozenPrivate:
        All features of Private PLUS prevents modification of ANY attribute

protect(
        o,
        frozen=False, add=False, dynamic=True,
        hide_all=False, hide_data=False, hide_method=False,
        hide_private=False, hide_dunder=False,
        ro_all=False, ro_data=False, ro_method=True, ro_dunder=True,
        ro=[], rw=[], hide=[], show=[],
    ) --> FrozenProtected if frozen; Protected otherwise

    Protected:
        Features of Private PLUS allows customization of:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE
            - Attributes cannot BE deleted UNLESS they were added at run-time
            - If an attribute cannot be read, it cannot be written or deleted

    FrozenProtected:
        All features of Protected PLUS prevents modification of ANY attribute

What kind of python objects can be wrapped?
    Any object that supports getattr, setattr and delattr
    Pickling / unpickling of wrapped objects is not supported
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

        If 'dynamic' is False and you do NOT use any of the followng in kwargs:
            hide_data
            hide_method
            ro_data
            ro_method
        then: YES !

        If 'dynamic' is False and you use any of the followng in kwargs:
            hide_data
            hide_method
            ro_data
            ro_method
        the run-time behavior will NOT be as expected if the wrapped
        object adds attributes or changes the type of attributes at run-time

        Also, if 'dynamic' is False, dir(wrapped_object) will not
        accurately reflect attributes added or deleted at run-time

        Note that the above caveats are UNAFFECTED by 'add' or 'frozen'
        kwargs:
            'add' controls whether attributes can be added from OUTSIDE
                the wrapped object
            add = True is required to add attributes from OUTSIDE the
                wrapped object
            Deleting attributes ONLY works if both conditions below are met:
                - 'add' is True
                - Attribute was added at run-time from OUTSIDE wrapped object
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
        - dir(w) will necessarily be different from dir(o):
            'wrap' / 'freeze' / 'private' / 'protect':
                Additional attributes in 'w':
                    _Protected_id_____
                    _Protected_isinstance_____
            'private':
                One more additional attribute in 'w':
                    _Protected_testop_____
                    Used in unit tests for pyprotect
                Traditionally 'private' mangled attributes will not appear

            'protect':
                One more additional attribute in 'w':
                    _Protected_rules_____
                    Used to avoid redundant multiple wraps when using 'protect'
                Traditionally 'private' mangled attributes will not appear
                Further differences depending on keyword arguments to 'protect'

    Following applies only to wrapping with private / protect (not wrap):
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
            Instead of help(o), use protected.help_protected(o)
            Can also (even) alias help to protected.help_protected

Object equality:
    Two objects returned by wrap / freeze / private / protect are equal
    IF AND ONLY IF all the following conditions are met:
        - They wrap the SAME object - id(o1) == id(o2)
        - They were wrapped using the same method
        - For private: bothe were wrapped with the same value for 'frozen'
        - For protect: the EFFECTIVE visibility and writeability implied
          by keyword arguments provided to 'protect' for the two objects
          is identical


Can a Frozen / Private / Protected class instance be wrapped again
using freeze / private / protect?
    YES !

    To avoid unnecessarily wrapping multiple times and impacting performance
    while guaranteeing the behavior intended by calling wrap / freeze /
    private / protect, the following optimizations are done:

    wrap(o): if 'o' was already created using 'wrap', returns 'o'

    private(o, frozen):
        If 'o' was already created using 'private' AND with the SAME value for
        frozen, returns 'o'

    protect(o, **kwargs):
        If 'o' was already created using 'protect' AND the EFFECTIVE
        visibility and writeability of 'o' is identical to visibility
        and writeability implied by kwargs, returns 'o

    freeze(o): If 'o' is already known to be immutable, returns 'o'
        This means that when using

        w = freeze(o)

        you should check

        isimmutable(w)

        rather than

        isfrozen(w)

        since, for an immutable 'o' (like o=10)

        freeze(o) will return o

        and isfrozen(freeze(10)) will return False
        but isimmutable(freeze(10)) will return True

Checking at run-time whether an attribute is visible:
    Assuming 'o' is the object, whether wrapped or not and 'a is attribute:
    Just use hasattr(o, a).  Works on any object, wrapped or not

Checking at run-time whether an attribute is writeable:
    Assuming 'o' is the object, whether wrapped or not and you waht to set
    attribute 'a' to value 'val':

    Pythonic way - optimistic - try and handle exception

        from pyprotect.protected import ProtectionError

        try:
            setattr(o, a, val)
        except (TypeError|ProtectionError):
            # Do something if attribute cannot be set
            # Should (hopefully) work on any object, wrapped or not

    Non-pythonic way - 'check and hope'
    if isreadonly(o, a):
        # Do something if attribute is read-only
        pass
    else:
        # Do something else if attribute is writeable
        pass

Checking at run-time whether an attribute can be deleted:
    Assuming 'o' is the object, whether wrapped or not and you waht to delete
    attribute 'a':

    Pythonic way - optimistic - try and handle exception

        from pyprotect.protected import ProtectionError

        try:
            delattr(o, a)
        except (TypeError|ProtectionError):
            # Do something if attribute cannot be deleted
            # Should (hopefully) work on any object, wrapped or not
'''
