#!/bin/bash

LOGPATH=/tmp/debug

if [ $# -eq 0 ]
  then
    echo "$0 <https_url> <secret>"
    exit 0
fi

URL=$1
SECRET=$2

rm -rf $LOGPATH
mkdir -p $LOGPATH
cd $LOGPATH

# get report
wget $URL -O report.tar.gz.gpg

# Decrypt report
echo $SECRET | gpg  --passphrase-fd 0 --batch --batch -o $LOGPATH/report.tar.gz --decrypt report.tar.gz.gpg
rm report.tar.gz.gpg

# Extract report
tar -xf report.tar.gz
rm report.tar.gz

# If tar files (ansible onprem report), extract all
if ls | grep '.tar$' > /dev/null
  then
    for i in $(ls); do
      tar xf $i;
      rm $i;
    done
fi

echo ""
echo "Report ready: $(pwd)"
