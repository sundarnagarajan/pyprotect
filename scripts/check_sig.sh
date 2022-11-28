#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
gpg --verify signature.asc
