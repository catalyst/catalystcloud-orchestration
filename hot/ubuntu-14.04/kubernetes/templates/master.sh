#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export DISCOVERY_IP=discovery_ip
export MASTER_IP=master_ip
export DEBIAN_FRONTEND=noninteractive

echo "PATH=\$PATH:/opt/bin" >> /etc/bash.bashrc

# configure syslog
apt-get install -y rsyslog
sed -i "s/#\$ModLoad imudp/\$ModLoad imudp/" /etc/rsyslog.conf
sed -i "s/#\$UDPServerRun 514/\$UDPServerRun 514/" /etc/rsyslog.conf
restart rsyslog

# configure dnsmasq
echo "dhcp-option=6,8.8.8.8,8.8.4.4" >> /etc/dnsmasq.conf
/etc/init.d/dnsmasq restart

# download files
mkdir -p /opt/bin

# Download Kubernetes Binaries
# wget --no-check-certificate -N -O /opt/bin/hyperkube 'k8s_url/hyperkube'
wget --no-check-certificate -N -O /opt/bin/kube-apiserver 'k8s_url/kube-apiserver'
wget --no-check-certificate -N -O /opt/bin/kube-controller-manager 'k8s_url/kube-controller-manager'
wget --no-check-certificate -N -O /opt/bin/kubectl 'k8s_url/kubectl'
wget --no-check-certificate -N -O /opt/bin/kube-scheduler 'k8s_url/kube-scheduler'
wget --no-check-certificate -N -O /opt/bin/kube-proxy 'k8s_url/kube-proxy'
wget --no-check-certificate -N -O /opt/bin/kubelet 'k8s_url/kubelet'
# chmod +x /opt/bin/hyperkube
chmod +x /opt/bin/kube-apiserver
chmod +x /opt/bin/kube-controller-manager
chmod +x /opt/bin/kubectl
chmod +x /opt/bin/kube-scheduler
chmod +x /opt/bin/kube-proxy
chmod +x /opt/bin/kubelet

# Flannel stuff
wget --no-check-certificate -N -O /tmp/flannel.tar.gz "flannel_url"
#tar --wildcards --to-stdout -xzvf /tmp/flannel.tar.gz "flannel*/flanneld" > /opt/bin/flannel
tar --to-stdout -xzvf /tmp/flannel.tar.gz "flanneld" > /opt/bin/flannel
rm -f /tmp/flannel.tar.gz
chmod +x /opt/bin/flannel

# etcd
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
      ETCD=/opt/bin/\$UPSTART_JOB
      if [ -f /etc/default/\$UPSTART_JOB ]; then
          . /etc/default/\$UPSTART_JOB
      fi
      if [ -f \$ETCD ]; then
          exit 0
      fi
  exit 22
  end script

  script
      # modify these in /etc/default/\$UPSTART_JOB (/etc/default/docker)
      ETCD=/opt/bin/\$UPSTART_JOB
      ETCD_OPTS=""
      if [ -f /etc/default/\$UPSTART_JOB ]; then
          . /etc/default/\$UPSTART_JOB
      fi
      exec "\$ETCD" \$ETCD_OPTS
  end script
EOF

cat << EOF > /etc/default/etcd
 # Use ETCD_OPTS to modify the start/restart options
 HostIP="discovery_ip"
 ETCD_OPTS="  -listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001  -advertise-client-urls=http://master_ip:4001"
EOF

# Docker
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get purge lxc-docker -y
sudo apt-get install linux-image-extra-$(uname -r)
sudo apt-get install -y bridge-utils


