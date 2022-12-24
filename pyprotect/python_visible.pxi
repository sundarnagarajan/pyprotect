
# ------------------------------------------------------------------------
# Methods to query metadata on wrapped object
# ------------------------------------------------------------------------

def attribute_protected():
    '''
    attribute_protected() -> str: name of special attribute in Wrapped objects
    '''
    return PROT_ATTR_NAME

def id_protected(o: object) -> int:
    '''
    id_protected(o: object) -> int:
    id of wrapped object if iswrapped(o); id of 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).id
    return id(o)


def hash_protected(o: object) -> int:
    '''
    hash_protected(o: object) -> int:
    hash of wrapped object if iswrapped(o); hash of 'o' otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).hash()
    return hash(o)


def isinstance_protected(o: object, c: type) -> bool:
    '''
    isinstance_protected(o: object, c: type) -> bool:
    Returns: isinstance(wrapped_object, c) if iswrapped(o)
        isinstance(o, c) otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).isinstance(c)
    return isinstance(o, c)


def issubclass_protected(o: type, c: type) -> bool:
    '''
    issubclass_protected(o: object, c: type) -> bool:
    Returns: issubclass(wrapped_object, c) if iswrapped(o);
        issubclass(o, c) otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).issubclass(c)
    return issubclass(o, c)


def instance_of_protected(x: object, w: object) -> bool:
    '''
    instance_of_protected(x: object, w: object) -> bool
    If iswrapped(w) and w wraps 'o':
        Returns isinstance(x, type(o))
    Else: returns isinstance(x, w)
    '''
    if iswrapped(w):
        return getattr(w, PROT_ATTR_NAME).instanceof(x)
    return isinstance(x, w)


def subclass_of_protected(x: object, w: object) -> bool:
    '''
    subclass_of_protected(x: object, w: object) -> bool
    If iswrapped(w) and w wraps 'o':
        Returns issubclass(x, type(o))
    Else: returns issubclass(x, w)
    '''
    if iswrapped(w):
        return getattr(w, PROT_ATTR_NAME).subclassof(x)
    return issubclass(x, w)


def same_class_protected(c: type, w: object) -> bool:
    '''
    same_class_protected(c: type, w: object) -> bool
    If iswrapped(w) and w wraps 'o':
        Returns (c is type(o))
    Else: returns (c is type(w))
    '''
    if iswrapped(w):
        return id(c) == getattr(w, PROT_ATTR_NAME).id_class
    return c is type(w)


def help_protected(o: object) -> None:
    '''
    help_protected(o: object) -> None
    Calls help(wrapped_object) if iswrapped(o); help(o) otherwise
    '''
    if isinstance(o, Wrapped):
        return getattr(o, PROT_ATTR_NAME).help()
    return help(o)


def contains(p: object, o: object):
    '''
    contains(p: object, o: object): bool: whether 'p' wraps 'o'
    '''
    if isinstance(p, Wrapped):
        return getattr(p, PROT_ATTR_NAME).id == id(o)
    return False


# ------------------------------------------------------------------------
# Boolean checks on (potentially) wrapped object
# ------------------------------------------------------------------------


def isimmutable(o: object) -> bool:
    '''
    isimmutable(o: object) -> bool: 'o' is KNOWN to be immutable
    '''
    # Everything in builtin module is immutable
    if id(o) in builtins_ids:
        return True
    # None and NotImplemented are immutable
    if o is None or o is NotImplemented:
        return True
    if isfrozen(o):
        return True
    if type(o) in immutable_types_set:
        # Although 'tuple' is immutable in python, for our purposes, 'tuple' does
        # NOT prevent modification to MEMBERS of the tuple that may be mutable
        # Hence, check if 'o' has a stable hash - python hash() does this for us
        try:
            hash(o)
            return True
        except TypeError:
            pass
    return False


def iswrapped(o: object) -> bool:
    '''
    iswrapped(o: object) -> bool:
    'o' was created using wrap / freeze / private / protect
    '''
    return isinstance(o, Wrapped)


def isfrozen(o: object) -> bool:
    '''
    isfrozen(o: object) -> bool: 'o' was created using freeze()
    '''
    return isinstance(o, (
        Frozen, FrozenPrivate, FrozenPrivacyDict, FrozenProtected,
    ))


def isprivate(o: object) -> bool:
    '''
    isprivate(o: object) -> bool: 'o' was created using private()
    '''
    return isinstance(o, (
        Private,
        FrozenPrivate,
    ))


def isprotected(o: object) -> bool:
    '''
    isprotected(o: object) -> bool: 'o' was created using protect()
    '''
    return isinstance(o, (
        Protected,
        FrozenProtected,
    ))


def isreadonly(o: object, a: str) -> bool:
    '''
    isreadonly(o: object, a: str) -> bool:
    Returns-->bool: True IFF 'o' is wrapped AND 'o' makes arribute 'a'
        read-only if present in wrapped object
    This represents RULE of wrapped object - does not guarantee
    that WRAPPED OBJECT has attribute 'a' or that setting attribute
    'a' in object 'o' will not raise any exception
    '''
    try:
        if isimmutable(o):
            return True
    except:
        pass
    if isprivate(o) or isprotected(o):
        return not getattr(o, PROT_ATTR_NAME).testop(a, 'w')
    else:
        return False


