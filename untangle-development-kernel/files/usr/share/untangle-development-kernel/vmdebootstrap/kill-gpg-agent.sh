#! /bin/bash

CHROOT=$1
IMAGE=$2

kill $(lsof $CHROOT | awk '{print $2}' | sort -u)  2> /dev/null

exit 0


