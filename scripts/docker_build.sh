#!/bin/bash
# Can be fully reused, changing only config.sh
#
# config.sh supports having separate Docker images for
# Cython3, PY3, PY2, PYPY3, PYPY2
#   TAG_IMAGE
#
# Following scripts source config.sh and use these variables:
#   build_in_place_in_docker.sh
#   install_test_in_docker.sh
#   test_in_docker.sh
#
# At this time, this script and Dockerfile use a SINGLE Docker image for
# Cython3, PY3, PY2, PYPY3, PYPY2
#
# To split out into multiple Docker images, following changes will be required:
#   - Changes to this script
#   - Changes to config.sh: variables specifying separate Dockerfiles
#   - Creating / splitting out into separate Dockerfiles


set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))

source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh


# Check that required variables are set
for v in HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID
do
    declare -n check=${v}
    [[ ${check+x} ]] || {
        >&2 red "Required variable not set in config.sh: ${v}"
        exit 1
    }
done
[[ -n $(declare -p DOCKERFILE_IMAGE 2>/dev/null) ]] || {
    >&2 red "Required variable not set in config.sh: DOCKERFILE_IMAGE" 
    exit 1
}

cd "${PROG_DIR}"

for k in ${!DOCKERFILE_IMAGE[@]}
do
    IMAGE_NAME=${DOCKERFILE_IMAGE[$k]}
    [[ ${IMAGE_NAME}+x == "x" ]] && {
        >&2 red "Image name not found for Docker file: $k"
        exit 1
    }
    >&2 red "Building $IMAGE_NAME from $k"

    docker build ${ADDL_ARGS:-} \
        --build-arg HOST_USERNAME=$HOST_USERNAME \
        --build-arg HOST_GROUPNAME=$HOST_GROUPNAME \
        --build-arg HOST_UID=$HOST_UID \
        --build-arg HOST_GID=$HOST_GID \
        --build-arg HOME_DIR=/home \
        --build-arg PYPROTECT_DIR=/${PY_MODULE} \
        -t $IMAGE_NAME -f $k .
done



