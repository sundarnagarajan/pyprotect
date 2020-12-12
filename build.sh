#!/bin/bash

# builds using setup.py
# If C source is not present or is older than .pyx
# cython is used to create / update C source from .pyx
# cython and cython3 produce exactly the same C source,
# so we can use which ever one is found
MOD_NAME=protected_class

PROG_DIR=$(readlink -e $(dirname $0))
cd "$PROG_DIR"
PYX_SOURCE="src/${MOD_NAME}.pyx"
C_SOURCE="src/${MOD_NAME}.c"

if [[ ! -f "$C_SOURCE" ]]; then
    REBUILD_C=yes
elif [[ "${PYX_SOURCE}" -nt "$C_SOURCE" ]]; then
    REBUILD_C=yes
else
    REBUILD_C=no
fi

if [[ "$REBUILD_C" = "yes" ]]; then
    which cython 1>/dev/null 2>&1 && HAVE_CYTHON2=yes || HAVE_CYTHON2=no
    which cython3 1>/dev/null 2>&1 && HAVE_CYTHON3=yes || HAVE_CYTHON3=no
    if [[ "$HAVE_CYTHON2" = "no" && "$HAVE_CYTHON3" = "no" ]]; then
        >&2 echo "cython and cython3 not found"
        exit 1
    fi
    if [[ "$HAVE_CYTHON2" = "yes" ]]; then
        CYTHON_PROG=cython
    else
        CYTHON_PROG=cython3
    fi
    echo "Building C source using $CYTHON_PROG"
    cython3 "${PYX_SOURCE}" || exit 2
fi

MOD_BUILD_FAILED=0
echo "Building Python 3 extension module"
python3 setup.py build_ext --inplace 1>/dev/null && rm -rf build || MOD_BUILD_FAILED=1
echo "Building Python 2 extension module"
python2 setup.py build_ext --inplace 1>/dev/null && rm -rf build || MOD_BUILD_FAILED=1

if [[ $MOD_BUILD_FAILED -eq 0 ]]; then
    echo ""
    ls -l *.so
    ls -l "$C_SOURCE"
    echo ""
    echo "Running module test"
    tests/test.sh
else
    echo "Python module build failed"
    exit 1
fi
