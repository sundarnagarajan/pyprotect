import sys
sys.dont_write_bytecode = True
from setuptools import setup, Extension

version = '1.2'
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
)
