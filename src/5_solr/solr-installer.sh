#!/bin/bash

echo "Resolving the latest Solr version..."
latestSolrVersion=$(curl --insecure --silent https://api.github.com/repos/apache/solr/tags | jq --raw-output '.[0].name' | cut -d '/' -f 3)
echo "The latest Solr version: $latestSolrVersion"
solrArchive="solr-$latestSolrVersion.tgz"

echo ""
echo "Downloading the latest Solr binaries..."
curl --insecure --location --output "$solrArchive" "https://www.apache.org/dyn/closer.lua/solr/solr/$latestSolrVersion/$solrArchive?action=download"

echo ""
echo "Extracting the Solr binaries..."
tempDir=$(mktemp -d)
tar --extract --gzip --verbose --file "$solrArchive" --directory "$tempDir"
# Identify the extracted directory (assuming it's the only one in the temporary directory):
extractedDir=$(find "$tempDir" -mindepth 1 -maxdepth 1 -type d)
mv -v "$extractedDir"/* "$SOLR_DIR"

echo ""
echo "Exposing Solr to the connections from the outside of the container..."
sed -i 's/#SOLR_JETTY_HOST="127.0.0.1"/SOLR_JETTY_HOST="0.0.0.0"/' "$SOLR_DIR/bin/solr.in.sh"

echo ""
echo "Cleanup..."
rm -vrf "$tempDir"
rm -v "$solrArchive"
