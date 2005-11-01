#!/bin/sh

echo -e "\n\nSyncing...\n\n"

sudo rsync -rlpvz -e ssh /var/www/dogfood \
    --exclude 'echospam*' \
    --exclude 'echod*' \
    --exclude 'test-*' \
    --exclude 'fprot-*' \
    --exclude 'sophos-*' \
    --exclude 'virus-transform*' \
    --exclude 'kernel-dev*' \
    --exclude 'dev-mv*' \
    --exclude 'ids-*' \
    --exclude 'kav-*' \
    root@release.metavize.com:/var/www.release/

scp \
    ~/work/pkgs/scripts/override.testing.metavize \
    ~/work/pkgs/scripts/deb-scan.sh  \
    ~/work/pkgs/scripts/clean-packages.sh \
    root@release.metavize.com:~/

echo -e "\n\nCleaning...\n\n"

ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/e/echod*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/e/echospam*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/t/test-*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/f/fprot-*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/s/sophos-*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/v/virus-transform*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/k/kernel-dev*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/d/dev-mv*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/i/ids-*"
ssh release.metavize.com -lroot "rm -f /var/www.release/metavize/pool/metavize/k/kav-*"
#ssh release.metavize.com -lroot "sh ~/clean-packages.sh /var/www.release/metavize 3 move"

echo -e "\n\nBuilding Package List...\n\n"

ssh release.metavize.com -lroot "sh ~/deb-scan.sh /var/www.release/metavize "

