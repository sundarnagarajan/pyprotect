## python_protected_class

### Protect class attributes in any python object instance

- Supports (virtually) any python object
- Uses Cython to build a C extension
- Does not leave a back door like:
    - Attributes still accessible using ```object.__getattribute__(myobj, atribute)```
    - Looking at python stack frame
- Tested on Python 2.7.17 and python 3.6.9, 3.7.5, 3.8.0
- Should work on any Python 3 version
- Well documented (docstring)
- doctests in tests directory
- Tested (only) on Ubuntu Bionic 18.04. Should work on any Linux distribution
- Should work wherever cython works
- If you want to CHANGE the source and recompile protected_class.c, and you want it
  to work with Python 3.7+, you need to install cython version >= 0.27.3
  Do this with
  ```sudo pip3 install --upgrade cython>=0.27.3```
- This README.md is not completely up to date. Use ```pydoc protected_class``` for the most up-to-date documentation


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

### Options: Proteced class constructor keyword arguments:

| Option            | Type        | Default  | Description | Overrides |
| ----------------- | ----------- | -------- | ----------- | --------- |
| **add**           | **bool**    | **True** | **<ul><li>Whether attributes can be ADDED</li></ul>** | |
| frozen            | bool        | False    | <ul><li>If True, no attributes can be CHANGED or ADDED</li></ul> | <ul><li>add</li><li>rw</li></ul> | |
| **protect_class** | bool        | **True** | **<ul><li>Prevents modification of CLASS of wrapped object</li><li>Doesn't PREVENT modification, but modification has no effect</li></ul>** | |
| hide_all          | bool        | False    | <ul><li>All attributes will be hidden</li><li>Can override selectively with 'show'</li></ul> | |
| hide_data         | bool        | False    | <ul><li>Data (non-method) attributes will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| hide_method       | bool        | False    | <ul><li>Method attributes will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| hide_private      | bool        | False    | <ul><li>Private vars (form _var) will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| hide_dunder       | bool        | False    | <ul><li>'dunder-vars' will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| ro_all            | bool        | False    | <ul><li>All attributes will be read-only</li><li>Can override selectively with 'rw'</li></ul> | |
| ro_data           | bool        | False    | <ul><li>Data (non-method) attributes will be read-only</li><li>Override selectively with 'rw'</li></ul> | |
| **ro_method**     | **bool**    | **True** | **<ul><li>Method attributes will be read-only</li><li>Override selectively with 'rw'</li></ul>** | |
| **ro_dunder**     | **bool**    | **True** | **<ul><li>'dunder-vars' will be  read-only</li><li>Override selectively with 'rw'</li></ul>** | |
| ro                | list of str | [ ]   | <ul><li>Attributes that will be read-only</li><li>Can selectively override with 'rw'</li></ul> | |
| rw                | list of str | [ ]   | <ul><li>Attributes that will be read-write</li></ul> | <ul><li>ro_all</li><li>ro_data</li><li>ro_method</li><li>ro_dunder</li><li>ro</li></ul> |
| hide              | list of str | [ ]   | <ul><li>Attributes that will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| show              | list of str | [ ]   | <ul><li>Attributes that will be visible</li></ul> | <ul><li>hide_all</li><li>hide_data</li><li>hide_method</li><li>hide_dunder</li><li>hide</li></ul> |

### VISIBILITY versus READABILITY or ACCESSIBILITY
#### VISIBILITY: appears in dir(object)
- Never affected by Protected class: ```object.__dir__(myinst)``` will still show ALL attribute **NAMES**
- Note: visibility in Protected object IS controlled by Protected class: ```object.__dir__(wrapped)``` will show attributes based on options used with Protected class

#### READABILITY or ACCESSIBILITY: Accessing the VALUE of the attribute
- Applies to Protected object instance - NOT original wrapped object
- Code of original wrapped object instance is completely UNAFFECTED by Protected Class
- Accessibility of attributes of original wrapped object through Protected class instance IS controled by Protected class
- Affects ```getattr```, ```hasattr```, ```object.__getattribute__``` etc

### MUTABILITY: Ability to CHANGE or DELETE an attribute
- Protected class will not allow CHANGING OR DELETING an attribute that is not VISIBLE - per rules of Protected class
- Attributes set to read-only using Protected class cannot be modified through Protected class instance. The code of the original wrapped object is not affected by this.

