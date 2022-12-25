#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/docker_config.sh
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
CYTHONIZE_SCRIPT=$(readlink -m "$PROG_DIR"/../scripts/cythonize.sh)
[[ -x "$CYTHONIZE_SCRIPT" ]] || {
    >&2 echo "Required script not found: $CYTHONIZE_SCRIPT"
    exit 1
}

# CYTHONIZE_SCRIPT will rebuild protected.c only if required
$CYTHONIZE_SCRIPT

# Script path from docker mount path perspective
BUILD_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/inplace_build.sh


cd "$PROG_DIR"/..
[[ "$PYVER" == "PY3" || -z "$PYVER" ]] && {
    docker image inspect $PY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 echo "Docker image not found: $DOCKER_IMAGE"
    } && {
        rm -rf build
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY3_DOCKER_IMAGE ${BUILD_SCRIPT} python3"
        $DOCKER_CMD
    }
}
[[ "$PYVER" == "PY2" || -z "$PYVER" ]] && {
    docker image inspect $PY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 echo "Docker image not found: $DOCKER_IMAGE"
    } && {
        rm -rf build
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY2_DOCKER_IMAGE ${BUILD_SCRIPT} python2"
        $DOCKER_CMD
    }
}
rm -rf build
