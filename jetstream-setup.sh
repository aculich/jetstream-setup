#!/bin/bash -ex

## latest versions as of 2017-03-24
# $ apt-cache madison docker-engine
##  docker-engine | 17.03.0~ce-0~ubuntu-trusty | https://apt.dockerproject.org/repo/ ubuntu-trusty/main amd64 Packages
##  docker-engine | 1.13.1-0~ubuntu-trusty     | https://apt.dockerproject.org/repo/ ubuntu-trusty/main amd64 Packages
##  docker-engine | 1.13.0-0~ubuntu-trusty     | https://apt.dockerproject.org/repo/ ubuntu-trusty/main amd64 Packages
##    ...

DOCKER_VERSION=17.03.0~ce-0
GLOBUS_VERSION=2.3.3
SINGULARITY_VERSION=2.2.1

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
apt-get -y upgrade

## Recommended extra packages for Trusty 14.04
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
       ubuntu-$(lsb_release -c -s) \
       main"

apt-get update

VERSION=${DOCKER_VERSION}~ubuntu-$(lsb_release -c -s)
apt-get -y install docker-engine=$VERSION

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

## automatically install and enable byobu for the default Jetstream user
apt-get -y install byobu
sudo -u $JETSTREAM_USER -i /usr/bin/byobu-launcher-install

## Make sure some basic cloud utilities are installed
## OpenStack, AWS, Azure, GCloud, Kubernetes
apt-get install -y --no-install-recommends \
	python3-pip \
	python3-yaml \
	python3-dev \
	libffi-dev \
	libssl-dev

pip3 install --upgrade setuptools
pip3 install pytz
pip3 install python-openstackclient
pip3 install awscli

## https://cloud.google.com/sdk/downloads#apt-get
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install --yes google-cloud-sdk
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

## https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
## only a wheezy (not trusty) repo is provided for azure-cli
#echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/azure-cli/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/azure-cli/ wheezy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-key adv --keyserver apt-mo.trafficmanager.net --recv-keys 417A0893
sudo apt-get install --yes apt-transport-https
sudo apt-get update && sudo apt-get install --yes azure-cli


## install Globus Personal Connect
VERSION=$GLOBUS_VERSION
wget --directory-prefix=/usr/local https://s3.amazonaws.com/connect.globusonline.org/linux/stable/globusconnectpersonal-$VERSION.tgz
(cd /usr/local && tar zxvf globusconnectpersonal-$VERSION.tgz)
(cd /usr/local/bin && ln -s ../globusconnectpersonal-$VERSION/globusconnect)

VERSION=$SINGULARITY_VERSION
cd /tmp
wget https://github.com/singularityware/singularity/releases/download/$VERSION/singularity-$VERSION.tar.gz
tar xvf singularity-$VERSION.tar.gz
cd singularity-$VERSION
./configure --prefix=/usr/local
make
sudo make install

apt-get clean

## This should be the last line so that we only run the script once, per the
## check at the start of the script
touch /var/log/jetstream-setup.done
echo "Setup completed successfully"
echo
echo "Restarting system in 60 seconds so all changes take effect."
echo "Hit Ctrl-C to abort this automatic reboot."

/sbin/shutdown -r +1
