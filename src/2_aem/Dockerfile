FROM ciechanowiec/aem-base:1.0.4

ARG AEM_DIR
ARG AEM_TYPE
ARG RUN_MODES
ARG AEM_PORT
ARG DEBUG_PORT
ARG NUM_OF_EXPECTED_BUNDLES_AFTER_FIRST_START
ARG NUM_OF_EXPECTED_BUNDLES_AFTER_SECOND_AND_SUBSEQUENT_STARTS
ARG LICENSE_KEY
ARG AEM_PUBLISH_HOSTNAME
ARG DISPATCHER_HOSTNAME
ARG SECRETS_DIR

WORKDIR ${AEM_DIR}

COPY ../quickstart/${AEM_TYPE}/aem-quickstart.jar .
COPY ../commons/crypto/data ./data
COPY ../commons/passwordfile.properties .
COPY ../2_aem/aem-installer.sh .
COPY ../2_aem/aem-starter.sh .

RUN java -jar aem-quickstart.jar -unpack

RUN mkdir -v -p crx-quickstart/install

COPY ../packages/${AEM_TYPE}/* crx-quickstart/install

RUN rm crx-quickstart/install/.gitkeep

RUN ./aem-installer.sh

RUN rm aem-installer.sh

VOLUME ${AEM_DIR}/crx-quickstart
