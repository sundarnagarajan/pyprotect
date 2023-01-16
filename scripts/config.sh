#!/bin/bash
# As of now (ubuntu jammy) have Cython3, PY2, PY3, PYPY2, PYPY3
# in the same container

SCRIPT_DIR=$(readlink -f $(dirname $BASH_SOURCE))
# config vars are made read-only, so they are guarded by __CONFIG_SOURCED
[[ -n $(declare -p __CONFIG_SOURCED 2>/dev/null) && -n "${__CONFIG_SOURCED}+_" ]] || {
    # Do not change the line ABOVE
    # --------------------------------------------------------------------

    EXTENSION_NAME=protected
    PY_MODULE=pyprotect
    DOCKER_MOUNTPOINT=/${PY_MODULE}
    # SCRIPTS_DIR should be basename of directory with scripts
    # This is for cases where the project already has a top-level directory
    # named 'scripts'
    SCRIPTS_DIR=scripts
    # TEST_MODULE_FILENAME should be basename of top-level test module
    # under tests/ WITH '.py' extension
    TEST_MODULE_FILENAME=test_pyprotect.py

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
    DOCKER_USER="${HOST_UID}:${HOST_GID}"

    # Source the distro-specific config_docker_XXX.sh
    DOCKER_CONFIG_FILE=${__DISTRO:-}
    [[ -z "$DOCKER_CONFIG_FILE" ]] && {
        DOCKER_CONFIG_FILE=$SCRIPT_DIR/config_docker.sh
    } || {
        DOCKER_CONFIG_FILE=${SCRIPT_DIR}/config_docker_${DOCKER_CONFIG_FILE}.sh
    }
    source "$DOCKER_CONFIG_FILE"

    # Make config entries read-only
    # DOCKER_USER is not read-only - it may be set in docker_as.sh
    SCRIPTS_DIR=$(basename "$SCRIPTS_DIR")
    TEST_MODULE_FILENAME=$(basename "$TEST_MODULE_FILENAME")
    readonly EXTENSION_NAME PY_MODULE DOCKER_MOUNTPOINT \
        TAG_PYVER \
        HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID \
        SCRIPTS_DIR TEST_MODULE_FILENAME
    __CONFIG_SOURCED=yes
    readonly __CONFIG_SOURCED
}
