## python_protected_class
### Protect class attributes in any python object instance

- Supports (virtually) any python object
- Uses Cython to build a C extension
- Does not leave a back door like:
    - Attributes still accessible using ```object.__getattribute__(myobj, atribute)```
    - Looking at python stack frame
- Tested on Python 2.7.17 and python 3.6.9
- Should work on any Python 3 version
- Well documented (docstring)
- doctests in tests directory


### Usage
```python
# Use any custom class of your own
class MyClass(object):
    def __init__(self):
        self.__hidden = 1
        self._private = 2
        self.public = 3


# Get an instance of your class
myinst = MyClass()

# import + ONE line to wrap and protect class attributes
from protected_class import Protected
wrapped = Protected(myinst)
```

That's it!


### Default settings:
- Traditional (mangled) Python private vars are ALWAYS hidden
    - CANNOT be overridden
- Private vars (form _var) will be read-only
    - Can use hide_private to hide them
    - They CANNOT be made read-write
- add == True: New attributes can be added (Python philosophy)
- ro_dunder == True: 'dunder-vars' will be  read-only
- ro_method == True: Method attributes will be read-only
- All other non-dunder non-private data attributes are read-write

### Options: Proteced class constructor keyword arguments:

| Option            | Type | Default | Description | Overrides |
| ----------------- | ---- | ------- | ----------- | --------- |
| **add**           | bool | **True** | Whether attributes can be ADDED | |
| frozen            | bool | False   | If True, no attributes can be CHANGED or ADDED | <ul><li>add</li><li>rw</li></ul> | |
| **protect_class** | bool | **True** | <ul><li>Prevents modification of CLASS of wrapped object</li><li>Doesn't PREVENT modification, but modification has no effect</li></ul> | |
| hide_all          | bool | False   | <ul><li>All attributes will be hidden</li><li>Can override selectively with 'show'</li></ul> | |
| hide_data         | bool | False   | Data (non-method) attributes will be hidden | |
| hide_method       | bool | False   | Method attributes will be hidden | |
| hide_private      | bool | False   | Private vars (form _var) will be hidden | |
| hide_dunder       | bool | False   | 'dunder-vars' will be hidden | |
| ro_all            | bool | False   | <ul><li>All attributes will be read-only</li><li>Can override selectively with 'rw'</li></ul> | |
| ro_data           | bool | False   | Data (non-method) attributes will be read-only | |
| **ro_method**     | bool | **True** | Method attributes will be read-only | |
| **ro_dunder**     | bool | **True** | 'dunder-vars' will be  read-only | |
| ro                | list of str | [ ] | <ul><li>Attributes that will be read-only</li><li>Can selectively override with 'rw'</li></ul> | |
| rw                | list of str | [ ] | Attributes that will be read-write | <ul><li>ro_all</li><li>ro_data</li><li>ro_method></li><li>ro_dunder></li><li>ro</li></ul> |
| hide | list of str | [ ] | <ul><li>Attributes that will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| show | list of str | [ ] | Attributes that will be visible | <ul><li>hide_all</li><li>hide_data</li><li>hide_method</li><li>hide_dunder</li><li>hide</li></ul> |


### VISIBILITY versus READABILITY:
#### VISIBILITY: appears in dir(object)
- Never affected by Protected class
- Note: visibility in Protected object IS controlled by PermsDict

#### READABILITY: Whether the attribute VALUE can be read
- Applies to Protected object - NOT original wrapped object
- IS controled by Protected clsas
- Affects ```getattr```, ```hasattr```, ```object.__getattribute__``` etc

### MUTABILITY: Ability to CHANGE or DELETE an attribute
- Protected class will not allow CHANGING OR DELETING an attribute that is not VISIBLE - per rules of Protected class

### Python rules for attributes of type 'property':
- Properties are defined in the CLASS, and cannot be changed in the object INSTANCE
- Properties cannot be DELETED
- Properties cannot be WRITTEN to unless property has a 'setter' method defined in the CLASS
- These rules are implemented by the python language (interpreter) and Protected class does not enforce or check


### Non-overrideable behaviors of Protected class:
1. Traditional python 'private' vars - start with ```__``` but do not end with ```__``` - can never be read, written or deleted
2. If an attribute cannot be read, it cannot be written or deleted
3. Attributes can NEVER be DELETED UNLESS they were added at run-time
4. Attributes that are properties are ALWAYS visible AND WRITABLE
    - Properties indicate an intention of class author to expose them
    - Whether they are actually writable depends on whether class author implemented property.setter
5. The following attributes of wrapped object are NEVER visible:
       ```__dict__```, ```__delattr__```, ```__setattr__```, ```__slots__```, ```__getattribute__```
6. Subclassing from Protected class
    - Protected class is only for wrapping a python object INSTANCE
    - Subclassing is possible, but MOST things will not work:
        - Overriding methods of Protected class is not possible - since Protected is implemented in C
        - Overriding attributes of wrapped object is not possible, since the original object is wrapped inside ProtectedC and all accesses are mediated
        - New attributes defined in sub-class will not be accessible, since attribute access is mediated by ProtectedC class
    - Because of this, Protected class PREVENTS sub-classing
    - Subclass your python object BEFORE wrapping with Protected

### What kind of python objects can be wrapped?
Pretty much anything. Protected only mediates attribute access using ```object.__getattribute__```, ```object.__setattr__``` and ```object.__delatr__```. If these methods work on your object, your object can be wrapped

### Can a Protected class instance be wrapped again using Protected?
**YES !**

### Some run-time behaviors to AVOID in wrapped objects:
- Creating attribute at run-time - these will not be detected once the object instance is wrapped in Protected
- Deleting attributes at run-time - these will still appear to be part of the wrapped object when accessing through the wrapping Protected class. Actual access will result in ```AttributeError``` as expected
- Change attribute TYPE - from METHOD to DATA or vice-versa
    - This will cause predictable effects if Protected instance was created using any of the following options:
          hide_method
          hide_data
          ro_method
          ro_data
- None of the above run-time behaviors should be common or recommended - especially when wanting to expose a wrapped
  interface with visibility and/or mutability protections



