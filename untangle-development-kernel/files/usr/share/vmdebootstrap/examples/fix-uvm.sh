#! /bin/bash

CHROOT=$1
IMAGE=$2

# on jessie & stretch, the initrd produced by dracut causes systemd to
# choke during the switch-root service startup, for no apparent
# reason.
# This does not happen with the more recent systemd version in
# buster.
version=$(systemd --version | awk '/^systemd / { print $2 }')
if [[ $version -lt 236 ]] ; then 
  sed -i -e '/^OnFailure=/d' ${CHROOT}/lib/systemd/system/initrd-switch-root.service
fi

# the UVM will create sources as it sees fit during startup
echo >| ${CHROOT}/etc/apt/sources.list

exit 0
