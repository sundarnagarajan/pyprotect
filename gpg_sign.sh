#!/bin/bash
PROG_DIR=$(readlink -e $(dirname "$0"))
cd "${PROG_DIR}"

FILES_TO_SIGN='protected_class/doc.py protected_class/__init__.py protected_class/protected.c protected_class/protected.pyx setup.cfg pyproject.toml setup.py LICENSE README.md MANIFEST.in'
sha256sum $FILES_TO_SIGN | gpg --clearsign > signature.asc
