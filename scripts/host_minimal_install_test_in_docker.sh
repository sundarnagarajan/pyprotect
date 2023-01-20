#!/bin/bash
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/common_functions.sh

need_docker_command

# Script path from docker mount path perspective
ROOT_SCRIPT=${DOCKER_MOUNTPOINT}/${SCRIPTS_DIR}/root_install_test_in_docker.sh
DISTRO=${__DISTRO:-${DEFAULT_DISTRO}}
export __MINIMAL_TESTS=yes

function install_test_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local img=${TAG_IMAGE[${pyver}]}
    cd "$PROG_DIR"/..
    DOCKER_CMD="docker run --rm -it -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user root --env __DISTRO=$DISTRO --env __MINIMAL_TESTS=${__MINIMAL_TESTS:-} --env __NOTEST=${__NOTEST:-} $img ${ROOT_SCRIPT} $pyver"
    $DOCKER_CMD
}


# Will be running build in docker, so need image validation
VALID_PYVER=$(process_std_cmdline_args yes yes $@)

for p in $VALID_PYVER
do
    install_test_1_pyver $p
done
