# wordpress-project

Steps
Containerize the application and upload image to container image registry
Setup Kubernetes cluster and CLI
Create PersistentVolumeClaims and PersistentVolumes
Create Secret and config-map for MySQL
Create Service and Deployment for MySQL
Create config-map for Wordpress
Create Service and Deployment for WordPress
Troubleshooting
Step 1. Containerize the application and upload image to container image registry
The first step would be to create a container image of the application we have implemented and upload it to the container registry that is Docker Hub.

Now we will create container images by building docker images using Dockerfile . Ultimately, both ENTRYPOINT and CMD give you a way to identify which executable should be run when a container is started from your image.

## Dockerfile for MySQL-Server:

FROM ubuntu:16.04

ARG MYSQL_PWD_INSTALLATION

RUN apt-get update -y \
    && { \
            echo "mysql-server mysql-server/root_password password $MYSQL_PWD_INSTALLATION"; \
            echo "mysql-server mysql-server/root_password_again password $MYSQL_PWD_INSTALLATION"; \
    } | debconf-set-selections \
    && apt-get install mysql-server -y

RUN set -x \
    && sudo sh -c "echo '[mysqld]' >> /etc/mysql/my.cnf" \
    && sudo sh -c "echo 'bind-address = 0.0.0.0' >> /etc/mysql/my.cnf" \
    && sudo sh -c "echo 'default-authentication-plugin=mysql_native_password' >> /etc/mysql/my.cnf" \
    && sudo sh -c "echo 'datadir=/var/lib/mysql' >> /etc/mysql/my.cnf"

VOLUME /var/lib/mysql
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]



## Entrypoint for MySQL-server:

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
tail -f /var/log/mysql/error.logz



Now we need to build the MySQL image with the following command. We are passing a build argument as MYSQL_PWD_INSTALLATION to set the root password for MySQL server at the time of building the image.

docker build --build-arg MYSQL_PWD_INSTALLATION=<YOUR_PASSWORD> -t mydb .

Press enter or click to view image in full size

## Dockerfile for Wordpress:


FROM ubuntu:16.04

RUN apt-get -y update && apt-get -y install apache2 \
    php \
    php-mysql \
    libapache2-mod-php \ 
    wget \
    && a2enmod php7.0

WORKDIR /var/www/html

