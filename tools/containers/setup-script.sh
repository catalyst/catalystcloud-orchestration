#!/bin/bash

host_name=$1
domain_name=$2
ddns_password=$3
ip_address=$4
file_upload_size=$5

bash -x ddns-script.sh $host_name $domain_name $ip_address $ddns_password 

# DNS propagation delay
sleep 1m

# Create custom nginx proxy configuration
echo "client_max_body_size $file_upload_size;" > /tmp/proxy.conf
chmod 666 /tmp/proxy.conf  # Change file permissions

# Mount volume for Nextcloud database
mkdir /data
if [[ "$(blkid -s TYPE -o value /dev/vdb)" == "" ]]; then
  mkfs.ext4 /dev/vdb
fi
mount /dev/vdb /data

# Pull containers
docker pull nginxproxy/nginx-proxy
docker pull nginxproxy/acme-companion
docker pull nextcloud

# Run nginx-proxy
docker run --detach \
 --name nginx-proxy \
 --publish 80:80 \
 --publish 443:443 \
 --volume certs:/etc/nginx/certs \
 --volume vhost:/etc/nginx/vhost.d \
 --volume html:/usr/share/nginx/html \
 --volume /tmp/proxy.conf:/etc/nginx/conf.d/proxy.conf \
 --volume /var/run/docker.sock:/tmp/docker.sock:ro \
 nginxproxy/nginx-proxy
    
# Run acme-companion
docker run --detach \
 --name nginx-proxy-acme \
 --volumes-from nginx-proxy \
 --volume /var/run/docker.sock:/var/run/docker.sock:ro \
 --volume acme:/etc/acme.sh \
 --env "DEFAULT_EMAIL=admin@$domain_name" \
 nginxproxy/acme-companion
    
# Run nextcloud container
docker run --detach \
 --name=nextcloud \
 -e TZ=NZ \
 -p 8080:80 \
 --env "VIRTUAL_HOST=$host_name.$domain_name" \
 --env "LETSENCRYPT_HOST=$host_name.$domain_name"  \
 --volume /data/www/html:/var/www/html \
 --restart unless-stopped \
 nextcloud
