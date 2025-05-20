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
  if [ $? -ne 0 ] || [ -z "$SEARCH_PLUGIN_DOWNLOAD_URL" ]; then
    echo "ERROR: Failed to retrieve the GitHub download URL." >&2
    exit 1
  fi
  curl --location "$SEARCH_PLUGIN_DOWNLOAD_URL" --output "$INSTALL_DIR/$(basename "$SEARCH_PLUGIN_DOWNLOAD_URL")"
}

setUniversalEditorService () {
  # Docs:
  # https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/implementing/developing/universal-editor/local-dev
  # https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/implementing/developing/universal-editor/developer-overview
  echo "Setting up the Universal Editor Service..."
  if [[ "$RUN_MODES" == *"author"* && "$AEM_TYPE" == "cloud" ]]; then
    openssl req \
      -newkey rsa:2048 -nodes \
      -keyout "$AEM_DIR/universal-editor-service/key.pem" \
      -x509 -days 1825 \
      -out "$AEM_DIR/universal-editor-service/certificate.pem" \
      -subj "/C=/ST=/L=/O=/OU=/CN="
  else
    echo "The Universal Editor Service is not supported for this AEM type or run mode and will be removed..."
    rm -rfv "$AEM_DIR/universal-editor-service"
  fi
}

installWKND() {
  echo "Installing WKND sample project..."
  INSTALL_DIR="$AEM_DIR/crx-quickstart/install"
  mkdir --parents --verbose "$INSTALL_DIR"
  if [ "$AEM_TYPE" = "cloud" ]; then
    AEM_GUIDES_DOWNLOAD_URL=$(curl --silent https://api.github.com/repos/adobe/aem-guides-wknd/releases/latest \
      | grep browser_download_url \
      | grep "all-.*\.zip" \
      | grep -v "classic" \
      | cut -d '"' -f 4)
    if [ $? -ne 0 ] || [ -z "$AEM_GUIDES_DOWNLOAD_URL" ]; then
      echo "ERROR: Failed to retrieve the GitHub download URL." >&2
      exit 1
    fi
    echo "Will download the WKND sample project from: $AEM_GUIDES_DOWNLOAD_URL"
    curl --location "$AEM_GUIDES_DOWNLOAD_URL" --output "$INSTALL_DIR/$(basename "$AEM_GUIDES_DOWNLOAD_URL")"
  elif [ "$AEM_TYPE" = "65" ]; then
    AEM_GUIDES_DOWNLOAD_URL=$(curl --silent https://api.github.com/repos/adobe/aem-guides-wknd/releases/latest \
      | grep browser_download_url \
      | grep "all-.*-classic\.zip" \
      | cut -d '"' -f 4)
    if [ $? -ne 0 ] || [ -z "$AEM_GUIDES_DOWNLOAD_URL" ]; then
      echo "ERROR: Failed to retrieve the GitHub download URL." >&2
      exit 1
    fi
    echo "Will download the WKND sample project from: $AEM_GUIDES_DOWNLOAD_URL"
    curl --location "$AEM_GUIDES_DOWNLOAD_URL" --output "$INSTALL_DIR/$(basename "$AEM_GUIDES_DOWNLOAD_URL")"
  else
    echo "No AEM type specified, aborting WKND installation..."
  fi
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
  ACTUAL_BUNDLES_STATUS=$(curl --verbose --user admin:"$ADMIN_PASSWORD" "localhost:$AEM_HTTP_PORT/system/console/bundles.json" | jq --raw-output ".status")
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

enableHTTPS () {
  # Docs: https://experienceleague.adobe.com/en/docs/experience-manager-learn/foundation/security/use-the-ssl-wizard#self-signed-private-key-and-certificate
  echo ""
  echo "Enabling HTTPS..."
  CURRENT_DIR=$(pwd)
  mkdir --parents --verbose "$AEM_DIR/certificates"
  cd "$AEM_DIR/certificates" || exit

  echo "Generating certificates..."
  # 1) Create a Private Key that is encrypted with passphrase "admin"
  openssl genrsa -aes256 \
    -passout pass:admin \
    -out localhostprivate.key 4096

  # 2) Generate Certificate Signing Request (CSR) using the encrypted private key
  openssl req -sha256 \
    -passin pass:admin \
    -new \
    -key localhostprivate.key \
    -out localhost.csr \
    -subj '/CN=localhost'

  # 3) Generate the SSL certificate, sign it with the same private key, and set it to expire after one year
  openssl x509 -req \
    -passin pass:admin \
    -extfile <(printf "subjectAltName=DNS:localhost") \
    -days 1825 \
    -in localhost.csr \
    -signkey localhostprivate.key \
    -out localhost.crt

  # 4) Convert the Private Key to DER format (non-interactive, reading passphrase "admin" and outputting an unencrypted DER file)
  openssl pkcs8 \
    -passin pass:admin \
    -topk8 \
    -inform PEM \
    -outform DER \
    -in localhostprivate.key \
    -out localhostprivate.der \
    -nocrypt

  echo "Enabling SSL in AEM..."
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/libs/granite/security/post/sslSetup.html" \
    -X POST \
    -F "keystorePassword=admin" \
    -F "keystorePasswordConfirm=admin" \
    -F "truststorePassword=admin" \
    -F "truststorePasswordConfirm=admin" \
    -F "privatekeyFile=@$AEM_DIR/certificates/localhostprivate.der;type=application/x-x509-ca-cert" \
    -F "certificateFile=@$AEM_DIR/certificates/localhost.crt;type=application/x-x509-ca-cert" \
    -F "httpsHostname=localhost" \
    -F "httpsPort=$AEM_HTTPS_PORT"
  cd "$CURRENT_DIR" || exit
  rm -rfv "$AEM_DIR/certificates"
  sleep 10
  echo "Latest logs:"
  tail -n 10 "$AEM_DIR/crx-quickstart/logs/error.log"
}

enableCRX () {
  echo ""
  echo "Enabling CRX DE..."
  curl --verbose --user admin:"$ADMIN_PASSWORD" -F "jcr:primaryType=sling:OsgiConfig" -F "alias=/crx/server" -F "dav.create-absolute-uri=true" -F "dav.create-absolute-uri@TypeHint=Boolean" "http://localhost:$AEM_HTTP_PORT/apps/system/config/org.apache.sling.jcr.davex.impl.servlets.SlingDavExServlet"
}

killAEM () {
  echo "AEM process will be terminated..."
  fuser -TERM --namespace tcp --kill "$AEM_HTTP_PORT"
  echo ""
  while fuser "$AEM_HTTP_PORT"/tcp > /dev/null 2>&1; do
      echo "Latest logs:"
      tail -n 5 "$AEM_DIR/crx-quickstart/logs/error.log"
      echo "Waiting for AEM process to be terminated..."
      sleep 15
  done

  echo "Latest logs:"
  tail -n 5 "$AEM_DIR/crx-quickstart/logs/error.log"
  echo "AEM process has been terminated"
  sleep 5

  echo "Universal Editor Service process will be terminated..."
  fuser -TERM --namespace tcp --kill "$UNIVERSAL_EDITOR_SERVICE_PORT"
  echo ""
  while fuser "$UNIVERSAL_EDITOR_SERVICE_PORT"/tcp > /dev/null 2>&1; do
      echo "Waiting for Universal Editor Service process to be terminated..."
      sleep 3
  done
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
      -F "transportUri=http://$AEM_PUBLISH_HOSTNAME:$AEM_PUBLISH_HTTP_PORT/bin/receive?sling:authRequestLogin=1" \
      -F "transportUser=admin" \
      "http://localhost:$AEM_HTTP_PORT/etc/replication/agents.author/publish/jcr:content")
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
                     "http://localhost:${AEM_HTTP_PORT}/etc/replication/agents.author/publish/jcr:content/userId")

  if [ "$getResponse" -eq 200 ]; then
    # If the resource is available, perform the delete operation:
    curlOutput=$(curl --verbose --user "admin:${ADMIN_PASSWORD}" \
      -F ":operation=delete" \
      "http://localhost:${AEM_HTTP_PORT}/etc/replication/agents.author/publish/jcr:content/userId")
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
      "http://localhost:$AEM_HTTP_PORT/etc/replication/agents.author/flush/jcr:content")
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
        -F "transportUri=http://$AEM_PUBLISH_HOSTNAME:$AEM_PUBLISH_HTTP_PORT/bin/receive?sling:authRequestLogin=1" \
        -F "transportUser=admin" \
        -F "userId=admin" \
        "http://localhost:$AEM_HTTP_PORT/etc/replication/agents.author/publish_reverse/jcr:content")
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
          "http://localhost:$AEM_HTTP_PORT/etc/replication/agents.publish/outbox/jcr:content")
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
  curl --user "admin:$ADMIN_PASSWORD" --verbose "localhost:$AEM_HTTP_PORT/system/console/configMgr/com.day.cq.mailer.DefaultMailService" \
  --data-raw 'apply=true&action=ajaxConfigManager&%24location=&smtp.host=fake-smtp-server&smtp.password=mysecretpassword&debug.email=true&smtp.port=8025&smtp.user=myuser&from.address=aem-sender@example.com&smtp.ssl=false&smtp.starttls=false&oath.flow=false&propertylist=smtp.host%2Csmtp.password%2Cdebug.email%2Csmtp.port%2Csmtp.user%2Cfrom.address%2Csmtp.ssl%2Csmtp.starttls%2Coath.flow'
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
  curl --verbose "http://localhost:$AEM_HTTP_PORT/libs/granite/core/content/login.html" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/aem/start.html" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/sites.html/content" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/assets.html/content/dam" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/mnt/override/libs/wcm/core/content/common/managepublicationwizard.html" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/aem/forms.html/content/dam/formsanddocuments" > /dev/null
  curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/editor.html/conf/global/settings/workflow/models/request_for_activation.html" > /dev/null
  if [ "$INSTALL_WKND_SAMPLE" = "true" ]; then
    curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/content/wknd/language-masters/en.html" > /dev/null
    curl --verbose --user admin:"$ADMIN_PASSWORD" "http://localhost:$AEM_PORT/editor.html/content/wknd/language-masters/en.html" > /dev/null
  fi
  sleep 5
}

