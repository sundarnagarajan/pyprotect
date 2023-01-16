#!/bin/bash
# As of now (ubuntu jammy) have Cython3, PY2, PY3, PYPY2, PYPY3
# in the same container

# config vars are made read-only, so they are guarded by __CONFIG_DOCKER_SOURCED
[[ -n $(declare -p __CONFIG_SOURCED 2>/dev/null) && -n "${__CONFIG_DOCKER_SOURCED}+_" ]] || {
    # Do not change the line ABOVE
    # --------------------------------------------------------------------

    COMMON_CONTAINER_NAME=python23:jammy
    # If $CYTHON_DOCKER_FILE is in DOCKERFILE_IMAGE, CYTHON3_DOCKER_IMAGE
    # is not required
    CYTHON_DOCKER_FILE=Dockerfile.ubuntu
    # CYTHON3_DOCKER_IMAGE=$COMMON_CONTAINER_NAME

    # TAG_IMAGE: maps PYTHON_VERSION tags to docker image names
    declare -A TAG_IMAGE=(
        ["PY3"]=$COMMON_CONTAINER_NAME
        ["PY2"]=$COMMON_CONTAINER_NAME
        ["PYPY3"]=$COMMON_CONTAINER_NAME
        ["PYPY2"]=$COMMON_CONTAINER_NAME
    )
    # DOCKERFILE_IMAGE maps Docker file names to Docker image names
    # Used (only) in docker_build.sh
    declare -A DOCKERFILE_IMAGE=(
        [Dockerfile.ubuntu]=${TAG_IMAGE[PY3]}
    )

    # --------------------------------------------------------------------
    # Do not change anything beow this
    # --------------------------------------------------------------------
    # If required, Derive CYTHON3_DOCKER_IMAGE or make sure it is set
    [[ -n "${EXTENSION_NAME:-}" && "${CYTHONIZE_REQUIRED:-}" = "yes" ]] && {
        [[ -z "${CYTHON_DOCKER_FILE:-}" ]] && {
            >&2 red "$(basename $BASH_SOURCE): C-Extension with CYTHONIZE_REQUIRED=yes, but CYTHON_DOCKER_FILE not set"
            return 1
        }
        [[ -n ${DOCKERFILE_IMAGE[$CYTHON_DOCKER_FILE]+_} ]] && {
            [[ -z "${CYTHON3_DOCKER_IMAGE:-}" ]] && CYTHON3_DOCKER_IMAGE=${DOCKERFILE_IMAGE[$CYTHON_DOCKER_FILE]}
        } || {
            >&2 red "$(basename $BASH_SOURCE): C-Extension with CYTHONIZE_REQUIRED=yes, but CYTHON3_DOCKER_IMAGE not set and $CYTHON_DOCKER_FILE not in DOCKERFILE_IMAGE"
            return 1
        }
    }
    unset COMMON_CONTAINER_NAME
    # Make config entries read-only
    readonly TAG_IMAGE DOCKERFILE_IMAGE CYTHON3_DOCKER_IMAGE
    __CONFIG_DOCKER_SOURCED=yes
    readonly __CONFIG_DOCKER_SOURCED
}
