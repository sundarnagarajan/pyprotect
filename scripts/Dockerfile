
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

# On Ubuntu / Debian cannot install python-pip and python3-pip
# together - they conflict among each other
# Need pip2 (python-pip) to install pip2 under /usr/local/bin
# Need python2-dev python3-dev and cython3 ONLY to BUILD module
# These are not required to install from PyPi or from bdist / wheel
# python3-numpy is used in a unit test test_62_matmul)
RUN apt-get install -y less unzip build-essential python2-dev python-pip python-setuptools python3-dev python3-setuptools cython3 python3-numpy
# Install pip2 under /usr/local/bin
RUN python2 -m pip install -U --force --no-python-version-warning pip
# Now install python3-pip, which will uninstall python-pip
RUN apt-get install -y python3-pip
# Upgrade pip3 to 22.3.1 - v22.0.2+dfsg-1 has problems uninstalling packages !
# AttributeError: 'EggMetadata' object has no attribute 'isdir'
# Silence irrelevant warning about running pip as root user
RUN pip3 install -U "pip>=22.3.1" 2>/dev/null

RUN rm -rf /var/lib/apt/lists
