#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/config.sh
cd "$PROG_DIR"/..
echo "Updating MANIFEST.in"
git ls-files | grep "^${PY_MODULE}/" | sed -e 's/^/include /' | LC_ALL=C sort > "${PROG_DIR}"/../MANIFEST.in
