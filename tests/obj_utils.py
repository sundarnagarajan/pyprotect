'''
GENERIC utils for objects that do NOT use pyprotect
'''

import sys
sys.dont_write_bytecode = True


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
