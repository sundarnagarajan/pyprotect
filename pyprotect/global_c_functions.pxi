
cdef get_protected_attr_name():
    '''Returns: str'''
    # The ONLY place where the name of the special attribute is set
    cdef str LOCAL_PROT_ATTR_NAME = '_Protected_____'
    cdef str ENV_VAR = LOCAL_PROT_ATTR_NAME
    cdef str PROT_ATTR_SHORTEST_SUFFIX = '_____'
    # Can override by setting env var '_Protected_____'
    # Value of env var '_Protected_____' will be fixed to have EXACTLY
    # ONE leading underscore and AT LEAST 5 trailing underscores
    x = os.environ.get(ENV_VAR, None)
    if x is not None:
        if x.startswith('_'):
            x = x.lstrip('_') + '_'
        if not x.endswith(PROT_ATTR_SHORTEST_SUFFIX):
            x = x.rstrip('_') + PROT_ATTR_SHORTEST_SUFFIX
        return x
    return LOCAL_PROT_ATTR_NAME

cdef get_builtin_obj(s):
    '''
    s-->str: attribute name in builtin_module
    Returns-->object
    '''
    return getattr(builtin_module, s)

cdef get_immutables():
    '''
    Returns: tuple of frozenset:
        immutable_types_set: frozenset(type)
        builtin_module_immutable_attributes : frozenset(str)
        builtins_ids: frozenset(int)
    '''
    cdef list builtin_names
    cdef list basic_data_names
    cdef list basic_mutable_data_names
    cdef list basic_immutable_data_names
    cdef list basic_data_types
    cdef list basic_mutable_data_types
    cdef list basic_immutable_data_types
    cdef list mapping_types
    cdef list list_types
    cdef list tuple_types
    cdef list set_types
    cdef list sequence_types
    cdef list mutable_mapping_types
    cdef list mutable_sequence_types
    cdef list mutable_set_types
    cdef list immutable_mapping_types
    cdef list immutable_sequence_ytpes
    cdef list immutable_set_types
    cdef list immutable_types

    cdef frozenset ret_immutable_types_set
    cdef frozenset ret_builtins_ids
    cdef frozenset ret_builtin_module_immutable_attributes


    builtin_names = dir(builtin_module)

    basic_data_names = [
        'bool', 'bytearray', 'bytes', 'complex',
        'dict', 'float', 'frozenset', 'int', 'list', 'object', 'set', 'str',
        'tuple', 'basestring', 'unichr', 'unicode', 'long'
    ]
    basic_mutable_data_names = ['bytearray', 'dict', 'list']
    basic_immutable_data_names = [
        'bool', 'bytes', 'complex', 'float',
        'frozenset', 'int', 'str', 'tuple', 'basestring', 'unichr',
        'unicode', 'long'
    ]

    basic_data_names = [x for x in basic_data_names if x in builtin_names]

    basic_mutable_data_names = [
        x for x in basic_mutable_data_names if
        x in builtin_names
    ]
    basic_immutable_data_names = [
        x for x in basic_immutable_data_names if
        x in builtin_names
    ]

    basic_data_types = [get_builtin_obj(x) for x in basic_data_names]
    basic_mutable_data_types = [
        get_builtin_obj(x) for x in basic_mutable_data_names
    ]
    basic_immutable_data_types = [
        get_builtin_obj(x) for x in basic_immutable_data_names
    ]

    mapping_types = [dict, CollectionsABC.MutableMapping, CollectionsABC.Mapping]
    list_types = [list, CollectionsABC.MutableSequence]
    tuple_types = [tuple, CollectionsABC.Sequence]
    set_types = [set, CollectionsABC.Set, CollectionsABC.MutableSet]

    sequence_types = tuple_types + list_types

    mutable_sequence_types = list_types
    mutable_mapping_types = [dict, CollectionsABC.MutableMapping]
    mutable_set_types = [set, CollectionsABC.MutableSet]


    immutable_mapping_types = [
        x for x in mapping_types if
        x not in mutable_mapping_types
    ]
    immutable_sequence_ytpes = [
        x for x in sequence_types if
        x not in mutable_sequence_types
    ]
    immutable_set_types = [x for x in set_types if x not in mutable_set_types]

    immutable_types = list(set(
        basic_immutable_data_types +
        immutable_mapping_types +
        immutable_sequence_ytpes +
        immutable_set_types
    ))
    immutable_types = [x for x in immutable_types if isinstance(x, type)]

    # Since builtin_module is by default writeable in Python and attributes
    # in builtin_module can be overwritten, we only track attributes
    # that do not allow __class__ attribute to be overwritten (crude test)
    s = set()
    test_attr_name = '__class__'
    for a in builtin_names:
        try:
            x = getattr(builtin_module, a)
            try:
                setattr(x, test_attr_name, getattr(x, test_attr_name))
                continue
            except:
                s.add(a)
        except:
            continue

    ret_immutable_types_set = frozenset(immutable_types)
    ret_builtin_module_immutable_attributes = frozenset(s)
    ret_builtins_ids = frozenset([
        id(getattr(builtin_module, a)) for a in builtin_names
        if a in ret_builtin_module_immutable_attributes
    ])

    return (
        ret_immutable_types_set,
        ret_builtin_module_immutable_attributes,
        ret_builtins_ids,
    )
