#!/bin/bash
# Fully resuable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
source "${PROG_DIR}"/common_functions.sh
# Exit if feature is not implemented
var_empty_not_spaces FEATURES_DIR && {
    >&2 blue "FEATURES_DIR not set"
    exit 0
}
[[ -d "${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR" ]] || {
    >&2 blue "FEATURES_DIR not a directory: ${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR"
    exit 0
}
cd "$SOURCE_TOPLEVEL_DIR"/$FEATURES_DIR
[[ -f signature.asc ]] || {
    >&2 blue "Signature file not found: ${SOURCE_TOPLEVEL_DIR}/${FEATURES_DIR}/signature.asc"
    exit 0
}
# Need gpg2 (preferred) or gpg
GPG_CMD=$(command -v gpg2)  || {
    GPG_CMD=$(command -v gpg) || {
        >&2 echo "Neither gpg2 nor gpg command was found"
        >&2 echo "On Debian-like systems you need to install package gnupg2"
        exit 1
    }
}

$GPG_CMD --verify signature.asc
