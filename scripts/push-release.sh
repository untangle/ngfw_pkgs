#!/bin/sh

sudo rsync -rlptvz -e ssh /var/www/metavize root@www.metavize.com:/var/www.release/
scp ~/work/pkgs/scripts/override.testing.metavize ~/work/pkgs/scripts/deb-scan-release.sh root@www.metavize.com:~/
ssh www.metavize.com -lroot "rm /var/www.release/metavize/pool/metavize/t/test-transform_*"
ssh www.metavize.com -lroot "rm /var/www.release/metavize/pool/metavize/f/fprot-transform_*"
ssh www.metavize.com -lroot "rm /var/www.release/metavize/pool/metavize/s/sophos-transform_*"
ssh www.metavize.com -lroot "~/deb-scan-release.sh /var/www.release/metavize "

