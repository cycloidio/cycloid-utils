#!/bin/bash

LOGPATH=/tmp/debug

if [ $# -eq 0 ]
  then
    echo "$0 <http_url> <secret>"
    exit 0
fi

URL=$1
SECRET=$2

mkdir -p $LOGPATH
cd $LOGPATH

# get report
wget $URL -O report.tar.gz.gpg

# Decrypt report
echo $SECRET | gpg  --passphrase-fd 0 --batch --batch -o $LOGPATH/report.tar.gz --decrypt report.tar.gz.gpg

# Extract report
tar -xf report.tar.gz

echo ""
echo "Report ready: $(pwd)"
