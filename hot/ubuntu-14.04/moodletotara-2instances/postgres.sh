#!/bin/bash -v
# Change shell to bash
sudo /usr/bin/chsh -s /bin/bash ec2-user
# Set up shell variables
export DEBIAN_FRONTEND=noninteractive
export SITENAME=site_name
export SERVERNAME=$SITENAME-"dbserver"
export ENVIRONMENT=environment
export APPTYPE=app_type
export SITEENVIRONMENT=$SITENAME-$ENVIRONMENT-$APPTYPE
# Add server name to host file
echo "127.0.0.1 $SERVERNAME" >> /etc/hosts
# Redirect output to syslog
exec 1> >(logger -s -t $(basename $0)) 2>&1
# Set timezone
echo "Pacific/Auckland NZ" | sudo tee /etc/timezone
sudo dpkg-reconfigure --frontend noninteractive tzdata
# DATABASE
# Install PostgreSQL, modify config files, restart and create database and user
echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/90install-recommends
apt-get update
apt-get -y install postgresql
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/9.3/main/postgresql.conf
echo "host    $SITEENVIRONMENT $SITEENVIRONMENT             192.168.0.0/24        md5" >> /etc/postgresql/9.3/main/pg_hba.conf
/etc/init.d/postgresql restart
sudo -u postgres createuser --no-superuser --no-createdb --no-createrole $SITEENVIRONMENT
sudo -u postgres psql -c "alter user \"$SITEENVIRONMENT\" with password 'db_rootpassword'"
sudo -u postgres createdb -Eutf8 --owner=$SITEENVIRONMENT $SITEENVIRONMENT -T template0

