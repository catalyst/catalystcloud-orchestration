#! /bin/bash
# Check arguments
if [[ $# -eq 0 ]] ; then
    echo 'usage: stackhost.sh <stack name>'
    exit 0
fi


STACK=$1

# Check stack exist and set IP from heat client 
IP=$(heat output-show $STACK server_public_ip)
if [ $? -ne 0 ]; then
    echo "Exiting"
	exit 0
fi

# Strip quotes
TMP="${IP%\"}"
IP="${TMP#\"}"

# Check stack exist and set hostname from heat client 
HOST=$(heat output-show $STACK host_name)
# Strip quotes
TMP="${HOST%\"}"
HOST="${TMP#\"}"


# Print host entry and query user to authorise autoupdate
echo "/etc/hosts entry for $STACK is: $IP	$HOST"
read -p "Do you want me to modify your hosts file (requires sudo)? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Add/update hosts file entry
	if grep -q "$HOST" /etc/hosts
	then
	# Update
		sudo sed -i "/$HOST/ s/.*/$IP\t$HOST/g" /etc/hosts
		echo "Updated $HOST in /etc/hosts"
	else
	# Add
		sudo sh -c "echo \"$IP\t$HOST\" >> /etc/hosts"
		echo "Added $HOST to /etc/hosts"
	fi
else
	echo "/etc/hosts not modified. Exiting."
	exit 0
fi

