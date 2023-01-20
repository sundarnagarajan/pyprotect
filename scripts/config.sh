#!/bin/bash
# As of now (ubuntu jammy) have Cython3, PY2, PY3, PYPY2, PYPY3
# in the same container

# The name of the module - should be a top-level directory
PY_MODULE=pyprotect

# Set EXTENSION_NAME="" if module does not use a C-Extension
EXTENSION_NAME=protected

# Set CYTHONIZE_REQUIRED=no (not yes) if C-Extension does not need cython
CYTHONIZE_REQUIRED=yes
CYTHON3_PROG_NAME=cython3
CYTHON3_MIN_VER=0.27.3

# SCRIPTS_DIR should be basename of directory with scripts - for cases
# where the project already has a top-level directory named 'scripts'
# Optional - defaults to 'scripts' - can be commented if using default
SCRIPTS_DIR=scripts

# TESTS_DIR should be basename of directory with tests - for cases
# where the project already has a top-level directory named 'tests'
# Optional - defaults to 'tests' - can be commented if using default
TESTS_DIR=tests

# PROJECT_FILES is used only in relocate_source
# Include only FILES required to run python setup.py install
# Do not include $PY_MODULE or $SCRIPTS_DIR or $TESTS_DIR
# All the files MUST EXIST as regular files
# Optional - defaults to "MANIFEST.in README.md pyproject.toml setup.cfg setup.py"
# Can be commented if using default list
PROJECT_FILES="MANIFEST.in README.md pyproject.toml setup.cfg setup.py"

# TEST_MODULE_FILENAME should be basename of top-level test module under
# TESTS_DIR/ WITH '.py' extension - mandatory
TEST_MODULE_FILENAME=test_pyprotect.py

# git URL (can be github / bitbucket / gitlab URL etc) - any URL that
# can be used with the 'git' command to clone a repository
# In general, GIT_URL could be:
#   HTTPS URL - e.g.:
#       github:    https://github.com/sundarnagarajan/python_protected_class.git
#       gitlab:    https://gitlab.com/{your_gitlab_username}/{repository_name}.git
#       bitbucket: https://bitbucket.org/<project_owner>/<project_name>
#   SSH URL   - e.g. ssh:git@github.com:sundarnagarajan/python_protected_class.git
# Optional
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

# More related to docker than the project, but it is in config.sh
# to avoid repeating in each of the config_docker_<distro>.sh files
DOCKER_MOUNTPOINT=/${PY_MODULE}

# Distro to use in docker if __DISTRO env var is not set
# Should have corresponding config_docker_<distro>.sh and Dockerfile.<distro>
DEFAULT_DISTRO=ubuntu
