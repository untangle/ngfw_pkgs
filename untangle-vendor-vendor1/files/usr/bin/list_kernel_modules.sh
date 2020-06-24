#! /bin/bash

usage() {
  echo "Usage:"
  echo "  dpkg-deb -c <kernel-package>.deb | $0"
  echo "    (where <kernel-package.deb> could for instance be curl'ed from https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.98/linux-modules-4.19.98-041998-generic_4.19.98-041998.202001230334_amd64.deb)" 
  echo "or"
  echo "  find /lib/modules/4.19.0-5-amd64 | $0"
}


if [[ $1 == "-h" ]] ; then
  usage
  exit
fi

perl -lne 'print $1 if m|([^/]+).ko$|' | sort -u
