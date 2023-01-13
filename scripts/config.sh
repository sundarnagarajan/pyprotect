#!/bin/bash
# In the future, PY2_DOCKER_IMAGE may be different
# As of now (ubuntu jammy) we have PY2, PY3, Cython3
# in the same container

# We make config vars read-only, so they are guarded by __CONFIG_SOURCED
[[ -n $(declare -p __CONFIG_SOURCED 2>/dev/null) && -n "${__CONFIG_SOURCED}+_" ]] || {
    EXTENSION_NAME=protected
    PY_MODULE=pyprotect
    DOCKER_MOUNTPOINT=/home
    CYTHON3_DOCKER_IMAGE=python23:jammy

    # TAG_PYVER: Maps PYTHON_VERSION tags to python executable basename
    # Values should be basenames of respective python executables
    # WITHOUT path
    declare -A TAG_PYVER=(
        ["PY3"]=python3
        ["PY2"]=python2
        ["PYPY3"]=pypy3
        ["PYPY2"]=pypy
    )

    # TAG_IMAGE: maps PYTHON_VERSION tags to docker image names
    declare -A TAG_IMAGE=(
        ["PY3"]=python23:jammy
        ["PY2"]=python23:jammy
        ["PYPY3"]=python23:jammy
        ["PYPY2"]=python23:jammy
    )

    # Rest are automatic - do not need to be set / reviewed
    HOST_USERNAME=$(id -un)
    HOST_GROUPNAME=$(id -gn)
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)
    DOCKER_USER="${HOST_UID}:${HOST_GID}"


    # Make config entries read-only
    readonly EXTENSION_NAME PY_MODULE DOCKER_MOUNTPOINT \
        TAG_PYVER TAG_IMAGE \
        HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID \
    __CONFIG_SOURCED=yes
    readonly __CONFIG_SOURCED
}
