#!/usr/bin/sh
PROG_DIR=$(readlink -e $(dirname $0))
cd "$PROG_DIR"/pyprotect
PYDOC_CMD=""
PYDOC_CMD=$(command -v pydoc3)
[ $? -eq 0 ] && exec $PYDOC_CMD protected
PYDOC_CMD=$(command -v pydoc2)
[ $? -eq 0 ] && exec $PYDOC_CMD protected
