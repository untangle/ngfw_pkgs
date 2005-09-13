#!/bin/sh

if [ $# -lt 2 ] ; then
    echo "Usage: push.sh /var/www/dmorris /var/www/metavize"
    exit 2
fi

echo "-------------------------"
sudo rsync -rlptvz $1 $2
echo "-------------------------"
sudo ./deb-scan.sh $2

