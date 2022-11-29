import sys
sys.dont_write_bytecode = True
import os
module_dir = os.path.dirname(__file__)
in_sys_path = (module_dir in sys.path)
try:
    import protected
except ImportError:
    # Installed with 'setup.py build_ext --inplace'
    if in_sys_path:
        raise
    sys.path.append(module_dir)
    import protected

# I have .flake8 in parent dir containing:
# [flake8]
# per-file-ignores =
#     __init__.py: F401

if sys.version_info.major > 2:
    # protected = protected.freeze(protected) doesn't make sense
    # Doing it will make protected.{wrap|private|protect} always return Frozen!
    # And following will fail, though it should work
    #
    #     from pyprotect import protected
    #     o = {'a': 1, 'b': 2}
    #     w = protected.{wrap|private|protect)(o)
    #     protected.id_protected(w) == id(o)
    #
    # To avoid this, USERS of the module will always need to do:
    #     from pyprotect import protected
    #     from protected import wrap, private, protect
    #     ... use wrap / private / protect
    #
    # With this style of importing, they will work. This is used in
    # unit tests, and all tests pass even with protected being frozen (in pY3)
    #
    # and CANNOT do:
    #     from pyprotect import protected
    #     ... Use protected.wrap / protected.private / protected.protect
    #
    # ADDITIONALLY, it makes tests fail in PY2

    # protected = protected.freeze(protected)
    pass
else:
    # Module imported here does not allow further 'from x import y'
    # in PY2 without adding explicitly to sys.modules
    if 'protected' not in sys.modules:
        sys.modules['protected'] = protected
from doc import __doc__

if not in_sys_path:
    try:
        sys.path.remove(module_dir)
    except ValueError:
        pass
del in_sys_path, module_dir, os, sys
