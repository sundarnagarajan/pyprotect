#!/bin/bash
#
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/common_functions.sh

"${PROG_DIR}"/clean_build.sh
cd "$SOURCE_TOPLEVEL_DIR"
rm -rf ${PY_MODULE}/${EXTENSION_NAME}.c ${PY_MODULE}/*.so
