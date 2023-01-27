import sys
sys.dont_write_bytecode = True
from setuptools import setup, Extension
import os
PY_MODULE = 'pyprotect'

# ---------- Should not need to change anything after this ---------------
DEFS_FILE_BASENAME = 'version_extname.ini'
UNKNOWN_VERSION = '0.0.0-VERSION_NOT_FOUND'


def get_ver_extname():
    '''Returns: (ver->str, ext_name->str or None '''
    if sys.version_info.major == 2:
        from ConfigParser import ConfigParser
    else:
        from configparser import ConfigParser

    global DEFS_FILE_BASENAME, UNKNOWN_VERSION
    SETUP_PY_DIR = os.path.dirname(os.path.realpath(__file__))
    MODULE_DIR = os.path.join(SETUP_PY_DIR, PY_MODULE)
    DEFS_FILE = os.path.join(MODULE_DIR, DEFS_FILE_BASENAME)

    cfg = ConfigParser()
    cfg.read(DEFS_FILE)

    ver = UNKNOWN_VERSION
    ext_name = None
    if cfg.has_option('defs', 'EXTENSION_NAME'):
        ext_name = cfg.get('defs', 'EXTENSION_NAME')
    if cfg.has_option('defs', 'VERSION'):
        ver = cfg.get('defs', 'VERSION')
    return (ver, ext_name)


(version, EXTENSION_NAME) = get_ver_extname()

ext_modules = []
if EXTENSION_NAME:
    # Set CFLAGS to optimize further
    os.environ['CFLAGS'] = "-O3"
    # Set LDFLAGS to automatically strip .so
    os.environ['LDFLAGS'] = "-s"

    ext_modules = [Extension(
        '%s.%s' % (PY_MODULE, EXTENSION_NAME),
        ['%s/%s.c' % (PY_MODULE, EXTENSION_NAME)],
    )]
kwargs = dict(
    version=version,
    packages=[PY_MODULE],
)
if ext_modules:
    kwargs['ext_modules'] = ext_modules
setup(**kwargs)
