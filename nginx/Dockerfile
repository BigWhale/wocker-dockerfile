FROM wocker/base

MAINTAINER ixkaito <ixkaito@gmail.com>

#
# Prepare for installation
#
RUN apt-get update \
  && apt-get clean \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
   wget \
   gnupg \
   ca-certificates \
   apt-transport-https

RUN wget -q https://packages.sury.org/php/apt.gpg \
  && APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn apt-key add apt.gpg

RUN echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list

#
# Install nginx and PHP
#
RUN apt-get update \
  && apt-get clean \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nginx \
    php7.2 \
    php7.2-bz \
    php7.2-cli \
    php7.2-curl \
    php7.2-fpm \
    php7.2-gd \
    php7.2-mbstring \
    php7.2-mysql \
    php7.2-xdebug \
    php7.2-xml \
  && rm -rf /var/lib/apt/lists/*

#
# nginx settings
#
RUN sed -i -e "s#root /var/www/html;#root /var/www/wordpress/;#" /etc/nginx/sites-available/default \
  && sed -i -e "s/index index.html/index index.html index.php/" /etc/nginx/sites-available/default \
  && sed -i -e "/location.*php/,/}/ s/#//" /etc/nginx/sites-available/default \
  && sed -i -e "/# With php-cgi.*/,/}/ s/fastcgi.*//" /etc/nginx/sites-available/default \
  && sed -i -e "s/server_name _;/server_name localhost;/" /etc/nginx/sites-available/default \
  && sed -i -e "s/php7.0-fpm.sock;/php7.2-fpm.sock;/" /etc/nginx/sites-available/default \
  && sed -i -e "s/try_files \$uri \$uri\/ \=404;/try_files \$uri \$uri\/ \/index.php?\$args;/" /etc/nginx/sites-available/default \
  && sed -i '54i    include /etc/nginx/wordpress.conf;' /etc/nginx/sites-available/default \
  && sed -i -e "s/user www-data/user wocker/" /etc/nginx/nginx.conf

ADD wordpress.conf /etc/nginx/wordpress.conf

#
# PHP-FPM settings
#
RUN sed -i -e "s/^user =.*/user = wocker/" /etc/php/7.2/fpm/pool.d/www.conf \
  && sed -i -e "s/^group = .*/group = wocker/" /etc/php/7.2/fpm/pool.d/www.conf \
  && sed -i -e "s/^listen.owner =.*/listen.owner = wocker/" /etc/php/7.2/fpm/pool.d/www.conf \
  && sed -i -e "s/^listen.group =.*/listen.group = wocker/" /etc/php/7.2/fpm/pool.d/www.conf

RUN sed -i -e "s/;daemonize = yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf

#
# php.ini settings
#
RUN sed -i -e "s/^upload_max_filesize.*/upload_max_filesize = 32M/" /etc/php/7.2/fpm/php.ini \
  && sed -i -e "s/^post_max_size.*/post_max_size = 64M/" /etc/php/7.2/fpm/php.ini \
  && sed -i -e "s/^display_errors.*/display_errors = On/" /etc/php/7.2/fpm/php.ini \
  && sed -i -e "s/^;mbstring.internal_encoding.*/mbstring.internal_encoding = UTF-8/" /etc/php/7.2/fpm/php.ini \
  && sed -i -e "s#^;sendmail_path.*#sendmail_path = /usr/local/bin/mailhog sendmail#" /etc/php/7.2/fpm/php.ini \
  && service php7.2-fpm start

#
# MariaDB settings & install WordPress
#
WORKDIR ${DOCROOT}
RUN service mysql start \
  && mysqladmin -u root password root \
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
  && chown -R wocker:wocker ${DOCROOT}

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
