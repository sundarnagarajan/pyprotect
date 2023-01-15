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

    # TAG_PYVER: Maps PYTHON_VERSION tags to python executable basename
    # Values should be respective python executables - with or without path
    declare -A TAG_PYVER=(
        ["PY3"]=python3
        ["PY2"]=python2
        ["PYPY3"]=pypy3
        ["PYPY2"]=pypy
    )

    # Rest are related to UID / GID on the host
    HOST_USERNAME=$(id -un)
    HOST_GROUPNAME=$(id -gn)
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)
    DOCKER_USER="${HOST_UID}:${HOST_GID}"

    DOCKER_CONFIG_FILE=${__DISTRO:-}
    [[ -z "$DOCKER_CONFIG_FILE" ]] && {
        DOCKER_CONFIG_FILE=$SCRIPT_DIR/config_docker.sh
    } || {
        DOCKER_CONFIG_FILE=${SCRIPT_DIR}/config_docker_${DOCKER_CONFIG_FILE}.sh
    }
    source "$DOCKER_CONFIG_FILE"

    # --------------------------------------------------------------------
    # Do not change anything beow this
    # --------------------------------------------------------------------
    # Make config entries read-only
    # DOCKER_USER is not read-only - it may be set in docker_as.sh
    readonly EXTENSION_NAME PY_MODULE DOCKER_MOUNTPOINT \
        TAG_PYVER \
        HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID \
    __CONFIG_SOURCED=yes
    readonly __CONFIG_SOURCED
}
