#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/config.sh
DOCKER_USER="$(id -u):$(id -g)"

[[ $# -lt 1 ]] && {
    PYVER='' 
} || {
    PYVER=$1
}
[[ "$PYVER" == "PY3" || "$PYVER" == "PY2" || -z "$PYVER" ]] || {
    >&2 echo "Unknown PYVER: $PYVER"
    exit 1
}

# Script path from docker mount path perspective
CYTHONIZE_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/cythonize.sh
cd "$PROG_DIR"/..
docker image inspect $CYTHON3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
    >&2 echo "Docker image not found: $CYTHON3_DOCKER_IMAGE"
} && {
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $CYTHON3_DOCKER_IMAGE ${CYTHONIZE_SCRIPT}"
    $DOCKER_CMD
}

# Script path from docker mount path perspective
BUILD_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/inplace_build.sh


[[ "$PYVER" == "PY3" || -z "$PYVER" ]] && {
    docker image inspect $PY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 echo "Docker image not found: $PY3_DOCKER_IMAGE"
    } && {
        rm -rf build
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY3_DOCKER_IMAGE ${BUILD_SCRIPT} python3"
        $DOCKER_CMD
    }
}
[[ "$PYVER" == "PY2" || -z "$PYVER" ]] && {
    docker image inspect $PY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 echo "Docker image not found: $PY2_DOCKER_IMAGE"
    } && {
        rm -rf build
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY2_DOCKER_IMAGE ${BUILD_SCRIPT} python2"
        $DOCKER_CMD
    }
}
rm -rf build
