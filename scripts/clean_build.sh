#!/bin/bash
# Fully reusable
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
rm -rf .eggs build dist pyprotect_package.egg-info
find -name '*.pyc' -exec rm -fv {} \;
