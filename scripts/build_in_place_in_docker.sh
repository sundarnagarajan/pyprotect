#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/common_functions.sh

must_not_be_in_docker

# Script path OUTSIDE docker
CLEAN_BUILD_SCRIPT="${PROG_DIR}"/../scripts/clean_build.sh
# Script path from docker mount path perspective
CYTHONIZE_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/cythonize.sh
BUILD_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/inplace_build.sh


function build_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local img=${TAG_IMAGE[${pyver}]}
    local build_args=${TAG_PYVER[${pyver}]}
    cd "$PROG_DIR"/..
    "${CLEAN_BUILD_SCRIPT}"
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $img ${BUILD_SCRIPT} $pyver"
    $DOCKER_CMD
    "${CLEAN_BUILD_SCRIPT}"
}


# Will be running build in docker, so need image validation
VALID_PYVER=$(process_std_cmdline_args yes yes $@)

cd "$PROG_DIR"/..

# Still need to check for CYTHON3_DOCKER_IMAGE and run CYTHONIZE_SCRIPT
docker_image_must_exist $CYTHON3_DOCKER_IMAGE
DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $CYTHON3_DOCKER_IMAGE ${CYTHONIZE_SCRIPT}"
$DOCKER_CMD

for p in $VALID_PYVER
do
    build_1_pyver $p
done