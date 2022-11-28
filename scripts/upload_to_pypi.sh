#!/bin/bash
set -eu -o pipefail
PROG_DIR=$(readlink -e $(dirname "$0"))
cd "${PROG_DIR}"/..

./clean.sh
./check_sha256.sh
./check_sig.sh
python setup.py sdist && \
    twine upload --verbose dist/* && \
    ./clean.sh
