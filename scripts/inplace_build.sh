#!/bin/bash
# Can be fully reused, changing only config.sh
#
# Expects Python basename ('python2' or 'python3' as first argument

set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/config.sh

[[ $# -lt 1 ]] && {
    >&2 echo "Usage: ${SCRIPT_NAME} <python2|python3>"
    exit 1
}
case "$1" in
    python2)
        PYTHON_BASENAME=$1
        ;;
    python3)
        PYTHON_BASENAME=$1
        ;;
    *)
        >&2 echo "Unknown argument: $1"
        >&2 echo "Usage: ${SCRIPT_NAME} <python2|python3>"
        exit 1
        ;;
esac

cd "$PROG_DIR"/..
PYTHON_CMD=$(command -v ${PYTHON_BASENAME}) && {
    # Check if .so has to be rebuilt
    PY_CODE='import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX") or "");'
    SUFFIX=$($PYTHON_CMD -c "$PY_CODE")
    [[ -z "$SUFFIX" ]] && SUFFIX=".so"
    SRC="${PY_MODULE}/${EXTENSION_NAME}.c"
    TARGET="${PY_MODULE}/${EXTENSION_NAME}${SUFFIX}"
    [[ -f "$TARGET" ]] && REBUILD_REQUIRED=0 || REBUILD_REQUIRED=1
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        [[ "$SRC" -nt "$TARGET" ]] && REBUILD_REQUIRED=1
    }
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        >&2 echo "${SCRIPT_NAME}: ${TARGET}: No rebuild required"
        exit 0
    }
    $PYTHON_CMD setup.py build_ext --inplace
} || {
    >&2 echo "${SCRIPT_NAME}: ${PYTHON_BASENAME} not found"
}
