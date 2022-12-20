
'''
Module with methods to wrap an object controlling visibility
and mutability of attributes

VISIBILITY or READABILITY: Whether the attribute VALUE can be read

- Applies to wrapped object - NOT original object
- Should not be affected when using wrap()
- IS affected if you use private / protect
- Objects wrapped with private / protect do not expose getattr,
  __getattribute__, __setattr__ or __delattr__

MUTABILITY: Ability to CHANGE or DELETE an attribute

- Protected object will not allow CHANGING OR DELETING an attribute
  that is not VISIBLE
- Objects wrapped with private / protect do not allow modification
  of __class__, __dict__ or __slots attributes
- When using protect(o, **kwargs), writeability depends on kwargs

What kind of python objects can be wrapped?

- Any object that supports getattr, setattri, delattr and __class__
- Python2 'old-style' classes (without '__class__' attribute) are
  not supported. INSTANCES of such classes CAN be wrapped.
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
YES ! Objects are guaranteed to end up being wrapped at most once.

Checking at run-time whether an attribute is visible:
Assuming 'o' is the object, whether wrapped or not and 'a is attribute:
Just use hasattr(o, a).  Works on any object, wrapped or not

Checking at run-time whether an attribute is writeable:
Assuming 'o' is the object, whether wrapped or not and you want to set
attribute 'a' to value 'val':

Pythonic way - optimistic - try and handle exception

try:
    setattr(o, a, val)
except Exception:
    # Do something if attribute cannot be set
    # Should (hopefully) work on any object, wrapped or not
    pass

Non-pythonic way - 'check and hope'
if isreadonly(o, a):
    # Do something if attribute is read-only
    pass
else:
    # Do something else if attribute is writeable
    pass

Checking at run-time whether an attribute can be deleted:
Assuming 'o' is the object, whether wrapped or not and you want to delete
attribute 'a':

try:
    delattr(o, a)
except Exception:
    # Do something if attribute cannot be deleted
    # Should (hopefully) work on any object, wrapped or not
    pass

'''