disableAuthoringHints() {
  echo ""
  echo "Disabling authoring hints..."
  ADMIN_USER_JCR_PATH=$(curl --verbose --user "admin:$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/bin/querybuilder.json?path=/home/users&type=rep:User&property=rep:authorizableId&property.value=admin&p.limit=-1" | jq -r '.hits[0].path')
  curl --verbose --user "admin:$ADMIN_PASSWORD" \
  "http://localhost:$AEM_HTTP_PORT/$ADMIN_USER_JCR_PATH/preferences" \
  -F "jcr:primaryType=nt:unstructured" \
  -F "cq.authoring.editor.page.showOnboarding62=false" \
  -F "cq.authoring.editor.page.showOnboarding62@TypeHint=String" \
  -F "granite.shell.showonboarding620=false" \
  -F "granite.shell.showonboarding620@TypeHint=String"
  sleep 5
}

installXWalkEDSTemplate() {
  echo "Installing XWalk EDS template..."
  XWALK_EDS_TEMPLATE_DOWNLOAD_URL=$(curl --silent https://api.github.com/repos/adobe-rnd/aem-boilerplate-xwalk/releases/latest \
    | grep browser_download_url \
    | grep ".*\.zip" \
    | cut -d '"' -f 4)
  if [ $? -ne 0 ] || [ -z "$XWALK_EDS_TEMPLATE_DOWNLOAD_URL" ]; then
    echo "ERROR: Failed to retrieve the GitHub download URL." >&2
    exit 1
  fi
  echo "Will download the XWalk EDS template from: $XWALK_EDS_TEMPLATE_DOWNLOAD_URL"
  XWALK_EDS_TEMPLATE="$(mktemp -d)/$(basename "$XWALK_EDS_TEMPLATE_DOWNLOAD_URL")"
  curl --location "$XWALK_EDS_TEMPLATE_DOWNLOAD_URL" --output "$XWALK_EDS_TEMPLATE"
  curl --verbose --user "admin:$ADMIN_PASSWORD" "http://localhost:$AEM_HTTP_PORT/bin/wcm/site-template/import" \
    -X POST \
    -F "file=@$XWALK_EDS_TEMPLATE;type=application/zip"
}

