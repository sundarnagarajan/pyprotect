import sys
from setuptools import setup as setuptools_setup
from setuptools import Extension
# from setuptools.command.install import install

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

# PostInstallCommand etc do not work when installing from a wheel
# - what happens when installling from PyPi / github


def post_install():
    import subprocess
    import sys

    cmd = 'test_protected_data'
    try:
        cmd_loc = subprocess.check_output('which ' + cmd, shell=True)
        cmd_line = '%s -v' % (cmd_loc,)

        try:
            print('')
            print('-' * 75)
            print('Running unit tests')
            print('-' * 75)
            print('')
            subprocess.call(cmd_line, shell=True)
            print('')
            print('-' * 75)
            print('All unit tests passed.')
            print("Run unit tests any time with the command 'test_protected_class'")
            print('-' * 75)
            print('')
        except:
            sys.stderr.write('\n' + ('-' * 75) + '\n')
            sys.stderr.write('Unit tests failed !\n')
            sys.stderr.write(('-' * 75) + '\n')
            exit(1)

    except:
        return


'''
class PostInstallCommand(install):
    def run(self):
        install.run(self)
        # Run unit tests after installation is complete


cmdclass = {
    'install': PostInstallCommand,
}
'''


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
    # cmdclass=cmdclass,
)


# long_description_content_type and produces warning if used with
# 'build_ext --inplace'

if 'build_ext' in sys.argv and '--inplace' in sys.argv:
    del kwargs['long_description_content_type']


def setup(*args, **kwargs):
    setuptools_setup(*args, **kwargs)
    post_install()


setup(**kwargs)
