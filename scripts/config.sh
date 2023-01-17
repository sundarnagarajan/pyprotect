#!/bin/bash
# As of now (ubuntu jammy) have Cython3, PY2, PY3, PYPY2, PYPY3
# in the same container

SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))
# config vars are made read-only, so they are guarded by __CONFIG_SOURCED
[[ -n $(declare -p __CONFIG_SOURCED 2>/dev/null) && -n "${__CONFIG_SOURCED}+_" ]] || {
    # Do not change the line ABOVE
    # --------------------------------------------------------------------

    # Set EXTENSION_NAME="" if module does not use a C-Extension
    EXTENSION_NAME=protected

    # Set CYTHONIZE_REQUIRED=no (not yes) if C-Extension does not need cython
    CYTHONIZE_REQUIRED=yes

    PY_MODULE=pyprotect
    DOCKER_MOUNTPOINT=/${PY_MODULE}

    # SCRIPTS_DIR should be basename of directory with scripts
    # This is for cases where the project already has a top-level directory
    # named 'scripts'
    SCRIPTS_DIR=scripts

    # TEST_MODULE_FILENAME should be basename of top-level test module
    # under tests/ WITH '.py' extension
    TEST_MODULE_FILENAME=test_pyprotect.py

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

    # --------------------------------------------------------------------
    # Do not change anything beow this
    # --------------------------------------------------------------------
    # These are related to UID / GID on the host
    HOST_USERNAME=$(id -un)
    HOST_GROUPNAME=$(id -gn)
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)

    # Source the distro-specific config_docker_XXX.sh
    DOCKER_CONFIG_FILE=${__DISTRO:-}
    [[ -z "$DOCKER_CONFIG_FILE" ]] && {
        DOCKER_CONFIG_FILE=$SCRIPT_DIR/config_docker.sh
    } || {
        DOCKER_CONFIG_FILE=${SCRIPT_DIR}/config_docker_${DOCKER_CONFIG_FILE}.sh
    }
    source "$DOCKER_CONFIG_FILE"

    # Make config entries read-only
    SCRIPTS_DIR=$(basename "$SCRIPTS_DIR")
    TEST_MODULE_FILENAME=$(basename "$TEST_MODULE_FILENAME")
    readonly \
        EXTENSION_NAME CYTHONIZE_REQUIRED \
        PY_MODULE DOCKER_MOUNTPOINT \
        SCRIPTS_DIR TEST_MODULE_FILENAME \
        GIT_URL GPG_KEY \
        TAG_PYVER \
        HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID \
        DOCKER_CONFIG_FILE
    __CONFIG_SOURCED=yes
    readonly __CONFIG_SOURCED
}
