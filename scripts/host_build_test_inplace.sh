#!/bin/bash
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/common_functions.sh

need_docker_command

# Script path OUTSIDE docker
CLEAN_BUILD_SCRIPT="${PROG_DIR}"/clean_build.sh
# Script path from docker mount path perspective
CYTHONIZE_SCRIPT=${DOCKER_MOUNTPOINT}/${SCRIPTS_DIR}/inplace_cythonize.sh
BUILD_SCRIPT=${DOCKER_MOUNTPOINT}/${SCRIPTS_DIR}/build_inplace.sh


function build_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local img=${TAG_IMAGE[${pyver}]}
    local build_args=${TAG_PYVER[${pyver}]}
    cd "$PROG_DIR"/..
    "${CLEAN_BUILD_SCRIPT}"
    DOCKER_CMD="docker run --rm -it -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user "${HOST_UID}:${HOST_GID}" --env __DISTRO=${__DISTRO:-} --env __NOTEST=${__NOTEST:-} $img ${BUILD_SCRIPT} $pyver"
    $DOCKER_CMD
    "${CLEAN_BUILD_SCRIPT}"
}


# Will be running build in docker, so need image validation
VALID_PYVER=$(process_std_cmdline_args yes yes $@)

cd "$PROG_DIR"/..

[[ -n "${EXTENSION_NAME:-}" && "${CYTHONIZE_REQUIRED:-}" = "yes" ]] && {
    # Still need to check for CYTHON3_DOCKER_IMAGE and run CYTHONIZE_SCRIPT
    docker_image_must_exist $CYTHON3_DOCKER_IMAGE
    DOCKER_CMD="docker run --rm -it -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user "${HOST_UID}:${HOST_GID}" --env __DISTRO=${__DISTRO:-} $CYTHON3_DOCKER_IMAGE ${CYTHONIZE_SCRIPT}"
    $DOCKER_CMD
}

for p in $VALID_PYVER
do
    build_1_pyver $p
done
