#!/bin/bash
set -e -u -o pipefail
PROG_DIR=$(dirname $0)
cd "$PROG_DIR"
cd  protected_class
cython3 --3str protected.pyx
