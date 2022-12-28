## pyprotect module

### Protect attributes in any python object instance

- Supports (virtually) any python object
- Uses Cython to build a C extension
- Does not leave a back door like:
    - Attributes still accessible using ```object.__getattribute__(myobj, atribute)```
    - Looking at python stack frame
- Tested on Python 2.7.17 and python 3.6.9, 3.7.5, 3.8.0, 3.10.6
- Should work on any Python 3 version
- Well documented (docstring)
- doctests in tests directory
- Tested (only) on Ubuntu Bionic 18.04. Should work on any Linux distribution
- Should work wherever cython works
- If you want to CHANGE the source and recompile protected.c, and you want it
  to work with Python 3.7+, you need to install cython version >= 0.27.3
  Do this with
  ```sudo pip3 install --upgrade cython>=0.27.3```
- This README.md is not completely up to date. Use ```pydoc pyprotect``` for the most up-to-date documentation

### VISIBILITY versus READABILITY or ACCESSIBILITY
#### VISIBILITY: appears in dir(object)
- Never affected by wrapping: ```object.__dir__(myinst)``` will still show ALL attribute **NAMES**
- Note: visibility in wrapping object IS controlled by Protected class: ```object.__dir__(wrapped)``` will show attributes based on options used with protect() method

#### READABILITY or ACCESSIBILITY: Accessing the VALUE of the attribute
- Applies to wrapping object instance - NOT original wrapped object
- Code of original wrapped object instance is completely UNAFFECTED by Protected Class
- Accessibility of attributes of original wrapped object through Protected class instance IS controled by Protected class
- Affects ```getattr```, ```hasattr```, ```object.__getattribute__``` etc

### MUTABILITY: Ability to CHANGE or DELETE an attribute
- Wrapping object will not allow CHANGING OR DELETING an attribute that is not VISIBLE - per rules of Protected class
- Attributes set to read-only using protect() method cannot be modified through wrapping object. The code of the original wrapped object is not affected by this.

### Classes

(classdiagram.svg)


### FUNCTIONS
#### contains(p: object, o: object):
    Returns--whether 'p' wraps 'o'

#### freeze(o: object) -> object:
    Frozen object prevents modification of ANY attribute
        - Does not hide traditionally 'private' mangled python attributes

#### help_protected(o: object) -> None:
    help for wrapped object if wrapped; help for 'o' otherwise

#### id_protected(o: object) -> int:
    id of wrapped object if wrapped; id of 'o' otherwise

#### immutable_builtin_attributes() -> Set[str]:
    Returns-->set of str: attributes in builtins that are immutable
    Used in unit tests

#### isfrozen(o: object) -> bool:
    'o' was created using freeze()

#### isimmutable(o: object) -> bool:
    'o' is KNOWN to be immutable

#### isinstance_protected(o: object, c: type) -> bool:
    Returns-->True IFF isinstance(object_wrapped_by_o, c)
    Similar to isinstance, but object o can be an object returned
    by freeze(), private() or protect()

#### isprivate(o: object) -> bool:
    'o' was created using private()

#### isprotected(o: object) -> bool:
    'o' was created using protect()

#### isreadonly(o: object, a: str) -> bool:
    Returns-->bool: True IFF 'o' is wrapped AND 'o' makes arribute 'a'
        read-only if present in wrapped object
    This represents RULE of wrapped object - does not guarantee
    that WRAPPED OBJECT has attribute 'a' or that setting attribute
    'a' in object 'o' will not raise any exception

#### iswrapped(o: object) -> bool:
    'o' was created using wrap / freeze / private / protect

#### private(o: object, frozen: bool = False) -> object:
    FrozenPrivate instance if frozen; Private instance otherwise
    
    Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
    
    FrozenPrivate:
        Features of Private PLUS prevents modification of ANY attribute

#### protect(o: object frozen: bool = False, dynamic: bool = True, hide_private: bool = False, ro_data: bool = False, ro_method: bool = True, ro: List[str] = [], rw: List[str] = [], hide: List[str] = []

    o-->object to be wrapped
    frozen-->bool: No attribute can be modified. Default: False
        - Overrides 'add'
    dynamic-->bool: Attribute additions, deletions, type changes in wrapped
        object are automatically visible
        If True, 'add' is automatically set to False
        Default: True
    
    hide_private-->bool: Private vars (_var) will be hidden. Default: False
    ro_data-->bool: Data attributes will be read-only. Default: False
    ro_method-->bool: Method attributes will be read-only. Default: True
    
    ro-->list of str: attributes that will be read-only. Default: []
    rw-->list of str: attributes that will be read-write. Default: []
        Overrides 'ro_*'
    
    hide-->list of str: attributes that will be hidden. Default: []
    Returns-->Instance of FrozenProtected if frozen; Instance of Protected otherwise
    
    Protected:
        Features of Private PLUS allows customization of:
            - Which attributes are VISIBLE
            - Which attributes are WRITEABLE
    
    FrozenProtected:
        Features of Protected PLUS prevents modification of ANY attribute
    
    Default settings:
    Features of Private:
        - Cannot access traditionally 'private' mangled python attributes
        - Cannot modify traditionally private attributes (form '_var')
        - Cannot modify CLASS of wrapped object
        - Cannot modify __dict__ of wrapped object
        - Cannot modify __slots__ of wrapped object
    - dynamic == True
      Attribute additions, deletions, type changes automatically visible
    - ro_method == True: Method attributes will be read-only
    - All other non-dunder non-private data attributes are read-write
    
