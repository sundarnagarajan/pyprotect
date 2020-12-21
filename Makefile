
SHELL := /bin/bash

MOD_NAME := protected_class
PYX_SOURCE := src/${MOD_NAME}.pyx
C_SOURCE := src/${MOD_NAME}.c
CYTHON_PROG := $(shell which cython3 2>/dev/null || which cython 2>/dev/null)
LS_CMD := ls -g --time-style="+%Y-%m-%d %H:%M:%S"

# Do not echo each command
.SILENT: 
.PHONY: all

# ---------- Combined targets --------------------------------------------

all: ${C_SOURCE} module

${C_SOURCE}: ${PYX_SOURCE}
	@echo Building C source using ${CYTHON_PROG}
	${CYTHON_PROG} ${PYX_SOURCE}
	${LS_CMD} ${C_SOURCE}
	@echo ""

module: python3 python2

test: test3 test2

forcetest: forcetest3 forcetest2

clean:
	@echo rm -f *.so
	rm -f *.so
	@echo rm -f src/protected_class.c
	rm -f src/protected_class.c
	@echo ""

# ---------- Python 2 targets --------------------------------------------

protected_class.so: ${C_SOURCE}
	@echo Building Python 2 extension module
	python2 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.so
	@echo ""

py2 : python2

python2: protected_class.so

test2: python2
	tests/test.sh PY2
	@echo ""

forcetest2: python2
	tests/test.sh PY2 -v
	@echo ""

# ---------- Python 3 targets --------------------------------------------

protected_class.cpython-3*.so: ${C_SOURCE}
	@echo Building Python 3 extension module
	python3 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.cpython-3*.so
	@echo ""

py3: python3

python3: protected_class.cpython-3*.so

test3: python3
	tests/test.sh PY3
	@echo ""

forcetest3: python3
	tests/test.sh PY3 -v
	@echo ""
