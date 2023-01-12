#!/bin/bash
# Can be fully reused, changing only config.sh
#
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
source "$PROG_DIR"/config.sh

# Script path from docker mount path perspective
TEST_SCRIPT=${DOCKER_MOUNTPOINT}/tests/run_func_tests.sh

function red() {
    ANSI_ESC=$(printf '\033')
    ANSI_RS="${ANSI_ESC}[0m"    # reset
    ANSI_HC="${ANSI_ESC}[1m"    # hicolor
    ANSI_FRED="${ANSI_ESC}[31m" # foreground red

    echo -e "${ANSI_RS}${ANSI_HC}${ANSI_FRED}$@${ANSI_RS}"
}

[[ $# -lt 1 ]] && {
    PYVER='' 
} || {
    PYVER=$1
}
[[ "$PYVER" == "PY3" || "$PYVER" == "PY2" \
    || "$PYVER" == "PYPY3" || "$PYVER" == "PYPY2" || \
    "$PYVER" == "PYPY2" || -z "$PYVER" ]] || {
    >&2 red "Unknown PYVER: $PYVER"
    exit 1
}

cd "$PROG_DIR"/..
[[ "$PYVER" == "PY3" || -z "$PYVER" ]] && {
    docker image inspect $PY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 red "Docker image not found: $PY3_DOCKER_IMAGE"
    } && {
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY3_DOCKER_IMAGE ${TEST_SCRIPT} PY3"
        $DOCKER_CMD
    }
}
[[ "$PYVER" == "PY2" || -z "$PYVER" ]] && {
    docker image inspect $PY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 red "Docker image not found: $PY2_DOCKER_IMAGE"
    } && {
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PY2_DOCKER_IMAGE ${TEST_SCRIPT} PY2"
        $DOCKER_CMD
    }
}

[[ "$PYVER" == "PYPY3" || -z "$PYVER" ]] && {
    docker image inspect $PYPY3_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 red "Docker image not found: $PYPY3_DOCKER_IMAGE"
    } && {
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PYPY3_DOCKER_IMAGE ${TEST_SCRIPT} PYPY3"
        $DOCKER_CMD
    }
}

[[ "$PYVER" == "PYPY2" || -z "$PYVER" ]] && {
    docker image inspect $PYPY2_DOCKER_IMAGE 1>/dev/null 2>&1 || {
        >&2 red "Docker image not found: $PYPY2_DOCKER_IMAGE"
    } && {
        DOCKER_CMD="docker run --rm -v $(pwd):${DOCKER_MOUNTPOINT}:rw --user $DOCKER_USER $PYPY2_DOCKER_IMAGE ${TEST_SCRIPT} PYPY2"
        $DOCKER_CMD
    }
}
