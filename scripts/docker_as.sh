#!/bin/bash
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/common_functions.sh

function show_usage() {
    >&2 echo "$SCRIPT_NAME [-|--help] [-p <PYTHON_VERSION_TAG>] [-u DOCKER_USER"
    >&2 echo "    -h | --help              : Show this help and exit"
    >&2 echo "    -p <PYTHON_VERSION_TAG>  : Use docker image for PYTHON_VERSION_TAG"
    >&2 echo "        PYTHON_VERSION_TAG   : Key of TAG_PYVER in config.sh"
    >&2 echo "    -u <DOCKER_USER>"
    >&2 echo "        DOCKER_USER          : <username | uid | uid:gid>"
}

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

VALID_PYVER=$(process_std_cmdline_args yes yes $PYVER)
[[ -z "$VALID_PYVER" ]] && exit 1
DOCKER_IMAGE=${TAG_IMAGE[$VALID_PYVER]}

docker_image_must_exist $DOCKER_IMAGE

cd "$PROG_DIR"/..
DOCKER_CMD="docker run -it --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER --env __DISTRO=${__DISTRO:-} $DOCKER_IMAGE /bin/bash"
>&2 echo $DOCKER_CMD
$DOCKER_CMD
