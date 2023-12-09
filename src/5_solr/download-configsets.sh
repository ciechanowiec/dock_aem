#!/bin/bash

exportedConfigsDir="$SOLR_DIR/exported_configs"

echo "Removing old exported configs..."
rm -rvf "$exportedConfigsDir"

echo ""
echo "Retrieving the existing config set names..."
configSets=$(curl --silent http://localhost:8983/api/cluster/configs?omitHeader=true | jq --raw-output '.configSets[]')
echo "Config set names retrieved:"
echo "$configSets"

echo ""
for configName in $configSets; do
    echo "Downloading config set: $configName"
    "$SOLR_DIR/bin/solr" zk downconfig -n "$configName" -d "$exportedConfigsDir/$configName"
done
