#!/bin/bash
set -e -u -o pipefail
CYTHON_CMD=$(command -v cython3) || {
    >&2 echo "cython3 command not found"
    >&2 echo "On Debian-like system install package cython3"
    exit 1
}

PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/../pyprotect
$CYTHON_CMD --3str protected.pyx
