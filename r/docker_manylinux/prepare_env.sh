#!/bin/bash
set -eu -o pipefail
source /usr/local/bin/manylinux_functions.sh || exit 1

# Find highest-version PY3 version
PYTHON_CMD=$(python3_latest_version)

# Need bash 5 (associative arrays, 'declare -n')
[[ "${BASH_VERSINFO[0]}" -lt 5 ]] && {
    echo "Installing bash 5.0"
    cd /tmp
    mkdir bash
    cd bash
    [[ $MANYLINUX_IMAGE = "musllinux" ]] && {
        apk add wget
    } || {
        yum install -y --quiet wget
    }
    wget -q -O - http://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz | tar zx
    cd bash-5.0
    ./configure --prefix=/ 1>/dev/null && make -j32 1>/dev/null && make install 1>/dev/null
    cd /
    rm -rf /tmp/bash
}

# Need cryptography (older version not needing rust) for twine
[[ $MANYLINUX_IMAGE = "musllinux" ]] && {
    apk update
    apk add libffi-dev --quiet openssl-dev
} || yum install -y --quiet libffi-devel
$PYTHON_CMD -m pip install "cryptography==3.2.1" 2>/dev/null
$PYTHON_CMD -m pip install twine 2>/dev/null
TWINE=$(dirname $PYTHON_CMD)/twine
[[ -f $TWINE ]] && {
    ln -s $TWINE /usr/local/bin/
} || {
    >&2 red "TWINE not found: $TWINE"
    exit 1
}
