
from distutils.core import setup
from distutils.extension import Extension

# Metadata for setup()
module_name = 'protected_class'
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
    ('test_scripts', [
        module_name + '/tests/__init__.py',
        module_name + '/tests/test_protected_class.py',
        module_name + '/tests/run_tests.sh',
    ]),
    ('sources', [
        module_name + '/src/' + module_name + '.c',
        module_name + '/src/' + module_name + '.pyx',
    ]),
]


language = 'c'
include_dirs = []

src = 'protected_class_src' + '/c/' + module_name + '.c'
extensions = [
    Extension(
        module_name,
        [src],
        language='c',
        include_dirs=include_dirs,
    )
]

setup(
    name=module_name,
    version=version,
    description=description,
    long_description=long_description,
    # long_description_content_type ignored and produces warning !
    # long_description_content_type=long_description_content_type,
    url=url,
    classifiers=classifiers,
    keywords=keywords,
    data_files=data_files,
    ext_modules=extensions
)
