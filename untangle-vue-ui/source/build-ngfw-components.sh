#!/usr/bin/env bash

REMOTE_NGFW_WEBFOLDER="/var/www/vue/";

echo "building NGFW components...";

echo "making sure yarn packages are installed and up to date...";
yarn install --force --network-concurrency 1;

echo "cleaning old build cache...";
yarn clean;

echo "deleting old build files...";
rm -rf dist;

echo "Building NGFW components ...";
VUE_CLI_SERVICE_CONFIG_PATH=$(pwd)/vue.config.ngfw-components.js yarn vue-cli-service build;

echo "Removing old built files from NGFW box (ngfw.untangle.com)"
ssh root@ngfw.untangle.com rm -rf ${REMOTE_NGFW_WEBFOLDER}

echo "Copying built files to NGFW box (ngfw.untangle.com)";
ssh root@ngfw.untangle.com mkdir ${REMOTE_NGFW_WEBFOLDER}
scp -r dist/ngfw-components/* root@ngfw.untangle.com:${REMOTE_NGFW_WEBFOLDER};
