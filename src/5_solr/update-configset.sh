bin/bash

##############################
#      COMMON FUNCTIONS      #
##############################

help() {
    echo "DESCRIPTION:"
    echo "   Script to upload a SolrCloud config set."
    echo ""
    echo "SYNOPSIS:"
    echo "   sh $(basename "$0") -d DIRECTORY [-u URL]"
    echo ""
    echo "MANDATORY ARGUMENTS:"
    echo "   -d DIRECTORY  Specify the relative or absolute path to the directory containing the config set."
    echo "                 The name of the directory is used as the config set name."
    echo "                 For an example of such directory see \$SOLR_HOME/server/solr/configsets/_default."
    echo
    echo "OPTIONAL ARGUMENTS:"
    echo "   -u URL        Specify the URL of the SolrCloud instance. Default: $defaultSolrURL"
    echo "   -h            Display this help and exit."
    echo
    echo "EXAMPLES:"
    echo "   sh $(basename "$0") -d /var/solr/path/to/configus_setus"
    echo "   sh $(basename "$0") -d path/to/configus_setus"
    echo "   sh $(basename "$0") -d configus_setus"
    echo "   sh $(basename "$0") -d configus_setus -u http://10.48.192.74:$SOLR_PORT"
    exit 0
}

validateInput() {
  echo "Validating the input..."
  if [ -z "$configSetPath" ]; then
    echo "[ERROR] No path to the directory containing the config set was specified."
    echo "[HELP]  Use -h for help."
    exit 1
  fi
  if [ ! -d "$configSetPath" ]
   then
    echo "[ERROR] Not a valid directory: '$configSetPath'"
    exit 1
  fi
}

createConfigSet() {
  echo ""
  echo "Creating a config set..."
  (cd "$configSetPath/conf" && zip -r - ./*) > "$configSetArchive"
}

uploadConfigSet() {
  echo ""
  echo "Uploading a config set..."
  curl -X POST --verbose --header "Content-Type:application/octet-stream" --data-binary @"$configSetArchive" "$solrURL/solr/admin/configs?action=UPLOAD&name=$configSetName&overwrite=true"
}

showCurrentConfigSets() {
  echo ""
  echo "Current config sets:"
  curl --silent "$solrURL/api/cluster/configs?omitHeader=true" | jq
}

##############################
#        DRIVING CODE        #
##############################
defaultSolrURL="http://localhost:$SOLR_PORT"
solrURL="$defaultSolrURL"
configSetPath=""
configSetName=""
configSetArchive=""

# Parse command line options:
while getopts u:d:h option; do
    case "${option}" in
        u) solrURL=${OPTARG} ;;
        d) configSetPath=${OPTARG} ;;
        h) help ;;
        *) help ;;
    esac
done

validateInput

configSetPath=$(realpath "$configSetPath")
configSetName=$(basename "$configSetPath")
configSetArchive=$(pwd)/"$configSetName.zip"

echo ""
echo "Solr URL: $solrURL"
echo "Config set path: $configSetPath"
echo "Config set name: $configSetName"
echo "Config set archive: $configSetArchive"

showCurrentConfigSets
createConfigSet
uploadConfigSet
showCurrentConfigSets
rm "$configSetArchive"
