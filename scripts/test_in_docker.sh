#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh

must_not_be_in_docker

# Script path from docker mount path perspective
TEST_SCRIPT=${DOCKER_MOUNTPOINT}/scripts/run_func_tests.sh


function test_1_pyver() {
    # $1: PYVER - guaranteed to be in TAG_PYVER and have valid image in TAG_IMAGE
    local pyver=$1
    local img=${TAG_IMAGE[${pyver}]}
    cd "$PROG_DIR"/..
    DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $img ${TEST_SCRIPT} $pyver"
    $DOCKER_CMD
}

# Will be running build in docker, so need image validation
VALID_PYVER=$(process_std_cmdline_args yes yes $@)

for p in $VALID_PYVER
do
    test_1_pyver $p
done

