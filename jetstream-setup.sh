#!/bin/bash -ex

## Run this script as root (with sudo)
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script must be run as root to install packages."
    echo "Become root with: sudo -i"
    exit
fi

## only run this script once, if docker is not already installed
if [ -e /var/log/jetstream-setup.done ]; then
  echo "setup script has already been run according to /var/log/jetstream-setup.done"
  exit
fi

## From official Docker recommendations for installing on Ubuntu 14.04 (trusty):
##    https://docs.docker.com/engine/installation/linux/ubuntu/

apt-get update

## Recommended extra packages for Trusty 14.04¶
##    Unless you have a strong reason not to, install the linux-image-extra-*
##    packages, which allow Docker to use the aufs storage drivers.
apt-get install -y --no-install-recommends \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual

## Set up the repository
apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://apt.dockerproject.org/gpg | apt-key add -
apt-key fingerprint 58118E89F3A912897C070ADBF76221572C52609D
add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       ubuntu-$(lsb_release -cs) \
       main"

apt-get update
apt-get -y upgrade
apt-get -y install docker-engine

## latest Docker version as of 2017-02-23
# $ apt-cache madison docker-engine
##  docker-engine | 1.13.1-0~ubuntu-trusty | https://apt.dockerproject.org/repo/ ubuntu-trusty/main amd64 Packages
##  docker-engine | 1.13.0-0~ubuntu-trusty | https://apt.dockerproject.org/repo/ ubuntu-trusty/main amd64 Packages
##    ...

## Wrapper script to avoid explicitly requiring sudo to use docker (since
## examples for Docker on Mac and Docker on Windows do not require it).

# cat > /usr/local/bin/docker <<EOF
# #!/bin/bash
#
# sudo /usr/bin/docker $*
# EOF
# chmod 755 /usr/local/bin/docker

## add default Jetstream user (uid:1000) to docker group so the user does not
## have to type `sudo docker` each time.
## https://www.explainxkcd.com/wiki/index.php/149:_Sandwich
JETSTREAM_USER=$(getent passwd 1000 | cut -d: -f1)
adduser $JETSTREAM_USER docker

## install Globus Personal Connect
wget --directory-prefix=/usr/local https://s3.amazonaws.com/connect.globusonline.org/linux/stable/globusconnectpersonal-2.3.3.tgz
(cd /usr/local && tar zxvf globusconnectpersonal-2.3.3.tgz)
(cd /usr/local/bin && ln -s ../globusconnectpersonal-2.3.3/globusconnect)

## This should be the last line so that we only run the script once, per the
## check at the start of the script
touch /var/log/jetstream-setup.done
echo "Setup completed successfully"
echo
echo "Restarting system in 60 seconds so all changes take effect."
echo "Hit Ctrl-C to abort this automatic reboot."

/sbin/shutdown -r +1

