import sys
sys.dont_write_bytecode = True
import os
UNKNOWN_VERSION = '0.0.0-VERSION_NOT_FOUND'
DEFS_FILE_BASENAME = 'version_extname.ini'


def get_ver_and_extmod():
    import sys
    import os
    import sysconfig
    import imp

    if sys.version_info.major == 2:
        from ConfigParser import ConfigParser
    else:
        from configparser import ConfigParser

    global UNKNOWN_VERSION
    global DEFS_FILE_BASENAME
    MODULE_DIR = os.path.dirname(os.path.realpath(__file__))
    DEFS_FILE = os.path.join(MODULE_DIR, DEFS_FILE_BASENAME)
    cfg = ConfigParser()
    cfg.read(DEFS_FILE)

    __ver = UNKNOWN_VERSION
    ext_name = None
    if cfg.has_option('defs', 'VERSION'):
        __ver = cfg.get('defs', 'VERSION')
    if cfg.has_option('defs', 'EXTENSION_NAME'):
        ext_name = cfg.get('defs', 'EXTENSION_NAME')

    if not ext_name:
        return (__ver, None)

    if sys.version_info.major == 2:
        CONFIG_KEY = "SO"
    else:
        CONFIG_KEY = 'EXT_SUFFIX'
    ext_fn = ext_name + sysconfig.get_config_var(CONFIG_KEY)
    ext_fn = os.path.join(MODULE_DIR, ext_fn)
    return (__ver, imp.load_dynamic(ext_name, ext_fn))


(__version__, e) = get_ver_and_extmod()
if e:
    globals().update({k: getattr(e, k) for k in e.__all__})
    __doc__ = e.__doc__
del sys, os, get_ver_and_extmod
del UNKNOWN_VERSION, e
# -------------------------------------------------------------------------
