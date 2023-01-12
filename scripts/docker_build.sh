#!/bin/bash
# Can be fully reused, changing only config.sh
#
# config.sh supports having separate Docker images for
# Cython3, PY3, PY2, PYPY3, PYPY2
#	PY3_DOCKER_IMAGE
#	PY2_DOCKER_IMAGE
#	PYPY3_DOCKER_IMAGE
#	PYPY2_DOCKER_IMAGE
#	CYTHON3_DOCKER_IMAGE
#
# Following scripts source config.sh and use these variables:
#   build_in_place_in_docker.sh
#   install_test_in_docker.sh
#   test_in_docker.sh
#
# At this time, this script and Dockerfile use a SINGLE Docker image for
# Cython3, PY3, PY2, PYPY3, PYPY2
#
# If / when we want to split out into multiple DOcker images, following
# changes will be required:
#   - Changes to this script
#   - Changes to config.sh: variables specifying separate Dockerfiles
#   - Createing / splitiing out into separate Dockerfiles


set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))

source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh


# Check that required variables are set
for v in PY3_WHEELS_DIR PYPY3_WHEELS_DIR HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID PY3_DOCKER_IMAGE
do
    declare -n check=${v}
    [[ ${check+x} ]] || {
        >&2 red "Required variable not set in config.sh: ${v}"
        exit 1
    }
done

IMAGE_NAME=${PY3_DOCKER_IMAGE}

cd "${PROG_DIR}"

docker build ${ADDL_ARGS:-} \
    --build-arg PY3_WHEELS_DIR="$PY3_WHEELS_DIR" \
    --build-arg PYPY3_WHEELS_DIR="$PYPY3_WHEELS_DIR" \
    --build-arg HOST_USERNAME=$HOST_USERNAME \
    --build-arg HOST_GROUPNAME=$HOST_GROUPNAME \
    --build-arg HOST_UID=$HOST_UID \
    --build-arg HOST_GID=$HOST_GID \
    --build-arg HOME_DIR=$DOCKER_MOUNTPOINT \
    -t $IMAGE_NAME .
