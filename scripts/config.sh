#!/bin/bash
# As of now (ubuntu jammy) have Cython3, PY2, PY3, PYPY2, PYPY3
# in the same container

# Set EXTENSION_NAME="" if module does not use a C-Extension
EXTENSION_NAME=protected

# Set CYTHONIZE_REQUIRED=no (not yes) if C-Extension does not need cython
CYTHONIZE_REQUIRED=yes
CYTHON3_PROG_NAME=cython3
CYTHON3_MIN_VER=0.27.3

PY_MODULE=pyprotect
DOCKER_MOUNTPOINT=/${PY_MODULE}

# SCRIPTS_DIR should be basename of directory with scripts
# This is for cases where the project already has a top-level directory
# named 'scripts'
# Optional - defaults to 'scripts'
SCRIPTS_DIR=scripts

# TESTS_DIR should be basename of directory with tests
# This is for cases where the project already has a top-level directory
# named 'tests'
# Optional - defaults to 'tests'
TESTS_DIR=tests

# PROJECT_FILES is used only in relocate_source
# Include only FILES required to run python setup.py install
# Do not include $PY_MODULE or $SCRIPTS_DIR or $TESTS_DIR
# All the files must EXIST
# Optional - defaults to "MANIFEST.in README.md pyproject.toml setup.cfg setup.py"
PROJECT_FILES="MANIFEST.in README.md pyproject.toml setup.cfg setup.py"

# TEST_MODULE_FILENAME should be basename of top-level test module
# under tests/ WITH '.py' extension
TEST_MODULE_FILENAME=test_pyprotect.py

# Distro to use if __DISTRO env var is not set
# Should have corresponding config_docker_<distro>.sh and Dockerfile.<distro>
DEFAULT_DISTRO=ubuntu

# git URL (can be github URL)
# In general, GIT_URL could be:
#   HTTPS URL - e.g.:
#       github:    https://github.com/sundarnagarajan/python_protected_class.git
#       gitlab:    https://gitlab.com/{your_gitlab_username}/{repository_name}.git
#       bitbucket: https://bitbucket.org/<project_owner>/<project_name>
#   SSH URL   - e.g. ssh:git@github.com:sundarnagarajan/python_protected_class.git
GIT_URL="https://github.com/sundarnagarajan/python_protected_class.git"

# Used in gpg_sign.sh
GPG_KEY=3DCAB9392661EB519C4CCDCC5CFEABFDEFDB2DE3

# TAG_PYVER: Maps PYTHON_VERSION tags to python executable basename
# Values should be respective python executables - with or without path
declare -A TAG_PYVER=(
    ["PY3"]=python3
    ["PY2"]=python2
    ["PYPY3"]=pypy3
    ["PYPY2"]=pypy
)
