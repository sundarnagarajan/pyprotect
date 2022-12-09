import sys
sys.dont_write_bytecode = True
import os
module_dir = os.path.dirname(__file__)
in_sys_path = (module_dir in sys.path)
try:
    import protected as protected
except ImportError:
    # Installed with 'setup.py build_ext --inplace'
    if in_sys_path:
        raise
    sys.path.append(module_dir)
    import protected as protected

# I have .flake8 in parent dir containing:
# [flake8]
# per-file-ignores =
#     __init__.py: F401

from protected import *   # noqa: F403
__doc__ = protected.__doc__
'''
# Hacking at modules to control what attributes are exposed is actively
# supported by Guido. See:
# http://mail.python.org/pipermail/python-ideas/2012-May/014969.html
# But when we do this, it becomes difficult to see help(pyprotect)
# You HAVE to use help_protected(pyprotect)
# Otherwise everything works!
protected = protected.private(p, frozen=True)
# __doc__ = getattr(protected, protected.attribute_protected()).help_str()
sys.modules['pyprotect'] = protected
'''
del protected

if not in_sys_path:
    try:
        sys.path.remove(module_dir)
    except ValueError:
        pass
    except:
        pass
del in_sys_path, module_dir, os, sys
