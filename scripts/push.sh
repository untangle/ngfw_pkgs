#!/bin/sh

echo "-------------------------"
sudo rsync -rlptvz $1 $2
echo "-------------------------"
sudo ./deb-scan.sh $2

