import sys
sys.dont_write_bytecode = True
from setuptools import setup, Extension

import os
# Set CFLAGS to optimize further
os.environ['CFLAGS'] = "-O3"
# Set LDFLAGS to automatically strip .so
os.environ['LDFLAGS'] = "-s"

long_description = open('README.md', 'r').read(),
version = '1.3'
PY_MODULE = 'pyprotect'
# Set EXT_Name = None if you don't have an extension
# Do not require cython for INSTALLATION
# Instead make sure DEVELOPER runs:
#   'cython3 --3str ${EXT_NAME}.pyx' when(ever) ${EXT_NAME}.pyx changes
EXT_NAME = 'protected'

# ---------- Should not need to change anything after this ---------------
ext_modules = []
if EXT_NAME:
    ext_modules = [Extension(
        '%s.%s' % (PY_MODULE, EXT_NAME),
        ['%s/%s.c' % (PY_MODULE, EXT_NAME)],
    )]
kwargs = dict(
    version=version,
    packages=[PY_MODULE],
)
if ext_modules:
    kwargs['ext_modules'] = ext_modules
setup(**kwargs)