enableAccessForRemoteUniversalEditor() {
  # Docs: https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/implementing/developing/universal-editor/developer-overview
  echo "Enabling access for remote Universal Editor..."
  curl --user "admin:$ADMIN_PASSWORD" --verbose "localhost:$AEM_HTTP_PORT/system/console/configMgr/org.apache.sling.engine.impl.SlingMainServlet" \
   --data-raw 'apply=true&action=ajaxConfigManager&%24location=&sling.serverinfo=Apache Sling&sling.max.calls=1500&sling.additional.response.headers=X-Content-Type-Options=nosniff&sling.includes.checkcontenttype=false&propertylist=sling.serverinfo%2Csling.max.calls%2Csling.additional.response.headers%2Csling.includes.checkcontenttype'
  # Gives configuration like:
  # {
  #   "sling.serverinfo":"Apache Sling",
  #   "sling.max.calls:Integer":1500,
  #   "sling.additional.response.headers":[
  #     "X-Content-Type-Options=nosniff"
  #   ],
  #   "sling.includes.checkcontenttype":false
  # }
  curl --user "admin:$ADMIN_PASSWORD" --verbose "localhost:$AEM_HTTP_PORT/system/console/configMgr/com.day.crx.security.token.impl.impl.TokenAuthenticationHandler" \
   --data-raw 'apply=true&action=ajaxConfigManager&%24location=&token.samesite.cookie.attr=None&token.required.attr=none&propertylist=token.samesite.cookie.attr%2Ctoken.required.attr'
  # Gives configuration like:
  # {
  #   "token.samesite.cookie.attr":"None",
  #   "token.required.attr":"none"
  # }
}

