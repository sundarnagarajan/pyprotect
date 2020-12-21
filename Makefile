
SHELL := /bin/bash

MOD_NAME := protected_class
PYX_SOURCE := protected_class_src/cython/${MOD_NAME}.pyx
C_SOURCE := protected_class_src/c/${MOD_NAME}.c
CYTHON_PROG := $(shell which cython3 2>/dev/null || which cython 2>/dev/null)
LS_CMD := ls -g --time-style="+%Y-%m-%d %H:%M:%S"
RUN_TEST_FILE := protected_class_src/tests/run_tests.sh

# Do not echo each command
.SILENT: 
.PHONY: all

# ---------- Combined targets --------------------------------------------

all: ${C_SOURCE} module

${C_SOURCE}: ${PYX_SOURCE}
	@echo Building C source using ${CYTHON_PROG}
	${CYTHON_PROG} ${PYX_SOURCE} -o ${C_SOURCE}
	${LS_CMD} ${C_SOURCE}
	@echo ""

module: python3 python2

test: module test3 test2

forcetest: module forcetest3 forcetest2

clean:
	@echo rm -f protected_class.so protected_class.cpython-3*.so
	rm -f protected_class.so protected_class.cpython-3*.so
	@echo ""

# ---------- Python 2 targets --------------------------------------------

protected_class.so: ${C_SOURCE}
	@echo Building Python 2 extension module
	python2 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.so
	nm -D -g --defined-only protected_class.so | sed -e 's/^/    /'
	@echo ""

py2 : python2

python2: protected_class.so

test2: python2
	${RUN_TEST_FILE} PY2
	@echo ""

forcetest2: python2
	${RUN_TEST_FILE} PY2 -v
	@echo ""

# ---------- Python 3 targets --------------------------------------------

protected_class.cpython-3*.so: ${C_SOURCE}
	@echo Building Python 3 extension module
	python3 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.cpython-3*.so
	nm -D -g --defined-only protected_class.cpython-3*.so | sed -e 's/^/    /'
	@echo ""

py3: python3

python3: protected_class.cpython-3*.so

test3: python3
	${RUN_TEST_FILE} PY3
	@echo ""

forcetest3: python3
	${RUN_TEST_FILE} PY3 -v
	@echo ""
