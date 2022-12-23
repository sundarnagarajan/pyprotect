import sys
sys.dont_write_bytecode = True
if sys.version_info.major == 2:
    PY2 = True
else:
    PY2 = False
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

__doc__ = protected.__doc__
if '__Protected_NOFREEZE_MODULE_____' in os.environ:
    from protected import *   # noqa: F403
else:
    # Hacking at modules to control what attributes are exposed is actively
    # supported by Guido. See:
    # http://mail.python.org/pipermail/python-ideas/2012-May/014969.html
    # But when we do this, it becomes difficult to see help(pyprotect)
    # To make it developer-friendly, we need to override 'help' in
    # builtin module to point at protected.help_protected
    #
    # But STILL, pydoc(pyprotect) will not work !
    # This is still developer-unfriendly !!

    if PY2:
        sys.modules['__builtin__'].help = protected.help_protected
    else:
        sys.modules['builtins'].help = protected.help_protected
    protected.__file__ = __file__
    protected = protected.private(protected, frozen=True)
    # __doc__ = getattr(protected, protected.attribute_protected()).help_str()
    sys.modules['pyprotect'] = protected


del protected

if not in_sys_path:
    try:
        sys.path.remove(module_dir)
    except ValueError:
        pass
    except:
        pass
del PY2, in_sys_path, module_dir, os, sys
