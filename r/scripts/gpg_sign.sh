#!/bin/bash
# ---------- Should not need to change anything after this ---------------
set -eu -o pipefail
PROG_DIR=$(readlink -f $(dirname "$0"))
source "${PROG_DIR}"/common_functions.sh
# Exit if feature is not implemented
var_empty_not_spaces GPG_KEY && {
    >&2 blue "GPG_KEY not set"
}
var_empty_not_spaces FEATURES_DIR && {
    >&2 blue "FEATURES_DIR not set"
    exit 0
}
[[ -d "${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR" ]] || {
    >&2 blue "FEATURES_DIR not a directory: ${SOURCE_TOPLEVEL_DIR}/$FEATURES_DIR"
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

"${PROG_DIR}"/update_signed_files.sh
cd "$SOURCE_TOPLEVEL_DIR"/$FEATURES_DIR
FILES_TO_SIGN=$(cat signed_files.txt)
cd "$SOURCE_TOPLEVEL_DIR"
sha256sum $FILES_TO_SIGN | gpg --default-key "$GPG_KEY" --clearsign > "${FEATURES_DIR}"/signature.asc
