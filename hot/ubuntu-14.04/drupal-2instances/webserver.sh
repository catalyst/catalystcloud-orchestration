#!/bin/bash

#---------------
# Install Apache
#---------------

# Drupal requires gd to resize images
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 libapache2-mod-php5 php5-gd mysql-client

# Enable modules required by Drupal
#----------------------------------

# Enable PHP
sudo a2enmod php5

# Enable rewrite, so that Drupal can create human-friendly URLs
sudo a2enmod rewrite

# Enable headers, so we can serve gzip compressed CSS and JS files
sudo a2enmod headers

# Enable SSL, so we can serve encrypted content over HTTPS
sudo a2enmod ssl
a2ensite default-ssl

# Generate self-signed certificate
#---------------------------------

sudo mkdir /etc/apache2/ssl
sudo openssl req -x509 -nodes -days 365 -subj '/CN=webserver.domain_name' -newkey rsa:2048 -keyout /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.crt
# TODO: allow existing certificate to be uploaded

# Configure the vHost
#--------------------

(cat << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@domain_name
    DocumentRoot /var/www/drupal
    <Directory /var/www/drupal>
        AllowOverride All
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
) | sudo tee /etc/apache2/sites-available/000-default.conf

(cat << EOF
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@domain_name
        DocumentRoot /var/www/drupal
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/apache.crt
        SSLCertificateKeyFile /etc/apache2/ssl/apache.key
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                        SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
                        SSLOptions +StdEnvVars
        </Directory>
        BrowserMatch "MSIE [2-6]" \
                        nokeepalive ssl-unclean-shutdown \
                        downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
    </VirtualHost>
</IfModule>
EOF
) | sudo tee /etc/apache2/sites-available/default-ssl.conf

# Configure PHP
#--------------

# Tweak php.ini as per https://www.drupal.org/requirements/php
sudo sed -i 's/^\(post_max_size\s*=\s*\).*$/\110M/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(upload_max_filesize\s*=\s*\).*$/\110M/' /etc/php5/apache2/php.ini
sudo sed -i 's/;realpath_cache_size/realpath_cache_size/' /etc/php5/apache2/php.ini
sudo sed -i 's/;realpath_cache_ttl/realpath_cache_ttl/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(realpath_cache_size\s*=\s*\).*$/\164k/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(realpath_cache_ttl\s*=\s*\).*$/\13600/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(error_reporting\s*=\s*\).*$/\1E_ALL \& ~E_NOTICE/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(session.cache_limiter\s*=\s*\).*$/\1nocache/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(session.auto_start\s*=\s*\).*$/\10/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(expose_php\s*=\s*\).*$/\1off/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(allow_url_fopen\s*=\s*\).*$/\1off/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(magic_quotes_gpc\s*=\s*\).*$/\1off/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(register_globals\s*=\s*\).*$/\1off/' /etc/php5/apache2/php.ini
sudo sed -i 's/^\(register_globals\s*=\s*\).*$/\1Off/' /etc/php5/apache2/php.ini
sudo sed -i 's/;opcache.enable=0/opcache.enable=1/' /etc/php5/apache2/php.ini

# Enable the opcache module
sudo php5enmod opcache

# Restart apache to apply the changes
sudo service apache2 restart

#----------------
# Install Drupal
#----------------

# Install drush
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install drush

# Create groups for drupal
sudo groupadd drupal

# Create users for drupal
# -- system: system user
# -M: do not create home directory
# -N: do not create group with the same name as the user
# -g: add user to group
sudo useradd -N -g drupal --shell /bin/bash --create-home --home /home/drupal drupal

# Deploy the Drupal 7 codebase
drush dl drupal-7.x
sudo mv drupal-7.x-dev /var/www/drupal

# Secure it with the appropriate permissions
sudo chown -R drupal.drupal /var/www/drupal
sudo chgrp www-data /var/www/drupal/sites/default
sudo chmod 554 /var/www/drupal/sites/default
sudo mkdir -p /var/www/drupal/sites/default/files
sudo chgrp www-data /var/www/drupal/sites/default/files
sudo chmod 775 /var/www/drupal/sites/default/files

# Create a new settings file and secure it
sudo cp /var/www/drupal/sites/default/default.settings.php /var/www/drupal/sites/default/settings.php
sudo chown drupal.drupal /var/www/drupal/sites/default/settings.php
sudo chmod 644 /var/www/drupal/sites/default/settings.php

# Perform the automated site install process
cd /var/www/drupal
sudo drush -y site-install standard --account-name=drupal_user --account-pass=drupal_password --db-url=mysql://db_user:db_password@db_ipaddr/db_name

