#!/bin/bash -v
# Set up shell variables
export DEBIAN_FRONTEND=noninteractive
export SITENAME=site_name
export SERVERNAME=$SITENAME-"webserver"
export ENVIRONMENT=environment
export APPTYPE=app_type
export GITREPO=git_repo
export GITBRANCH=git_branch
export URL=site_url
export DBSERVERIP=dbserver_ip
export PGPASSWORD=db_rootpassword
export SITEENVIRONMENT=$SITENAME-$ENVIRONMENT-$APPTYPE
# Add server name to host file
echo "127.0.0.1 $SERVERNAME" >> /etc/hosts
# Redirect output to syslog
exec 1> >(logger -s -t $(basename $0)) 2>&1
# Set timezone
echo "Pacific/Auckland NZ" | sudo tee /etc/timezone
sudo dpkg-reconfigure --frontend noninteractive tzdata
# Web server setup
# Create user groups and give sudo rights
sudo useradd --system --uid 147 www-code --home /var/lib/codesrc/ --no-user-group
sudo groupadd --system --gid 147 deploystaff
# Create a simple script to sudo to that user & run a command (saves typing later)
(echo '#!/bin/bash'; echo 'sudo -H -u www-code -g deploystaff "$@";') | sudo tee /usr/local/bin/s >/dev/null 2>&1; sudo chmod 755 /usr/local/bin/s 
# Add some sudo config to grant permissions
echo "# Cmnd alias specification
Cmnd_Alias APACHERESTART = /usr/sbin/apache2ctl graceful
Cmnd_Alias PHPCOMMANDS = /usr/bin/php
# User privilege specification
%deploystaff ALL = (www-code:deploystaff) NOPASSWD: ALL
%deploystaff ALL=(root) NOPASSWD: APACHERESTART
%deploystaff ALL = (www-data) NOPASSWD: PHPCOMMANDS
# Allow users in the deploystaff group to run commands as postgres without prompting for a password:
User_Alias DEPLOYSTAFF = %deploystaff
Runas_Alias DBOP = postgres
DEPLOYSTAFF ALL = (DBOP) NOPASSWD: ALL
" | sudo tee >/dev/null /etc/sudoers.d/catalystelearning
sudo chmod 0440 /etc/sudoers.d/catalystelearning
# Put people into groups
for NAME in `echo "ec2-user"`; do
    sudo adduser $NAME deploystaff;
    sudo adduser $NAME sudo;
done
# Configure and install packages
sudo add-apt-repository "deb http://debian.catalyst.net.nz/catalyst stable catalyst #Catalyst"
sudo apt-key advanced --keyserver pgp.net.nz --recv-keys 2CA4EE29621846D9
echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/90install-recommends
sudo apt-get update
# Configure silent installs of postfix and pgdumper
sudo debconf-set-selections <<< "postfix postfix/mailname string moodletotara-heat"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo debconf-set-selections <<< "pgdumper pgdumper/backupcopies string 5"
sudo debconf-set-selections <<< "pgdumper pgdumper/annoy string null@catalyst.net.nz"
sudo debconf-set-selections <<< "pgdumper pgdumper/skipdb string "
# Install required packages
sudo apt-get  -y  --fix-missing install apache2 libapache2-mod-php5 php5-pgsql cron php5-cli aspell \
php5-curl php5-xmlrpc php5-gd php5-intl php5-imagick file git-core \
graphviz bsd-mailx libapache2-mod-rpaf pgdumper aexec postgresql-client
sed -i "s/upload_max_filesize = [[:alnum:]]/upload_max_filesize = 512M/"  /etc/php5/apache2/php.ini
sed -i "s/post_max_size = [[:alnum:]]/post_max_size = 518M/"  /etc/php5/apache2/php.ini
# Make a bunch of directories we will need
for DIR in "/var/www" "/var/log/sitelogs" "/var/lib/codesrc/"; do
    sudo mkdir $DIR -p
    sudo chown root:deploystaff $DIR
    sudo chmod 775 $DIR
done;
umask 0002;
sudo -H -u www-code -g deploystaff mkdir -p /var/www/$SITEENVIRONMENT
sudo chmod g+s /var/www/$SITEENVIRONMENT
sudo mkdir -p /var/lib/sitedata/$SITEENVIRONMENT
sudo chmod g+w /var/lib/sitedata/$SITEENVIRONMENT
sudo chown www-data:www-data /var/lib/sitedata/$SITEENVIRONMENT
sudo -H -u www-code -g deploystaff mkdir -p /var/log/sitelogs/$SITEENVIRONMENT
#create a site-available file for apache
cat | sudo tee /etc/apache2/sites-available/100-$SITEENVIRONMENT.conf >/dev/null <<DEMARC
<VirtualHost *:1080>
    ServerName $URL

    DocumentRoot /var/www/$SITEENVIRONMENT
    CustomLog /var/log/sitelogs/$SITEENVIRONMENT/apache-access.log combined
    ErrorLog  /var/log/sitelogs/$SITEENVIRONMENT/apache-error.log

    <Directory /var/www/$SITEENVIRONMENT>
        Options -Indexes
        AllowOverride All
    </Directory>
