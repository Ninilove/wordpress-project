#!/bin/sh
DB_DIRECTORY="/var/www/html/wp-admin"
sudo chmod 777 -R /var/www/html
create_wp() {
    echo "Inserting Wordpress Env variables for connection..."
    sed -i "s/database_name_here/$WORDPRESS_DB_NAME/" /var/www/html/wp-config.php
    sed -i "s/username_here/$WORDPRESS_DB_USER/" /var/www/html/wp-config.php
    sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/" /var/www/html/wp-config.php
    sed -i "s/localhost/$WORDPRESS_DB_HOST/" /var/www/html/wp-config.php
    sed -i "s/false/true/" /var/www/html/wp-config.php
    echo "done ..."
}
main() {
        create_wp
}
main
# Apache gets grumpy about PID files pre-existing
rm -f /var/run/apache2/apache2.pid

/usr/sbin/apachectl -D FOREGROUND
