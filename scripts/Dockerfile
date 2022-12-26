
FROM ubuntu:jammy
RUN echo "export PYTHONDONTWRITEBYTECODE=Y" >> /root/.bashrc

RUN apt update
RUN apt full-upgrade -y

# On Ubuntu / Debian cannot install python-pip and python3-pip
# together - they conflict among each other
# Need pip2 (python-pip) to install pip2 under /usr/local/bin
RUN apt install -y less python2-dev python-pip python-setuptools python3-dev python3-setuptools cython3 python3-numpy
# Install pip2 under /usr/local/bin
RUN python2 -m pip install -U --force pip
# Now install python3-pip, which will uninstall python-pip
RUN apt install -y python3-pip
# Upgrade pip3 to 22.3.1 - v22.0.2+dfsg-1 has problems uninstalling packages !
RUN pip3 install -U "pip>=22.3.1"

RUN rm -rf /var/lib/apt/lists
