#!/bin/bash

#--------------
# Install MySQL
#--------------

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-server

# To connect to mysql: mysql -u root -h ${PRIVATE_IP}

# Configure MySQL
#----------------

# Find out the IP associated to eth0
#PRIVATE_IP=$(ip addr list eth0 | grep "inet " | cut -d' ' -f6 | cut -d'/' -f1)

sudo cp /etc/mysql/my.cnf /etc/mysql/my.cnf.bkp
(cat << EOF
[mysql]

# CLIENT #
port                           = 3306
socket                         = /var/lib/mysql/mysql.sock

[mysqld_safe]

socket                         = /var/run/mysqld/mysqld.sock
nice                           = 0

[mysqld]

# GENERAL #
user                           = mysql
default-storage-engine         = InnoDB
socket                         = /var/run/mysqld/mysqld.sock
pid-file                       = /var/run/mysqld/mysqld.pid
bind-address                   = 0.0.0.0
port                           = 3306

# MyISAM #
key-buffer-size                = 32M
myisam-recover-options         = FORCE,BACKUP
skip-external-locking

# SAFETY #
max-allowed-packet             = 16M
max-connect-errors             = 1000000
skip-name-resolve
sysdate-is-now                 = 1
innodb                         = FORCE

# DATA STORAGE #
datadir                        = /var/lib/mysql
tmpdir                         = /tmp
basedir                        = /usr
lc-messages-dir                = /usr/share/mysql

# BINARY LOGGING #
log-bin                        = /var/lib/mysql/mysql-bin
expire-logs-days               = 14
sync-binlog                    = 1

# CACHES AND LIMITS #
tmp-table-size                 = 32M
max-heap-table-size            = 32M
query-cache-type               = 0
query-cache-size               = 0
max-connections                = 500
thread-stack                   = 192K
thread-cache-size              = 50
open-files-limit               = 65535
table-definition-cache         = 1024
table-open-cache               = 2048

# INNODB #
innodb-flush-method            = O_DIRECT
innodb-log-files-in-group      = 2
innodb-log-file-size           = 5M
innodb-flush-log-at-trx-commit = 1
innodb-file-per-table          = 1
innodb-buffer-pool-size        = 250M

# LOGGING #
log-error                      = /var/log/mysql/error.log
log-queries-not-using-indexes  = 1
slow-query-log                 = 1
slow-query-log-file            = /var/log/mysql/mysql-slow.log

[mysqldump]

quick
quote-names
max_allowed_packet             = 16M

[isamchk]

key_buffer                     = 16M

#
# * IMPORTANT: Additional settings that can override those from this file!
#   The files must end with '.cnf', otherwise they will be ignored.
#
!includedir /etc/mysql/conf.d/
EOF
) | sudo tee /etc/mysql/my.cnf

# TODO: Use additional volume for mysql database

# Restart the database to apply the configuration
sudo service mysql restart

# Create backup user
(cat << EOF
use mysql
GRANT LOCK TABLES, SELECT ON *.* TO 'backup'@'%' IDENTIFIED BY 'db_password';
flush privileges;
exit
EOF
) | sudo mysql -u root -h 127.0.0.1

# Create website databases and grant DB access to corresponding drupal users
(cat << EOF
use mysql
CREATE DATABASE db_name CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON \`db_name\`.* TO 'db_user'@'%' IDENTIFIED BY 'db_password';
flush privileges;
exit
EOF
) | sudo mysql -u root -h 127.0.0.1

# To connect to the database from the webserver host: mysql -h ${PRIVATE_IP} -u ${USER} -p

#---------
# Backups
#---------

# Implement backup for MySQL
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y automysqlbackup
sudo sed -i 's/^#USERNAME=.*$/USERNAME=backup/' /etc/default/automysqlbackup
sudo sed -i 's/^#PASSWORD=.*$/PASSWORD=db_password/' /etc/default/automysqlbackup
sudo sed -i 's/^\(DBHOST\s*=\s*\).*$/\1127.0.0.1/' /etc/default/automysqlbackup

