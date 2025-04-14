#!/bin/bash

if [ -n "$LICENSE_KEY" ]; then
echo "Setting a new license"
cat > "$AEM_DIR/license.properties" << EOF
license.product.name=Adobe Experience Manager
license.customer.name=AEM Customer
license.product.version=default
license.downloadID=$LICENSE_KEY
EOF
fi

if [ -e "$AEM_DIR/universal-editor-service/universal-editor-service.cjs" ]; then
# Docs:
# https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/implementing/developing/universal-editor/local-dev
echo "Setting up Universal Editor Service..."
cat > "$AEM_DIR/universal-editor-service/.env" << EOF
UES_PORT=$UNIVERSAL_EDITOR_SERVICE_PORT
UES_PRIVATE_KEY=./key.pem
UES_CERT=./certificate.pem
UES_TLS_REJECT_UNAUTHORIZED=false
UES_CORS_PRIVATE_NETWORK=true
EOF
CURRENT_DIR=$(pwd)
cd "$AEM_DIR/universal-editor-service" || exit 1
node "$AEM_DIR/universal-editor-service/universal-editor-service.cjs" &
cd "$CURRENT_DIR" || exit 1
fi

echo "Ensuring secrets directory: $SECRETS_DIR..."
mkdir --parents --verbose "$SECRETS_DIR"

echo "Starting AEM..."
# exec is required in order to set the Java process as PID 1 inside the container, since Docker sends
# termination signals only to PID 1, and we need those signals to be handled by the java process:
exec java \
    -Xmx4096M \
    -Djdk.util.zip.disableZip64ExtraFieldValidation=true \
    -Djava.awt.headless=true \
    -Dorg.apache.felix.configadmin.plugin.interpolation.secretsdir="$SECRETS_DIR" \
    -XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning \
    -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:"$DEBUG_PORT" \
    -Dadmin.password.file="$AEM_DIR/passwordfile.properties" \
    -Dsling.run.modes="$RUN_MODES" \
    -jar "$AEM_DIR/aem-quickstart.jar" \
    -nointeractive \
    -port "$AEM_HTTP_PORT" \
    -nofork \
    -nobrowser