cat << EOF > /etc/init/flannel.conf
  description "Flannel service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and started etcd
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      FLANNEL=/opt/bin/flannel
      if [ -f /etc/default/\$UPSTART_JOB ]; then
          . /etc/default/\$UPSTART_JOB
      fi
      if [ -f \$FLANNEL ]; then
          exit 0
      fi
  exit 22
  end script

  script
      # modify these in /etc/default/flannel (/etc/default/docker)
      FLANNEL=/opt/bin/flannel
      FLANNEL_OPTS=""
      if [ -f /etc/default/\$UPSTART_JOB ]; then
          . /etc/default/\$UPSTART_JOB
      fi
      exec "\$FLANNEL" \$FLANNEL_OPTS
  end script
EOF

cat << EOF > /etc/default/flannel
# Use FLANNEL_OPTS to modify the start/restart options
FLANNEL_OPTS="--etcd-endpoints=http://discovery_ip:4001 -iface=master_ip -logtostderr=true"
EOF

sudo start etcd

echo "waiting because discovery node will be rebooting....."
sleep 30

# wait until the discovery nodes is available
until curl http://discovery_ip:4001/v2/machines; do echo "Waiting for discovery etcd..."; sleep 2; done

/opt/bin/etcdctl -C http://discovery_ip:4001 rm --recursive /coreos.com/network
/opt/bin/etcdctl -C http://discovery_ip:4001 set /coreos.com/network/config '{"Network":"10.100.0.0/16"}'

mkdir -p /run/flannel
sudo start flannel

sudo apt-get install docker-engine -y
stop docker

sudo usermod -aG docker ubuntu

sudo ip link set dev docker0 down
sudo brctl delbr docker0

# reconfigure Docker - must start after flannel
cat << EOF > /etc/default/docker
# Docker Upstart and SysVinit configuration file
# Use DOCKER_OPTS to modify the daemon startup options.
. /run/flannel/subnet.env
#DOCKER_OPTS=" --log-driver=syslog --log-opt tag="{{.ImageName}}/{{.Name}}/{{.ID}}" --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU} --insecure-registry=master_ip:5000 --storage-opt dm.override_udev_sync_check=true --dns master_ip --dns 8.8.8.8 --dns 8.8.4.4"
DOCKER_OPTS=" --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU} --insecure-registry=master_ip:5000 --storage-opt dm.override_udev_sync_check=true --dns master_ip --dns 8.8.8.8 --dns 8.8.4.4"
EOF

cat << EOF > /etc/init/docker.conf
description "Docker daemon"

start on (local-filesystems
         and net-device-up IFACE!=lo
         and started flannel
         and runlevel [2345])
stop on runlevel [!2345]
limit nofile 524288 1048576
limit nproc 524288 1048576

respawn

kill timeout 20

pre-start script
        BRIDGE_EXISTS=\$(brctl show | grep docker0 || true)
        if [ -n "\${BRIDGE_EXISTS}" ]; then
           /sbin/ip link set dev docker0 down
           /sbin/brctl delbr docker0
        fi
        # see also https://github.com/tianon/cgroupfs-mount/blob/master/cgroupfs-mount
        if grep -v '^#' /etc/fstab | grep -q cgroup \
                || [ ! -e /proc/cgroups ] \
                || [ ! -d /sys/fs/cgroup ]; then
                exit 0
        fi
        if ! mountpoint -q /sys/fs/cgroup; then
                mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
        fi
        (
                cd /sys/fs/cgroup
                for sys in \$(awk '!/^#/ { if (\$4 == 1) print \$1 }' /proc/cgroups); do
                        mkdir -p \$sys
                        if ! mountpoint -q \$sys; then
                                if ! mount -n -t cgroup -o \$sys cgroup \$sys; then
                                        rmdir \$sys || true
                                fi
                        fi
                done
        )
end script

script
        # modify these in /etc/default/$UPSTART_JOB (/etc/default/docker)
        DOCKER=/usr/bin/\$UPSTART_JOB
        DOCKER_OPTS=
        if [ -f /etc/default/\$UPSTART_JOB ]; then
                . /etc/default/\$UPSTART_JOB
        fi
        exec "\$DOCKER" daemon \$DOCKER_OPTS
