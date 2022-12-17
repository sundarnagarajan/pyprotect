'''
Module for testing pyprotect

wrap: Like other Wrapped objects
    As close as possible o using the unwrapped module

freeze: Like other Frozen objects
    No restriction on VISIBILITY - like wrap.
        Even attributes not in dir(mod) can be accessed
        using getattr(mod, a) or mod.a if you know the
        attribute name.
    BUT Objects returned by callable objects in module are
    NOT frozen - the actual objects are returned unwrapped
    This is UNLIKE FrozenProtected for modules

private: Like other Private objects:
    - Private mangled attribute hidden
    - Private single '_' attributes read-only
    - Only attributes in dir(mod) are visible
    - In PY2, only attributes returned by __dir__() are visible
    - If frozen, behaves like other frozen objects, EXCEPT:
        Objects returned by callable objects in module are
        NOT frozen - the actual objects are returned unwrapped
        This is UNLIKE FrozenProtected for modules

protect: Like other Protected objects:
    - Inherits Private behavior
    - If frozen, behaves like EXACTLY like other frozen
      objecs, with no difference for module objects
      This is UNLIKE FrozenPrivate or Frozen for modules
'''

# Not visible if wrapped by Private
__module_private_invisible = 1
# Read-only if wrapped by Private
_module_ro = 2
module_attr = 3
# Not visible if wrapped in Private
module_attr_not_in_dir = 4


class C(object):
    # Not visible if wrapped in Private
    __clspvt = 1
    # Read-only if wrapped by Private
    _clsro = 2
    b = 3

    def instfn(self):
        def inner1():
            def inner2():
                return C

            return inner2

        return inner1

    @classmethod
    def clsfn(cls):
        def inner1():
            def inner2():
                return C

            return inner2

        return inner1

    def __init__(self):
        # Not visible if wrapped in Private
        self.__pvt = 1
        # Read-only if wrapped by Private
        self._ro = 2
        self.a = 3


def module_meth_return_cls():
    return C


def module_meth_return_cls_meth():
    return C.clsfn


def module_meth_return_inst_meth():
    o = C()
    return o.instfn


# Not visible if wrapped in Private
def meth_not_in_dir():
    return True


def __dir__():
    return [
        '_module_ro',
        'module_attr',
        # 'module_attr_not_in_dir',
        'C',
        'module_meth_return_cls',
        'module_meth_return_cls_meth',
        'module_meth_return_inst_meth',
        # 'module_meth_not_in_dir',
        # __dict__ added in __dir__ for unit test
        '__dict__',
    ]
