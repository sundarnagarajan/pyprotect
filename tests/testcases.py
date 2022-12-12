
import re
from cls_gen import generate


def gen_test_objects():
    '''generator'''
    class C:
        pass

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
        C(),
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
