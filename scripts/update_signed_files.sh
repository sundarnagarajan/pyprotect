#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
echo "Updating signed_files.txt"
# Do not sign signature.asc
git ls-files | fgrep -vx signature.asc | LC_ALL=C sort > "${PROG_DIR}"/../signed_files.txt
