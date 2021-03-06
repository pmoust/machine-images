#!/bin/bash
# this is run as root

function new_section {
  echo
  echo $(date +"%F %T") $1
  echo "----------------------------------------------------------------------------------------"
}

set -e
mkdir -p /opt
cp -R /tmp/features /opt/

## Update index and install packages
new_section "Configuring extra repositories"
add-apt-repository "deb http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ trusty universe multiverse"
add-apt-repository "deb http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ trusty main restricted"
add-apt-repository "deb http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ trusty-updates universe multiverse"
# sometimes apt-get update doesn't see the changes here, try sleeping for a moment
sleep 1

new_section "Updating package lists"
apt-get update

## Install packages
new_section "Installing required packages"
apt-get --yes --force-yes install \
  git wget language-pack-en build-essential python-setuptools \
  openjdk-7-jre-headless openjdk-7-jdk cloud-guest-utils jq \
  ntp unzip python3-pip

## Install AWSCLI tools
new_section "Installing latest AWSCLI"
pip3 install awscli

## Install AWS-CFN tools
new_section "Installing AWS-CFN tools"
wget -P /tmp https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
mkdir -p /tmp/aws-cfn-bootstrap-latest
tar xvfz /tmp/aws-cfn-bootstrap-latest.tar.gz --strip-components=1 -C /tmp/aws-cfn-bootstrap-latest
# This seems to frequently fail, so run in a short loop
LIMIT=3
COUNT=1
while [ $COUNT -le $LIMIT ]; do
  echo "Attempting to install cfn-init ($COUNT/$LIMIT)..."
  if easy_install /tmp/aws-cfn-bootstrap-latest/; then
    rm -fr /tmp/aws-cfn-bootstrap-latest
    break
  else
    let COUNT=COUNT+1
  fi
done

## Configure Amazon's NTP servers
new_section "Configuring NTP"
sed -i s/ubuntu.pool.ntp.org/amazon.pool.ntp.org/ /etc/ntp.conf
# TODO: If building a PV based image we should change the sysctl to disable the wallclock

## Setup network adapter
new_section "Configuring enhanced networking (ixgbevf)"
# See http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking.html
wget http://sourceforge.net/projects/e1000/files/ixgbevf%20stable/2.16.1/ixgbevf-2.16.1.tar.gz
tar -xzf ixgbevf-2.16.1.tar.gz
pushd ./ixgbevf-2.16.1/src
wget "https://gist.githubusercontent.com/defila-aws/44946d3a3c0874fe3d17/raw/af64c3c589811a0d214059d1e4fd220a96eaebb3/patch-ubuntu_14.04.1-ixgbevf-2.16.1-kcompat.h.patch" -O patch.kcompat.h
patch <patch.kcompat.h
make install
modprobe ixgbevf
update-initramfs -c -k all
popd
rm -r ixgbevf-2.16.1.tar.gz ixgbevf-2.16.1/

## Ensure we don't swap unnecessarily
echo "vm.overcommit_memory=1" > /etc/sysctl.d/70-vm-overcommit

new_section "Configuring locale"
locale-gen en_GB.UTF-8