| Option        | Attribute Type    | Readability | Mutability     |
| ------------- | ----------------- | ----------- | -------------- |
| frozen        | Any               | NO          | YES            |
| add           | Added at run-time | NO          | NO             |
| protect_class | object class      | NO          | YES            |
| hide_all      | ANY               | YES         | YES (Indirect) |
| hide_data     | Data attributes   | YES         | YES (Indirect) |
| hide_method   | Method attributes | YES         | YES (Indirect) |
| hide_private  | Private attributes | YES         | YES (Indirect) |
| hide_dunder   | dunder-attributes | YES         | YES (Indirect) |
| ro_all        | ANY               | NO          | YES            |
| ro_data       | Data attributes   | NO          | YES            |
| ro_method     | Method attributes | NO          | YES            |
| ro_dunder     | dunder-attributes | NO          | YES            |
| ro            | ANY               | NO          | YES            |
| rw            | ANY               | NO          | YES            |
| hide          | ANY               | YES         | YES (Indirect) |
| show          | ANY               | YES         | NO             |


### Default settings:
- Traditional (mangled) Python private vars are ALWAYS hidden
    - CANNOT be overridden
- Private vars (form _var) will be read-only
    - Can use hide_private to hide them
    - They CANNOT be made read-write
- add == True: New attributes can be added (Python philosophy)
- protect_class == True: Prevents modification of CLASS of wrapped object
- ro_dunder == True: 'dunder-vars' will be  read-only
- ro_method == True: Method attributes will be read-only
- All other non-dunder non-private data attributes are read-write

### Non-overrideable behaviors of Protected class:
1. Traditional python 'private' vars - start with ```__``` but do not end with ```__``` - can never be read, written or deleted
2. If an attribute cannot be read, it cannot be written or deleted
3. Attributes can NEVER be DELETED UNLESS they were added at run-time
4. Attributes that are properties are ALWAYS visible AND WRITABLE (except if 'frozen' is used)
    - Properties indicate an intention of class author to expose them
    - Whether they are actually writable depends on whether class author implemented property.setter
5. The following attributes of wrapped object are NEVER visible:
       ```__dict__```, ```__delattr__```, ```__setattr__```, ```__slots__```, ```__getattribute__```
6. You cannot subclass Protected class

### Python rules for attributes of type 'property':
- Properties are defined in the CLASS, and cannot be changed in the object INSTANCE
- Properties cannot be DELETED
- Properties cannot be WRITTEN to unless property has a 'setter' method defined in the CLASS
- These rules are implemented by the python language (interpreter) and Protected class does not enforce or check

### What kind of python objects can be wrapped?
Pretty much anything. Protected only mediates attribute access using ```object.__getattribute__```, ```object.__setattr__``` and ```object.__delatr__```. If these methods work on your object, your object can be wrapped

### Can a Protected class instance be wrapped again using Protected?
**YES !**

### Why can't I subclass Protected class?
- Protected class is only for wrapping a python object INSTANCE
- NONE of the atributes of Protected class are exposed - only (selecive) attributes of the WRAPPED object
- Overriding methods of Protected class is not possible - since Protected is implemented in C
- Overriding attributes of wrapped object is not possible, since the original object is wrapped inside Protected and all accesses are hrough the Proteced class instance
- New attributes defined in sub-class will not be accessible, since attribute access is mediated by Protected class
- Because of this, Protected class PREVENTS sub-classing
- Subclass your python object BEFORE wrapping with Protected


### How do I
#### Make my object completely read-only
- Use ```add=False, frozen=True```

#### Completely hide private variables hat are normally read-only, but visible
- Use ```hide_private=True```

#### Hide all except properties
- Use ```ro_all=True```

#### Hide all dunder-attributes except specific ones
- Use ```hide_dunder=True, show=['exception1', 'exception2']```

#### Hide all attributes except specific ones
- Use ```hide_all=True, show=['exception1', 'exception2']```

#### Make all attributes read-only except specific ones
- Use ```ro_all=True, rw=['exception1', 'exception2']```

#### How can I get close to default python behavior
- Use ```add=True, protect_class=False, ro_method=False, ro_dunder=False```
- Mangled private variables still won't be visible
- Private variables (form ```_var```) will still be read-only

### Some RUN-TIME behaviors to AVOID in wrapped objects:
- Do not create attribute - these will not be detected once the object instance is wrapped in Protected
- Do not delete attributes - these will still appear to be part of the wrapped object when accessing through the wrapping Protected class. Actual access will result in ```AttributeError``` as expected
- Do not change attribute TYPE - from METHOD to DATA or vice-versa
    - This will cause predictable effects if Protected instance was created using any of the following options:
          hide_method
          hide_data
          ro_method
          ro_data
- None of the above run-time behaviors should be common or recommended - especially when wanting to expose a wrapped interface with visibility and/or mutability protections

### Work in progress
- Completing setup.py to allow installation with ```pip```
- Uploading to pypi.org