def isvisible(o: object, a: str) -> bool:
    '''
    isvisible(o: object, a: str) -> bool:
    Returns-->bool: False IFF 'o' is wrapped AND 'o' makes arribute 'a'
        invisible if present in wrapped object
    This represents RULE of wrapped object - does not guarantee
    that WRAPPED OBJECT has attribute 'a' or that accessing attribute
    'a' in object 'o' will not raise any exception

    If 'o' is not a wrapped object, unconditionally returns False
    '''
    if not iswrapped(o):
        return False
    return getattr(o, PROT_ATTR_NAME).testop(a, 'r')


# ------------------------------------------------------------------------
# Methods to created Wrapped objects
# ------------------------------------------------------------------------


def wrap(o: object) -> object:
    '''
    wrap(o: object) -> object:
    Returns: instance of Wrapped

    Wrapped:
        - Should behave just like the wrapped object, except
          following attributes cannot be modified:
            'getattr, __getattribute__',
            '__delattr__', '__setattr__', '__slots__',
        - Explicitly does NOT support pickling, and will raise
          ProtectionError
        - Does NOT protect CLASS of wrapped object from modification
        - Does NOT protect __dict__ or __slots__

    Useful for testing if wrapping is failing for a particular type of object
    '''
    if iswrapped(o):
        # Do not wrap twice
        return o
    return Wrapped(o, frozen=False)


def freeze(o: object) -> object:
    '''
    freeze(o: object) -> object:
    Returns: Instance of Frozen | FrozenPrivacyDict | FrozenPrivate |
        FrozenProtected, depending on what 'o' is

    Object returned prevents modification of ANY attribute
    '''
    if isfrozen(o):
        # Never freeze twice
        return o
    elif isimmutable(o):
        # Object is KNOWN to be immutable - return as-is
        return o
    # Must freeze

    # If Wrapped, avoid double wrapping
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).freeze()
    return Frozen(o)


def private(o: object, frozen: bool = False) -> object:
    '''
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

    '''
    # Avoid double-wrapping
    if frozen or isfrozen(o):
        frozen = True
    if iswrapped(o):
        if isprotected(o):
            return protect(o, frozen=True)
        return getattr(o, PROT_ATTR_NAME).private()
    else:
        if frozen:
            return FrozenPrivate(o)
        else:
            return Private(o)


def protect(
    o: object,
    frozen: bool = False, dynamic: bool = True,
    hide_private: bool = False,
    ro_data: bool = False, ro_method: bool = True,
    ro=[], rw=[], hide=[],
):
    '''
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
    '''
    kwargs = {
        'frozen': frozen,
        'hide_private': hide_private,
        'ro_data': ro_data,
        'ro_method': ro_method,
        'ro': ro,
        'rw': rw,
        'hide': hide,
        'dynamic': dynamic,
    }

    # Avoid double-wrapping
    if isprotected(o):
        kw1 = getattr(o, PROT_ATTR_NAME).rules.get('kwargs', {})
        d = {}
        for (k, v) in kw1.items():
            d[k] = v
        kw1 = d
        kw2 = dict(kwargs)
        kwargs = protected_merge_kwargs(kw1, kw2)
        assert(isinstance(kwargs, dict))
    rules = dict(protected_rules_from_kwargs(kwargs))
    assert(isinstance(rules, dict))
    want_frozen = bool(rules.get('frozen', False)) or isfrozen(o)
    if want_frozen and not isfrozen(o):
        # Frozen objects remain frozen
        rules['frozen'] = True
    if iswrapped(o):
        return getattr(o, PROT_ATTR_NAME).protect(rules)
    else:
        if want_frozen:
            return FrozenProtected(o, rules)
        else:
            return Protected(o, rules)


# ------------------------------------------------------------------------
# Other python-accesssible attributes
# ------------------------------------------------------------------------

def never_writeable():
    '''
    never_writeable() -> set(str): Attributes that are never writeable
    in object 'o' if iswrapped(o)
    '''
    return overridden_always

def never_writeable_private():
    '''
    never_writeable_private() -> set(str): Attributes that are never
    writeable in object 'o' if isprivate(o)
    '''
    return frozenset(set().union(
        overridden_always,
        always_frozen
    ))

def hidden_pickle_attributes():
    '''
    hidden_pickle_attributes() -> set(str): Attributes that are never
    visible in object 'o' if iswrapped(o) - to disallow pickling
    '''
    return pickle_attributes

def always_delegated_attributes():
    '''
    always_delegated_attributes() -> set(str): Attributes that are
    always delegated to wrapped object
    '''
    return always_delegated

def immutable_builtin_attributes():
    '''
    immutable_builtin_attributes() -> frozenset(str)
    Returns: attributes in builtins that are immutable
    '''
    return builtin_module_immutable_attributes

__all__ = [
    'contains', 'freeze', 'id_protected', 'immutable_builtin_attributes',
    'isfrozen', 'isimmutable', 'isinstance_protected', 'isprivate',
    'isprotected', 'isreadonly', 'iswrapped', 'private', 'protect', 'wrap',
    'help_protected', 'attribute_protected', 'isvisible',
    '__file__', 'never_writeable', 'never_writeable_private',
    'hidden_pickle_attributes', 'always_delegated_attributes',
    'ProtectionError', 'issubclass_protected',
    'instance_of_protected', 'subclass_of_protected', 'same_class_protected',
    # 'Wrapped', 'Private', 'Protected', 'PrivacyDict',
    # 'Frozen', 'FrozenPrivate', 'FrozenProtected', 'FrozenPrivacyDict',
]


def __dir__():
    return __all__

class ProtectionError(Exception):
    pass

# ------------------------------------------------------------------------
# End of python-accesssible methods
# ------------------------------------------------------------------------

