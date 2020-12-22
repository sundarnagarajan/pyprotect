#!/bin/bash
PROG_DIR=$(readlink -e $(dirname $0))
cd "${PROG_DIR}"
python setup.py install && rm -rf build dist protected_class.egg-info
