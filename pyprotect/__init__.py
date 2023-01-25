import sys
sys.dont_write_bytecode = True

# -------------------------------------------------------------------------
# Setting __version__
# -------------------------------------------------------------------------
# KEEP Next line - for version-updater script to update
__version__ = ''
__module_name = 'pyprotect'
# PyPi package name is set (only) in setup.cfg - set to None if it is
# the same as module_name
__pypi_name = 'pyprotect_package'


def get_installed_version(module_name, default_version, pypi_name=None):
    '''
    Generic reusable function
    module_name->str
    default_version->str
    pypi_name->str|None

    Set pypi_name if different from module_name
    '''
    if not pypi_name:
        pypi_name = module_name
    import os.path
    # pkg_resources is being deprecated, however importlib.metadata
    # is not available in PY2 and even in PY3 < 3.7
    try:
        from importlib.metadata import version
        try:
            return version(pypi_name)
        except:
            return default_version
    except:
        # Silence PkgResourcesDeprecationWarning
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            from pkg_resources import get_distribution, DistributionNotFound
            try:
                _dist = get_distribution(pypi_name)
                if _dist.has_version():
                    return _dist.version
                return default_version
            except:
                return default_version


__version__ = get_installed_version(
    module_name=__module_name,
    default_version='0.0.0-VERSION_NOT_FOUND',
    pypi_name=__pypi_name,
)
del get_installed_version, __pypi_name, __module_name
# -------------------------------------------------------------------------

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

