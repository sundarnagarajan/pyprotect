import sys
import os
from setuptools import Extension
from setuptools import setup

# Metadata for setup()
name = 'protected_class'
pyver = '%d.%d.%d-%s' % (
    sys.version_info.major,
    sys.version_info.minor,
    sys.version_info.micro,
    sys.version_info.releaselevel
)
module_dir = name + '_src-' + pyver

version = '1.1.0'
description = 'Protect class attributes in any python object instance'
long_description = open('README.md', 'r').read()
long_description_content_type = 'text/markdown'

url = 'https://github.com/sundarnagarajan/python_protected_class'

author = 'Sundar Nagarajan'
author_email = 'sun.nagarajan@gmail.com'

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
license = 'BSD'
project_urls = {
    'Source': 'ihttps://github.com/sundarnagarajan/python_protected_class',
    'Tracker': 'https://github.com/sundarnagarajan/python_protected_class/issues',   # noqa: E501
    'Documentation': 'https://github.com/sundarnagarajan/python_protected_class/blob/main/README.md',   # noqa: E501
}


if sys.version_info.major < 3:
    src = 'src/c/2/' + name + '.c'
else:
    src = 'src/c/3/' + name + '.c'

data_files = [
    (module_dir, [
        src,
        'src/cython/' + name + '.pyx',
        'tests/__init__.py',
        'tests/test_protected_class.py',
        'tests/run_tests.sh',
    ]),
]

language = 'c'
include_dirs = []

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
    author=author,
    author_email=author_email,
    classifiers=classifiers,
    keywords=keywords,
    license=license,
    # project_urls=project_urls,
    data_files=data_files,
    ext_modules=extensions,
    scripts=scripts,
)


# long_description_content_type and produces warning if used with
# 'build_ext --inplace' (when calling setup.py from Makefile

if 'build_ext' in sys.argv and '--inplace' in sys.argv:
    del kwargs['long_description_content_type']

setup(**kwargs)
