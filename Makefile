
SHELL := /bin/bash

MOD_NAME := protected_class
PYX_SOURCE := src/${MOD_NAME}.pyx
C_SOURCE := src/${MOD_NAME}.c
CYTHON_PROG := $(shell which cython3 2>/dev/null || which cython 2>/dev/null)
LS_CMD := ls -g --time-style="+%Y-%m-%d %H:%M:%S"


# Do not echo each command
.SILENT: 

all: ${C_SOURCE} module
.PHONY: all

${C_SOURCE}: ${PYX_SOURCE}
	@echo Building C source using ${CYTHON_PROG}
	${CYTHON_PROG} ${PYX_SOURCE}
	${LS_CMD} ${C_SOURCE}

module: python3 python2

py2 : python2

py3: python3

python2: protected_class.so

python3: protected_class.cpython-3*.so

protected_class.cpython-3*.so: ${C_SOURCE}
	@echo Building Python 3 extension module
	python3 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.cpython-3*.so

protected_class.so: ${C_SOURCE}
	@echo Building Python 2 extension module
	python2 setup.py build_ext --inplace 1>/dev/null && rm -rf build
	${LS_CMD} protected_class.so

.tested3: protected_class.cpython-3*.so
	tests/test.sh PY3
	touch .tested3

.tested2: protected_class.so
	tests/test.sh PY2
	touch .tested2

test: .tested3 .tested2

forcetest:
	tests/test.sh PY3 -v
	tests/test.sh PY2 -v

clean:
	rm -f *.so
	rm -f src/protected_class.c
	rm -f .tested3 .tested2

testclean:
	rm -f .tested3 .tested2
