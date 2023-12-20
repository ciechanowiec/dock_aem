#!/bin/bash

echo "Resolving the latest Solr version..."
latestSolrVersion=$(curl --insecure --silent https://api.github.com/repos/apache/solr/tags | jq --raw-output '.[0].name' | cut -d '/' -f 3)
echo "The latest Solr version: $latestSolrVersion"
solrArchive="solr-$latestSolrVersion.tgz"

echo ""
echo "Downloading the latest Solr binaries..."
curl --insecure --location --output "$solrArchive" "https://archive.apache.org/dist/solr/solr/$latestSolrVersion/$solrArchive"

echo ""
echo "Extracting the Solr binaries..."
tempDir=$(mktemp -d)
tar --extract --gzip --verbose --file "$solrArchive" --directory "$tempDir"
# Identify the extracted directory (assuming it's the only one in the temporary directory):
extractedDir=$(find "$tempDir" -mindepth 1 -maxdepth 1 -type d)
mv -v "$extractedDir"/* "$SOLR_DIR"

echo ""
solrEnvFile="$SOLR_DIR/bin/solr.in.sh"
echo "Adjusting $solrEnvFile..."
echo "- exposing Solr to the connections from the outside of the container..."
sed -i 's|#SOLR_JETTY_HOST="127.0.0.1"|SOLR_JETTY_HOST="0.0.0.0"|' "$solrEnvFile"
echo "- setting up a ZooKeeper host..."
sed -i 's|#ZK_HOST=""|ZK_HOST='"$ZK_HOST"'/solr|' "$solrEnvFile"
echo "- enforcing chroot creation..."
sed -i 's|#ZK_CREATE_CHROOT=true|ZK_CREATE_CHROOT=true|' "$solrEnvFile"

# Designed for local environments to add a wildcard Access-Control-Allow-Origin header:
if [ "$IS_UNSAFE" = "true" ]; then
  echo "Updating Jetty settings..."
  rm -v "$SOLR_DIR/server/etc/jetty.xml"
  mv -v jetty.xml "$SOLR_DIR/server/etc/jetty.xml"
fi

echo ""
echo "Cleanup..."
rm -vrf "$tempDir"
rm -v "$solrArchive"
