#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True
import os
try:
    # Installed in virtualenv or system-wide
    import pyprotect     # noqa: F401
except ImportError:
    # Installed with --inplace (relative to 'tests' dir)
    module_dir = os.path.join(
        os.path.dirname(__file__),
        '..'
    )
    if module_dir in sys.path:
        raise
    sys.path.append(module_dir)
    import pyprotect     # noqa: F401
    sys.path.remove(module_dir)
    del module_dir
del sys, os
