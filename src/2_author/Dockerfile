FROM aem-base:latest

WORKDIR /opt/aem/author

COPY ../quickstart/aem-quickstart-6.5.0.jar .
COPY ../quickstart/license.properties .
COPY ../crypto/data ./data
COPY ../2_author/passwordfile.properties .
COPY ../2_author/installer.sh .

RUN java -jar /opt/aem/author/aem-quickstart-6.5.0.jar -unpack

RUN mkdir -p crx-quickstart/install

COPY ../packages/* crx-quickstart/install

RUN rm crx-quickstart/install/.gitkeep

RUN ./installer.sh

RUN rm installer.sh

VOLUME /opt/aem/author/crx-quickstart
