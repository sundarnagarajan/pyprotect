# pyprotect: Restrict visibility or mutability of Python object attributes
pyprotect is a python module that provides API to restrict visibility or mutability of selected Python object attributes in a robust manner.

The key functions in the pyprotect module API - __private()__ and __protect()__ wrap the python object (like a _Proxy_) to restrict visibility or mutability of selected attributes of the wrapped object, while allowing the __wrapping__ object to behave virtually identical to the __wrapped__ object.

## Features
- Can wrap virtually any Python object - instances, classes (types), modules, methods, classmethods, instancemethods, staticmethods, partials, lambdas.
- Tested on Python 2.7.18 and Python 3.6.9, 3.7.5, 3.8.0, 3.10.6. Should work on any version of Python3.
- Has extensive unit (functional) tests - in [_tests_](https://github.com/sundarnagarajan/python_protected_class/tree/main/tests) directory.

## Table of Contents


<!-- vim-markdown-toc GFM -->

* [Quick start](#quick-start)
    * [Options: protect method arguments](#options-protect-method-arguments)
    * [Readability and mutability of attributes with protect() method](#readability-and-mutability-of-attributes-with-protect-method)
* [Classes](#classes)
* [Features of key classes](#features-of-key-classes)
    * [Frozen](#frozen)
    * [Private](#private)
    * [FrozenPrivate](#frozenprivate)
    * [Protected](#protected)
    * [FrozenProtected](#frozenprotected)
* [FUNCTIONS](#functions)
    * [Wrapping API](#wrapping-api)
        * [Options: protect method arguments](#options-protect-method-arguments-1)
        * [Readability and mutability of attributes with protect() method](#readability-and-mutability-of-attributes-with-protect-method-1)
    * [Checking types of wrapped objects](#checking-types-of-wrapped-objects)
    * [Checking properties objects inside wrapped objects](#checking-properties-objects-inside-wrapped-objects)
    * [pyprotect module metadata](#pyprotect-module-metadata)
* [Python rules for attributes of type 'property':](#python-rules-for-attributes-of-type-property)
* [What kind of python objects can be wrapped?](#what-kind-of-python-objects-can-be-wrapped)
* [Work in progress](#work-in-progress)
* [Changelog](#changelog)
    * [Dec-08-2022](#dec-08-2022)

<!-- vim-markdown-toc -->

## Quick start
```python

freeze(o: object) -> Frozen:
```

```python
private(o: object, frozen: bool = False) -> object:
```
Returns: __FrozenPrivate__ instance if _frozen_; __Private__ instance otherwise
    
```python
protect(
    o: object frozen: bool = False,
    dynamic: bool = True,
    hide_private: bool = False,
    ro_data: bool = False,
    ro_method: bool = True,
    ro: List[str] = [],
    rw: List[str] = [],
    hide: List[str] = []
) -> object:
# o-->object to be wrapped
```
Returns-->Instance of __FrozenProtected__ if _frozen_; Instance of __Protected__ otherwise

### Options: protect method arguments
| Option       | Type        | Default | Description                                                                            | Overrides                  |
|--------------|-------------|---------|----------------------------------------------------------------------------------------|----------------------------|
| frozen       | bool        | False   | If True, no attributes can be changed, added or deleted                                |                            |
| hide_private | bool        | False   | If True, private vars of the form ```_var``` will be hidden                            |                            |
| ro_data      | bool        | False   | Data (non-method) attributes will be immutable<br>Can override selectively with __rw__ |                            |
| ro_method    | bool        | True    | Method (callable) attributes will be immutable<br>Can override selectively with __rw__ |                            |
| ro           | list of str | []      | Attributes that will be immutable<br>Can override selectively with __rw__              |                            |
| rw           | list of str | []      | Attributes that will be mutable                                                        | ro_data<br>ro_method<br>ro |
| hide         | list of str | []   |                                                                                        |                            |

### Readability and mutability of attributes with protect() method

| Option       | Attribute Type     | Restricts Readability | Restricts Mutability |
|--------------|--------------------|-----------------------|----------------------|
| frozen       | Any                | NO                    | YES                  |
| hide_private | Private attributes | YES                   | YES (Indirect)       |
| ro_data      | Data attributes    | NO                    | YES                  |
| ro_method    | Method attributes  | NO                    | YES                  |
| ro           | ANY                | NO                    | YES                  |
| rw           | ANY                | NO                    | YES                  |
| hide         | ANY                | YES                   | YES (Indirect)       |

## Classes

![class diagram](classdiagram.svg "class diagram")

## Features of key classes
### Frozen
Frozen object prevents modification of ANY attribute
- Does not __additionally__ restrict visibility of any attributes in __wrapped__ object accessed through __wrapping__ object

### Private
- Cannot access traditionally 'private' mangled python attributes
- Cannot modify traditionally private attributes (form '_var')
- Cannot add or delete attributes
- Cannot modify CLASS (```__class__```)of wrapped object
- Cannot modify ```__dict__``` of wrapped object
- Cannot modify ```__slots__``` of wrapped object
- The following attributes of wrapped object are NEVER writeable:
    ```__dict__```, ```__delattr__```, ```__setattr__```, ```__slots__```, ```__getattribute__```
- Traditional (mangled) Python private vars are ALWAYS hidden
- Private vars (form \_var) will be read-only
- Attributes cannot be added or removed
- Attributes not part of dir(wrapped_object) are not visible
- Attributes that are properties are ALWAYS visible AND WRITABLE (except if '_frozen_' is used)
    - Properties indicate an intention of class author to expose them
    - Whether they are actually writable depends on whether class author implemented property.setter
### FrozenPrivate
- Features of Private PLUS prevents modification of ANY attribute
### Protected
- Features of Private PLUS allows __further restriction__ of:
    - Which attributes are VISIBLE
    - Which attributes are WRITEABLE
- Default settings:
    - Features of Private - see above
    - dynamic == True
        Attribute additions, deletions, type changes automatically visible
    - ro_method == True: Method attributes will be read-only
    - All other non-private data attributes are read-write
### FrozenProtected
- Features of Protected PLUS prevents modification of ANY attribute

## FUNCTIONS
### Wrapping API
```python

freeze(o: object) -> Frozen:
```

```python
private(o: object, frozen: bool = False) -> object:
```
Returns: __FrozenPrivate__ instance if _frozen_; __Private__ instance otherwise
    
```python
protect(
    o: object frozen: bool = False,
    dynamic: bool = True,
    hide_private: bool = False,
    ro_data: bool = False,
    ro_method: bool = True,
    ro: List[str] = [],
    rw: List[str] = [],
    hide: List[str] = []
) -> object:
# o-->object to be wrapped
```
Returns-->Instance of __FrozenProtected__ if _frozen_; Instance of __Protected__ otherwise

#### Options: protect method arguments
| Option       | Type        | Default | Description                                                                            | Overrides                  |
|--------------|-------------|---------|----------------------------------------------------------------------------------------|----------------------------|
| frozen       | bool        | False   | If True, no attributes can be changed, added or deleted                                |                            |
| hide_private | bool        | False   | If True, private vars of the form ```_var``` will be hidden                            |                            |
| ro_data      | bool        | False   | Data (non-method) attributes will be immutable<br>Can override selectively with __rw__ |                            |
| ro_method    | bool        | True    | Method (callable) attributes will be immutable<br>Can override selectively with __rw__ |                            |
| ro           | list of str | []      | Attributes that will be immutable<br>Can override selectively with __rw__              |                            |
| rw           | list of str | []      | Attributes that will be mutable                                                        | ro_data<br>ro_method<br>ro |
| hide         | list of str | []   |                                                                                        |                            |

#### Readability and mutability of attributes with protect() method

| Option       | Attribute Type     | Restricts Readability | Restricts Mutability |
|--------------|--------------------|-----------------------|----------------------|
| frozen       | Any                | NO                    | YES                  |
| hide_private | Private attributes | YES                   | YES (Indirect)       |
| ro_data      | Data attributes    | NO                    | YES                  |
| ro_method    | Method attributes  | NO                    | YES                  |
| ro           | ANY                | NO                    | YES                  |
| rw           | ANY                | NO                    | YES                  |
| hide         | ANY                | YES                   | YES (Indirect)       |

```python
freeze(o: object) -> object:
```
Frozen object prevents modification of ANY attribute
- Does not hide traditionally 'private' mangled python attributes

```python
wrap(o: object) -> Wrapped:
```
- Should behave just like the wrapped object, except following attributes cannot be modified:
    ```__getattribute__```, ```__delattr__```, ```__setattr__```, ```__slots__```,
- Does NOT protect CLASS (or ```__class__```) of wrapped object from modification
- Does NOT protect ```__dict__``` or ```__slots__```
    
Useful for testing if wrapping is failing for a particular type of object

###  Checking types of wrapped objects
```python
isfrozen(x: object) -> bool
```
_x_ was created using _freeze()_ or _private(o, frozen=True)_ or _protect(o, frozen=True)_

```python
isimmutable(x: object) -> bool
```
_x_ is known to be immutable

```python
isprivate(x: object) -> bool
```
_x_ was created using _private()_

```python
isprotected(x: object) -> bool
```
_x_ was created using _protect()_

### Checking properties objects inside wrapped objects
```python
contains(w: object, o: object) -> bool
```
If _w_ is a wrapped object (_iswrapped(w)_ is True), returns whether _w_ wraps _o_
Otherwise unconditionally returns False

```python
help_protected(x: object) -> None
```
If _x_ wraps _o_, executes _help(o)_
Otherwise executes h_elp(x)_

```python
id_protected(x: object) -> int
```
if _x_ is a wrapped object (_iswrapped(x)_ is True) and _x_ wraps _o_, returns _id(o)_
Otherwise returns _id(x)_

```python
isinstance_protected(x: object, t: type) -> bool
```
If _x_ is a wrapped object (_iswrapped(x)_ is True) and _x_ wraps _o_, returns _isinstance(o, t)_
Otherwise returns _isinstance(x, t)_

```python
isreadonly(x: object, a: str) -> bool
```
If _x_ is a wrapped object (_iswrapped(x)_ is True) and _x_ wraps _o_, returns whether rules of __wrapper__ make attribute _a_ read-only when accessed through _x_
This represents __rule__ of wrapped object - does not guarantee that_o_ has attribute_a_ or that setting attribute _a_ in object _o_ will not raise any exception
If _x_ is __not__ a wrapped object (_iswrapped(x)_ is False) , unconditionally returns False

### pyprotect module metadata
```python
immutable_builtin_attributes() -> Set[str]
```
Returns-->set of str: attributes in builtins that are immutable
Used in unit tests

## Python rules for attributes of type 'property':
- Properties are defined in the CLASS, and cannot be changed in the object INSTANCE
- Properties cannot be DELETED
- Properties cannot be WRITTEN to unless property has a 'setter' method defined in the CLASS
- These rules are implemented by the python language (interpreter) and Protected class does not enforce or check

## What kind of python objects can be wrapped?
Pretty much anything. pyprotect only mediates attribute access using ```object.__getattribute__```, ```object.__setattr__``` and ```object.__delatr__```. If these methods work on your object, your object can be wrapped

## Work in progress
- Uploading to pypi.org

## Changelog
### Dec-08-2022
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

