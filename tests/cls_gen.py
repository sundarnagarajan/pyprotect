'''
Utilities to generate test classes
'''

import sys
sys.dont_write_bytecode = True
if sys.version_info.major == 2:
    from random import sample as choices
else:
    from random import choices
import string
from obj_utils import minimal_attributes
from obj_utils import nested_obj   # noqa: F401

LEN_RANDOM_ATTR_PART = 6
SRC_RANDOM_ATTR_PART = string.ascii_uppercase + string.ascii_lowercase


def gen_random(n=LEN_RANDOM_ATTR_PART):
    '''Generator'''
    s = set()
    while True:
        x = ''.join(choices(SRC_RANDOM_ATTR_PART, k=n))
        if x in s:
            continue
        yield x


def generate(
    mult=1, obj_derived=True,
    nested=False, depth=100, no_cycles=True,
):
    '''
    mult: int = 1: Basic 48 attributes will be multiplied by mult
    obj_derived: bool = True: Whether class is derived from object
    nested: bool = False: Whether a deeply nested object is added
    depth: int = 100: Depth of nested object if nested is True
    no_cycles: bool = True: If True, nested obj has no cycles

    Returns--> dict:
        class->ytpe: class object
        props-->dict: various properties
        src-->str: source of class
    '''
    mult = max(1, int(1))
    obj_derived = bool(obj_derived)
    nested = bool(nested)
    n = 1
    n = n * mult
    GEN = gen_random()

    # Need to use tot within local wrapped functions, but PY2 doesn't have
    # nonlocal keyword
    class TOT:
        tot = 0

    d = {
        'tot': 0,
        'minimal_attributes': minimal_attributes(obj_derived=obj_derived),
        'ro_attr': set(),
        'pvt_attr': set(),
        'props_ro': set(),
        'props_rw': set(),
        'normal_class_methods': set(),
        'normal_static_methods': set(),
        'normal_inst_methods': set(),
        'dunder_class_methods': set(),
        'dunder_static_methods': set(),
        'dunder_inst_methods': set(),
        'normal_attr': set(),
        'dunder_attr': set(),

        'normal_static_methods_ro': set(),
        'normal_inst_methods_ro': set(),
        'dunder_static_methods_ro': set(),
        'dunder_inst_methods_ro': set(),
        'normal_attr_ro': set(),
        'dunder_attr_ro': set(),

        'normal_static_methods_rw': set(),
        'normal_inst_methods_rw': set(),
        'dunder_static_methods_rw': set(),
        'dunder_inst_methods_rw': set(),
        'normal_attr_rw': set(),
        'dunder_attr_rw': set(),

        'normal_static_methods_rw_over': set(),
        'normal_inst_methods_rw_over': set(),
        'dunder_static_methods_rw_over': set(),
        'dunder_inst_methods_rw_over': set(),
        'normal_attr_rw_over': set(),
        'dunder_attr_rw_over': set(),

        'normal_static_methods_hide': set(),
        'normal_inst_methods_hide': set(),
        'dunder_static_methods_hide': set(),
        'dunder_inst_methods_hide': set(),
        'normal_attr_hide': set(),
        'dunder_attr_hide': set(),

        'normal_static_methods_show': set(),
        'normal_inst_methods_show': set(),
        'dunder_static_methods_show': set(),
        'dunder_inst_methods_show': set(),
        'normal_attr_show': set(),
        'dunder_attr_show': set(),

        'normal_static_methods_show_over': set(),
        'normal_inst_methods_show_over': set(),
        'dunder_static_methods_show_over': set(),
        'dunder_inst_methods_show_over': set(),
        'normal_attr_show_over': set(),
        'dunder_attr_show_over': set(),

        'nested': set(),
        'missing': set()
    }

    class_source = ''
    if nested:
        class_source += 'from obj_utils import nested_obj\n\n'

    if obj_derived:
        class_source += '''
class MyClass(object):
'''
    else:
        class_source = '''
class MyClass:
'''

    def src_ro_attr(x):
        return "        self.%s = '%s'\n" % (x, x)

    def src_pvt_attr(x):
        return "        self.%s = '%s'\n" % (x, x)

    def src_ro_prop(x):
        return (
            "\n    @property\n"
            "    def %s(self):\n"
            "        return '%s'\n"
        ) % (x, x)

    def src_rw_prop(x):
        return (
            '\n'
            "    @property\n"
            "    def %s(self):\n"
            "        return '%s'\n"
            '\n'
            "    @%s.setter\n"
            "    def %s(self, val):\n"
            "        pass\n"
        ) % (x, x, x, x)

    def src_class_m(x):
        return (
            '\n'
            '    @classmethod\n'
            '    def %s(self):\n'
            '        return "%s"\n'
        ) % (x, x)

    def src_static_m(x):
        return (
            '\n'
            '    @staticmethod\n'
            '    def %s():\n'
            '        return "%s"\n'
        ) % (x, x)

    def src_inst_m(x):
        return (
            '\n'
            '    def %s(self):\n'
            '        return "%s"\n'
        ) % (x, x)

    def src_attr(x):
        return (
            '\n'
            '    %s = "%s"\n'
        ) % (x, x)

    def add(a_rnd, fn, prefix, group, dunder=False):
        TOT.tot += 1
        if dunder:
            a = '__' + prefix + a_rnd + '__'
        else:
            a = prefix + a_rnd
        d[group].add(a)
        return fn(a)

    class_source += '\n    def __init__(self):\n'

    for rnd_a in [next(GEN) for i in range(n)]:
        # single_ Class / instance attributes
        class_source += add(rnd_a, src_ro_attr, '_ro_', 'ro_attr')

        # double_ Class / instance attributes
        class_source += add(rnd_a, src_pvt_attr, '__pvt_', 'pvt_attr')

        # Read-only properties
        class_source += add(rnd_a, src_ro_prop, 'prop_ro_', 'props_ro')

        # Read-write properties. We don't really set anything
        class_source += add(rnd_a, src_rw_prop, 'prop_rw_', 'props_rw')

        # Normal class methods
        class_source += add(
            rnd_a, src_class_m, 'class_', 'normal_class_methods'
        )

        # Normal static methods
        class_source += add(
            rnd_a, src_static_m, 'static_', 'normal_static_methods'
        )

        # Normal static methods that can be added to 'ro'
        class_source += add(
            rnd_a, src_static_m, 'static_ro_', 'normal_static_methods_ro'
        )

        # Normal static methods that can be added to 'rw'
        class_source += add(
            rnd_a, src_static_m, 'static_rw_', 'normal_static_methods_rw'
        )

        # Normal static methods that can be added to 'rw' AND 'ro'
        class_source += add(
            rnd_a, src_static_m,
            'static_rw_over_', 'normal_static_methods_rw_over'
        )

        # Normal static methods that can be added to 'hide'
        class_source += add(
            rnd_a, src_static_m,
            'static_hide_', 'normal_static_methods_hide'
        )

        # Normal static methods that can be added to 'show'
        class_source += add(
            rnd_a, src_static_m,
            'static_show_', 'normal_static_methods_show'
        )

        # Normal static methods that can be added to 'show' AND 'hide'
        class_source += add(
            rnd_a, src_static_m,
            'static_show_over_', 'normal_static_methods_show_over'
        )

        # Normal instance methods
        class_source += add(
            rnd_a, src_inst_m, 'inst_', 'normal_inst_methods'
        )

        # Normal instance methods that can be added to 'ro'
        class_source += add(
            rnd_a, src_inst_m, 'inst_ro_', 'normal_inst_methods_ro'
        )

        # Normal instance methods that can be added to 'rw'
        class_source += add(
            rnd_a, src_inst_m, 'inst_rw_', 'normal_inst_methods_rw'
        )

        # Normal instance methods that can be added to 'rw' AND 'ro'
        class_source += add(
            rnd_a, src_inst_m, 'inst_rw_over_', 'normal_inst_methods_rw_over'
        )

        # Normal instance methods that can be added to 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_hide_', 'normal_inst_methods_hide'
        )

        # Normal instance methods that can be added to 'show'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_show_', 'normal_inst_methods_hide'
        )

        # Normal instance methods that can be added to 'show' AND 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_show_over_', 'normal_inst_methods_show_over'
        )

        # dunder class methods
        class_source += add(
            rnd_a, src_class_m, 'class_dunder_', 'dunder_class_methods',
            dunder=True
        )

        # dunder static methods
        class_source += add(
            rnd_a, src_static_m, 'static_dunder_', 'dunder_static_methods',
            dunder=True
        )

        # dunder static methods that can be added to 'ro'
        class_source += add(
            rnd_a, src_static_m,
            'static_dunder_ro_', 'dunder_static_methods_ro',
            dunder=True
        )

        # dunder static methods that can be added to 'rw'
        class_source += add(
            rnd_a, src_static_m,
            'static_dunder_rw_', 'dunder_static_methods_rw',
            dunder=True
        )

        # dunder static methods that can be added to 'rw' AND 'ro'
        class_source += add(
            rnd_a, src_static_m,
            'static_dunder_rw_over_', 'dunder_static_methods_rw_over',
            dunder=True
        )

        # dunder static methods that can be added to 'hide'
        class_source += add(
            rnd_a, src_static_m,
            'static_dunder_hide_', 'dunder_static_methods_hide',
            dunder=True
        )

        # dunder static methods that can be added to 'show'
        class_source += add(
            rnd_a, src_static_m,
            'static_dunder_show_', 'dunder_static_methods_show',
            dunder=True
        )

        # dunder static methods that can be added to 'show' AND 'hide'
        class_source += add(
            rnd_a, src_static_m,
            'static_dunder_show_over_', 'dunder_static_methods_show_over',
            dunder=True
        )

        # dunder instance methods
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_', 'dunder_inst_methods',
            dunder=True,
        )
        # dunder instance methods that can be added to 'ro'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_ro_', 'dunder_inst_methods_ro',
            dunder=True,
        )
        # dunder instance methods that can be added to 'rw'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_rw_', 'dunder_inst_methods_rw',
            dunder=True,
        )
        # dunder instance methods that can be added to 'rw' AND 'ro'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_rw_over_', 'dunder_inst_methods_rw_over',
            dunder=True,
        )
        # dunder instance methods that can be added to 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_hide_', 'dunder_inst_methods_hide',
            dunder=True,
        )
        # dunder instance methods that can be added to 'show'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_show_', 'dunder_inst_methods_show',
            dunder=True,
        )
        # dunder instance methods that can be added to 'show' AND 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_show_over_', 'dunder_inst_methods_show_over',
            dunder=True,
        )

        # Normal instance attr
        class_source += add(
            rnd_a, src_inst_m, 'inst_attr_', 'normal_attr'
        )

        # Normal instance attr that can be added to 'ro'
        class_source += add(
            rnd_a, src_inst_m, 'inst_attr_ro_', 'normal_attr_ro'
        )

        # Normal instance attr that can be added to 'rw'
        class_source += add(
            rnd_a, src_inst_m, 'inst_attr_rw_', 'normal_attr_rw'
        )

        # Normal instance attr that can be added to 'rw' AND 'ro'
        class_source += add(
            rnd_a, src_inst_m, 'inst_attr_rw_over_', 'normal_attr_rw_over'
        )

        # Normal instance attr that can be added to 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_attr_hide_', 'normal_attr_hide'
        )

        # Normal instance attr that can be added to 'show'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_attr_show_', 'normal_attr_hide'
        )

        # Normal instance attr that can be added to 'show' AND 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_attr_show_over_', 'normal_attr_show_over'
        )

        # dunder instance attr
        class_source += add(
            rnd_a, src_inst_m, 'inst_dunder_attr_', 'dunder_attr',
            dunder=True,
        )

        # dunder instance attr that can be added to 'ro'
        class_source += add(
            rnd_a, src_inst_m, 'inst_dunder_attr_ro_', 'dunder_attr_ro',
            dunder=True,
        )

        # dunder instance attr that can be added to 'rw'
        class_source += add(
            rnd_a, src_inst_m, 'inst_dunder_attr_rw_', 'dunder_attr_rw',
            dunder=True,
        )

        # dunder instance attr that can be added to 'rw' AND 'ro'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_attr_rw_over_', 'dunder_attr_rw_over',
            dunder=True,
        )

        # dunder instance attr that can be added to 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_attr_hide_', 'dunder_attr_hide',
            dunder=True,
        )

        # dunder instance attr that can be added to 'show'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_attr_show_', 'dunder_attr_hide',
            dunder=True,
        )

        # dunder instance attr that can be added to 'show' AND 'hide'
        class_source += add(
            rnd_a, src_inst_m,
            'inst_dunder_attr_show_over_', 'dunder_attr_show_over',
            dunder=True,
        )

    if nested:
        rnd_a = next(GEN)
        a = 'nested_' + rnd_a
        depth = max(100, int(depth))
        no_cycles = bool(no_cycles)
        class_source += '''\n
    %s = nested_obj(depth=%d, no_cycles=%s)
''' % (a, depth, no_cycles)
        d['nested'].add(a)

    for rnd_a in [next(GEN) for i in range(n)]:
        d['missing'] = rnd_a

    local_d = {}
    exec(class_source, None, local_d)
    MyClass = local_d['MyClass']

    d['tot'] = TOT.tot
    ret = {
        'class': MyClass,
        'props': d,
        'src': class_source,
    }
    return ret

