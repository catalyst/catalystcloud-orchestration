#!/bin/bash

# add header with our origin hostname
sed -i "s/# server_tokens off;/# server_tokens off;\n\tadd_header Origin host_name;\n\tadd_header Cache-Control \"max-age=0, no-store\";/g" /etc/nginx/nginx.conf
service nginx restart
