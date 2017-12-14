#! /bin/bash

DIR=$1

# on jessie & stretch, the initrd produced by dracut causes systemd to
# choke during the switch-root service startup, for no apparent
# reason.
# This does not happen with the more recent systemd version in
# buster.

version=$(systemd --version | awk '/^systemd / { print $2 }')

if [[ $version -lt 236 ]] ; then 
  sed -i -e '/^OnFailure=/d' ${DIR}/lib/systemd/system/initrd-switch-root.service
fi
