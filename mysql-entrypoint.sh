#!/bin/sh
DB_DIRECTORY="/var/lib/mysql/mysql"
chown mysql:mysql -R /var/lib/mysql
intilize_data_dir() {
    echo "Initilizing data directory"
    mysqld --initialize-insecure
}
wait_for_intilization() {
    while true;
    do
        if [ ! -d "$DB_DIRECTORY" ];
        then
            sleep 1;
            echo "Waiting for data directory to be created"
        else
            break
        fi
    done
}
start_mysql() {
    echo "Starting mysql service"
    service mysql start
}
change_root_password() {
    echo "Changing root password."
    mysql -u root -p'' -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
}
create_db() {
    if [ "$MYSQL_DATABASE" != "" ]; then
        RESULT=`mysql -u root -p$MYSQL_ROOT_PASSWORD --skip-column-names -e "SHOW DATABASES LIKE '$MYSQL_DATABASE';"`
        if [ "$RESULT" = "$MYSQL_DATABASE" ]; then
            echo "database: $MYSQL_DATABASE already exists."
        else
            echo "Creating database: $MYSQL_DATABASE"
            mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;"
        fi
        QUERY_RESULT=`mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT COUNT(*) FROM mysql.user WHERE user = '$MYSQL_USER';"`
        echo "myresult=$QUERY_RESULT"
        result=$(echo $QUERY_RESULT | awk '{print $2}')
        echo "result=$result"
        if [ "$result" = 0 ];then
            echo "Creating user: $MYSQL_USER"
            mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$MYSQL_USER' IDENTIFIED BY '$MYSQL_PASSWORD';"
            mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER';"
            mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
        else
            echo "Database user '$MYSQL_USER' already created. Continue ..."
        fi
    fi
}
main() {
    if [ ! -d "$DB_DIRECTORY" ]; then
        intilize_data_dir
        wait_for_intilization
        start_mysql
        change_root_password
        create_db
    else
        start_mysql
        create_db
    fi
}
main
tail -f /var/log/mysql/error.log
