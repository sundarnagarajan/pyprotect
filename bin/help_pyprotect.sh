#!/usr/bin/sh
PROG_DIR=$(readlink -e $(dirname $0))

PYTHON_CMD=$(command -v python3) && PYDOC_CMD=pydoc3 || {
    PYTHON_CMD=$(command -v python2) && PYDOC_CMD=pydoc2
}
[ -z "$PYTHON_CMD" ] && {
    >&2 echo "Neither python2 nor python3 found"
    exit 1
}
command -v $PYDOC_CMD 1>/dev/null 2>&1 || {
    >&2 echo "$PYDOC_CMD not found"
    exit 1
}
export __Protected_NOFREEZE_MODULE_____=yes
$PYTHON_CMD -c "import pyprotect" 2>/dev/null && exec "$PYDOC_CMD" pyprotect || {
    cd "$PROG_DIR" && \
    $PYTHON_CMD -c "import pyprotect" 2>/dev/null && exec "$PYDOC_CMD" pyprotect || {
        >&2 echo "pyprotect module not found"
        exit 1
    }
}
