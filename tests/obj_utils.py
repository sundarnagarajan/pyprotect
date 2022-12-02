'''
GENERIC utils for objects that do NOT use pyprotect
'''

import sys
sys.dont_write_bytecode = True
import re


def nested_obj(
    depth, no_cycles=False, json_compatible=False, custom_obj=True
):
    '''
    depth-->int
    no_cycles-->bool
    json_compatible--:bool: If True, convert sets to lists, tuples to lists
    custom_obj-->bool: If True, adds custom objects
    Generates a deeply nested object with depth 'depth'
    '''
    width = 5
    if json_compatible:
        custom_obj = False
        no_cycles = True

    class CustomObj(object):
        pass

    class MyList(list):
        pass

    class MyTuple(tuple):
        pass

    class MyDict(dict):
        pass

    class MySet(set):
        pass

    def gen_dict():
        d = dict.fromkeys([
            'dict', 'list', 'tuple', 'set', 'cycle'
        ])
        if custom_obj:
            d['obj'] = None
        return d

    obj = gen_dict()
    top_obj = obj
    for x in range(depth):
        obj['dict'] = gen_dict()
        obj['list'] = [a for a in range(width)]
        if json_compatible:
            obj['tuple'] = list(tuple([a for a in range(width)]))
            obj['set'] = list(set([a for a in range(width)]))
        else:
            obj['tuple'] = tuple([a for a in range(width)])
            obj['set'] = set([a for a in range(width)])
        if not no_cycles:
            obj['cycle'] = top_obj
        if custom_obj:
            obj['obj'] = CustomObj()
            obj['mylist'] = MyList([a for a in range(width)])
            obj['mytuple'] = MyTuple([a for a in range(width)])
            obj['mydict'] = MyDict(obj['dict'])
            if not json_compatible:
                obj['myset'] = MySet([a for a in range(width)])
        obj = obj['dict']
    return top_obj


def minimal_attributes(obj_derived=True):
    '''
    obj_derived: bool: Whether object is derived from object
    Returns-->dict
    '''
    obj_derived = bool(obj_derived)
    d = {
        'all': set(),
        'methods': set(),
        'data': set(),
        'ro': set(),
    }

    class NotFromObj:
        pass

    class FromObj:
        pass

    if obj_derived:
        o = FromObj()
    else:
        o = NotFromObj()

    d['all'] = set(dir(o))
    d['methods'] = set([x for x in dir(o) if callable(x)])
    d['data'] = set([x for x in dir(o) if not callable(x)])
    for a in dir(o):
        try:
            setattr(o, a, getattr(o, a))
        except:
            d['ro'].add(a)

    return d


def obj_attr_props(o):
    '''
    o: object: Any object
    Returns: dict
        'ro'      : set: Read-only attributes
        'rw'      : set: Writeable attributes
        'methods' : set: All method attributes (callable)
        'attrs':  : set: All non-method attributes (not callable)
        'props'   : set: Attributes that are properties
        'all'     : set: All attributes (from dir)
    '''
    d = {
        'ro': set(),
        'rw': set(),
        'methods': set(),
        'attrs': set(),
        'all': set(),
    }
    for attr_name in dir(o):
        d['all'].add(attr_name)
        a = getattr(o, attr_name)
        if callable(a):
            d['methods'].add(attr_name)
        elif isinstance(a, property):
            d['props'].add(attr_name)
        else:
            d['attrs'].add(attr_name)
        try:
            setattr(o, attr_name, a)
            d['rw'].add(attr_name)
        except:
            d['ro'].add(attr_name)
    return d


def isproperty(o, a):
    '''Returns-->bool'''
    try:
        x = getattr(o.__class__, a)
        return isinstance(x, property)
    except:
        pass
    return False


def writeable_in_python(o, a):
    '''
    o-->object
    a-->str: attribute name
    Returns-->bool
    Some attributes are readonly in python
    '''
    if a == '__weakref__':
        return False
    if isproperty(o, a):
        return False
    return True


def dunder_vars(o):
    '''
    Returns-->set of str: dunder attribute names in o
    '''
    ret = set()
    for a in dir(o):
        if a.startswith('__') and a.endswith('__'):
            ret.add(a)
    return ret


def hidden_private_vars(o):
    '''
    Returns-->set of str: traditionally private mangled adttribute names
    '''
    ret = set()
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    for a in dir(o):
        if h1_regex.match(a):
            ret.add(a)
    return ret


def ro_private_vars(o):
    '''
    Returns-->set of str: attribute names of the form _var
    '''
    ret = set()
    # Regex for mangled private attributes
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    for a in dir(o):
        if h1_regex.match(a):
            # Do not match mangled private attributes
            continue
        if a.startswith('_') and not a.endswith('_'):
            ret.add(a)
    return ret


def method_vars(o):
    '''
    Returns-->set of str: attribute names of method attributes
    '''
    ret = set()
    # Regex for mangled private attributes
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    for a in dir(o):
        if h1_regex.match(a):
            # Do not match mangled private attributes
            continue
        if callable(getattr(o, a)):
            ret.add(a)
    return ret


def data_vars(o):
    '''
    Returns-->set of str: attribute names of data attributes
    '''
    # Regex for mangled private attributes
    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o.__class__.__name__))
    ret = set()
    for a in dir(o):
        if h1_regex.match(a):
            # Do not match mangled private attributes
            continue
        if callable(getattr(o, a)):
            continue
        ret.add(a)
    return ret


def visible_is_readable(o):
    # a in dir(o) ==> getattr(o, a) works without exception
    for a in dir(o):
        try:
            getattr(o, a)
        except:
            print('Attribute %s of object(%s) not readable' % (
                a, str(type(o)),
            ))
            return False
    return True
