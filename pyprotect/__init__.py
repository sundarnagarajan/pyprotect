import sys
sys.dont_write_bytecode = True

# I have .flake8 in parent dir containing:
# [flake8]
# per-file-ignores =
#     __init__.py: F401

import os
try:
    import protected as protected
except ImportError:
    module_dir = os.path.dirname(__file__)
    if module_dir in sys.path:
        raise
    sys.path.append(module_dir)
    import protected as protected
    sys.path.remove(module_dir)
    del module_dir

__doc__ = protected.__doc__
from protected import *   # noqa: F403
del os, sys, protected
