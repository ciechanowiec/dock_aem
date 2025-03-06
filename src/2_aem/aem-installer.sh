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

installSearchWebConsolePlugin () {
  echo "Installing Search Web Console Plugin for Apache Felix..."
  # Plugin: https://github.com/neva-dev/felix-search-webconsole-plugin
  INSTALL_DIR="$AEM_DIR/crx-quickstart/install"
  mkdir --parents --verbose "$INSTALL_DIR"
  SEARCH_PLUGIN_DOWNLOAD_URL=$(curl --silent https://api.github.com/repos/neva-dev/felix-search-webconsole-plugin/releases/latest \
    | grep browser_download_url \
    | grep ".jar" \
    | cut -d '"' -f 4)
  curl --location "$SEARCH_PLUGIN_DOWNLOAD_URL" --output "$INSTALL_DIR/$(basename "$SEARCH_PLUGIN_DOWNLOAD_URL")"
}

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
    echo ""
    echo "Latest logs:"
    tail -n 30 "$AEM_DIR/crx-quickstart/logs/error.log"
    date
    echo "Actual bundles status: $ACTUAL_BUNDLES_STATUS"
    echo "Expected bundles status: $expectedBundlesStatus"
    if [[ "$ACTUAL_BUNDLES_STATUS" =~ .*"$expectedBundlesStatus".* ]]
      then
        isInitializationFinalized=true
        echo "Number of bundles matched"
        sleep 10
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
  fuser -TERM --namespace tcp --kill "$AEM_PORT"
  echo ""
  while fuser "$AEM_PORT"/tcp > /dev/null 2>&1; do
      echo "Latest logs:"
      tail -n 5 "$AEM_DIR/crx-quickstart/logs/error.log"
      echo "Waiting for AEM process to be terminated..."
      sleep 15
  done

  echo "Latest logs:"
  tail -n 5 "$AEM_DIR/crx-quickstart/logs/error.log"
  echo "AEM process has been terminated"
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
      -F "transportUri=http://$AEM_PUBLISH_HOSTNAME:4503/bin/receive?sling:authRequestLogin=1" \
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

  # First, check if the resource is available (HTTP 200) (for `samplecontent` run mode the resource is absent).
  getResponse=$(curl --user "admin:${ADMIN_PASSWORD}" \
                     --write-out "%{http_code}" \
                     --silent \
                     --output /dev/null \
                     "http://localhost:${AEM_PORT}/etc/replication/agents.author/publish/jcr:content/userId")

  if [ "$getResponse" -eq 200 ]; then
    # If the resource is available, perform the delete operation:
    curlOutput=$(curl --verbose --user "admin:${ADMIN_PASSWORD}" \
      -F ":operation=delete" \
      "http://localhost:${AEM_PORT}/etc/replication/agents.author/publish/jcr:content/userId")
    echo "$curlOutput"

    # Check if the delete operation succeeded based on the response content:
    if echo "$curlOutput" | grep -iq "Content modified"; then
      echo "Response is OK"
      IS_RESPONSE_OK=true
    else
      echo "Response is not OK"
      IS_RESPONSE_OK=false
    fi
  else
    # If resource is not available (not 200), skip deletion logic, mark response as OK:
    echo "Response is OK"
    IS_RESPONSE_OK=true
  fi

  # Wait a bit before continuing:
  sleep 5
}

