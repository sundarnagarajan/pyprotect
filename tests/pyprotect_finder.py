#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True
import os
try:
    import pyprotect
    # from pyprotect import protected    # noqa: F401
except ImportError:
    sys.path.append(
        os.path.join(
            os.path.dirname(__file__),
            '..'
        )
    )
    import pyprotect     # noqa: F401
    # from pyprotect import protected    # noqa: F401
del sys, os
