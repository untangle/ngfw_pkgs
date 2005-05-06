#!/bin/sh

sudo rsync -rlptvz -e ssh /var/www/metavize root@release2.metavize.com:/var/www.release2/
scp ~/work/pkgs/scripts/override.testing.metavize ~/work/pkgs/scripts/deb-scan-release2.sh root@release2.metavize.com:~/
ssh release2.metavize.com -lroot "rm /var/www.release2/metavize/pool/metavize/t/test-*"
ssh release2.metavize.com -lroot "rm /var/www.release2/metavize/pool/metavize/f/fprot-*"
ssh release2.metavize.com -lroot "rm /var/www.release2/metavize/pool/metavize/s/sophos-*"
ssh release2.metavize.com -lroot "rm /var/www.release2/metavize/pool/metavize/v/virus-transform_*" &>/dev/null
ssh release2.metavize.com -lroot "rm /var/www.release2/metavize/pool/metavize/k/kernel-dev*"
ssh release2.metavize.com -lroot "sh ~/deb-scan-release2.sh /var/www.release2/metavize "

