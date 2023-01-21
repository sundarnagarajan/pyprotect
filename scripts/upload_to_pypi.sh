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
# To uplad to testpypi using twine:
#   twine upload --repository testpypi dist/*
#
# To install with pip from testpypi:
#   python3 -m pip install --index-url https://test.pypi.org/simple/ your-package
#
# Building and uploading wheels for Linux is more complex
# See: https://github.com/pypa/manylinux
# Build and twine upload needs to be done inside special docker images
# ONLY PY3 and PYPY3 are supported
# So PY2 and PYPY2 will not get wheels
#
# auditwheel - see: https://github.com/pypa/auditwheel
# auditwheel works for building on ubuntu and wheel install from PyPi
# works on Ubuntu, Arch, Fedora (python 3.10)
# Wheel was not used on alpine
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
