#!/bin/bash

echo "Setting up the script variables..."
aemDir="/opt/aem/publish"
slingPropsFile="$aemDir/crx-quickstart/conf/sling.properties"
runModes="publish,nosamplecontent,local"
aemPort="4503"
debugPort="8889"
passwordFile="$aemDir/passwordfile.properties"
adminPassword=$(grep "admin.password" "$passwordFile" | head -n 1 | cut -d '=' -f 2)
# The exact number of bundles in expectedBundlesStatusAfterFirstAEMStart
# depends on the exact AEM setup. Here are example values for some of those setups:
#  577 bundles active - clean AEM 6.5.0 + nosamplecontent
#  606 bundles active - clean AEM 6.5.0 + 6.5.16 Service Pack + nosamplecontent
#  719 bundles active - clean AEM 6.5.0 + 6.5.16 Service Pack + 6.0.914 AEM Forms Addon + nosamplecontent
expectedBundlesStatusAfterFirstAEMStart="719 bundles active"
actualBundlesStatus=""

###################################
#                                 #
#            FUNCTIONS            #
#                                 #
###################################

updateSlingPropsForForms () {
  echo ""
  echo "Updating Sling properties related to AEM Forms..."
  # The following adjustments are required for AEM Forms addon work correctly.
  # Although the documentation requires it only for Windows, but for UNIX that is also the case
  # (https://experienceleague.adobe.com/docs/experience-manager-learn/forms/adaptive-forms/installing-aem-form-on-windows-tutorial-use.html?lang=en):
  echo "sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*" >> "$slingPropsFile"
  echo "sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*" >> "$slingPropsFile"
}

updateSlingPropsForSQL () {
  echo ""
  echo "Updating Sling properties related to SQL..."
  # We need it to have SQL on the class path:
  sed -i 's/org.osgi.framework.system.packages.extra=/&java.sql,/' "$slingPropsFile"
}

startAEMInBackground () {
  echo ""
  echo "AEM will be started in the background..."
  java \
      -Xmx4096M \
      -Djava.awt.headless=true \
      -XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning \
      -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address="$debugPort" \
      -Dadmin.password.file="$aemDir/passwordfile.properties" \
      -Dsling.run.modes="$runModes" \
      -jar "$aemDir/aem-quickstart-6.5.0.jar" \
      -nointeractive \
      -port "$aemPort" \
      -nofork \
      -nobrowser &
}

updateActualBundlesStatus () {
  echo ""
  echo "Updating actual bundles status..."
  actualBundlesStatus=$(curl --verbose --user admin:"$adminPassword" "localhost:$aemPort/system/console/bundles.json" | jq --raw-output ".status")
}

waitUntilBundlesStatusMatch () {
  expectedBundlesStatus=$1
  isInitializationFinalized=false
  while [ $isInitializationFinalized = false ]; do
    updateActualBundlesStatus
    date
    echo ""
    echo "Latest logs:"
    tail -n 50 "$aemDir/crx-quickstart/logs/error.log"
    echo "Actual bundles status: $actualBundlesStatus"
    echo "Expected bundles status: $expectedBundlesStatus"
    if [[ "$actualBundlesStatus" =~ .*"$expectedBundlesStatus".* ]]
      then
        isInitializationFinalized=true
        echo "Number of bundles matched"
        sleep 5
      else
        sleep 15
    fi
  done
  actualBundlesStatus=""
  isInitializationFinalized=false
}

killAEM () {
  echo "AEM process will be terminated..."
  fuser --namespace tcp --kill "$aemPort"
  sleep 5
}

setupCryptoKeys () {
  echo "Setting crypto keys..."
  bundlesDir="$aemDir/crx-quickstart/launchpad/felix"
  # Iterate over all direct subdirectories
  for bundleDir in "$bundlesDir"/*; do
    # Check if it is a directory:
    if [[ -d "$bundleDir" ]]; then
      # Check if the file bundle.info exists in this bundlesDir:
      if [[ -f "$bundleDir/bundle.info" ]]; then
        # Use grep to find the specific line in the file
        # If the line exists, grep will return 0 (success)
        if grep -q "com.adobe.granite.crypto.file" "$bundleDir/bundle.info"; then
          # If the line was found, set the path to the bundlesDir in the variable
          pathToGraniteCryptoBundle="$bundleDir"
          echo "This path to Granite Crypto bundle was determined: $pathToGraniteCryptoBundle"
          # Stop the loop
          break
        fi
      fi
    fi
  done

  targetCryptoData="$pathToGraniteCryptoBundle/data"
  sourceCryptoData="$aemDir/data"

  if [[ -d "$sourceCryptoData" ]]; then
    echo "Removing the target crypto data: $targetCryptoData"
    rm -rf "$targetCryptoData"
    echo "Updating the target crypto data"
    mv -v "$sourceCryptoData" "$targetCryptoData"
  fi
}

###################################
#                                 #
#          DRIVING CODE           #
#                                 #
###################################

updateSlingPropsForForms

startAEMInBackground
waitUntilBundlesStatusMatch "$expectedBundlesStatusAfterFirstAEMStart"
# Without this sleep installation of some packages might not be successful:
echo "Sleeping for 60 seconds to let AEM be fully initialized..."
sleep 60
killAEM

setupCryptoKeys
updateSlingPropsForSQL
