#! /bin/bash

XSESSION_FILE=/home/kiosk/.xsession
XSET_S_OPTIONS="s blank s 120 15"

if grep -i -E 'Loading.*drivers' /var/log/XFree86.0.log | grep -q vesa ; then
  XSET_S_OPTIONS=${XSET_S_OPTIONS/blank/noblank}
fi

case $1 in
  on)
    xset $XSET_S_OPTIONS
    xset dpms

    sed -i "s/xset s.*/xset ${XSET_S_OPTIONS}/" $XSESSION_FILE
    sed -i "s/xset .dpms/xset dpms/" $XSESSION_FILE
    ;;
  off)
    xset s off
    xset -dpms

    sed -i "s/xset s.*/xset s off/" $XSESSION_FILE
    sed -i "s/xset .dpms/xset -dpms/" $XSESSION_FILE
    ;;
esac