end script
# Don't emit "started" event until docker.sock is ready.
# See https://github.com/docker/docker/issues/6647
post-start script
        DOCKER_OPTS=
        if [ -f /etc/default/\$UPSTART_JOB ]; then
                . /etc/default/\$UPSTART_JOB
        fi
        if ! printf "%s" "\$DOCKER_OPTS" | grep -qE -e '-H|--host'; then
                while ! [ -e /var/run/docker.sock ]; do
                        initctl status \$UPSTART_JOB | grep -qE "(stop|respawn)/" && exit 1
                        echo "Waiting for /var/run/docker.sock"
                        sleep 0.1
                done
                echo "/var/run/docker.sock is up"
        fi
end script

post-stop script
        BRIDGE_EXISTS=\$(brctl show | grep docker0 || true)
        if [ -n "\${BRIDGE_EXISTS}" ]; then
           /sbin/ip link set dev docker0 down
           /sbin/brctl delbr docker0
        fi
end script
EOF

sudo start docker


# setup kubenetes service account key
mkdir -p /opt/bin
/usr/bin/openssl genrsa -out /opt/bin/kube-serviceaccount.key 2048 2>/dev/null

# Generate Kubernetes API Server certificates
mkdir -p /srv/kubernetes
if [ -f /srv/kubernetes/.certs.lock ]; then
    echo "cert lock exists - bypassing cert creation"
else
    echo "cert lock does NOT exist - CREATING CERT!!!!"
    /usr/sbin/groupadd -r kube-cert
    wget --no-check-certificate -N -O /opt/bin/make-ca-cert.sh "make_cert_url"
    chmod u=rwx,go= /opt/bin/make-ca-cert.sh
    /opt/bin/make-ca-cert.sh _use_aws_external_ip_ IP:10.100.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local
fi

# Setup Docker Registry
/usr/bin/docker rm -f private_reg
mkdir -p /var/lib/registry-data
umount /dev/vdb
mount /var/lib/registry-data
/usr/bin/docker pull registry:2
/usr/bin/docker run -d --restart always -p 5000:5000 -v /var/lib/registry-data:/var/lib/registry --name=private_reg registry:2

# launch Kubernetes

# start the API Server
cat << EOF > /etc/init/kube-apiserver.conf
  description "kube-apiserver service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and started docker
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      KUBE=/opt/bin/kube-apiserver
      if [ -f /etc/default/kube-apiserver ]; then
          . /etc/default/kube-apiserver
      fi
      if [ -f \$KUBE ]; then
          exit 0
      fi
  exit 22
  end script

  script
      KUBE=/opt/bin/kube-apiserver
      KUBE_OPTS=""
      if [ -f /etc/default/kube-apiserver ]; then
          . /etc/default/kube-apiserver
      fi
      exec "\$KUBE" \$KUBE_OPTS
  end script
EOF

cat << EOF > /etc/default/kube-apiserver
KUBE_OPTS="--client-ca-file=/srv/kubernetes/ca.crt --tls-cert-file=/srv/kubernetes/server.cert --tls-private-key-file=/srv/kubernetes/server.key --service-account-key-file=/opt/bin/kube-serviceaccount.key --service-account-lookup=false --admission-control=NamespaceLifecycle,NamespaceAutoProvision,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota --runtime-config=api/v1 --allow-privileged=true --insecure-bind-address=0.0.0.0 --insecure-port=8080 --kubelet-https=true --secure-port=6443 --service-cluster-ip-range=10.100.0.0/16 --etcd-servers=http://discovery_ip:4001 --public-address-override=master_ip --logtostderr=true"
EOF

start kube-apiserver

