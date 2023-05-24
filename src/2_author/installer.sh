#!/bin/bash

echo "Reading the admin password..."
passwordFile="passwordfile.properties"
adminPassword=$(grep "admin.password" "$passwordFile" | head -n 1 | cut -d '=' -f 2)

# The following adjustments are required for AEM Forms addon work correctly.
# Although the documentation requires it only for Windows, but for UNIX that is also the case
# (https://experienceleague.adobe.com/docs/experience-manager-learn/forms/adaptive-forms/installing-aem-form-on-windows-tutorial-use.html?lang=en):
echo "sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*" >> /opt/aem/author/crx-quickstart/conf/sling.properties
echo "sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*" >> /opt/aem/author/crx-quickstart/conf/sling.properties

echo "AEM will be started in the background..."
java \
    -Xmx4096M \
    -Djava.awt.headless=true \
    -XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning \
    -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8888 \
    -Dadmin.password.file=/opt/aem/author/passwordfile.properties \
    -Dsling.run.modes=author,nosamplecontent,local \
    -jar /opt/aem/author/aem-quickstart-6.5.0.jar \
    -nointeractive \
    -port 4502 \
    -nofork \
    -nobrowser &

updateActualStatus () {
  echo "Checking AEM initialization status..."
  actualStatus=$(curl --verbose --user admin:"$adminPassword" localhost:4502/system/console/bundles.json | jq --raw-output ".status")
}

# The exact number of bundles in expectedStatus depends on the exact
# AEM setup. Here are example values for some of those setups:
#  577 bundles active - clean AEM 6.5.0 + nosamplecontent
#  606 bundles active - clean AEM 6.5.0 + 6.5.16 Service Pack + nosamplecontent
#  719 bundles active - clean AEM 6.5.0 + 6.5.16 Service Pack + 6.0.914 AEM Forms Addon + nosamplecontent
expectedStatus="719 bundles active"
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

setPublishReplicationAgentPartOne () {
  echo "Setting up a publish replication agent, part 1 of 2..."
  curlOutput=$(curl --verbose --user admin:"$adminPassword" \
      -F "enabled=true" \
      -F "transportPassword=admin" \
      -F "transportUri=http://localhost:4503/bin/receive?sling:authRequestLogin=1" \
      -F "transportUser=admin" \
      http://localhost:4502/etc/replication/agents.author/publish/jcr:content)
  echo "$curlOutput"
  if echo "$curlOutput" | grep -iq "Content modified"
   then
     echo "Response is OK"
     isResponseOK=true
  else
     echo "Response is not OK"
     isResponseOK=false
  fi
  sleep 5
}

setPublishReplicationAgentPartTwo () {
  echo "Setting up a publish replication agent, part 2 of 2..."
  curlOutput=$(curl --verbose --user admin:"$adminPassword" \
      -F ":operation=delete" \
      http://localhost:4502/etc/replication/agents.author/publish/jcr:content/userId)
  echo "$curlOutput"
  if echo "$curlOutput" | grep -iq "Content modified"
   then
     echo "Response is OK"
     isResponseOK=true
  else
     echo "Response is not OK"
     isResponseOK=false
  fi
  sleep 5
}

setDispatcherReplicationAgent () {
  echo "Setting up a dispatcher replication agent..."
  curlOutput=$(curl --verbose --user admin:"$adminPassword" \
      -F "transportUri=http://localhost:80/dispatcher/invalidate.cache" \
      -F "enabled=true" \
      http://localhost:4502/etc/replication/agents.author/flush/jcr:content)
  echo "$curlOutput"
  if echo "$curlOutput" | grep -iq "Content modified"
   then
     echo "Response is OK"
     isResponseOK=true
  else
     echo "Response is not OK"
     isResponseOK=false
  fi
  sleep 5
}

isResponseOK=false
while [ $isResponseOK = false ]; do
  setPublishReplicationAgentPartOne
done

isResponseOK=false
while [ $isResponseOK = false ]; do
  setPublishReplicationAgentPartTwo
done

isResponseOK=false
while [ $isResponseOK = false ]; do
  setDispatcherReplicationAgent
done

# Without this sleep installation of some packages might not be successful:
echo "Sleeping for 30 seconds to let AEM be fully initialized..."
sleep 30

echo "AEM process will be terminated..."
fuser --namespace tcp --kill 4502
sleep 5