</VirtualHost>
DEMARC
#link them to sites enabled
sudo a2ensite 100-$SITEENVIRONMENT.conf
sudo service apache2 reload
#make /var/www/default
mkdir /var/www/default
cat > /var/www/default/index.html << DEMARC
<html>
    <head>
        <title>Incorrect URL</title>
    </head>
    <body>
        <p>You have tried to access a site that doesn't exist.  Check the URL and try again.</p>
        <!-- Apache -->
    </body>
</html>
DEMARC
# change apache's ports.conf to listen on port 1080, the default site to use /var/www/default and be a namevhost for post 1080
sed -i "s/Listen 80/Listen 1080/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:80>/<VirtualHost \*:1080>/" /etc/apache2/sites-enabled/000-default.conf
sed -i "s|DocumentRoot /var/www/html|DocumentRoot /var/www/default|" /etc/apache2/sites-enabled/000-default.conf
# Output webserver IP
export WEBSERVERIP=`ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
# Do a clone & quick tidyup, and checkout
sudo chmod g+w /var/www/$SITEENVIRONMENT
# Do a git clone as you, and a git checkout as www-code.
cd /var/www/$SITEENVIRONMENT
git clone $GITREPO .
# Pack directories need to be owned by deploystaff, with group sticky bit set, so files that later get created in them (due to updates) maintain the same group ownership.
sudo chown www-code:deploystaff /var/www/$SITEENVIRONMENT/ -R
sudo find /var/www/$SITEENVIRONMENT/.git -type d -exec chmod g+s {} \;
sudo find /var/www/$SITEENVIRONMENT/.git -exec chmod g+w {} \;
sudo -u www-code -g deploystaff git branch -a
sudo -u www-code -g deploystaff git branch --track $GITBRANCH origin/$GITBRANCH
sudo -u www-code -g deploystaff git checkout $GITBRANCH

APPVERSION=$(grep "\$branch" /var/www/$SITEENVIRONMENT/version.php | awk '{print $3}' | sed "s/'//g" | sed "s/;//g")

# Copy the config-dist to config.php & fill in values
sudo -u www-code cp config-dist.php config.php
sed -i "s|$CFG->dbhost    = 'localhost';|$CFG->dbhost    = '$DBSERVERIP';|" config.php
sed -i "s|^\$CFG->dbname.*=.*$|\$CFG->dbname    = '$SITEENVIRONMENT';|" config.php
sed -i "s|$CFG->dbuser    = 'username';|$CFG->dbuser    = '$SITEENVIRONMENT';|" config.php
sed -i "s|$CFG->dbpass    = 'password';|$CFG->dbpass    = '$PGPASSWORD';|" config.php
sed -i "s|^\$CFG->wwwroot.*=.*;$|\$CFG->wwwroot   = 'https://$URL';|" config.php
sed -i "s|^\$CFG->dataroot.*=.*;$|\$CFG->dataroot   = '/var/lib/sitedata/$SITEENVIRONMENT';|" config.php
sed -i "s|//[ ]*\$CFG->sslproxy = true;|      \$CFG->sslproxy = true;|" config.php

# Set site defaults
cat | sudo tee /var/www/$SITEENVIRONMENT/local/defaults.php >/dev/null <<DEMARC
<?php
\$defaults['moodle']['guestloginbutton'] = 0;     // Disable guest login
\$defaults['moodle']['rememberusername'] = 0;     // Disable remember username
\$defaults['moodle']['summary'] = 'Front page summary';     // Disable remember username
DEMARC

sudo chmod 755 /var/www/$SITEENVIRONMENT/local/defaults.php
sudo chown www-code:deploystaff /var/www/$SITEENVIRONMENT/local/defaults.php

# Run the site setup
sudo -u www-data php /var/www/$SITEENVIRONMENT/admin/cli/install_database.php \
--agree-license=yes --adminuser=admin --adminpass=$PGPASSWORD --adminemail='null@catalyst.net.nz' --fullname=$SITENAME --shortname=$SITENAME 
# For versions lower than 2.9, adminemail is not an install option, so do a manual Db update
if [[ $APPVERSION < 29 ]]
then
 psql -h $DBSERVERIP -U $SITEENVIRONMENT   $SITEENVIRONMENT -c "update mdl_user set email='null@catalyst.net.nz' where username LIKE 'admin';"
fi
# Install nginx
sudo apt-get -y install nginx

# make some files & links for nginx:

sudo mkdir /etc/nginx/maintenance
sudo touch /etc/nginx/maintenance/maintenancemodeoff.conf
sudo touch /etc/nginx/maintenance/maintenancemodeon.conf
sudo ln -s /etc/nginx/maintenance/maintenancemodeoff.conf /etc/nginx/maintenance/maintenancemode.conf
sudo mkdir /etc/nginx/ssl
s mkdir /var/www/errormessages

# Generate a key & CSR
sudo apt-get -y install openssl
cd /etc/nginx/ssl
sudo openssl genrsa -out $SITEENVIRONMENT.key 2048
sudo chmod 400 $SITEENVIRONMENT.key
sudo openssl req -new -key $SITEENVIRONMENT.key -out $SITEENVIRONMENT.csr -subj '/C=NZ/CN='"$URL"'/'
sudo openssl x509 -req -days 1096 -in $SITEENVIRONMENT.csr -signkey $SITEENVIRONMENT.key -out $SITEENVIRONMENT.crt
sudo cat $SITEENVIRONMENT.crt > $SITEENVIRONMENT.chain
sudo cp $SITEENVIRONMENT.crt $SITEENVIRONMENT.crtchain

sudo chown :deploystaff /etc/nginx/ssl/$SITEENVIRONMENT.crtchain
sudo chmod 644 /etc/nginx/ssl/$SITEENVIRONMENT.crtchain
sudo chown :deploystaff /etc/nginx/ssl/$SITEENVIRONMENT.key
sudo chmod 640 /etc/nginx/ssl/$SITEENVIRONMENT.key

# Create a site-available file for nginx
cat | sudo tee /etc/nginx/sites-available/100-$SITEENVIRONMENT.conf >/dev/null <<DEMARC
upstream $URL {
    server 127.0.0.1:1080;
}

server {
    listen $WEBSERVERIP:443;
    server_name $URL;

    ssl on;
    ssl_certificate /etc/nginx/ssl/$SITEENVIRONMENT.crtchain;
    ssl_certificate_key /etc/nginx/ssl/$SITEENVIRONMENT.key;
    ssl_ciphers HIGH:!aNULL:!MD5:!kEDH:!SSlv2:!SSLv3;

    location / {
        # Workaround for http://support.microsoft.com/kb/2019105 (see also WR201808)
        # This directive sends back a 501 "Method Not Implemented" response to
        # the OPTIONS and PROPFIND verbs, and to the HEAD verb if it is coming
        # from the user agent "Microsoft Office Existence Discovery"
        set \$notsharepoint "\${request_method},\${http_user_agent}";
        if (\$notsharepoint ~* "(^OPTIONS,)|(^PROPFIND,)|(^HEAD,Microsoft Office Existence Discovery\$)") {
            return 501;
        }

        proxy_pass http://$URL;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_ssl_session_reuse off;
        proxy_read_timeout 300s;
        error_page 502 /502.html;

        include /etc/nginx/maintenance/maintenancemode.conf;

    }

    location = /maintenance.html {
        root /var/lib/nginx/www;
    }
    location /502.html {
        internal;
        alias /var/www/errormessages/502.html;
    }

    access_log /var/log/sitelogs/$SITEENVIRONMENT/nginx-access.log;
    error_log /var/log/sitelogs/$SITEENVIRONMENT/nginx-error.log;
}
DEMARC

# Create a http-redirect config 
cat | sudo tee /etc/nginx/sites-available/100-$SITEENVIRONMENT-redirect.conf >/dev/null <<DEMARC
server {
    listen $WEBSERVERIP:80;
    server_name $URL;
    rewrite ^ https://$URL\$request_uri? permanent;
}
DEMARC

# Enable that nginx config 

sudo ln -s /etc/nginx/sites-available/100-$SITEENVIRONMENT.conf /etc/nginx/sites-enabled/100-$SITEENVIRONMENT.conf
sudo ln -s /etc/nginx/sites-available/100-$SITEENVIRONMENT-redirect.conf /etc/nginx/sites-enabled/100-$SITEENVIRONMENT-redirect.conf

# Create a 502 page 

cat | sudo tee /var/www/errormessages/502.html >/dev/null <<DEMARC
<html>
<head>
<title>Temporary Server Error</title>
<meta http-equiv="refresh" content="2">
</head>
<body>
<h1>The server encountered a temporary error</h1>

<p>This page will automatically refresh every 2 seconds; if it doesn't, click the refresh button in your browser.</p>

<p>Sorry for any inconvenience.</p>
</body>
</html>
DEMARC

# reload nginx 
sudo /etc/init.d/nginx reload

#Set up cron
echo "
1-56/5 * * * * www-data [ -e /var/www/$SITEENVIRONMENT/admin/cli/cron.php ] && /usr/bin/aexec -d 46 -f /var/lib/sitedata/$SITEENVIRONMENT/cron.lock /usr/bin/php5 -c /etc/php5/apache2/php.ini /var/www/$SITEENVIRONMENT/admin/cli/cron.php >> /var/lib/sitedata/$SITEENVIRONMENT/cron.log 2>&1" | sudo tee /etc/cron.d/$SITEENVIRONMENT >/dev/null




