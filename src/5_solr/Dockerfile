FROM ciechanowiec/aem-base:1.0.3

ARG SOLR_DIR
ARG ZK_HOST
ARG IS_UNSAFE

WORKDIR ${SOLR_DIR}

# The SSL adjustment required because of some curl issues related to GitHub API
# (https://stackoverflow.com/questions/75763525/curl-35-error0a000152ssl-routinesunsafe-legacy-renegotiation-disabled):
RUN echo "Options = UnsafeLegacyRenegotiation" >> /etc/ssl/openssl.cnf

COPY ../5_solr/solr-installer.sh .
COPY ../5_solr/solr-starter.sh .
COPY ../5_solr/jetty.xml .

RUN ./solr-installer.sh
RUN rm -v solr-installer.sh

COPY ../5_solr/update-configset.sh $SOLR_DIR/bin/
COPY ../5_solr/download-configsets.sh $SOLR_DIR/bin/