###################################
#                                 #
#          DRIVING CODE           #
#                                 #
###################################

if [ -z "$LICENSE_KEY" ]; then
  echo "ERROR: License key isn't set." >&2
  exit 1
fi

installSearchWebConsolePlugin
setUniversalEditorService
if [ "$INSTALL_WKND_SAMPLE" = "true" ]; then
  installWKND
fi
updateSlingPropsForForms

startAEMInBackground
waitUntilBundlesStatusMatch "$EXPECTED_BUNDLES_STATUS_AFTER_FIRST_START"
enableCRX
warmupScripts
disableAuthoringHints
if [ "$INSTALL_XWALK_EDS_TEMPLATE" = "true" ]; then
  installXWalkEDSTemplate
fi
if [ "$ENABLE_ACCESS_FOR_REMOTE_UNIVERSAL_EDITOR" = "true" ]; then
  enableAccessForRemoteUniversalEditor
fi
if [[ "$RUN_MODES" == *"publish"* ]]; then
  setAllReplicationAgentsOnPublish
fi
# Without this sleep installation of some packages might not be successful:
echo "Sleeping for 60 seconds to let AEM be fully initialized..."
sleep 60
killAEM

setupCryptoKeys
updateSlingPropsForSQL

startAEMInBackground
waitUntilBundlesStatusMatch "$EXPECTED_BUNDLES_STATUS_AFTER_SECOND_AND_SUBSEQUENT_STARTS"
if [[ "$RUN_MODES" == *"author"* ]]; then
  setAllReplicationAgentsOnAuthor
  sleep 3
  setMailService
fi
# Without this sleep installation of some packages might not be successful:
echo "Sleeping for 20 seconds to let AEM be fully initialized..."
sleep 20
enableHTTPS # Must be executed after `setupCryptoKeys`
echo "Sleeping for 20 seconds to let AEM be fully initialized..."
sleep 20 # After enabling HTTPS, AEM HTTP service might got stuck
killAEM
