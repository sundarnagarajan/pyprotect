
## Features explored
    - Single package
    - Includes C extension
    - Includes README.md
    - Includes additional source files (MANIFEST.IN)
    - Installing with 'python[23] setup.py install'
    - Installing with 'pip[23] install .'
    - Installing with 'python[23] setup.py install' in virtualenv
    - Installing with 'pip[23] install .' in virtualenv
    - Uninstalling  with 'pip[23] uninstall -y'
    - Build in-place
    - Build, install, test inside docker container

## Files
    - pyproject.toml    - Fully reusable
    - setup.py          - Fully reusable
    - setup.cfg         - Fully reusable (change metadata)
    - MANIFEST.in       - Project-specific (list of files)
    - README.md         - Project-specific



## pyproject.toml - no changes required
```
[build-system]
requires = ["setuptools"]
build-backend = "setuptools.build_meta"
```



## setup.py (sample)
```python
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
```



## setup.cfg (sample)
```
[metadata]
name = pypi_name
license = BSD
author = Author Name
author_email = author@example.com
url = https://github.com/author/project
description = Module description
long_description = file: README.md
long_description_content_type = text/markdown
classifiers = 
    Development Status :: 3 - Alpha
    Intended Audience :: Developers
    Topic :: Software Development :: Libraries
    Natural Language :: English
    Operating System :: POSIX :: Linux
    Programming Language :: Python :: 2.7
    Programming Language :: Python :: 3
    Programming Language :: Cython
    License :: OSI Approved :: BSD License
keywords =
    multiline space separated keyword list
    keep lines indented
project_urls =
    Source = https://github.com/author/project
    Tracker = https://github.com/author/project/issues
    Documentation = https://github.com/author/project/README.md

[options]
# If you use __file__, you need zip_safe=False
# See: http://tiny.cc/nef2vz
# or: https://t.ly/XBwC
# Otherwise omit this line
zip_safe = False
# To bundle additional sources (e.g. C-source / Cython source)
# Add the source file paths to MANIFEST.in and set
# include_package_data = True
# Otherwise (to ignore MANIFEST.in if present), omit this line
include_package_data = True
```



## MANIFEST.in:
```
include PYMODULE/EXT_NAME.pyx
include PYMODULE/EXT_NAME.c
include PYMODULE/first.pxi
include PYMODULE/second.pxi
```
