#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/config.sh
DOCKER_USER="$(id -u):$(id -g)"

[[ $# -lt 1 ]] && {
    PYVER='' 
} || {
    PYVER=$1
}
[[ "$PYVER" == "PY3" || "$PYVER" == "PY2" || -z "$PYVER" ]] || {
    >&2 echo "Unknown PYVER: $PYVER"
    exit 1
}
[[ -z "$PYVER" ]] && PYVER=PY3
[[ "$PYVER" = "PY3" ]] && DOCKER_IMAGE=$PY3_DOCKER_IMAGE || DOCKER_IMAGE=$PY2_DOCKER_IMAGE

docker image inspect $DOCKER_IMAGE 1>/dev/null 2>&1 || {
    >&2 echo "Docker image not found: $DOCKER_IMAGE"
}

cd "$PROG_DIR"/..
DOCKER_CMD="docker run -it --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER  $DOCKER_IMAGE /bin/bash"
>&2 echo $DOCKER_CMD
$DOCKER_CMD
