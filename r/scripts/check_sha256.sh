#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/common_functions.sh
# Exit if feature is not implemented
var_empty_not_spaces FEATURES_DIR && {
    [[ $VERBOSITY -lt 4 ]] || >&2 blue "FEATURES_DIR not set"
    exit 0
}
[[ -d "${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR" ]] || {
    [[ $VERBOSITY -lt 4 ]] || >&2 blue "FEATURES_DIR not a directory: ${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR"
    exit 0
}
[[ -f "$SOURCE_TOPLEVEL_DIR"/${FEATURES_DIR}/signature.asc ]] || {
    [[ $VERBOSITY -lt 4 ]] || >&2 blue "Signature file not found: ${SOURCE_TOPLEVEL_DIR}/${FEATURES_DIR}/signature.asc"
    exit 0
}
cd "$SOURCE_TOPLEVEL_DIR"
echo "Checking SHA256 sums:"
sha256sum -c "${SOURCE_TOPLEVEL_DIR}"/${FEATURES_DIR}/signature.asc 2>&1 | grep -v '^sha256sum: WARNING: ' | sed -e 's/^/    /'