# ------------------------------------------------------------------------


cdef protected_rules_from_kwargs(kwargs):
    '''
    kwargs-->dict
    Returns-->dict
    Called once by protect() before Protected class initialization
    '''
    def _build_regex(alist):
        _ret = ''
        _rl = []
        if not alist:
            return re.compile(_ret)
        for _x in alist:
            if not isinstance(_x, str):
                continue
            if attr_identifier.match(_x):
                _rl += ['^%s$' % (_x,)]
        for _x in _rl:
            if _ret:
                _ret = _ret + '|' + _x
            else:
                _ret = _x
        return re.compile(_ret)

    ro_method = bool(kwargs.get('ro_method', False))
    ro_data = bool(kwargs.get('ro_data', False))
    hide_private = kwargs.get('hide_private', False)

    ro = [
        x for x in list(kwargs.get('ro', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]
    rw = [
        x for x in list(kwargs.get('rw', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]
    hide = [
        x for x in list(kwargs.get('hide', []))
        if isinstance(x, str) and attr_identifier.match(x)
    ]
    ro = frozenset(ro)
    rw = frozenset(rw)
    hide = frozenset(hide)

    # Build regexes
    hide_regex = _build_regex(hide)
    ro_regex = _build_regex(ro)
    rw_regex = _build_regex(rw)

    d = {
        'hide_private': hide_private,
        'hide_regex': hide_regex,
        'ro_regex': ro_regex,
        'rw_regex': rw_regex,
        'ro_method': bool(ro_method),
        'ro_data': bool(ro_data),
    }
    d['dynamic'] = kwargs.get('dynamic', False)
    d['frozen'] = bool(kwargs.get('frozen', False))
    d['kwargs'] = kwargs

    d['attr_type_check'] = False
    for kw in ('ro_method', 'ro_data'):
        if bool(d.get(kw, False)):
            d['attr_type_check'] = True

    return d

cdef protected_merge_kwargs(kw1: dict, kw2: dict):
    '''
    Merges kw1 and kw2 to return dict with most restrictive options
    kw1, kw2: dict
    Returns: dict
    Called once by protect() before Protected class initialization
    '''
    (kw1, kw2) = (dict(kw1), dict(kw2))
    d = {}
    # Permissive bool options - must be 'and-ed'
    # dynamic defaults to True while add defaults to False
    a = 'dynamic'
    d[a] = (kw1.get(a, True) and kw2.get(a, True))

    # Restrictive bool options must be 'or-ed'
    for a in (
        'frozen', 'hide_private', 'ro_data', 'ro_method',
    ):
        d[a] = (kw1.get(a, False) or kw2.get(a, False))

    # Restrictive lists (non-bool) are unioned
    for a in (
        'ro', 'hide',
    ):
        s1 = set(list(kw1.get(a, [])))
        s2 = set(list(kw2.get(a, [])))
        d[a] = list(
            s1.union(s2)
        )
    # Permissive lists (non-bool) are intersected
    for a in (
        'rw',
    ):
        s1 = set(list(kw1.get(a, [])))
        s2 = set(list(kw2.get(a, [])))
        d[a] = list(
            s1.intersection(s2)
        )
    return d


cdef privatedict(o, cn, frozen=False, oldstyle_class=None):
    '''
    o-->Mapping (to be wrapped)
    Returns-->FrozenPrivacyDict if frozen; Privacybject otherwise
    '''
    if frozen:
        if isinstance (o, FrozenPrivacyDict):
            return o
        return FrozenPrivacyDict(o, cn, oldstyle_class)
    else:
        if isinstance (o, FrozenPrivacyDict):
            # Underlying already frozen
            return o
        elif isinstance(o, PrivacyDict):
            return o
        return PrivacyDict(o, cn, oldstyle_class)


