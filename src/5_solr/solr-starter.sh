#!/bin/bash

echo "Starting Solr..."

"$SOLR_DIR/bin/solr" start -cloud -force

tail -f /dev/null
