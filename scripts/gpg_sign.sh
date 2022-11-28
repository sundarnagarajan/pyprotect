#!/bin/bash
PROG_DIR=$(readlink -e $(dirname "$0"))
cd "${PROG_DIR}"/..

FILES_TO_SIGN=$(cat signed_files.txt)
sha256sum $FILES_TO_SIGN | gpg --clearsign > signature.asc
