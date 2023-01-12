#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))

source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh


# Check that required variables are set
for v in PY3_WHEELS_DIR PYPY3_WHEELS_DIR HOST_USERNAME HOST_GROUPNAME HOST_UID HOST_GID
do
    declare -n check=${v}
    [[ ${check+x} ]] || {
        >&2 red "Required variable not set in config.sh: ${v}"
        exit 1
    }
done

IMAGE_NAME=${PY3_DOCKER_IMAGE:-$1}

cd "${PROG_DIR}"

docker build ${ADDL_ARGS:-} \
    --build-arg PY3_WHEELS_DIR="$PY3_WHEELS_DIR" \
    --build-arg PYPY3_WHEELS_DIR="$PYPY3_WHEELS_DIR" \
    --build-arg HOST_USERNAME=$HOST_USERNAME \
    --build-arg HOST_GROUPNAME=$HOST_GROUPNAME \
    --build-arg HOST_UID=$HOST_UID \
    --build-arg HOST_GID=$HOST_GID \
    -t $IMAGE_NAME .
