#! /bin/bash

# constants

ASUS_ROOTFS="/var/lib/asus-ac88u-rootfs"
WL_BIN="/usr/sbin/wl"
NAS_BIN="/usr/sbin/nas"
PY_SCRIPT="/usr/lib/python2.7/brcm-wifi.py"

# functions

usage() {
  echo "Usage:"
  echo "  $0 <interface> (start|stop)"
}

interfaceUp() {
  chroot $ASUS_ROOTFS $WL_BIN -i $1 radio on
  chroot $ASUS_ROOTFS $WL_BIN -i $1 up
}

interfaceDown() {
  chroot $ASUS_ROOTFS $WL_BIN -i $1 down
  chroot $ASUS_ROOTFS $WL_BIN -i $1 radio off
}

interfaceApMode() {
  chroot $ASUS_ROOTFS $WL_BIN -i $1 ap 1
}

startAp() {
  chroot $ASUS_ROOTFS $NAS_BIN -P /tmp/nas.${nic}.pid -H 34954 -i $nic -A -m 4 -w 4 -g 3600 $($PY_SCRIPT)
}

# main

if [ $# != 2 ] ; then
  usage
  exit 1
fi

nic=$1
action=$2

case $action in
  start)
    interfaceUp $nic
    interfaceApMode $nic
    
    ;;
  stop)
    pkill nas 
    interfaceDown $nic ;;
esac
