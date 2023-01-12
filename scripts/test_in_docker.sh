#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh

must_not_be_in_docker

# Script path from docker mount path perspective
TEST_SCRIPT=${DOCKER_MOUNTPOINT}/tests/run_func_tests.sh

[[ $# -lt 1 ]] && {
    PYVER='' 
} || {
    PYVER=$1
}
[[ "$PYVER" == "PY3" || "$PYVER" == "PY2" \
    || "$PYVER" == "PYPY3" || "$PYVER" == "PYPY2" || \
    "$PYVER" == "PYPY2" || -z "$PYVER" ]] || {
    >&2 red "Unknown PYVER: $PYVER"
    exit 1
}

cd "$PROG_DIR"/..
[[ "$PYVER" == "PY3" || -z "$PYVER" ]] && {
    docker_image_must_exist $PY3_DOCKER_IMAGE
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY3_DOCKER_IMAGE ${TEST_SCRIPT} PY3"
    $DOCKER_CMD
}
[[ "$PYVER" == "PY2" || -z "$PYVER" ]] && {
    docker_image_must_exist $PY2_DOCKER_IMAGE
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY2_DOCKER_IMAGE ${TEST_SCRIPT} PY2"
    $DOCKER_CMD
}

[[ "$PYVER" == "PYPY3" || -z "$PYVER" ]] && {
    docker_image_must_exist $PYPY3_DOCKER_IMAGE
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PYPY3_DOCKER_IMAGE ${TEST_SCRIPT} PYPY3"
    $DOCKER_CMD
}

[[ "$PYVER" == "PYPY2" || -z "$PYVER" ]] && {
    docker_image_must_exist $PYPY2_DOCKER_IMAGE
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PYPY2_DOCKER_IMAGE ${TEST_SCRIPT} PYPY2"
    $DOCKER_CMD
}