RUN set -x \
    && wget https://wordpress.org/wordpress-5.1.1.tar.gz \
    && tar -xzf wordpress-5.1.1.tar.gz \
    && cp -r wordpress/* /var/www/html/ \
    && rm -f index.html \
    && rm -rf wordpress \
    && rm -rf wordpress-5.1.1.tar.gz \
    && mv wp-config-sample.php wp-config.php \
    && sed -i "s/index.php//" /etc/apache2/mods-available/dir.conf \
    && sed -i "s/index.php//" /etc/apache2/mods-enabled/dir.conf \
    && sed -i "s/DirectoryIndex/DirectoryIndex index.php/" /etc/apache2/mods-available/dir.conf \
    && sed -i "s/DirectoryIndex/DirectoryIndex index.php/" /etc/apache2/mods-enabled/dir.conf 

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]

## Entrypoint for Wordpress:

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

Now we need to build the Wordpress image with the following command.

docker build -t mywp .



Once container images are created, we can upload these to any container image registry. Here we will upload these images to Docker Hub. I have uploaded the back-end MySQL image with the name jolly3/wpback , and the front-end Wordpress image with the name jolly3/wpfront.

Step 2. Set up Kubernetes cluster and CLI
There are numerous solutions available for setting up a Kubernetes cluster. Different Kubernetes solutions meet different requirements: ease of maintenance, security, control, available resources, and expertise required to operate and manage a cluster. One could refer to the official documentation for more details about how a cluster could be set up. This example has been replicated on local setup (Minikube).

We will use kubectl as our CLI. Instructions for installing kubectl can be found here. Once kubectl is installed, it should be configured to communicate with the Kubernetes cluster we have set up. In the case of Minikube, minikube start command will automatically configure kubectl.

Step 3. Create PersistentVolumeClaims and PersistentVolumes
First we need to create a PV so that our MySQL database can claim that storage for further use. PV is a kind of spare part of your storage (can be assumed as a directory) which can be divided further into clusters which can be claimed by our deployments.

## Create a mysql-pv.yaml as below.

apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-volume
  labels:
    type: local
spec:
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/var/lib/mysql"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi

Let’s create PV and PVC with the given file. After successful creation of PV and PVC we will see below output.

kuebctl apply -f mysql-pv-pvc.yml 

Step 4. Create secret and config-map for MySQL
The MySQL Database docker image expects some environment variables. We will need to configure the following environment variables MYSQL_ROOT_PASSWORD,MYSQL_USER,MYSQL_PASSWORD, MYSQL_DATABASE.

Now that we have an idea about the configuration required for our application, we will create configMaps and secrets in our Kubernetes cluster with required data.

First, to hold database specific information, we will create one configMap and two secrets. The configMap will contain non-sensitive information about the database setup, like the location where the database is hosted and the name of the database.

Below is the configMap, which is used to store non-sensitive information related to the database in this example.

## Config-map for Database Creation:

apiVersion: v1
kind: ConfigMap
metadata:
  name: db-conf  
data:
  host: mysql   
  name: wpdb

 We will use two secrets to store sensitive data. The first secret will contain the database root user credentials and the second secret will contain application user credentials. Below are these two files. As I have encoded the passwords and usernames in Base64. Base64 is a group of binary-to-text encoding schemes that represent binary data in an ASCII string format by translating it into a radix-64 representation.

## Database Root User Credentials:

apiVersion: v1
kind: Secret
metadata:
  name: db-root-credentials
data:
  password: your password

## Database ApplicationUser Credentials:

apiVersion: v1
kind: Secret
metadata:
  name: db-credentials 
data:
  username: your username
  password: your password

 Then after this we need to create secrets and configMap with the following commands :
 kubectl apply -f mysql-config.yml
 kubectl apply -f db-root-cred.yml
 kubectl apply -f dc-cred.yml

  Step 5. Create Service and Deployment for MySQL
Our next step would be to create the services and deployments required for our MySQL setup. Below is the file which creates relevant Kubernetes Service and Kubernetes Deployment for the MySQL setup in this application.

## Configuration for Deploying MySQL Database on Kubernetes Cluster:

apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
    tier: database
spec:
  ports:
  - port: 3306
  selector:
    app: mysql
    tier: database
  clusterIP: None
---

apiVersion: apps/v1 
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
    tier: database
spec:
  selector:
    matchLabels:
      app: mysql
      tier: database
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
        tier: database
    spec:
      containers:
      - image: jolly3/wpback
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD 
          valueFrom:
            secretKeyRef:
              name: db-root-credentials 
              key: password  
        - name: MYSQL_USER 
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: MYSQL_PASSWORD 
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: MYSQL_DATABASE 
          valueFrom:
            configMapKeyRef:
              name: db-conf
              key: name
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim

Through this file, we created multiple Kubernetes objects. First, we created a Kubernetes Service with the name mysql for accessing the pod running the MySQL container. After this, we created a Deployment object, which configures the deployment of MySQL Server in the cluster. Into the MySQL container, we injected environment variables like MYSQL_ROOT_PASSWORD, MYSQL_USER, MYSQL_PASSWORD , and MYSQL_DATABASE using the configMaps and secrets we created in the previous step.

kubectl apply -f mysql.yml

Step 6. Create config-map for Wordpress
The configuration file expects some environment variables, like WORDPRESS_DB_USERNAME, WORDPRESS_DB_PASSWORD, WORDPRESS_DB_HOST, WORDPRESS_DB_NAME . We will pass the values of these variables to Kubernetes through configMaps and secrets. Then we will configure the Wordpress front-end pod to read the environment variable from the configMaps and secrets .

We will pass the WORDPRESS_DB_USERNAME, WORDPRESS_DB_PASSWORD and WORDPRESS_DB_NAME with the help of the secrets of MySQL which we have created earlier. For WORDPRESS_DB_HOST, we need to create one more configMap. As Wordpress expects the value of Service_Name:Port from the back-end, generated in the above step, to be passed in the form of the environment variable WORDPRESS_DB_HOST.

## Config-map for Backend Connection:

apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-conf
data:
  server-uri: mysql:3306


kubectl apply -f wp-configmap.yml

We will use this configMap to inject server-uri value when configuring the deployment of Wordpress, in the next step.

Step 7. Create Service and Deployment for Wordpress
Next, we set up our Wordpress application deployment. Below is the yaml file which creates the required Kubernetes objects.

## Configuration for Deploying Wordpress Application on Kubernetes Cluster:


apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
    tier: frontend
spec:
  ports:
  - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: NodePort
---

apiVersion: apps/v1 
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
    tier: frontend
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
      - image: jolly3/wpfront
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          valueFrom:
            configMapKeyRef:
              name: backend-conf
              key: server-uri
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: WORDPRESS_DB_NAME
          valueFrom:
            configMapKeyRef:
              name: db-conf
              key: name
        ports:
        - containerPort: 80
          name: wordpress

Here, we first created a Service of type NodePort (using NodePort as weare running Kubernetes locally) which exposes the front-end wordpress instances. NodePort type provides an External-IP , through which one could access the front-end services externally. Next, we created the Deployment object configured to contain one replica (we can increase the replicas at the run time also if we want) of the front-end instance. This deployment will use the image jolly3/wpfront, which we created in step one. After this, we injected the environment variable WORDPRESS_DB_HOST from configMap, which we created in the above setup. And other environment variables from the same secrets we have used in MySQL.

kubectl apply -f wordpress.yml

