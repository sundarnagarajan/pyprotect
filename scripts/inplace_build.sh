#!/bin/bash
# Can be fully reused, changing only config.sh
#
# Expects Python basename (python2 | python3 | pypy3 | pypy) as first argument

set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
SCRIPT_NAME=$(basename $0)
source "$PROG_DIR"/config.sh
source "$PROG_DIR"/common_functions.sh


[[ $# -lt 1 ]] && {
    >&2 red "Usage: ${SCRIPT_NAME} <python2|python3|pypy3|pypy>"
    exit 1
}
case "$1" in
    python2)
        PYTHON_BASENAME=$1
        ;;
    python3)
        PYTHON_BASENAME=$1
        ;;
    pypy3)
        PYTHON_BASENAME=$1
        ;;
    pypy)
        PYTHON_BASENAME=$1
        ;;
    *)
        >&2 red "Unknown argument: $1"
        >&2 red "Usage: ${SCRIPT_NAME} <python2|python3|pypy3|pypy>"
        exit 1
        ;;
esac

# Disable pip warnings that are irrelevant here
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_PYTHON_VERSION_WARNING=1
export PIP_ROOT_USER_ACTION=ignore


cd "$PROG_DIR"/..
# Set CFLAGS to optimize further
export CFLAGS="-O3"
# Set LDFLAGS to automatically strip .so
export LDFLAGS=-s
PYTHON_CMD=$(command -v ${PYTHON_BASENAME}) && {
    # Check if .so has to be rebuilt
    PY_CODE='
import sys
import sysconfig
if sys.version_info.major == 2:
    CONFIG_KEY = "SO"
else:
    CONFIG_KEY = "EXT_SUFFIX"
print(sysconfig.get_config_var(CONFIG_KEY) or "");
'
    SUFFIX=$($PYTHON_CMD -c "$PY_CODE")
    [[ -z "$SUFFIX" ]] && SUFFIX=".so"
    SRC="${PY_MODULE}/${EXTENSION_NAME}.c"
    TARGET="${PY_MODULE}/${EXTENSION_NAME}${SUFFIX}"
    [[ "$SUFFIX" = ".so" ]] && {
        TARGET_BASENAME=$(basename "$TARGET" )
    } || {
        TARGET_BASENAME=$(basename "$TARGET" | sed -e 's/^protected\.//')
    }
    [[ -f "$TARGET" ]] && REBUILD_REQUIRED=0 || REBUILD_REQUIRED=1
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        [[ "$SRC" -nt "$TARGET" ]] && REBUILD_REQUIRED=1
    }
    [[ $REBUILD_REQUIRED -eq 0 ]] && {
        >&2 echo "${SCRIPT_NAME}: ${TARGET_BASENAME}: No rebuild required"
        exit 0
    }
    PYTHON_BASENAME=$(basename "$PYTHON_CMD")
    echo "Building ${TARGET_BASENAME} using $PYTHON_BASENAME setup.py build_ext --inplace"
    hide_output_unless_error $PYTHON_CMD setup.py build_ext --inplace
} || {
    >&2 red "${SCRIPT_NAME}: ${PYTHON_BASENAME} not found"
}
