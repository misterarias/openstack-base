#!/bin/bash
yum install -y mariadb mariadb-server MySQL-python rabbitmq-server

cat > /Etc/my.cnf.d/mariadb_openstack.cnf << _EOF_

[mysqld]
bind-address = 10.0.0.11

default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8

_EOF_

systemctl enable mariadb.service
systemctl start mariadb.service


systemctl enable rabbitmq-server.service
systemctl start  rabbitmq-server.service
rabbitmqctl add_user openstack RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

