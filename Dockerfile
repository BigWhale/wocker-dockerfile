FROM ruby:2.5.0-slim-stretch AS builder
FROM ubuntu:bionic

MAINTAINER David Klasinc <david.klasinc@gmail.com> 

#
# Prepare for installation
#

RUN apt-get update && DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends software-properties-common \
  ca-certificates \
  curl \
  less \
  lftp \
  libyaml-0-2 \
  mysql-client \
  mysql-server \
  vim \
  openssh-client \
  sshpass \
  supervisor

RUN add-apt-repository ppa:ondrej/php

ENV BIN=/usr/local/bin

RUN apt-get update \
  && apt-get clean \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
   wget \
   gnupg \
   ca-certificates \
   apt-transport-https \
   nginx \
   php7.3 \
   php7.3-bz \
   php7.3-cli \
   php7.3-curl \
   php7.3-fpm \
   php7.3-gd \
   php7.3-mbstring \
   php7.3-mysql \
   php7.3-xdebug \
   php7.3-xml \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/bin/ruby ${BIN}/ruby
COPY --from=builder /usr/local/bin/gem ${BIN}/gem

#
# Install Gems
#
RUN gem install wordmove --no-document

#
# Install WP-CLI
#
RUN curl -o ${BIN}/wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x ${BIN}/wp

#
# Install PHPUnit
#
RUN curl -o ${BIN}/phpunit -L https://phar.phpunit.de/phpunit.phar \
  && chmod +x ${BIN}/phpunit

#
# Install Mailhog
#
RUN curl -o ${BIN}/mailhog -L https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64 \
  && chmod +x ${BIN}/mailhog

#
# Xdebug settings
#
ADD xdebug.ini /etc/php/7.3/cli/conf.d/20-xdebug.ini

#
# `mysqld_safe` patch
# @see https://github.com/wckr/wocker/pull/28#issuecomment-195945765
#
RUN sed -i -e 's/file) cmd="$cmd >> "`shell_quote_string "$err_log"`" 2>\&1" ;;/file) cmd="$cmd >> "`shell_quote_string "$err_log"`" 2>\&1 \& wait" ;;/' /usr/bin/mysqld_safe

#
# Setting lftp for wordmove via ftp
#
RUN echo "set ssl:verify-certificate no" >> ~/.lftp.rc

ENV WWW=/var/www
ENV DOCROOT=${WWW}/wordpress
RUN mkdir -p ${DOCROOT} \
  && adduser --uid 1000 --gecos '' --disabled-password wocker \
  && sed -i -e "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
ADD wp-cli.yml ${WWW}

#
# nginx settings
#
RUN sed -i -e "s#root /var/www/html;#root /var/www/wordpress/;#" /etc/nginx/sites-available/default \
  && sed -i -e "s/index index.html/index index.html index.php/" /etc/nginx/sites-available/default \
  && sed -i -e "/location.*php/,/}/ s/#//" /etc/nginx/sites-available/default \
  && sed -i -e "/# With php-cgi.*/,/}/ s/fastcgi.*//" /etc/nginx/sites-available/default \
  && sed -i -e "s/server_name _;/server_name localhost;/" /etc/nginx/sites-available/default \
  && sed -i -e "s/php7.0-fpm.sock;/php7.3-fpm.sock;/" /etc/nginx/sites-available/default \
  && sed -i -e "s/try_files \$uri \$uri\/ \=404;/try_files \$uri \$uri\/ \/index.php?\$args;/" /etc/nginx/sites-available/default \
  && sed -i '54i    include /etc/nginx/wordpress.conf;' /etc/nginx/sites-available/default \
  && sed -i -e "s/user www-data/user wocker/" /etc/nginx/nginx.conf \
  && sed -i -e "1s/^/daemon off;\n/" /etc/nginx/nginx.conf

ADD wordpress.conf /etc/nginx/wordpress.conf

#
# PHP-FPM settings
#
RUN mkdir -p /run/php
RUN sed -i -e "s/^user =.*/user = wocker/" /etc/php/7.3/fpm/pool.d/www.conf \
  && sed -i -e "s/^group = .*/group = wocker/" /etc/php/7.3/fpm/pool.d/www.conf \
  && sed -i -e "s/^listen.owner =.*/listen.owner = wocker/" /etc/php/7.3/fpm/pool.d/www.conf \
  && sed -i -e "s/^listen.group =.*/listen.group = wocker/" /etc/php/7.3/fpm/pool.d/www.conf

RUN sed -i -e "s/;daemonize = yes/daemonize = no/g" /etc/php/7.3/fpm/php-fpm.conf

#
# php.ini settings
#
RUN sed -i -e "s/^upload_max_filesize.*/upload_max_filesize = 32M/" /etc/php/7.3/fpm/php.ini \
  && sed -i -e "s/^post_max_size.*/post_max_size = 64M/" /etc/php/7.3/fpm/php.ini \
  && sed -i -e "s/^display_errors.*/display_errors = On/" /etc/php/7.3/fpm/php.ini \
  && sed -i -e "s/^;mbstring.internal_encoding.*/mbstring.internal_encoding = UTF-8/" /etc/php/7.3/fpm/php.ini \
  && sed -i -e "s#^;sendmail_path.*#sendmail_path = /usr/local/bin/mailhog sendmail#" /etc/php/7.3/fpm/php.ini


#
# MariaDB settings & install WordPress
#
WORKDIR ${DOCROOT}
RUN service mysql start && mysqladmin -u root password root \
  && mysql -uroot -proot -e \
    "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8; grant all privileges on wordpress.* to wordpress@'%' identified by 'wordpress';" \
  && wp core download --allow-root \
  && wp core config --allow-root \
    --dbname=wordpress \
    --dbuser=wordpress \
    --dbpass=wordpress \
    --dbhost=localhost \
  && wp core install --allow-root \
    --admin_name=admin \
    --admin_password=admin \
    --admin_email=admin@example.com \
    --url=http://wocker.test \
    --title=WordPress \
  && wp theme update --allow-root --all \
  && wp plugin update --allow-root --all \
  && chown -R wocker:wocker ${DOCROOT} \
  && service mysql stop && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
RUN chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
RUN rm -f /var/run/mysqld/mysqld.sock

VOLUME /var/lib/mysql

#
# Open ports
#
EXPOSE 80 3306 8025

#
# Supervisor
#
RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord"]

