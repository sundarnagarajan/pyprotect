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
docker image inspect $DOCKER_IMAGE 1>/dev/null 2>&1 || {
    >&2 echo "Docker image not found: $DOCKER_IMAGE"
}

# CYTHONIZE_SCRIPT will rebuild protected.c only if required
$CYTHONIZE_SCRIPT

# Script path from docker mount path perspective
PY3_BUILD_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/inplace_build_py3.sh
PY2_BUILD_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/inplace_build_py2.sh


cd "$PROG_DIR"/..
[[ "$PYVER" == "PY3" || -z "$PYVER" ]] && {
    rm -rf build
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $DOCKER_IMAGE ${PY3_BUILD_SCRIPT}"
    $DOCKER_CMD
}
[[ "$PYVER" == "PY2" || -z "$PYVER" ]] && {
    rm -rf build
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $DOCKER_IMAGE ${PY2_BUILD_SCRIPT}"
    $DOCKER_CMD
}
rm -rf build
