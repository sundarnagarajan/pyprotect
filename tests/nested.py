'''
Needs python boltons package:
Install with: 'pip install boltons'
Works in Python 2 | 3

Working with very deeply nested objects:
For depth > ~990, you can not call print() or repr() or compare them with
other objects - will exceed recursion limit !
Similarly, different forms of serialization also have deptgh limits that
trigger a recursion limit error.

    toml.dumps: Accepts arbitraily deep, provided no_cycles is True
    yaml.dump: Accepts depth up to ~325, provided no_cycles is True
    json.dumps: Accepts depth up to ~ 990
        - no_cycles is True AND
        json_compatible is True (sets converted to lists)
    pickle.dumps: Accepts depth upto ~495
        - no_cycles not required
        - json_compatible not required
    print / pprint / repr: Accepts depth up to ~ 990
        - no_cycles not required
        - json_compatible not required
    object comparison: Accepts depth upto ~990, provided no_cycles is True
        Could compare by first converting to str using toml.dumps()
        This will accept arbitrarily deep objects - see above
'''
from boltons.iterutils import remap


def depth(o):
    '''
    o-->object
    Returns-->int: depth
    Works (even) for deeply nested objects of arbitrary depth
    '''
    # Python3 has nonlocal keyword, but I use outer class to be
    # Py2 compatible. nonlocal in Py3 also can only refer to IMMEDIATE
    # outer scope
    class outer:
        pass

    outer.maxd = 0

    def _v(p, k, v):
        outer.maxd = max(outer.maxd, len(p))
        return (k, v)

    remap(o, visit=_v)
    return outer.maxd


def copy_nested(d):
    '''
    d-->dict: can have cycles and be DEEPLY nested
        Can contain custom objects too - provided boltons.iterutils.remap
        can handle those objects
    Returns-->dict: deep copy of d
        Custom classes derived from list, dict, tuple, set are copied
        Other custom objects are not copied - the copy references the SAME
        custom object
    '''
    return remap(d)
