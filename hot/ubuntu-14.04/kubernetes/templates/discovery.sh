#!/bin/bash

BASE=`pwd`
export DEBIAN_FRONTEND=noninteractive
export DISCOVERY_IP=discovery_ip

mkdir -p /opt/bin
wget --no-check-certificate -N -O /tmp/etcd.tar.gz "etcd_url"
tar --wildcards --to-stdout -xzvf /tmp/etcd.tar.gz "etcd-*/etcd" > /opt/bin/etcd
chmod +x /opt/bin/etcd
tar --wildcards --to-stdout -xzvf /tmp/etcd.tar.gz "etcd-*/etcdctl" > /opt/bin/etcdctl
chmod +x /opt/bin/etcdctl
rm -f /tmp/etcd.tar.gz


cat << EOF > /etc/init/etcd.conf
  description "etcd service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      ETCD=/opt/bin/etcd
      if [ -f /etc/default/etcd ]; then
          . /etc/default/etcd
      fi
      if [ -f \$ETCD ]; then
          exit 0
      fi
  exit 22
  end script

  script
      # modify these in /etc/default/etcd (/etc/default/docker)
      ETCD=/opt/bin/etcd
      ETCD_OPTS=""
      if [ -f /etc/default/etcd ]; then
          . /etc/default/etcd
      fi
      exec "\$ETCD" \$ETCD_OPTS
  end script
EOF

cat << EOF > /etc/default/etcd
 # Use ETCD_OPTS to modify the start/restart options
 HostIP="discovery_ip"
 ETCD_OPTS=" -name etcd0  -advertise-client-urls http://discovery_ip:2379,http://discovery_ip:4001  -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001  -initial-advertise-peer-urls http://discovery_ip:2380  -listen-peer-urls http://0.0.0.0:2380  -initial-cluster-token etcd-cluster-1  -initial-cluster etcd0=http://discovery_ip:2380  -initial-cluster-state new  -snapshot"
EOF

# set timezone
/usr/bin/timedatectl set-timezone "Pacific/Auckland"

