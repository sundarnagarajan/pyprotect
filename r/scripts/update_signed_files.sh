#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/common_functions.sh
# Exit if feature is not implemented
var_empty_not_spaces FEATURES_DIR && {
    >&2 blue "FEATURES_DIR not set"
    exit 1
}
[[ -d "${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR" ]] || {
    >&2 blue "FEATURES_DIR not a directory: ${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR"
    exit 1
}
cd "$SOURCE_TOPLEVEL_DIR"

echo "Updating signed_files.txt"
# Do not add signature.asc
git ls-files | fgrep -vx ${FEATURES_DIR}/signature.asc | LC_ALL=C sort > ${FEATURES_DIR}/signed_files.txt
