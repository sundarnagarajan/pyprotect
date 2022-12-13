
import re
from cls_gen import generate


def gen_test_objects():
    '''generator'''
    # In PY2 this is an 'old-style' class without a '__class__' attribute
    # Attributes '_ShouldBeVisible__abc' and '_ShouldBeVisible__def_'
    # will be hidden when this CLASS is wrapped in Private/Protected
    # (not when an INSTANCE of the class is wrapped) even though
    # these attributes should NOT be hidden as per normal Python rules.
    #
    # In PY3, this class behaves as usual when wrapped
    class OldStyleClassInPY2:
        __pvt = 1
        _ShouldBeVisible__abc = 2
        _ShouldBeVisible__def_ = 3
        _ro = 4
        a = 5

    # In PY2, this is a 'new style class', and will behave just like
    # classes in PY3 when wrapped
    class NewStyleClassInPY2(object):
        __pvt = 1
        _ShouldBeVisible__abc = 2
        _ShouldBeVisible__def_ = 3
        _ro = 4
        a = 5

    class CI(int):
        pass

    class CF(float):
        pass

    cls_obj = generate(obj_derived=True)['class']
    cls_obj_nested = generate(
        obj_derived=True,
        nested=True, depth=1000, no_cycles=False,
    )['class']
    cls_nonobj = generate(obj_derived=False)['class']
    cls_nonobj_nested = generate(
        obj_derived=False,
        nested=True, depth=1000, no_cycles=False,
    )['class']

    l = [
        1, [1, 2, 3], {'a': 1, 'b': 2},
        OldStyleClassInPY2, OldStyleClassInPY2(),
        NewStyleClassInPY2, NewStyleClassInPY2(),
        CI, CF,
        CI(10), CF(101.89),
        cls_obj,
        cls_nonobj,
        cls_obj_nested,
        cls_nonobj_nested,
        cls_obj(),
        cls_nonobj(),
        cls_obj_nested(),
        cls_nonobj_nested(),
        re,
    ]
    for o in l:
        yield o
