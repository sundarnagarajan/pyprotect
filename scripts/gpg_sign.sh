#!/bin/bash
set -eu -o pipefail
# Need gpg2 (preferred) or gpg
GPG_CMD=$(command -v gpg2)  || {
    GPG_CMD=$(command -v gpg) || {
        >&2 echo "Neither gpg2 nor gpg command was found"
        >&2 echo "On Debian-like systems you need to install package gnupg2"
        exit 1
    }
}


PROG_DIR=$(readlink -e $(dirname "$0"))
cd "${PROG_DIR}"/..

FILES_TO_SIGN=$(cat signed_files.txt)
GPG_KEY=3DCAB9392661EB519C4CCDCC5CFEABFDEFDB2DE3
sha256sum $FILES_TO_SIGN | gpg --default-key $GPG_KEY --clearsign > signature.asc
