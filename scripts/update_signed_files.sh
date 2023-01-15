#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
echo "Updating signed_files.txt"
git ls-files | LC_ALL=C sort > "${PROG_DIR}"/../signed_files.txt
