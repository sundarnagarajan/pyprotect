#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh

function show_usage() {
    >&2 echo "$SCRIPT_NAME [-|--help] [-p <PY2  PY3>] [-u DOCKER_USER"
    >&2 echo "    -h | --help        : Show this help and exit"
    >&2 echo "    -p <PY2 | PY3>     : Use docker image for PY2 | PY3"
    >&2 echo "    -u <DOCKER_USER>"
    >&2 echo "        DOCKER_USER: <username | uid | uid:gid>"
}

DOCKER_USER="$(id -u):$(id -g)"
PYVER=PY3

while [ $# -gt 0 ];
do
    case "$1" in
        -h|--help)
            shift
            show_usage
            exit 0
            ;;
        -p)
            shift
            [[ $# -lt 1 ]] && {
                >&2 echo "Missing PYVER"
                show_usage
                exit 1
            }
            PYVER=$1
            shift
            ;;
        -u)
            shift
            [[ $# -lt 1 ]] && {
                >&2 echo "Missing DOCKER_USER"
                show_usage
                exit 1
            }
            DOCKER_USER=$1
            shift
            ;;
        *)
            >&2 echo "Unknown argument"
            show_usage
            exit 1
            ;;
    esac
done

[[ "$PYVER" = "PY3" || "$PYVER" = "PY2" ]] || {
    >&2 echo "Unknown PYVER: $PYVER"
    exit 1
}
[[ "$PYVER" = "PY3" ]] && DOCKER_IMAGE=$PY3_DOCKER_IMAGE || DOCKER_IMAGE=$PY2_DOCKER_IMAGE

docker_image_must_exist $DOCKER_IMAGE

cd "$PROG_DIR"/..
DOCKER_CMD="docker run -it --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER  $DOCKER_IMAGE /bin/bash"
>&2 echo $DOCKER_CMD
$DOCKER_CMD
