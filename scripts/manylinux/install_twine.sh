#!/bin/bash
set -eu -o pipefail

MANYLINUX_IMAGE=$(cat /usr/local/bin/MANYLINUX_IMAGE)

# Find highest-version PY3 version
[[ $MANYLINUX_IMAGE = "manylinux1" ]] && PYTHON_CMD=$(ls -1d /opt/python/cp3*/bin/python | sort -n | tail -1)   || PYTHON_CMD=$(ls -1d /opt/python/cp3*/bin/python | sort -V | tail -1)

# Need cryptography (older version not needing rust) for twine
[[ $MANYLINUX_IMAGE = "musllinux" ]] && {
    apk update
    apk add libffi-dev openssl-dev
} || yum install -y libffi-devel
$PYTHON_CMD -m pip install "cryptography==3.2.1" 2>/dev/null
$PYTHON_CMD -m pip install twine 2>/dev/null
TWINE=$(dirname $PYTHON_CMD)/twine
[[ -f $TWINE ]] && {
    ln -s $TWINE /usr/local/bin/
} || {
    >&2 echo "TWINE not found: $TWINE"
    exit 1
}
