#!/bin/sh

sudo rsync -rlptvz -e ssh /var/www/metavize root@www.metavize.com:/var/www.trial/
scp ~/work/pkgs/scripts/override.testing.metavize ~/work/pkgs/scripts/deb-scan-trial.sh root@www.metavize.com:~/
ssh www.metavize.com -lroot "rm /var/www.trial/metavize/pool/metavize/t/test-transform_*"
ssh www.metavize.com -lroot "rm /var/www.trial/metavize/pool/metavize/f/fprot-transform_*"
ssh www.metavize.com -lroot "sh ~/deb-scan-trial.sh /var/www.trial/metavize "

