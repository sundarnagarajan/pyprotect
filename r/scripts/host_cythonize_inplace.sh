#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

need_docker_command


DISTRO=${__DISTRO:-${DEFAULT_DISTRO}}
# Script path from docker mount path perspective
CYTHONIZE_SCRIPT=${DOCKER_MOUNTPOINT}/${SCRIPTS_DIR}/cythonize_inplace.sh


cd "$PROG_DIR"/..
[[ -n "${EXTENSION_NAME:-}" && "${CYTHONIZE_REQUIRED:-}" = "yes" ]] && {
    # Still need to check for CYTHON3_DOCKER_IMAGE and run CYTHONIZE_SCRIPT
    docker_image_must_exist $CYTHON3_DOCKER_IMAGE
    echo "${SCRIPT_NAME}: Running docker in $CYTHON3_DOCKER_IMAGE"
    cd "${SOURCE_TOPLEVEL_DIR}"
    DOCKER_CMD="docker run --rm -it -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user "${HOST_UID}:${HOST_GID}" --env __DISTRO=${__DISTRO:-} $CYTHON3_DOCKER_IMAGE ${CYTHONIZE_SCRIPT}"
    echo $DOCKER_CMD
    $DOCKER_CMD
}
