#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True
import os
try:
    from protected_class import protected
except ImportError:
    sys.path.append(
        os.path.join(
            os.path.dirname(__file__),
            '..'
        )
    )
    from protected_class import protected                  # noqa: F401
del sys, os
