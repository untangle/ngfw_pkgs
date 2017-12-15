#! /bin/bash

CHROOT=$1
IMAGE=$2

# kill leftover processes (gpg-agent for instance)
kill $(lsof $CHROOT | awk '{print $2}' | sort -u)  2> /dev/null

# on jessie & stretch, the initrd produced by dracut causes systemd to
# choke during the switch-root service startup, for no apparent
# reason.
# This does not happen with the more recent systemd version in
# buster.
version=$(systemd --version | awk '/^systemd / { print $2 }')
if [[ $version -lt 236 ]] ; then 
  sed -i -e '/^OnFailure=/d' ${DIR}/lib/systemd/system/initrd-switch-root.service
fi

exit 0


