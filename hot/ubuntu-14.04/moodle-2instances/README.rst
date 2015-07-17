This directory contains the files used to set up a Moodle stack on two instances using PostgreSQL as the RDBMS and Nginx as the front-end proxy. It also creates a dedicated subnet and router and appropriate interfaces to permit communication between front- and back-end using the private subnet and a public IP for accessing the webserver. Access rules are in place to allow sshing onto the webserver from the Catalyst subnet.

At the moment the template has no ambition at being robust, elegant or production-grade. I am not a developer so YMMV. The main aim of the work is to demonstrate that the setup of a Moodle instance on the Catalyst Cloud can be automated/orchestrated. 

This folder contains the following files:

* environment.yaml: the environment file
* moodle_2servers.yaml: the HEAT template
* postgres.sh: Bash script used to create the RDBMS
* webserver.sh: Bash script used to install the webserver, download and install Moodle and configure Apache/Nginx
* README.rst: this README file

To create the stack, run::

heat stack-create <stack name> -f <template filename> -e <environment filename>

where:

* <stack name> is the name of the stack that will be created
* <template filename> is the name of the YAML template file used to set up the instance(s)
* <environment filename> is another YAML file with name/value pairs which are passed to the template 

At the moment the following parameters are defined:

* key_name: you must set this to your tenancy key name
* image: the image name (default: ubuntu-14.04-x86_64)
* servers_flavor: the instance size (default: c1.c1r1)
* public_net_id: ID of the public net for your region 
* private_net_dns_servers: comma-separated list of DNS server IPs
* ssh_ip_cidr: originating network for SSH connections in CIDR format

The next three parameters follow the naming scheme used in the e-learning team at Catalyst for self-host setup and are used primarily to christen the databases and the $SITEENVIRONMENT variable

* site_name: e.g. catcloud
* environment: e.g. test
* app_type: e.g. moodle 

* site_url: the site_url. You need to make sure that this resolves either locally or globally since at the moment the Moodle site will not be accessible via IP.
* moodle_version: a valid Moodle branch number. Assigned to env variable MOODLEVERSION and used to create the remote branch name as MOODLE_"$MOODLEVERSION"_STABLE.
* db_root_password: insert your DB root password here 
