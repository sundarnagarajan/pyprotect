#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/common_functions.sh
cd "$SOURCE_TOPLEVEL_DIR"
echo "Updating MANIFEST.in"
git ls-files | grep "^${PY_MODULE}/" | sed -e 's/^/include /' | LC_ALL=C sort > "${SOURCE_TOPLEVEL_DIR}"/MANIFEST.in
