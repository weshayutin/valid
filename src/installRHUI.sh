#!/bin/bash

## ASSUMES RHUI DVD in /root ###
## Run on the rhua and each cds ##
##
## example ./script.sh rhua xvdk
## example ./script.sh cds xvdf (xvdf for 6.0 rhel or so I've seen)

## CHANGE ME ####
export rhua=host.internal	
export cds1=host.internal
export cds2=host.internal
## CHANGE ME ####



export server="$1"
export device="$2"

if [ "$server" == "rhua" ]; then
 echo "RHUI Selected"
 mkdir /var/lib/pulp
 ls /var/lib/pulp
fi
if [ "$server" == "cds" ]; then
 echo "CDS Selected"
 mkdir /var/lib/pulp-cds
 ls /var/lib/pulp-cds
fi

iptables -A INPUT -p tcp -m state --state NEW  -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW  -m tcp --dport 5674 -j ACCEPT

/etc/init.d/iptables save
/etc/init.d/iptables restart

fdisk /dev/$device << EOF
n
p
1
1
54823
p
w
EOF

export partition=1
mkfs.ext4 /dev/$device$partition

if [ "$server" == "rhua" ]; then
 echo "/dev/$device$partition /var/lib/pulp ext4 defaults 1 1" >> /etc/fstab
 mount -a 
 mount 
fi
if [ "$server" == "cds" ]; then
 echo "/dev/$device$partition /var/lib/pulp-cds ext4 defaults 1 1" >> /etc/fstab
 mount -a
 mount
fi

if [ "$server" == "rhua" ]; then
 mkdir -p pem && pushd pem
 openssl req -new -x509 -extensions v3_ca -keyout ca.key -subj '/C=US/ST=NC/L=Raleigh/CN=localhost' -out ca.crt -days 365
 echo 10 > ca.srl
 openssl genrsa -out server.key 2048

 for node in $rhua $cds1 $cds2 ; do 
  echo -ne "\n\n\n## set CN for $server\n=="
  openssl req -new -key server.key -subj '/C=US/ST=NC/L=Raleigh/CN='$node'' -out $node.csr
  openssl x509 -req -days 365 -CA ca.crt -CAkey ca.key -in $node.csr -out $node.crt
 done
fi

mkdir /tmp/mnt
mount -o loop /root/RH* /tmp/mnt/
pushd /tmp/mnt/
if [ "$server" == "rhua" ]; then
 ./install_RHUA.sh ;./install_tools.sh 
fi
if [ "$server" == "cds" ]; then
 ./install_CDS.sh
fi

popd

nss-db-gen

#/etc/pulp/pulp.conf
#/etc/pulp/consumer/consumer.conf
#/etc/pulp/client.conf
#host = localhost.localdomain

if [ "$server" == "rhua" ]; then
 perl -npe 's/server_name: localhost/server_name: $rhui/g' -i /etc/pulp/pulp.conf;
 perl -npe 's/host = localhost.localdomain/host = $rhui/g' -i /etc/pulp/client.conf;
 perl -npe 's/host = localhost.localdomain/host = $rhui/g' -i /etc/pulp/consumer/consumer.conf;
fi

if [ "$server" == "cds" ]; then
 perl -npe 's/host = localhost.localdomain/host = $rhui/g' -i /etc/pulp/cds.conf;
fi

export cert=.crt

cat > /root/answers.txt <<DELIM
[general]
version: 1.0
dest_dir: /tmp/rhui
qpid_ca: /tmp/rhua/qpid/ca.crt
qpid_client: /tmp/rhua/qpid/client.crt
qpid_nss_db: /tmp/rhua/qpid/nss
[rhua]
rpm_name: rh-rhua-config
hostname: $rhua
ssl_cert: /root/pem/$rhui$cert
ssl_key: /root/pem/server.key
ca_cert: /root/pem/ca.crt
# proxy_server_host: proxy.example.com
# proxy_server_port: 443
# proxy_server_username: admin
# proxy_server_password: password
[cds-1]
rpm_name: rh-cds1-config
hostname: $cds1
ssl_cert: /root/pem/$cds1$cert
ssl_key: /root/pem/server.key
[cds-2]
rpm_name: rh-cds2-config
hostname: $cds2
ssl_cert: /root/pem/$cds2$cert
ssl_key: /root/pem/server.key

DELIM

if [ "$server" == "rhua" ]; then
 /usr/bin/rhui-installer /root/answers.txt
fi


