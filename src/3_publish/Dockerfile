FROM aem-base:latest

WORKDIR /opt/aem/publish

COPY ../resources/aem-quickstart-6.5.0.jar .
COPY ../resources/license.properties .
COPY ../3_publish/passwordfile.properties .
COPY ../3_publish/installer.sh .

RUN java -jar /opt/aem/publish/aem-quickstart-6.5.0.jar -unpack

RUN mkdir -p crx-quickstart/install

COPY ../packages/* crx-quickstart/install

RUN rm crx-quickstart/install/.gitkeep

RUN ./installer.sh

RUN rm installer.sh

VOLUME /opt/aem/publish/crx-quickstart
