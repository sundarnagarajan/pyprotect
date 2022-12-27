import sys
sys.dont_write_bytecode = True
from setuptools import setup, Extension

version = '1.3'
long_description = open('README.md', 'r').read(),

# Do not require cython for INSTALLATION
# Instead make sure DEVELOPER runs:
#   'cython3 --3str protected.pyx' when(ever) protected.pyx changes
ext_modules = [Extension(
    'pyprotect.protected',
    ['pyprotect/protected.c'],
)]

setup(
    version=version,
    packages=['pyprotect'],
    ext_modules=ext_modules,
    # We use __file__, so we need zip_safe=False
    # See: http://tiny.cc/nef2vz
    # or: https://t.ly/XBwC
    zip_safe=False,
)
