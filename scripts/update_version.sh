#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
# source "${PROG_DIR}"/common_functions.sh
cd "$PROG_DIR"/..
echo "Updating VERSION.txt"
grep '^version =' setup.py | awk -F= '{print $2}' | sed -e 's/^[[:space:]]*//g' -e "s/'//g" > VERSION.txt
