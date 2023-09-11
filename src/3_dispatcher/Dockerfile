FROM ubuntu/apache2:latest

ARG CPU_ARCH

RUN apt update
RUN apt install less -y && \
    apt install curl -y && \
    apt install htop -y && \
    apt install psmisc -y && \
    apt install jq -y && \
    apt install vim -y && \
    apt install tree -y && \
    apt install wget -y

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

WORKDIR /etc/apache2