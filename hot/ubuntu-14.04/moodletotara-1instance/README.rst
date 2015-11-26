This directory contains the files used to set up a Moodle/Totara stack on one instance using PostgreSQL as the RDBMS and Nginx as the front-end proxy. It also creates a dedicated subnet and router and appropriate interfaces to permit communication between front- and back-end using the private subnet and a public IP for accessing the webserver. Access rules are in place to allow sshing onto the webserver from the Catalyst subnet.

At the moment the template has no ambition at being robust, elegant or production-grade. I am not a developer so YMMV. The main aim of the work is to demonstrate that the setup of a Moodle/Totara instance on the Catalyst Cloud can be automated/orchestrated.

This folder contains the following files:

* environment.yaml: the environment file
* server.yaml: the HEAT template
* server.sh: Bash script used to create the RDBMS, webserver, download and install Moodle/Totara and configure Apache/Nginx
* README.rst: this README file
* stackhost.sh: a command-line utility which updates your /etc/hosts file with hostname and ip information from the stack outputs

To create the stack, run::

heat stack-create <stack name> -f <template filename> -e <environment filename>

where:

* <stack name> is the name of the stack that will be created
* <template filename> is the name of the YAML template file used to set up the instance(s)
* <environment filename> is another YAML file with name/value pairs which are passed to the template 

You can add or override individual parameter values by using the -P flag as follows: -P "par1=par1_value;par2=par2_value..."

At the moment the following parameter groups are defined:

Infrastructure

* key_name: you must set this to your tenancy key name
* image: the image name (default: ubuntu-14.04-x86_64)
* servers_flavor: the instance size (default: c1.c1r1)
* public_net: name of the public net in your region (default: public-net)
* public_net_id: ID of the public net for your region
* private_net_dns_servers: comma-separated list of DNS server IPs
* private_net_cidr: private network address range (CIDR notation). Default: 192.168.0.0/24
* private_net_gateway: private network gateway address (default: 192.168.0.1)
* private_net_pool_start: starting IP of private network IP address allocation pool (default: 192.168.0.10)
* private_net_pool_end: last IP of private network IP address allocation pool (default: 192.168.0.250)
* security_groups: the security group which defines allowed connecting ports/protocols (default: mdl_1server)

Application

The next three parameters follow the naming scheme used in the e-learning team at Catalyst for self-host setup and are used primarily to christen the databases and the $SITEENVIRONMENT variable

* site_name: (default:mdl1)
* environment: e.g. test
* app_type: e.g. moodle or totara

These parameters identify the Moodle/Totara version, the site URL and the Db admin password

* git_repo: the git repo url (default: git://git.moodle.org/moodle.git)
* git_branch: the git branch in git_repo that you want to run (default: MOODLE_29_STABLE)
* site_url: the site_url. You need to make sure that this resolves either locally or globally since at the moment the site will not be accessible via IP.
* db_root_password: insert your DB root password here (default: admin)
