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
from protected import immutable_builtin_attributes
from protected import isimmutable
from protected import id_protected
from protected import help_protected
from protected import isinstance_protected
from protected import isreadonly
from protected import contains
from protected import iswrapped
from protected import isfrozen
from protected import isprivate
from protected import isprotected
from protected import wrap
from protected import freeze
from protected import private
from protected import protect
from doc import __doc__

if not in_sys_path:
    try:
        sys.path.remove(module_dir)
    except ValueError:
        pass
del module_dir, os, sys
