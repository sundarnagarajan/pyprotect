
import sys
from setuptools import setup, Extension
# from distutils.core import setup
# from distutils.extension import Extension

# Metadata for setup()
name = 'protected_class'
module_dir = name + '_src'

version = '1.0.0'
description = 'Protect class attributes in any python object instance'
long_description = "README.md"
long_description_content_type = 'text/markdown'
url = 'https://github.com/sundarnagarajan/python_protected_class'
classifiers = [
    'Development Status :: 3 - Alpha',
    'Intended Audience :: Developers',
    'Topic :: Software Development :: Libraries',
    'Natural Language :: English',
    'Operating System :: POSIX :: Linux',
    'Programming Language :: Python :: 2.7',
    'Programming Language :: Python :: 3',
    'Programming Language :: Cython',
    'License :: OSI Approved :: BSD License',
]
keywords = (
    'private private_attributes frozen immutable freeze '
    'frozen_object immutable_object freeze_object'
)
data_files = [
    (module_dir, [
        'src/c/' + name + '.c',
        'src/cython/' + name + '.pyx',
        'tests/__init__.py',
        'tests/test_protected_class.py',
        'tests/run_tests.sh',
    ]),
]

language = 'c'
include_dirs = []

src = 'src/c/' + name + '.c'
extensions = [
    Extension(
        name=name,
        sources=[src],
        language='c',
        include_dirs=include_dirs,
    )
]
scripts = [
    'tests/test_protected_class',
]

kwargs = dict(
    name=name,
    version=version,
    description=description,
    long_description=long_description,
    long_description_content_type=long_description_content_type,
    url=url,
    classifiers=classifiers,
    keywords=keywords,
    data_files=data_files,
    ext_modules=extensions,
    scripts=scripts,
)


# long_description_content_type and produces warning if used with
# 'build_ext --inplace'

if 'build_ext' in sys.argv and '--inplace' in sys.argv:
    del kwargs['long_description_content_type']

setup(**kwargs)
