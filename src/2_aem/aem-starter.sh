#!/bin/bash

java \
    -Xmx4096M \
    -Djdk.util.zip.disableZip64ExtraFieldValidation=true \
    -Djava.awt.headless=true \
    -XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning \
    -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address="$DEBUG_PORT" \
    -Dadmin.password.file="$AEM_DIR/passwordfile.properties" \
    -Dsling.run.modes="$RUN_MODES" \
    -jar "$AEM_DIR/aem-quickstart.jar" \
    -nointeractive \
    -port "$AEM_PORT" \
    -nofork \
    -nobrowser
