#!/bin/bash

echo "Starting Solr..."

"$SOLR_DIR/bin/solr" start -cloud -force

# Required to keep the container running:
tail -f /dev/null
