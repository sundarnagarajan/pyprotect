#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)

cd "$PROG_DIR"/..
PYTHON_CMD=$(command -v python3) && {
    # Check if .so has to be rebuilt
    PY_CODE='import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX") or "");'
    SUFFIX=$($PYTHON_CMD -c "$PY_CODE")
    [[ -z "$SUFFIX" ]] && SUFFIX=".so"
    SRC="pyprotect/protected.c"
    TARGET="pyprotect/protected${SUFFIX}"
    [[ -f "$TARGET" ]] && REBUILD_REQUIRED=0 || REBUILD_REQUIRED=1
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        >&2 echo "${SCRIPT_NAME}: ${TARGET}: No rebuild required"
        exit 0
    }
    $PYTHON_CMD setup.py build_ext --inplace
} || {
    >&2 echo "${SCRIPT_NAME}: python3 not found"
}