# start the Scheduler
cat << EOF > /etc/init/kube-scheduler.conf
  description "kube-scheduler service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and started docker
    and started kube-apiserver
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      KUBE=/opt/bin/kube-scheduler
      if [ -f /etc/default/kube-scheduler ]; then
          . /etc/default/kube-scheduler
      fi
      if [ -f \$KUBE ]; then
          exit 0
      fi
  exit 22
  end script

  script
      KUBE=/opt/bin/kube-scheduler
      KUBE_OPTS=""
      if [ -f /etc/default/kube-scheduler ]; then
          . /etc/default/kube-scheduler
      fi
      exec "\$KUBE" \$KUBE_OPTS
  end script
EOF

cat << EOF > /etc/default/kube-scheduler
KUBE_OPTS="--logtostderr=true --master=127.0.0.1:8080"
EOF

start kube-scheduler


# start the Proxy
cat << EOF > /etc/init/kube-proxy.conf
  description "kube-proxy service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and started docker
    and started kube-apiserver
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      KUBE=/opt/bin/kube-proxy
      if [ -f /etc/default/kube-proxy ]; then
          . /etc/default/kube-proxy
      fi
      if [ -f \$KUBE ]; then
          exit 0
      fi
  exit 22
  end script

  script
      KUBE=/opt/bin/kube-proxy
      KUBE_OPTS=""
      if [ -f /etc/default/kube-proxy ]; then
          . /etc/default/kube-proxy
      fi
      exec "\$KUBE" \$KUBE_OPTS
  end script
EOF

cat << EOF > /etc/default/kube-proxy
KUBE_OPTS="--master=master_ip:8080 --logtostderr=true"
EOF

start kube-proxy



# start the Controller Manager
cat << EOF > /etc/init/kube-controller-manager.conf
  description "kube-controller-manager service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and started docker
    and started kube-apiserver
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      KUBE=/opt/bin/kube-controller-manager
      if [ -f /etc/default/kube-controller-manager ]; then
          . /etc/default/kube-controller-manager
      fi
      if [ -f \$KUBE ]; then
          exit 0
      fi
  exit 22
  end script

  script
      KUBE=/opt/bin/kube-controller-manager
      KUBE_OPTS=""
      if [ -f /etc/default/kube-controller-manager ]; then
          . /etc/default/kube-controller-manager
      fi
      exec "\$KUBE" \$KUBE_OPTS
  end script
EOF

cat << EOF > /etc/default/kube-controller-manager
KUBE_OPTS="--service-account-private-key-file=/opt/bin/kube-serviceaccount.key --root-ca-file=/srv/kubernetes/ca.crt --master=127.0.0.1:8080 --logtostderr=true"
EOF

start kube-controller-manager



# start the kubelet
cat << EOF > /etc/init/kubelet.conf
  description "kubelet service"
  author "@piers"

  start on (net-device-up
    and local-filesystems
    and started docker
    and started kube-apiserver
    and runlevel [2345])
  stop on runlevel [016]

  respawn
  respawn limit 10 5

  pre-start script
      KUBE=/opt/bin/kubelet
      if [ -f /etc/default/kubelet ]; then
          . /etc/default/kubelet
      fi
      if [ -f \$KUBE ]; then
          exit 0
      fi
  exit 22
  end script

  script
      KUBE=/opt/bin/kubelet
      KUBE_OPTS=""
      if [ -f /etc/default/kubelet ]; then
          . /etc/default/kubelet
      fi
      exec "\$KUBE" \$KUBE_OPTS
  end script
EOF

cat << EOF > /etc/default/kubelet
KUBE_OPTS="--address=0.0.0.0 --port=10250 --hostname-override=master_ip --api-servers=master_ip:8080 --cluster-dns=10.100.0.10 --cluster-domain=cluster.local --allow-privileged=true --logtostderr=true --cadvisor-port=4194 --healthz-bind-address=0.0.0.0 --healthz-port=10248"
EOF

start kubelet

# let everything settle - then pull the plug
sleep 5

# set timezone
/usr/bin/timedatectl set-timezone "Pacific/Auckland"

echo "Master done!"
