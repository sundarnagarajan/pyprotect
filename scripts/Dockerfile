
FROM ubuntu:jammy
# ----------------------------------------------------------------------
# Common things to always do
# ----------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg-reconfigure debconf --frontend=noninteractive
RUN apt-config dump | grep -we Recommends -e Suggests | sed s/1/0/ > /etc/apt/apt.conf.d/999no_recommend_suggests
# Next 3 lines are required for pydoc2 to show unicode data
ENV LANG=en_US.UTF-8
ENV LANGUAGE=$LANG
ENV LC_ALL=$LANG

RUN rm -rf /var/lib/apt/lists/*
RUN apt-get clean
RUN apt-get update
RUN apt-get install -y apt-utils locales 2>/dev/null
# Next 2 lines are required for pydoc2 to show unicode data
RUN locale-gen $LANG 2>/dev/null
RUN dpkg-reconfigure locales 2>/dev/null
RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y

RUN echo "export PYTHONDONTWRITEBYTECODE=Y" >> /root/.bashrc

# Need build-essential python2-dev python3-dev and cython3 ONLY to BUILD module
# These are not required to install from PyPi or from bdist / wheel
# python3-numpy is used in a unit (test test_62_matmul)
RUN apt-get install -y curl less unzip build-essential python2-dev python-setuptools python3-dev python3-setuptools cython3 python3-numpy python3-pip

# On Ubuntu / Debian cannot install python-pip and python3-pip
# together - they conflict among each other
# Install pip2 from https://bootstrap.pypa.io/get-pip.py
RUN curl -s https://raw.githubusercontent.com/pypa/get-pip/main/public/2.7/get-pip.py | python2

# Upgrade pip3 to 22.3.1 - v22.0.2+dfsg-1 has problems uninstalling packages !
# AttributeError: 'EggMetadata' object has no attribute 'isdir'
# Silence irrelevant warning about running pip as root user
RUN pip3 install -U "pip>=22.3.1" 2>/dev/null

# python2-setuptools-whl and python2-pip-whl are only needed to create
# PY2 virtualenv using virtualenv command
# RUN apt install -y python2-setuptools-whl python2-pip-whl

# ----------------------------------------------------------------------
# For installing pypy from PPA
RUN apt-get install -y apt-transport-https ca-certificates gnupg dirmngr curl less
WORKDIR /etc/apt/repo-keyrings
RUN curl -sL "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2862D0785AFACD8C65B23DB0251104D968854915" | gpg --dearmor > pypy.gpg
WORKDIR /etc/apt/sources.list.d
RUN echo "deb [ arch=amd64 signed-by=/etc/apt/repo-keyrings/pypy.gpg ] https://ppa.launchpadcontent.net/pypy/ppa/ubuntu jammy main" > pypy.list
RUN apt-get update
RUN apt-get install -y pypy3 pypy3-dev

# Rest is only to install numpy for pypy3

# cython >= 0.29.30 needed to BUILD numpy module for pypy3
RUN pypy3 -m pip install "cython >= 0.29.30"
WORKDIR /root
RUN rm -f *.whl
RUN >&2 echo "Building numpy wheel - takes 8-10 minutes"
RUN pypy3 -m pip wheel numpy
RUN pypy3 -m pip install numpy-*.whl
RUN rm -f *.whl
RUN pypy3 -m pip uninstall -y cython
# ----------------------------------------------------------------------

RUN rm -rf /var/lib/apt/lists
