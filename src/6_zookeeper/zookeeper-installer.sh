#!/bin/bash

echo "Resolving the latest ZooKeeper version..."
latestZooKeeperVersion=$(curl --insecure --silent https://api.github.com/repos/apache/zookeeper/tags | jq --raw-output '.[1].name' | cut -d '-' -f 2)
echo "The latest ZooKeeper version: $latestZooKeeperVersion"
zooKeeperArchive="zk-$latestZooKeeperVersion.tar.gz"

echo ""
echo "Downloading the latest ZooKeeper binaries..."
curl --insecure --location --output "$zooKeeperArchive" "https://archive.apache.org/dist/zookeeper/zookeeper-$latestZooKeeperVersion/apache-zookeeper-$latestZooKeeperVersion-bin.tar.gz"

echo ""
echo "Extracting the ZooKeeper binaries..."
tempDir=$(mktemp -d)
tar --extract --gzip --verbose --file "$zooKeeperArchive" --directory "$tempDir"
# Identify the extracted directory (assuming it's the only one in the temporary directory):
extractedDir=$(find "$tempDir" -mindepth 1 -maxdepth 1 -type d)
mv -v "$extractedDir"/* "$ZOOKEEPER_DIR"

echo ""
echo "Cleanup..."
rm -vrf "$tempDir"
rm -v "$zooKeeperArchive"

# Configuration as per Solr documentation:
# https://solr.apache.org/guide/solr/latest/deployment-guide/zookeeper-ensemble.html
echo ""
echo "Adjusting zoo.cfg"
dataDir="/var/lib/zookeeper"
myIDDir="$dataDir/$ZOOKEEPER_MY_ID"
mkdir -p -v "$myIDDir"
echo "$ZOOKEEPER_MY_ID" > "$myIDDir/myid"
cat > "$ZOOKEEPER_DIR/conf/zoo.cfg" << EOF
tickTime=2000
dataDir=$dataDir
clientPort=2181
4lw.commands.whitelist=*

initLimit=5
syncLimit=2
server.1=zoo1:2888:3888

autopurge.snapRetainCount=3
autopurge.purgeInterval=1

# Increase the size limit for files held in ZooKeeper to one byte less than 10MB:
jute.maxbuffer=0x9fffff
EOF

rm "$ZOOKEEPER_DIR/conf/zoo_sample.cfg"

# Configuration as per Solr documentation, but without SERVER_JVMFLAGS, as
# the values given in the documentation are obsolete for modern Java:
# https://solr.apache.org/guide/solr/latest/deployment-guide/zookeeper-ensemble.html
echo ""
echo "Adjusting zookeeper-env.sh"
cat > "$ZOOKEEPER_DIR/conf/zookeeper-env.sh" << EOF
ZOO_LOG_DIR="/var/log/zookeeper"
ZOO_LOG4J_PROP="INFO,ROLLINGFILE"
EOF
