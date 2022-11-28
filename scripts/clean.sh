#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"/..
rm -rf .eggs build dist protected_class.egg-info protected_class/*.so
