#!/bin/sh

echo -e "\n\nSyncing...\n\n"

sudo rsync -rlpvz -e ssh /var/www/dogfood/ \
    --exclude 'echospam*' \
    --exclude 'echod*' \
    --exclude 'test-*' \
    --exclude 'fprot-*' \
    --exclude 'sophos-*' \
    --exclude 'virus-transform*' \
    --exclude 'kernel-dev*' \
    --exclude 'dev-mv*' \
    --exclude 'kav-*' \
    root@release-alpha.metavize.com:/var/www.release-alpha/metavize

scp \
    ~/work/pkgs/scripts/override.testing.metavize \
    ~/work/pkgs/scripts/deb-scan.sh  \
    ~/work/pkgs/scripts/clean-packages.sh \
    root@release-alpha.metavize.com:~/

echo -e "\n\nCleaning...\n\n"

#ssh release-alpha.metavize.com -lroot "sh ~/clean-packages.sh /var/www.release-alpha/metavize 3 delete"

echo -e "\n\nBuilding Package List...\n\n"

ssh release-alpha.metavize.com -lroot "sh ~/deb-scan.sh /var/www.release-alpha/metavize "

