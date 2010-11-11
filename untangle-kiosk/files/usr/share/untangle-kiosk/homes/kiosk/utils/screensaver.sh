#! /bin/bash

XSESSION_FILE=/home/kiosk/.xsession

if grep -qiE 'LoadModule.*vesa' /var/log/Xorg.0.log ; then
  XSET_S_OPTIONS="s noblank"
else
  XSET_S_OPTIONS="s blank"
fi

XSET_DPMS_OPTIONS="dpms 120 240 0"

case $1 in
  on)
    xset $XSET_S_OPTIONS
    xset $XSET_DPMS_OPTIONS

    perl -i -pe "s/xset s.*/xset ${XSET_S_OPTIONS}/" $XSESSION_FILE
    perl -i -pe "s/xset .?dpms/xset ${XSET_DPMS_OPTIONS}/" $XSESSION_FILE
    ;;
  off)
    xset s off
    xset -dpms

    perl -i -pe "s/xset s.*/xset s off/" $XSESSION_FILE
    perl -i -pe "s/xset .dpms/xset -dpms/" $XSESSION_FILE
    ;;
esac
