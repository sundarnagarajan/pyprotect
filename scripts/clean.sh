#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
"${PROG_DIR}"/clean_build.sh
cd "$PROG_DIR"/..
rm -rf pyprotect/*.so