setDispatcherReplicationAgent () {
  echo ""
  echo "Setting up a dispatcher replication agent..."
  curlOutput=$(curl --verbose --user admin:"$ADMIN_PASSWORD" \
      -F "transportUri=http://$DISPATCHER_HOSTNAME:80/dispatcher/invalidate.cache" \
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

setPublishReverseReplicationAgent () {
  echo ""
  echo "Setting up a publish reverse replication agent..."
  curlOutput=$(curl --verbose --user admin:"$ADMIN_PASSWORD" \
        -F "enabled=true" \
        -F "transportPassword=admin" \
        -F "transportUri=http://$AEM_PUBLISH_HOSTNAME:4503/bin/receive?sling:authRequestLogin=1" \
        -F "transportUser=admin" \
        -F "userId=admin" \
        "http://localhost:$AEM_PORT/etc/replication/agents.author/publish_reverse/jcr:content")
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

setAllReplicationAgentsOnAuthor () {
  echo ""
  echo "Setting up replication agents on AEM Author..."
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

  IS_RESPONSE_OK=false
  while [ $IS_RESPONSE_OK = false ]; do
    setPublishReverseReplicationAgent
  done
}

setAllReplicationAgentsOnPublish () {
  echo ""
  echo "Setting up an Outbox replication agent on AEM Publish..."
  IS_RESPONSE_OK=false
  while [ $IS_RESPONSE_OK = false ]; do
    curlOutput=$(curl --verbose --user admin:"$ADMIN_PASSWORD" \
          -F "enabled=true" \
          -F "userId=admin" \
          "http://localhost:$AEM_PORT/etc/replication/agents.publish/outbox/jcr:content")
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
  done
}

setMailService() {
  echo "Setting com.day.cq.mailer.DefaultMailService..."
  curl --user "admin:$ADMIN_PASSWORD" --verbose "localhost:$AEM_PORT/system/console/configMgr/com.day.cq.mailer.DefaultMailService" \
  --data-raw 'apply=true&action=ajaxConfigManager&%24location=launchpad%3Aresources%2Finstall%2F20%2Fcq-mailer-5.14.2.jar&smtp.host=fake-smtp-server&smtp.port=8025&smtp.user=myuser&smtp.password=mysecretpassword&from.address=aem-sender%40example.com&smtp.ssl=false&smtp.starttls=false&debug.email=true&debug.email=false&oauth.flow=false&propertylist=oath.flow%2Csmtp.host%2Csmtp.port%2Csmtp.user%2Csmtp.password%2Cfrom.address%2Csmtp.ssl%2Csmtp.starttls%2Cdebug.email%2Coauth.flow'
  # Gives configuration like:
  #  {
  #    "smtp.host": "fake-smtp-server",
  #    "smtp.port": 8025,
  #    "smtp.user": "myuser",
  #    "smtp.password": "mysecretpassword",
  #    "from.address": "aem-sender@example.com",
  #    "smtp.ssl": false,
  #    "smtp.starttls": false,
  #    "debug.email": true,
  #    "oath.flow": false
  #  }
}

warmupScripts() {
  echo ""
  echo "Warming up AEM rendering scripts..."
  curl --verbose "http://localhost:$AEM_PORT/libs/granite/core/content/login.html" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/aem/start.html" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/sites.html/content" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/assets.html/content/dam" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/aem/forms.html/content/dam/formsanddocuments" > /dev/null
  sleep 5
}

disableAuthoringHints() {
  echo ""
  echo "Disabling authoring hints..."
  ADMIN_USER_JCR_PATH=$(curl --verbose --user "admin:$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/bin/querybuilder.json?path=/home/users&type=rep:User&property=rep:authorizableId&property.value=admin&p.limit=-1" | jq -r '.hits[0].path')
  curl --verbose --user "admin:$ADMIN_PASSWORD" \
  "http://localhost:$AEM_PORT/$ADMIN_USER_JCR_PATH/preferences" \
  -F "jcr:primaryType=nt:unstructured" \
  -F "cq.authoring.editor.page.showOnboarding62=false" \
  -F "cq.authoring.editor.page.showOnboarding62@TypeHint=String" \
  -F "granite.shell.showonboarding620=false" \
  -F "granite.shell.showonboarding620@TypeHint=String"
  sleep 5
}

###################################
#                                 #
#          DRIVING CODE           #
#                                 #
###################################

installSearchWebConsolePlugin
updateSlingPropsForForms

startAEMInBackground
waitUntilBundlesStatusMatch "$EXPECTED_BUNDLES_STATUS_AFTER_FIRST_START"
enableCRX
warmupScripts
disableAuthoringHints
if [[ "$RUN_MODES" == *"publish"* ]]; then
  setAllReplicationAgentsOnPublish
fi
# Without this sleep installation of some packages might not be successful:
echo "Sleeping for 60 seconds to let AEM be fully initialized..."
sleep 60
killAEM

setupCryptoKeys
updateSlingPropsForSQL

if [[ "$RUN_MODES" == *"author"* ]]; then
  startAEMInBackground
  waitUntilBundlesStatusMatch "$EXPECTED_BUNDLES_STATUS_AFTER_SECOND_AND_SUBSEQUENT_STARTS"
  setAllReplicationAgentsOnAuthor
  sleep 3
  setMailService
  # Without this sleep installation of some packages might not be successful:
  echo "Sleeping for 30 seconds to let AEM be fully initialized..."
  sleep 30
  killAEM
fi
