#!/bin/bash

echo "Starting ZooKeeper..."

# Configuration as per Solr documentation:
# https://solr.apache.org/guide/solr/latest/deployment-guide/zookeeper-ensemble.html
mkdir -p -v "$ZOOKEEPER_DATA_DIR"
echo "${ZOOKEEPER_MY_ID:-1}" > "$ZOOKEEPER_DATA_DIR/myid"

"$ZOOKEEPER_DIR/bin/zkServer.sh" start

# Required to keep the container running:
tail -f /dev/null
