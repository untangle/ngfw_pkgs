#! /bin/bash

set -e

# constants

ASUS_ROOTFS="/var/lib/asus-ac88u-rootfs"
WL_BIN="/usr/sbin/wl"
PY_SCRIPT="/usr/lib/python2.7/brcm-wifi.py"

# functions

usage() {
  echo "Usage:"
  echo "  $0 <interface> (start|stop)"
}

interfaceUp() {
  ifconfig $1 down
  chroot $ASUS_ROOTFS $WL_BIN -i $1 down
  chroot $ASUS_ROOTFS $WL_BIN -i $1 radio on
  chroot $ASUS_ROOTFS $WL_BIN -i $1 ap 1
  if [[ $1 == eth1 ]] ; then
    chroot $ASUS_ROOTFS $WL_BIN -i $1 vht_features 3
    chroot $ASUS_ROOTFS $WL_BIN -i $1 vhtmode 1
  fi
  chroot $ASUS_ROOTFS $WL_BIN -i $1 roam_delta 15
  # chroot $ASUS_ROOTFS $WL_BIN -i $1 band FIXME
  ifconfig $1 up
  chroot $ASUS_ROOTFS $WL_BIN -i $1 up
}

interfaceDown() {
  chroot $ASUS_ROOTFS $WL_BIN -i $1 ap off
  chroot $ASUS_ROOTFS $WL_BIN -i $1 radio off
  chroot $ASUS_ROOTFS $WL_BIN -i $1 down
}

startAp() {
  python $PY_SCRIPT $1 $2 | while read line ; do
    chroot $ASUS_ROOTFS $line
  done
}

# main

if [ $# != 2 ] ; then
  usage
  exit 1
fi

nic=$1
action=$2

hostapdConf="/etc/hostapd/hostapd.conf-$nic"

case $action in
  start)
    if [ -f $hostapdConf ] ; then
      interfaceUp $nic
      startAp $nic $hostapdConf
    fi
    ;;
  stop)
    pkill -9 nas || true
    interfaceDown $nic ;;
esac
