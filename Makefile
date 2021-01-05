
SHELL := /bin/bash

MOD_NAME := protected_class
PYX_SOURCE := src/cython/${MOD_NAME}.pyx
C_SOURCE_2 := src/c/2/${MOD_NAME}.c
C_SOURCE_3 := src/c/3/${MOD_NAME}.c
CYTHON_PROG := $(shell which cython 2>/dev/null || which cython3 2>/dev/null || which cython 2>/dev/null)
LS_CMD := ls -g --time-style="+%Y-%m-%d %H:%M:%S"
RUN_TEST_FILE := tests/run_tests.sh

# Do not echo each command
.SILENT:
.PHONY: help
help:    ## Show this help
	@echo -e "$$(grep -hE '^\S+[ ]*:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[34m\\x1b[1m\1\\x1b[0m:\2/' | column -c2 -t -s :)"


# ---------- Combined targets --------------------------------------------

${C_SOURCE_2}: ${PYX_SOURCE}
	@echo Building C source using ${CYTHON_PROG}
	${CYTHON_PROG} -2 ${PYX_SOURCE} -o ${C_SOURCE_2} 1>/dev/null
	${LS_CMD} ${C_SOURCE_2}
	@echo ""

${C_SOURCE_3}: ${PYX_SOURCE}
	@echo Building C source using ${CYTHON_PROG}
	${CYTHON_PROG} -3 ${PYX_SOURCE} -o ${C_SOURCE_3} 1>/dev/null
	${LS_CMD} ${C_SOURCE_3}
	@echo ""

module: py3 py2    ## (PY2 and PY3) Build modules

test: module test3 test2   ## (PY2 and PY3) Build and test modules

vtest: module vtest3 vtest2    ## (PY2 and PY3) Build and test module (VERBOSE)

clean:    ## (PY2 and PY3) Remove built modules
	@echo rm -f protected_class.so protected_class.cpython-3*.so
	rm -f protected_class.so protected_class.cpython-3*.so
	@echo ""

# ---------- Python 3 targets --------------------------------------------

protected_class.cpython-3*.so: ${C_SOURCE_3}
	@echo Building Python 3 extension module
	python3 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.cpython-3*.so
	nm -D -g --defined-only protected_class.cpython-3*.so | sed -e 's/^/    /'
	@echo ""

py3: protected_class.cpython-3*.so       ## PY3 Build module

test3: py3       ## PY3 Build and test module
	${RUN_TEST_FILE} PY3
	@echo ""

vtest3: py3       ## PY3 Build and test module (VERBOSE)
	${RUN_TEST_FILE} PY3 -v
	@echo ""

# ---------- Python 2 targets --------------------------------------------

protected_class.so: ${C_SOURCE_2}
	@echo Building Python 2 extension module
	python2 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.so
	nm -D -g --defined-only protected_class.so | sed -e 's/^/    /'
	@echo ""

py2: protected_class.so       ## PY2 Build module

test2: py2       ## PY2 Build and test module
	${RUN_TEST_FILE} PY2
	@echo ""

vtest2: py2     ## PY2 Build and test module (VERBOSE)
	${RUN_TEST_FILE} PY2 -v
	@echo ""
