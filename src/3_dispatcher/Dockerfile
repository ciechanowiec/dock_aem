FROM ubuntu/apache2:latest

ARG CPU_ARCH
ARG AEM_PUBLISH_HOSTNAME

COPY ../commons/apt-installer.sh .
RUN ./apt-installer.sh
RUN rm apt-installer.sh

RUN mkdir -p /etc/apache2/conf
RUN mkdir -p /etc/apache2/extra
RUN mkdir -p /etc/apache2/logs
RUN mkdir -p /tmp/dispatcher
RUN mkdir -p /usr/local/var/www

# Let Apache user write into cache directory:
RUN chown www-data:www-data /usr/local/var/www/

WORKDIR /tmp/dispatcher

RUN curl --output /tmp/dispatcher/dispatcher.tar.gz https://download.macromedia.com/dispatcher/download/dispatcher-apache2.4-linux-${CPU_ARCH}-4.3.5.tar.gz
RUN tar --extract --verbose --file dispatcher.tar.gz

RUN cp --verbose dispatcher-apache2.4-4.3.5.so /usr/lib/apache2/modules/mod_dispatcher.so
COPY ../3_dispatcher/apache2.conf /etc/apache2/apache2.conf
COPY ../3_dispatcher/dispatcher.any /etc/apache2/conf/dispatcher.any
COPY ../3_dispatcher/httpd-dispatcher.conf /etc/apache2/extra

RUN sed -i "s/\/hostname \"127.0.0.1\"/\/hostname \"${AEM_PUBLISH_HOSTNAME}\"/g" /etc/apache2/conf/dispatcher.any

WORKDIR /etc/apache2
