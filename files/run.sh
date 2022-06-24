#!/bin/bash

if [ "$1" = "healthcheck" ]; then
  curl -q -SIs "http://localhost:80" | grep -qE 'HTTP/[1,2]*' &&
    ls var/run/php-fpm.sock /var/run/mysqld/mysqld.sock /var/run/nginx/nginx.pid &>/dev/null &&
    exit 0 || exit 1
fi

[ -f /run-pre.sh ] && /run-pre.sh

if [ ! -d "/usr/html/wp-admin" ] && [ ! -f "/usr/html/wp-config.php" ]; then
  echo "[i] Installing wordpress..."
  cd /tmp || exit 1
  wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz &&
    tar -xzf /tmp/latest.tar.gz &&
    cp -Rf /tmp/wordpress/. /usr/html/ &&
    rm -Rf /tmp/wordpress /tmp/latest.tar.gz &&
    chown -Rf nginx:nginx /usr/html
else
  echo "[i] Fixing permissions..."
  chown -R nginx:nginx /usr/html
fi

if [ ! -d "/var/lib/mysql/mysql" ]; then
  rm -Rf "/var/lib/mysql/"
  /usr/bin/mysql_install_db --user=mysql --datadir=/var/lib/mysql
  mysqld_safe --datadir=/var/lib/mysql &
  mysqladmin --silent --wait=30 ping || exit 1
  mysqladmin -u root password "$DB_PASS"
fi

mkdir -p /usr/logs/php8
mkdir -p /usr/logs/nginx
mkdir -p /tmp/nginx

chown -Rf nginx /tmp/nginx
chown -Rf mysql:mysql /var/lib/mysql /run/mysqld

/usr/bin/php-fpm &
mysqladmin --silent --wait=30 ping || mysqld_safe --datadir=/var/lib/mysql &

if [ ! -d "/var/lib/mysql/wordpress" ]; then
  sleep 10
  mysql -uroot -p$DB_PASS -e "CREATE DATABASE $DB_NAME"
  mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO $DB_NAME@localhost IDENTIFIED BY '$DB_PASS'"
fi

[ -z "$DB_HOST" ] && echo "Database host: not set" || echo "Database host: $DB_HOST"
[ -z "$DB_NAME" ] && echo "Database name: not set" || echo "Database name: $DB_NAME"
[ -z "$DB_USER" ] && echo "Database user: not set" || echo "Database user: $DB_USER"
[ -z "$DB_PASS" ] && echo "Database pass: not set" || echo "Database pass: $DB_PASS"

nginx
