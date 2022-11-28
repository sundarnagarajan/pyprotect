'''
Utilities used in unit tests that need protected_class
'''

import sys
sys.dont_write_bytecode = True
import re
from obj_utils import writeable_in_python
from protected_wrapper import protected
from protected import attribute_protected


PROT_ATTR = attribute_protected()
overridden_always = set((
    '__getattribute__', '__setattr__', '__delattr__',
    '__reduce__', '__reduce_ex__',
))
special_attributes = set((
    PROT_ATTR,
))


def identical_in_both(a, o1, o2):
    '''
    a-->str: attribute name
    o1, o2-->object
    Returns-->bool
    '''
    try:
        a1 = getattr(o1, a)
        a2 = getattr(o2, a)
        return protected.id_protected(a1) == protected.id_protected(a2)
    except:
        return False


def compare_readable_attrs(o1, o2, flexible=True):
    '''
    Returns-->(
        list of str-->attributes only in o1,
        list of str-->attributes only in o2,
    ASSUMES visible_is_readable(o1) and visible_is_readable(o2)
    '''
    def get_dir(o):
        ret = set()
        for a in dir(o):
            if a in overridden_always:
                continue
            if protected.iswrapped(o) and a in special_attributes:
                continue
            ret.add(a)
        return ret

    h1_regex = re.compile('^_%s__.*?(?<!__)$' % (o1.__class__.__name__))
    h2_regex = re.compile('^_%s__.*?(?<!__)$' % (o2.__class__.__name__))

    s1 = get_dir(o1)
    s2 = get_dir(o2)

    only_in_1 = []
    only_in_2 = []

    for a in s1:
        if flexible and (not protected.isprivate(o1)) and h1_regex.match(a):
            continue
        if a not in s2:
            only_in_1.append(a)
    for a in s2:
        if flexible and (not protected.isprivate(o2)) and h2_regex.match(a):
            continue
        if a not in s1:
            only_in_2.append(a)
    return (only_in_1, only_in_2)


def writeable_attrs(o):
    '''
    Returns-->list of str: attribute names that could be written
    If o is NOT wrapped, we use immutable()
    '''
    ret = []
    if not protected.iswrapped(o):
        if protected.isimmutable(o):
            return ret
    for a in dir(o):
        # Some properties are not writeable due to python protection
        if not writeable_in_python(o, a):
            continue
        old_val = getattr(o, a)
        try:
            setattr(o, a, old_val)
            ret.append(a)
        except:
            continue
    return ret


def compare_writeable_attrs(o1, o2):
    '''
    Returns-->(
        list of str-->attributes writeable only in o1,
        list of str-->attributes writeable only in o2,

        if o1 or o2 is wrapped, filters out special_attributes
        that are NEVER writeable
    '''
    w1 = writeable_attrs(o1)
    w2 = writeable_attrs(o2)

    only_in_1 = [x for x in w1 if x not in w2]
    only_in_2 = [x for x in w2 if x not in w1]
    return (only_in_1, only_in_2)


