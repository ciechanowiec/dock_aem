ARG AEM_BASE_IMAGE_VERSION

FROM ciechanowiec/aem-base:${AEM_BASE_IMAGE_VERSION}

ARG AEM_DIR
ARG AEM_TYPE
ARG RUN_MODES
ARG INSTALL_WKND_SAMPLE
ARG INSTALL_XWALK_EDS_TEMPLATE
ARG ENABLE_ACCESS_FOR_REMOTE_UNIVERSAL_EDITOR
ARG AEM_HTTP_PORT
ARG AEM_HTTPS_PORT
ARG UNIVERSAL_EDITOR_SERVICE_PORT
ARG DEBUG_PORT
ARG NUM_OF_EXPECTED_BUNDLES_AFTER_FIRST_START
ARG NUM_OF_EXPECTED_BUNDLES_AFTER_SECOND_AND_SUBSEQUENT_STARTS
ARG LICENSE_KEY
ARG AEM_PUBLISH_HOSTNAME
ARG AEM_PUBLISH_HTTP_PORT
ARG DISPATCHER_HOSTNAME
ARG SECRETS_DIR
ARG PATH_INSIDE_CONTAINER_TO_EDS_GIT_REPOSITORY

WORKDIR ${AEM_DIR}

COPY ../quickstart/${AEM_TYPE}/aem-quickstart.jar .
COPY ../commons/crypto/data ./data
COPY ../commons/passwordfile.properties .
COPY ../2_aem/aem-installer.sh .
COPY ../2_aem/aem-starter.sh .

COPY ../universal-editor-service ./universal-editor-service
RUN rm universal-editor-service/.gitkeep

RUN java -jar aem-quickstart.jar -unpack

RUN mkdir -v -p crx-quickstart/install

COPY ../packages/${AEM_TYPE}/* crx-quickstart/install

RUN rm crx-quickstart/install/.gitkeep

RUN ./aem-installer.sh

RUN rm aem-installer.sh

VOLUME ${AEM_DIR}/crx-quickstart
