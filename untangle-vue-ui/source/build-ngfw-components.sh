#!/usr/bin/env bash

# Add DNS entry for ngfw.untangle.com with NGFW box's IP in /etc/hosts
REMOTE_NGFW_WEBFOLDER="/usr/share/untangle/web/vue/";

echo "building NGFW components...";

echo "making sure yarn packages are installed and up to date...";
yarn install --force --network-concurrency 1;

echo "cleaning old build cache...";
yarn clean;

echo "deleting old build files...";
rm -rf dist;

echo "Building NGFW components ...";
yarn build;

echo "Removing old built files from NGFW box (ngfw.untangle.com)"
ssh root@192.168.58.121 rm -rf ${REMOTE_NGFW_WEBFOLDER}

echo "Copying built files to NGFW box (ngfw.untangle.com)";
ssh root@192.168.58.121 mkdir ${REMOTE_NGFW_WEBFOLDER}
scp -r dist/* root@192.168.58.121:${REMOTE_NGFW_WEBFOLDER};
