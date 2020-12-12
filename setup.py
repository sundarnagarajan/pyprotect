
from distutils.core import setup
from distutils.extension import Extension
import sys

module_name = 'protected_class'
language = 'c'
include_dirs = []

if '--use-cython' in sys.argv:
    USE_CYTHON = True
    sys.argv.remove('--use-cython')
else:
    USE_CYTHON = False
if USE_CYTHON:
    ext = '.pyx'
elif language == 'c':
    ext = '.c'
elif language == 'c++':
    ext = '.cpp'

src = 'src/' + module_name
extensions = [
    Extension(
        module_name,
        [src + ext],
        language=language,
        include_dirs=include_dirs,
    )
]

if USE_CYTHON:
    from Cython.Build import cythonize
    extensions = cythonize(extensions)

setup(ext_modules=extensions)
