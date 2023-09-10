FROM varnish:latest

USER root

RUN apt update
RUN apt install less -y && \
    apt install curl -y && \
    apt install htop -y && \
    apt install psmisc -y && \
    apt install jq -y && \
    apt install vim -y && \
    apt install tree -y && \
    apt install wget -y

COPY ../4_varnish/default.vcl /etc/varnish
