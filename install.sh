#!/bin/bash

# Install Dependences
sudo apt-get update 
sudo apt-get install docker.io wget -y 

wget -O cf.deb 'https://coding.net/u/tprss/p/bluemix-source/git/raw/master/cf-cli-installer_6.16.0_x86-64.deb' 
sudo dpkg -i cf.deb
cf install-plugin -f https://coding.net/u/tprss/p/bluemix-source/git/raw/master/ibm-containers-linux_x64 

# Set Parameters
sv_region=$1
sv_port=443
passwd=`openssl rand -base64 12`
method=chacha20
sgn=`openssl rand -hex 4`

# Initialize Environment
cf login -a https://api.${sv_region}.bluemix.net
cf ic namespace set ss_${sgn}
cf ic init 
sleep 10

# Generate Image
mkdir ss_${sgn}
cd ss_${sgn}

cat << _END_ >Dockerfile
FROM debian:8.5

RUN echo "deb http://shadowsocks.org/debian wheezy main" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y --force-yes wget shadowsocks-libev

RUN wget --no-check-certificate https://raw.githubusercontent.com/jwqmdddsm/ae7b8978a9/master/sysctl_tmp
CMD 'cat sysctl_tmp >> /etc/sysctl.conf'
CMD 'sysctl -f --system'

EXPOSE ${sv_port}
EXPOSE ${sv_port}/udp

ENTRYPOINT ["/usr/bin/ss-server"]

_END_

cf ic build -t ss_${sgn}:v1 .

# Run Instance & Allocate PublicAddr.
cf ic run -d --privileged --name=ss_${sgn} -d -p ${sv_port} registry.ng.bluemix.net/`cf ic namespace get`/ss_${sgn}:v1 -s 0.0.0.0 -p ${sv_port} -k ${passwd} -m ${method} --fast-open
echo `cf ic ip request`>tmp_${sgn}
addr=`grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' ./tmp_${sgn}`
cid=`cf ic inspect --format="{{.Id}}" ss_${sgn}`
rm -rf tmp_${sgn}
cf ic ip bind `${addr}` `${cid}`

# Return Result
clear
echo -e "Container id:\n"${cid}"\nPassword:\n"${passwd}"\nServer addr:\n"${addr}:${sv_port}