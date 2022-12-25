#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/docker_config.sh
DOCKER_USER="root:root"

docker image inspect $DOCKER_IMAGE 1>/dev/null 2>&1 || {
    >&2 echo "Docker image not found: $DOCKER_IMAGE"
}

cd "$PROG_DIR"/..
DOCKER_CMD="docker run -it --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER  $DOCKER_IMAGE /bin/bash"
>&2 echo $DOCKER_CMD
$DOCKER_CMD
