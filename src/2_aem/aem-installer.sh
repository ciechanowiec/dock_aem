#!/bin/bash

echo "Setting up the script variables..."
SLING_PROPS_FILE="$AEM_DIR/crx-quickstart/conf/sling.properties"
PASSWORD_FILE="$AEM_DIR/passwordfile.properties"
ADMIN_PASSWORD=$(grep "admin.password" "$PASSWORD_FILE" | head -n 1 | cut -d '=' -f 2)
EXPECTED_BUNDLES_STATUS_AFTER_FIRST_START="$NUM_OF_EXPECTED_BUNDLES_AFTER_FIRST_START bundles active"
EXPECTED_BUNDLES_STATUS_AFTER_SECOND_AND_SUBSEQUENT_STARTS="$NUM_OF_EXPECTED_BUNDLES_AFTER_SECOND_AND_SUBSEQUENT_STARTS bundles active"
ACTUAL_BUNDLES_STATUS=""
IS_RESPONSE_OK=false

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
  echo "sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*" >> "$SLING_PROPS_FILE"
  echo "sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*" >> "$SLING_PROPS_FILE"
}

updateSlingPropsForSQL () {
  echo ""
  echo "Updating Sling properties related to SQL..."
  # We need it to have SQL on the class path:
  sed -i 's/org.osgi.framework.system.packages.extra=/&java.sql,/' "$SLING_PROPS_FILE"
}

startAEMInBackground () {
  echo ""
  echo "AEM will be started in the background..."
  ./aem-starter.sh &
}

updateActualBundlesStatus () {
  echo ""
  echo "Updating actual bundles status..."
  ACTUAL_BUNDLES_STATUS=$(curl --verbose --user admin:"$ADMIN_PASSWORD" "localhost:$AEM_PORT/system/console/bundles.json" | jq --raw-output ".status")
}

waitUntilBundlesStatusMatch () {
  expectedBundlesStatus=$1
  isInitializationFinalized=false
  while [ $isInitializationFinalized = false ]; do
    updateActualBundlesStatus
    date
    echo ""
    echo "Latest logs:"
    tail -n 30 "$AEM_DIR/crx-quickstart/logs/error.log"
    echo "Actual bundles status: $ACTUAL_BUNDLES_STATUS"
    echo "Expected bundles status: $expectedBundlesStatus"
    if [[ "$ACTUAL_BUNDLES_STATUS" =~ .*"$expectedBundlesStatus".* ]]
      then
        isInitializationFinalized=true
        echo "Number of bundles matched"
        sleep 5
      else
        sleep 15
    fi
  done
  ACTUAL_BUNDLES_STATUS=""
  isInitializationFinalized=false
}

enableCRX () {
  echo ""
  echo "Enabling CRX DE..."
  curl --verbose --user admin:"$ADMIN_PASSWORD" -F "jcr:primaryType=sling:OsgiConfig" -F "alias=/crx/server" -F "dav.create-absolute-uri=true" -F "dav.create-absolute-uri@TypeHint=Boolean" "http://localhost:$AEM_PORT/apps/system/config/org.apache.sling.jcr.davex.impl.servlets.SlingDavExServlet"
}

killAEM () {
  echo "AEM process will be terminated..."
  fuser --namespace tcp --kill "$AEM_PORT"
  sleep 5
}

setupCryptoKeys () {
  echo "Setting crypto keys..."
  bundlesDir="$AEM_DIR/crx-quickstart/launchpad/felix"
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
  sourceCryptoData="$AEM_DIR/data"

  if [[ -d "$sourceCryptoData" ]]; then
    echo "Removing the target crypto data: $targetCryptoData"
    rm -rf "$targetCryptoData"
    echo "Updating the target crypto data"
    mv -v "$sourceCryptoData" "$targetCryptoData"
  fi
}

setPublishReplicationAgentPartOne () {
  echo ""
  echo "Setting up a publish replication agent, part 1 of 2..."
  curlOutput=$(curl --verbose --user admin:"$ADMIN_PASSWORD" \
      -F "enabled=true" \
      -F "transportPassword=admin" \
      -F "transportUri=http://localhost:4503/bin/receive?sling:authRequestLogin=1" \
      -F "transportUser=admin" \
      "http://localhost:$AEM_PORT/etc/replication/agents.author/publish/jcr:content")
  echo "$curlOutput"
  if echo "$curlOutput" | grep -iq "Content modified"
   then
     echo "Response is OK"
     IS_RESPONSE_OK=true
  else
     echo "Response is not OK"
     IS_RESPONSE_OK=false
  fi
  sleep 5
}

setPublishReplicationAgentPartTwo () {
  echo ""
  echo "Setting up a publish replication agent, part 2 of 2..."
  curlOutput=$(curl --verbose --user admin:"$ADMIN_PASSWORD" \
      -F ":operation=delete" \
      "http://localhost:$AEM_PORT/etc/replication/agents.author/publish/jcr:content/userId")
  echo "$curlOutput"
  if echo "$curlOutput" | grep -iq "Content modified"
   then
     echo "Response is OK"
     IS_RESPONSE_OK=true
  else
     echo "Response is not OK"
     IS_RESPONSE_OK=false
  fi
  sleep 5
}

setDispatcherReplicationAgent () {
  echo ""
  echo "Setting up a dispatcher replication agent..."
  curlOutput=$(curl --verbose --user admin:"$ADMIN_PASSWORD" \
      -F "transportUri=http://localhost:80/dispatcher/invalidate.cache" \
      -F "enabled=true" \
      "http://localhost:$AEM_PORT/etc/replication/agents.author/flush/jcr:content")
  echo "$curlOutput"
  if echo "$curlOutput" | grep -iq "Content modified"
   then
     echo "Response is OK"
     IS_RESPONSE_OK=true
  else
     echo "Response is not OK"
     IS_RESPONSE_OK=false
  fi
  sleep 5
}

setAllReplicationAgents () {
  echo ""
  echo "Setting up all replication agents..."
  IS_RESPONSE_OK=false
  while [ $IS_RESPONSE_OK = false ]; do
    setPublishReplicationAgentPartOne
  done

  IS_RESPONSE_OK=false
  while [ $IS_RESPONSE_OK = false ]; do
    setPublishReplicationAgentPartTwo
  done

  IS_RESPONSE_OK=false
  while [ $IS_RESPONSE_OK = false ]; do
    setDispatcherReplicationAgent
  done
}

###################################
#                                 #
#          DRIVING CODE           #
#                                 #
###################################

updateSlingPropsForForms

startAEMInBackground
waitUntilBundlesStatusMatch "$EXPECTED_BUNDLES_STATUS_AFTER_FIRST_START"
enableCRX
# Without this sleep installation of some packages might not be successful:
echo "Sleeping for 60 seconds to let AEM be fully initialized..."
sleep 60
killAEM

setupCryptoKeys
updateSlingPropsForSQL

if [[ "$RUN_MODES" == *"author"* ]]; then
  startAEMInBackground
  waitUntilBundlesStatusMatch "$EXPECTED_BUNDLES_STATUS_AFTER_SECOND_AND_SUBSEQUENT_STARTS"
  setAllReplicationAgents
  # Without this sleep installation of some packages might not be successful:
  echo "Sleeping for 30 seconds to let AEM be fully initialized..."
  sleep 30
  killAEM
fi
