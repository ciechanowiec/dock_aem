#!/bin/bash

echo "Starting ZooKeeper..."

"$ZOOKEEPER_DIR/bin/zkServer.sh" start

# Required to keep the container running:
tail -f /dev/null
