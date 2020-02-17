#!/bin/bash
MYIP=$(/sbin/ifconfig ens3 | grep 'inet '| awk '{print $2}');
OUTPUT="Welcome to my $MYIP";
while true; do echo -e "HTTP/1.1 200 OK\r\n\r\n${OUTPUT}\r" | sudo nc -q0 -l -p 80; done
