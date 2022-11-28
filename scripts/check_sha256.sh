#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
echo "Checking SHA256 sums:"
sha256sum -c signature.asc 2>&1 | grep -v '^sha256sum: WARNING: ' | sed -e 's/^/    /'
