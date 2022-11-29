#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
rm -rf .eggs build dist pyprotect.egg-info pyprotect/*.so
