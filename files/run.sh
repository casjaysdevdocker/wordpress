#!/bin/bash

__url_check() {
  curl -q -SIs "http://localhost:80" | grep -qE 'HTTP/[1,2]*' && return 0 || return 1
}

__file_check() {
  ls var/run/php-fpm.sock /var/run/mysqld/mysqld.sock /var/run/nginx/nginx.pid &>/dev/null && return 0 || return 1
}

__mysqld() {
  __mysql_test || mysqld_safe --datadir=/var/lib/mysql &
  [[ $? = 0 ]] && sleep 10 && return 0 || exit 1
}

__mysql_test() {
  server_db="$(mysqladmin --silent --wait=30 ping &>/dev/null && echo 'running')"
  [[ "$server_db" = "running" ]] && return 0 || return 1
}

if [ "$1" = "healthcheck" ]; then
  __url_check && __file_check && exit 0 || exit 1
fi

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

if [ -d "/var/lib/wordpress/devel" ]; then
  echo "[i] Initializing plugin development dir"
  for d in $(ls /var/lib/wordpress/devel); do
    ln -sf "/var/lib/wordpress/devel/$d" "/usr/html/wp-content/plugins/$d"
  done
fi

if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "[i] Initializing mysql database"
  rm -Rf "/var/lib/mysql/"
  /usr/bin/mysql_install_db --user=mysql --datadir=/var/lib/mysql
  __mysqld
  __mysql_test
  mysqladmin -u root password "$DB_PASS"
fi

mkdir -p /usr/logs/php8
mkdir -p /usr/logs/nginx
mkdir -p /tmp/nginx

chown -Rf nginx /tmp/nginx
chown -Rf mysql:mysql /var/lib/mysql /run/mysqld

/usr/bin/php-fpm &
__mysql_test || __mysqld

if [ ! -d "/var/lib/mysql/wordpress" ]; then
  echo "[i] Creating word database"
  mysql -uroot -p$DB_PASS -e "CREATE DATABASE $DB_NAME"
  mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO $DB_NAME@localhost IDENTIFIED BY '$DB_PASS'"
fi

[ -z "$DB_HOST" ] && echo "Database host: not set" || echo "Database host: $DB_HOST"
[ -z "$DB_NAME" ] && echo "Database name: not set" || echo "Database name: $DB_NAME"
[ -z "$DB_USER" ] && echo "Database user: not set" || echo "Database user: $DB_USER"
[ -z "$DB_PASS" ] && echo "Database pass: not set" || echo "Database pass: $DB_PASS"

nginx