#### wrap(o: object) -> object:
    Wrapped:
        - Should behave just like the wrapped object, except
          following attributes cannot be modified:
            'getattr, __getattribute__',
            '__delattr__', '__setattr__', '__slots__',
        - Does NOT protect CLASS of wrapped object from modification
        - Does NOT protect __dict__ or __slots__
    
    Useful for testing if wrapping is failing for a particular type of object


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
from pyprotect import protect
wrapped = protect(myinst)
```


### Options: protect method arguments

| Option            | Type        | Default  | Description | Overrides |
| ----------------- | ----------- | -------- | ----------- | --------- |
| frozen            | bool        | False    | <ul><li>If True, no attributes can be CHANGED or ADDED</li></ul> | <ul><li>add</li><li>rw</li></ul> | |
| hide_private      | bool        | False    | <ul><li>Private vars (form _var) will be hidden</li><li>Override selectively with 'show'</li></ul> | |
| ro_data           | bool        | False    | <ul><li>Data (non-method) attributes will be read-only</li><li>Override selectively with 'rw'</li></ul> | |
| ro_method     | bool    | True | <ul><li>Method attributes will be read-only</li><li>Override selectively with 'rw'</li></ul> | |
| ro                | list of str | [ ]   | <ul><li>Attributes that will be read-only</li><li>Can selectively override with 'rw'</li></ul> | |
| rw                | list of str | [ ]   | <ul><li>Attributes that will be read-write</li></ul> | <li>ro_data</li><li>ro_method</li><li>ro</li></ul> |
| hide              | list of str | [ ]   | <ul><li>Attributes that will be hidden</li><li>Override selectively with 'show'</li></ul> | |

### Configurable readability and mutability of attributes with protect() method
| Option        | Attribute Type    | Readability | Mutability     |
| ------------- | ----------------- | ----------- | -------------- |
| frozen        | Any               | NO          | YES            |
| hide_private  | Private attributes | YES         | YES (Indirect) |
| ro_data       | Data attributes   | NO          | YES            |
| ro_method     | Method attributes | NO          | YES            |
| ro            | ANY               | NO          | YES            |
| rw            | ANY               | NO          | YES            |
| hide          | ANY               | YES         | YES (Indirect) |
| show          | ANY               | YES         | NO             |


### Default settings for private() and protect() methods
- Traditional (mangled) Python private vars are ALWAYS hidden
    - CANNOT be overridden
- Private vars (form _var) will be read-only
    - Can use hide_private to hide them
    - They CANNOT be made read-write
- add == True: New attributes can be added (Python philosophy)
- ro_method == True: Method attributes will be read-only
- All other non-dunder non-private data attributes are read-write

### Non-overrideable behaviors of Protected class:
1. Traditional python 'private' vars - start with ```__``` but do not end with ```__``` - can never be read, written or deleted
2. If an attribute cannot be read, it cannot be written or deleted
3. Attributes that are properties are ALWAYS visible AND WRITABLE (except if 'frozen' is used)
    - Properties indicate an intention of class author to expose them
    - Whether they are actually writable depends on whether class author implemented property.setter
4. The following attributes of wrapped object are NEVER visible:
       ```__dict__```, ```__delattr__```, ```__setattr__```, ```__slots__```, ```__getattribute__```
5. You cannot subclass Protected class

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
- Uploading to pypi.org

### Changelog
#### Dec-08-2022
A number of parameters to protect() have been discontinued. See list and reasons below, as well as how to achieve the same effect without thos parameters (sometimes, it takes more work). Most of them would be realistically useful very rarely, and / or do not align with what I call 'idiomatic python'.

**hide_all, hide_method, hide_dunder**
So-called 'special methods' in Python serve an important functional roles - especially in emulating containers (tuples, lists, sets, dicts), emulating numeric types supporting arithmetic operators, numeric comparisons etc. If such specific 'dunder methods' were hidden, it would definitely affect the behavior of the wrapped object. ```hide_dunder``` would hide all such special methods. ```hide_method``` would in addition hide all methods in the objest. ```hide_all``` would hide all object attributes, making the object virtually useless, and the option useful in testing (if at all).

**hide_data**
In most cases, hiding all non-method data attributes will make the object less useful / cripple the expected usage of the object. Specific use-cases can be achieved using the 'hide' parameter.

**ro_dunder**
Seems like it can be replaced by using ro_method' Mostly, in 'idiomatic python', methods of a class / instance are not mutated from outside the class / instance. This expected 'idiomatic python' behavior can be achieved with 'ro_method'.

**ro_all**
Is unnecessary, since 'frozen' can be used instead.

**add**
In my opinion, 'add' does not align with 'idiomatic python'. While Python allows users of a class / instance adding attributes to the class / instance, that is not the expected style. Based on this, I have decided to promote that 'idiomatic style', and prevent adding / deleting any attributes in a Private or Protected object.

**show**
It is unnecessary, since all attributes are visible by default in Python. Only 'hide' or 'hide_private' will hide any attributes.

This leaves the following (incidentally also reducing testing load):

	- Visibility:
		- hide_private
		- hide
	- Mutability:
		- ro_data
		- ro_method
		- ro
		- rw
		- frozen
	- Behavior:
		- dynamic

