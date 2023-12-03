FROM aem-base:latest

ARG SOLR_DIR

WORKDIR ${SOLR_DIR}

# The SSL adjustment required because of some curl issues related to GitHub API
# (https://stackoverflow.com/questions/75763525/curl-35-error0a000152ssl-routinesunsafe-legacy-renegotiation-disabled):
RUN echo "Options = UnsafeLegacyRenegotiation" >> /etc/ssl/openssl.cnf

COPY ../5_solr/solr-installer.sh .
COPY ../5_solr/solr-starter.sh .

RUN ./solr-installer.sh

RUN rm -v solr-installer.sh
