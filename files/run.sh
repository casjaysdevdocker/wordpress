#!/bin/bash

__url_check() {
  curl -q -SIs "http://localhost:80" | grep -qE 'HTTP/[1,2]*' && return 0 || return 1
}

__file_check() {
  ls var/run/php-fpm.sock /var/run/mysqld/mysqld.sock /var/run/nginx/nginx.pid &>/dev/null && return 0 || return 1
}

__phpfpm() {
  if [ -f "/var/run/php-fpm.sock" ]; then
    return 0
  else
    echo "[i] Starting php-fpm..."
    /usr/bin/php-fpm &
    if [[ $? = 0 ]]; then
      sleep 10
      return 0
    else
      exit 1
    fi
  fi
}

__mysqld() {
  if ! __mysql_test; then
    mysqld_safe --datadir=/var/lib/mysql &
  fi
  if [[ $? = 0 ]]; then
    sleep 5
    return 0
  else
    exit 1
  fi
}

__mysql_test() {
  server_db="$(mysqladmin --silent --wait=2 ping &>/dev/null && echo 'running')"
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
  plugins="$(ls /var/lib/wordpress/devel 2>/dev/null || false)"
  [ -d "/usr/html/wp-content/plugins" ] || mkdir -p "/usr/html/wp-content/plugins"
  if [ -n "$plugins" ]; then
    for d in $plugins; do
      ln -sf "/var/lib/wordpress/devel/$d" "/usr/html/wp-content/plugins/$d"
    done
  fi
fi

if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "[i] Initializing mysql database"
  rm -Rf "/var/lib/mysql/" &>/dev/null
  /usr/bin/mysql_install_db --user=mysql --datadir=/var/lib/mysql
  __mysqld
  __mysql_test
  mysqladmin -u root password "$DB_PASS"
fi

echo "[i] Creating directories..."
mkdir -p /usr/logs/php8
mkdir -p /usr/logs/nginx
mkdir -p /tmp/nginx

echo "[i] Setting permissions..."
chown -Rf nginx /tmp/nginx
chown -Rf mysql:mysql /var/lib/mysql /run/mysqld

echo "[i] Starting mysql database server..."
__mysql_test || __mysqld

if [ ! -d "/var/lib/mysql/wordpress" ]; then
  echo "[i] Creating word database..."
  mysql -uroot -p$DB_PASS -e "CREATE DATABASE $DB_NAME"
  mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO $DB_NAME@localhost IDENTIFIED BY '$DB_PASS'"
fi

[ -z "$DB_HOST" ] && echo "Database host: not set" || echo "Database host: $DB_HOST"
[ -z "$DB_NAME" ] && echo "Database name: not set" || echo "Database name: $DB_NAME"
[ -z "$DB_USER" ] && echo "Database user: not set" || echo "Database user: $DB_USER"
[ -z "$DB_PASS" ] && echo "Database pass: not set" || echo "Database pass: $DB_PASS"

echo "[i] Starting web server..."
nginx
