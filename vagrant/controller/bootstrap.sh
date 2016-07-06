#!/bin/bash
yum install -y mariadb mariadb-server MySQL-python rabbitmq-server \
  openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached

cat > /etc/my.cnf.d/mariadb_openstack.cnf << _EOF_

[mysqld]
bind-address = 10.0.0.11

default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8

_EOF_

# making this non-interactive would be wonderful
mysql_secure_installation
systemctl enable mariadb.service
systemctl start mariadb.service

systemctl enable rabbitmq-server.service
systemctl start  rabbitmq-server.service
rabbitmqctl add_user openstack RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

systemctl enable memcached.service
systemctl start  memcached.service

# Config keystone
ADMIN_TOKEN=$(openssl rand -hex 10)
cat > /etc/keystone/keystone.conf << _EOF_
[DEFAULT]
admin_token = ${ADMIN_TOKEN}
verbose = True

[memcache]
server = localhost:11211

[database]
connection = mysql://keystone:MARIADB_PASS@controller/keystone

[token]
provider = keystone.token.providers.uuid.Provider
driver = keystone.token.persistence.backends.memcache.Token

[revoke]
driver = keystone.contrib.revoke.backends.sql.Revoke

_EOF_
su -s /bin/sh -c "keystone-manage db_sync" keystone

# Apache
sed -i.bk -e 's/.*ServerName.*/ServerName controller/g' /etc/httpd/conf/httpd.conf
cat > /etc/httpd/conf.d/wsgi-keystone.conf << _EOF_
Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /var/www/cgi-bin/keystone/main
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LogLevel info
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /var/www/cgi-bin/keystone/admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LogLevel info
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined
</VirtualHost>
_EOF_
mkdir -p /var/www/cgi-bin/keystone
curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/kilo \
    | tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin
chown -R keystone:keystone /var/www/cgi-bin/keystone
chmod 755 /var/www/cgi-bin/keystone/*

service httpd restart
