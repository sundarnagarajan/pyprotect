#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/common_functions.sh
cd "${SOURCE_TOPLEVEL_DIR}"
rm -rf .eggs build dist pyprotect_package.egg-info
find -name '*.pyc' -exec rm -fv {} \;
