#!/bin/bash

echo "1. Installing apt packages..."
apt update
apt upgrade -y
apt install less -y && \
    apt install git -y && \
    apt install git -y && \
    apt install curl -y && \
#   Traditional instead of usual, because usual might cause problems for Windows users:
    apt install netcat-traditional -y && \
    apt install zip -y && \
    apt install htop -y && \
    apt install lsof -y && \
    apt install psmisc -y && \
    apt install bc -y && \
    apt install jq -y && \
    apt install vim -y && \
    apt install tree -y && \
    apt install wget -y && \
    apt install unzip -y && \
    apt install automake -y && \
    apt install libtool -y && \
    apt install python3-docutils -y && \
    apt install python3-pip -y && \
    apt install icdiff -y && \
    apt install ffmpeg -y && \
    apt install exiftool -y && \
    apt install tesseract-ocr -y && \
    apt install libtesseract-dev -y && \
    apt install imagemagick -y

echo "2. Installing SDKMAN..."
curl -s "https://get.sdkman.io" | bash
sleep 3 # Required for the above command to be fully completed

echo "3. Sourcing SDKMAN..."
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "4. Installing Maven..."
yes | sdk install maven 3.9.6
