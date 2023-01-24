#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(readlink -e $(dirname $0))
# Just call host_distro_test.sh

__MINIMAL_TESTS=yes "${PROG_DIR}"/host_distro_test.sh $@
