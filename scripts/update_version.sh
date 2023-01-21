#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $BASH_SOURCE)
source "${PROG_DIR}"/common_functions.sh
ver=$(get_version)
[[ -z "$ver" ]] && {
    >&2 red "Version number not found"
    exit 1
}
echo "Updating VERSION.txt"
echo "$ver" > "${PROG_DIR}"/../VERSION.txt
