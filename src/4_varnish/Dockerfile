FROM varnish:latest

ARG AEM_PUBLISH_HOSTNAME

USER root

COPY ../commons/apt-installer.sh .
RUN ./apt-installer.sh
RUN rm apt-installer.sh

COPY ../4_varnish/default.vcl /etc/varnish

RUN sed -i "s/localhost/"${AEM_PUBLISH_HOSTNAME}"/g" /etc/varnish/default.vcl
