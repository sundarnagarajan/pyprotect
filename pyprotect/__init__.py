
# -------------------------------------------------------------------------
# Add additional __init__.py code AFTER this block
# -------------------------------------------------------------------------
import sys
sys.dont_write_bytecode = True
import os
UNKNOWN_VERSION = '0.0.0-VERSION_NOT_FOUND'
DEFS_FILE_BASENAME = 'version_extname.ini'


def get_ver_and_extmod():
    import sys
    import os
    from contextlib import contextmanager

    global UNKNOWN_VERSION
    global DEFS_FILE_BASENAME
    MODULE_DIR = os.path.dirname(os.path.realpath(__file__))
    MODULE_NAME = os.path.basename(MODULE_DIR)

    class NoImportlibError(Exception):
        pass

    def cfg_get_ver_extname(cf):
        '''
        cf->str: path to ini file
        Returns: (v->str, e-> str)
        Small (import) difference between PY2 andPY3
        '''
        if sys.version_info.major == 2:
            from ConfigParser import ConfigParser
        else:
            from configparser import ConfigParser
        (_v, _e) = ('', '')
        cfg = ConfigParser()
        cfg.read(cf)
        if cfg.has_option('defs', 'VERSION'):
            _v = cfg.get('defs', 'VERSION')
        if cfg.has_option('defs', 'EXTENSION_NAME'):
            _e = cfg.get('defs', 'EXTENSION_NAME')
        return(_v, _e)

    def extension_suffix():
        '''
        Returns->str with leading dot
        Small (CONFIG_KEY) difference between PY2 and PY3
        '''
        import sysconfig
        if sys.version_info.major == 2:
            CONFIG_KEY = "SO"
        else:
            CONFIG_KEY = 'EXT_SUFFIX'
        return sysconfig.get_config_var(CONFIG_KEY)

    def load_extension(name, path):
        '''
        name, path->str
        Returns module object
        PY2 has does not have importlib.util.spec_from_file_location
        PY3 3 deprecates imp and will be REMOVED in 3.12
        '''
        if sys.version_info.major == 2:
            import imp
            return imp.load_dynamic(name, path)
        else:
            # See importlib python docs: https://is.gd/qAgDsD
            # See: https://stackoverflow.com/a/56219484
            import importlib
            spec = importlib.util.spec_from_file_location(name, path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod

    @contextmanager
    def using_file(f):
        '''
        f->str: Filename within a package
        Use as context manager:
            with using_file(my_package_file) as A:
                do_something_with(A)
        PY2 does not have importlib.resources
        PY3 deprecates pkg_resources - may finally remove
        '''
        # Not using egg - NEEDED for running in-place
        if os.path.exists(f):
            try:
                yield f
            finally:
                pass
        else:
            # Using egg
            # Typically because zip_safe is True AND inside a virtualenv
            # At least on Ubuntu, system-wide installs do not seem to use egg
            # EVEN if zip_safe is True
            try:
                # See:Migration guide: https://is.gd/uCwmdM
                # importlib.resources python docs: https://is.gd/mjTuJK
                try:
                    import importlib
                    import importlib.resources
                except ImportError:
                    raise NoImportlibError
                ref = importlib.resources.files(MODULE_NAME) / f
                with importlib.resources.as_file(ref) as plf:
                    try:
                        yield str(plf)
                    finally:
                        pass
            except NoImportlibError:
                # See: https://is.gd/m9pK0G
                import pkg_resources
                try:
                    yield pkg_resources.resource_filename(
                        MODULE_NAME,
                        os.path.basename(f)
                    )
                finally:
                    pkg_resources.cleanup_resources()
            except:
                import traceback
                print(traceback.format_exc())
                raise

    # ---------- get_ver_and_extmod main code after this ----------
    with using_file(DEFS_FILE_BASENAME) as f:
        (__ver, ext_name) = cfg_get_ver_extname(f)
        __ver = __ver or UNKNOWN_VERSION

    if not ext_name:
        return (__ver, None)
    ext_fn = ext_name + extension_suffix()
    with using_file(ext_fn) as f:
        return (__ver, load_extension(ext_name, f))


(__version__, e) = get_ver_and_extmod()
if e:
    globals().update({k: getattr(e, k) for k in e.__all__})
    __doc__ = e.__doc__
del get_ver_and_extmod, e

del sys, os
del UNKNOWN_VERSION, DEFS_FILE_BASENAME
# -------------------------------------------------------------------------
# Add additional __init__.py code AFTER this block
# -------------------------------------------------------------------------
