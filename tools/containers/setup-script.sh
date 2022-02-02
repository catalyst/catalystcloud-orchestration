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
