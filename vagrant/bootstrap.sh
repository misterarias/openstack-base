#!/bin/bash

# System update + some basics
yum update -y
yum install -y yum-plugin-priorities
yum install -y http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum install -y http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm
yum upgrade -y
yum install -y wget curl vim ntp openstack-selinux

# This makes vagrant-ssh faster
sed -i.bk -e 's#.*UseDNS.*#UseDNS no#g' /etc/ssh/sshd_config
sed -i.bk -e 's#.*GSSAPIAuthentication.*#GSSAPIAuthentication no#g' /etc/ssh/sshd_config

# Config depending on ntp parameters
NTP_MASTER=$1
NTP_SYNC=${2}
cat > /etc/ntp.conf << _EOF_
server ${NTP_SYNC} iburst
_EOF_

[ "$NTP_MASTER" = "1" ] && \
  echo "restrict -4 default kod notrap nomodify" >> /etc/ntp.conf && \
  echo "restrict -6 default kod notrap nomodify" >> /etc/ntp.conf

echo "== Done!"
