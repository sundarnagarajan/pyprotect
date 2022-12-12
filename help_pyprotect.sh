#!/usr/bin/sh
PROG_DIR=$(readlink -e $(dirname $0))

PYPROTECT_DIR_CMD='import pyprotect; import os; print(os.path.dirname(pyprotect.__file__))'
PYPROTECT_DIR=""
PYTHON_CMD=$(command -v python3) && PYDOC_CMD=pydoc3 || {
    PYTHON_CMD=$(command -v python2) && PYDOC_CMD=pydoc2
}
[ -z "$PYTHON_CMD" ] && {
    >&2 echo "Neither python2 nor python3 found"
    exit 1
}
command -v $PYDOC_CMD || {
    >&2 echo "$PYDOC_CMD not found"
    exit 1
}

PYPROTECT_DIR=$($PYTHON_CMD -c "$PYPROTECT_DIR_CMD")
cd "$PYPROTECT_DIR"
exec "$PYDOC_CMD" protected
