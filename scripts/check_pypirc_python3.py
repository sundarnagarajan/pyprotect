#!/usr/bin/env -S python3 -B
# Uses two (optional) environment variables:
#   __PYPIRC    : Specifies PYPIRC file rather than default ~/.pypirc
#   __LIVEPYPI  : Use (live) 'pypi' section, rather than 'testpypi'
# By default will use 'testpypi'
# Call with __LIVEPYPI=yes host_check_pypirc_python3.py to use live Pypi.org
#
# We go a bit overboard in our checks because we expect to run twine
# within a Docker container

import sys
sys.dont_write_bytecode = True
import os
from configparser import ConfigParser


def check_pypirc():
    # Check for existence of PYPIRC file
    PYPIRC_FILE = os.path.expanduser('~/.pypirc')
    if '__PYPIRC' in os.environ:
        PYPIRC_FILE = os.path.expanduser(os.environ.get('__PYPIRC', ''))
    if not os.path.isfile(PYPIRC_FILE):
        sys.stderr.write('PYPIRC not found: %s\n' % (PYPIRC_FILE,))
        return False

    # Check PYPIRC_FILE
    cfg = ConfigParser()
    try:
        cfg.read(filenames=[PYPIRC_FILE])
    except Exception as e:
        sys.stderr.write('Error reading PYPIRC: %s\n' % (PYPIRC_FILE,))
        sys.stderr.write('%s\n' % (str(e),))
        return False

    # Check for required section
    PYPIRC_SECTION = 'testpypi'
    if '__LIVEPYPI' in os.environ and os.environ.get('__LIVEPYPI', ''):
        PYPIRC_SECTION = 'pypi'
    if PYPIRC_SECTION not in cfg.sections():
        sys.stderr.write('Section %s not found in %s\n' % (
            PYPIRC_SECTION, PYPIRC_FILE
        ))
        return False

    # Check for required keys and values in section
    sec_dict = dict(cfg.items(section=PYPIRC_SECTION))
    for k in ('username', 'password'):
        if k not in sec_dict:
            sys.stderr.write('Key %s not found in section %s\n' % (
                k, PYPIRC_SECTION
            ))
            return False
        if not sec_dict[k]:
            sys.stderr.write('No value for key %s in section %s\n' % (
                k, PYPIRC_SECTION
            ))
            return False

    # Check 'distutils' section key 'index-servers'
    if 'distutils' not in cfg.sections():
        sys.stderr.write('Section %s not found in %s\n' % (
            'distutils', PYPIRC_FILE
        ))
        return False
    if not cfg.has_option('distutils', 'index-servers'):
        sys.stderr.write('Key %s not found in section %s\n' % (
            'index-servers', 'distutils'
        ))
        return False
    # Need to parse value of 'index-servers'
    servers_val = cfg.get('distutils', 'index-servers')
    servers_val = [x for x in servers_val.splitlines() if x]
    if PYPIRC_SECTION not in servers_val:
        sys.stderr.write('%s not found in value of %s in section %s' % (
            PYPIRC_SECTION, 'index-servers', 'distutils'
        ))

    return True


if __name__ == '__main__':
    if not check_pypirc():
        exit(1)
