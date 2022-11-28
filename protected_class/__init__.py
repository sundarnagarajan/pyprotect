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
# Make protected MODULE read-only - doesn't work in PY2
if sys.version_info.major > 2:
    protected = protected.freeze(protected)
else:
    sys.modules['protected'] = protected
from doc import __doc__

if not in_sys_path:
    try:
        sys.path.remove(module_dir)
    except ValueError:
        pass
del in_sys_path, module_dir, os, sys
