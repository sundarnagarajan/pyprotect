#!/bin/bash
# See: https://python-packaging-tutorial.readthedocs.io/en/latest/uploading_pypi.html
# In Particular, see:
#   https://python-packaging-tutorial.readthedocs.io/en/latest/uploading_pypi.html#python-package-lifecycle
#
# Also see https://packaging.python.org/en/latest/guides/using-testpypi/
#
# Also see for pypirc:
#   https://packaging.python.org/en/latest/specifications/pypirc/
#
set -eu -o pipefail
PROG_DIR=$(readlink -e $(dirname "$0"))
cd "${PROG_DIR}"/..

./clean.sh
./check_sha256.sh
./check_sig.sh
python setup.py sdist && \
    twine upload --verbose dist/* && \
    ./clean.sh
