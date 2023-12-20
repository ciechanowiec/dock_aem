FROM aem-base:latest

ARG ZOOKEEPER_DIR
ARG ZOOKEEPER_MY_ID
ARG ZOOKEEPER_DATA_DIR

WORKDIR ${ZOOKEEPER_DIR}

# The SSL adjustment required because of some curl issues related to GitHub API
# (https://stackoverflow.com/questions/75763525/curl-35-error0a000152ssl-routinesunsafe-legacy-renegotiation-disabled):
RUN echo "Options = UnsafeLegacyRenegotiation" >> /etc/ssl/openssl.cnf

COPY ../6_zookeeper/zookeeper-installer.sh .
COPY ../6_zookeeper/zookeeper-starter.sh .

RUN ./zookeeper-installer.sh

RUN rm -v zookeeper-installer.sh
