FROM alpine:latest

ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="CasjaysDev <docker-admin@casjaysdev.com>" \
  alpine-version="latest" \
  nginx-version="latest" \
  php-version="latest" \
  wordpress-version="latest" \
  build="24-June-2022" \
  org.opencontainers.image.title="alpine-php-wordpress" \
  org.opencontainers.image.description="Wordpress image running on Alpine Linux" \
  org.opencontainers.image.authors="CasjaysDev <docker-admin@casjaysdev.com>" \
  org.opencontainers.image.vendor="CasjaysDev" \
  org.opencontainers.image.version="latest" \
  org.opencontainers.image.url="https://hub.docker.com/r/casjaysdev/wordpress/" \
  org.opencontainers.image.source="https://github.com/casjaysdev/wordpress" \
  org.opencontainers.image.revision=$VCS_REF \
  org.opencontainers.image.created=$BUILD_DATE

ENV TERM="xterm" \
  DB_HOST="localhost" \
  DB_NAME="wordpress" \
  DB_USER="root"\
  DB_PASS="password"

RUN apk -U upgrade && \ 
  apk add --no-cache bash curl less vim nginx ca-certificates git tzdata zip \
  libmcrypt-dev zlib-dev gmp-dev \
  freetype-dev libjpeg-turbo-dev libpng-dev \
  php-fpm php-json php-zlib php-xml php-xmlwriter \
  php-simplexml php-pdo php-phar php-openssl \
  php-pdo_mysql php-mysqli php-session \
  php-gd php-iconv php-gmp php-zip \
  php-curl php-opcache php-ctype \
  php-intl php-bcmath php-dom php-mbstring php-xmlreader \
  mysql-client mysql curl && \
  apk add -u musl && \
  rm -rf /var/cache/apk/* && \
  ln -sf /usr/sbin/php-fpm8 /usr/bin/php-fpm

RUN /usr/bin/mysql_install_db --user=mysql --datadir=/var/lib/mysql && \
  sed -i 's|skip-networking|#skip-networking|g' /etc/my.cnf && \
  sed -i 's|#bind-address=.*|bind-address=127.0.0.1|g' /etc/my.cnf.d/mariadb-server.cnf && \
  sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php8/php.ini && \
  sed -i 's/expose_php = On/expose_php = Off/g' /etc/php8/php.ini && \
  sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/usr:\/bin\/bash/g" /etc/passwd && \
  sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/usr:\/bin\/bash/g" /etc/passwd- && \
  echo "mysqld_safe --datadir=/var/lib/mysql --port=3306 &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysqladmin -u root password 'password'" >> /tmp/config && \
  bash /tmp/config && \
  rm -f /tmp/config

ADD files/nginx.conf /etc/nginx/
ADD files/php-fpm.conf /etc/php8/
ADD files/run.sh /usr/local/bin/entrypoint-wordpress.sh
RUN chmod +x /usr/local/bin/entrypoint-wordpress.sh && \
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
  chmod +x wp-cli.phar && \
  mv wp-cli.phar /usr/bin/wp-cli && \
  chown nginx:nginx /usr/bin/wp-cli && \
  chown -Rf mysql:mysql /var/lib/mysql /run/mysqld

EXPOSE 80
VOLUME ["/usr/html", "/var/lib/mysql"]

HEALTHCHECK CMD ["usr/local/bin/entrypoint-wordpress.sh", "healthcheck"]
ENTRYPOINT ["/usr/local/bin/entrypoint-wordpress.sh"]
