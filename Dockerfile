FROM php:5.6-apache
MAINTAINER Philip Senst

ENV PHPIPAM_SOURCE https://github.com/phpipam/phpipam/archive/
ENV PHPIPAM_VERSION 1.3.1
ENV PHPMAILER_SOURCE https://github.com/PHPMailer/PHPMailer/
ENV PHPMAILER_VERSION 5.2.21
ENV PHPSAML_SOURCE https://github.com/onelogin/php-saml/
ENV PHPSAML_VERSION 2.10.6
ENV WEB_REPO /var/www/html

RUN echo 'eintrag lokaler Proxy ;' > /etc/apt/apt.conf
RUN printf 'deb http://deb.debian.org/debian/ oldstable main contrib non-free\ndeb http://deb.debian.org/debian/ oldstable-updates main contrib non-free\ndeb http://deb.debian.org/debian-security oldstable/updates main' > /etc/apt/sources.list

RUN curl https://phar.phpunit.de/phpunit-5.6.0.phar -L -o phpunit.phar
RUN chmod +x phpunit.phar
RUN mv phpunit.phar /usr/local/bin/phpunit

# Install required deb packages
RUN apt-get update && apt-get -y upgrade && \
    apt-get install -y locales libgmp-dev libmcrypt-dev libpng12-dev libfreetype6-dev libjpeg-dev libpng-dev libldap2-dev && \
    rm -rf /var/lib/apt/lists/*

# Set the locale
RUN echo 'de_DE.UTF-8 UTF-8' >> /etc/locale.gen
RUN locale-gen de_DE.UTF-8
RUN locale-gen de_DE.iso88591
ENV LANG de_DE.UTF-8
ENV LANGUAGE de_DE:de
ENV LC_ALL de_DE.UTF-8

# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-configure gd --enable-gd-native-ttf --with-freetype-dir=/usr/include/freetype2 --with-png-dir=/usr/include --with-jpeg-dir=/usr/include && \
    docker-php-ext-install gd && \
    docker-php-ext-install sockets && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install gettext && \
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install mcrypt && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install ldap && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# copy phpipam sources to web dir
ADD ${PHPIPAM_SOURCE}/${PHPIPAM_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/${PHPIPAM_VERSION}.tar.gz -C ${WEB_REPO}/ --strip-components=1

# Copy referenced submodules into the right directory
ADD ${PHPMAILER_SOURCE}/archive/v${PHPMAILER_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPMAILER_VERSION}.tar.gz -C ${WEB_REPO}/functions/PHPMailer/ --strip-components=1
ADD ${PHPSAML_SOURCE}/archive/v${PHPSAML_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPSAML_VERSION}.tar.gz -C ${WEB_REPO}/functions/php-saml/ --strip-components=1

# Use system environment variables into config.php
RUN cp ${WEB_REPO}/config.dist.php ${WEB_REPO}/config.php && \
    sed -i -e "s/\['host'\] = 'localhost'/\['host'\] = 'mysql'/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = 'root'/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\")/" \
    ${WEB_REPO}/config.php && \
    sed -i -e "s/\['port'\] = 3306;/\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\");\nif(file_exists(\$password_file))\n\$db\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    ${WEB_REPO}/config.php

EXPOSE 80
