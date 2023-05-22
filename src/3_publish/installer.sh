#!/bin/bash

# The following adjustments are required for AEM Forms addon work correctly.
# Although the documentation requires it only for Windows, but for UNIX that is also the case
# (https://experienceleague.adobe.com/docs/experience-manager-learn/forms/adaptive-forms/installing-aem-form-on-windows-tutorial-use.html?lang=en):
echo "sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*" >> /opt/aem/publish/crx-quickstart/conf/sling.properties
echo "sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*" >> /opt/aem/publish/crx-quickstart/conf/sling.properties

echo "AEM will be started in the background..."
java \
    -Xmx4096M \
    -Djava.awt.headless=true \
    -XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning \
    -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8889 \
    -Dadmin.password.file=/opt/aem/publish/passwordfile.properties \
    -Dsling.run.modes=publish,samplecontent,local \
    -jar /opt/aem/publish/aem-quickstart-6.5.0.jar \
    -nointeractive \
    -port 4503 \
    -nofork \
    -nobrowser &

updateActualStatus () {
  echo "Checking AEM initialization status..."
  actualStatus=$(curl --verbose --user admin:admin localhost:4503/system/console/bundles.json | jq --raw-output ".status")
}

# The exact number of bundles in expectedStatus depends on the exact
# AEM setup. Here are example values for some of those setups:
#  581 bundles active - clean AEM 6.5.0
#  610 bundles active - clean AEM 6.5.0 + 6.5.14 Service Pack
#  722 bundles active - clean AEM 6.5.0 + 6.5.14 Service Pack + 6.0.772 AEM Forms Addon
#  723 bundles active - clean AEM 6.5.0 + 6.5.16 Service Pack + 6.0.914 AEM Forms Addon
expectedStatus="723 bundles active"
actualStatus=""
isInitializationFinalized=false

while [ $isInitializationFinalized = false ]; do
  updateActualStatus
  date
  echo "Actual bundles status: $actualStatus"
  echo "Expected bundles status: $expectedStatus"
  if [[ "$actualStatus" =~ .*"$expectedStatus".* ]]
    then
      isInitializationFinalized=true
      echo "AEM initialized"
      sleep 5
    else
      sleep 15
  fi
done

echo "AEM process will be terminated..."
fuser --namespace tcp --kill 4503
sleep 5
