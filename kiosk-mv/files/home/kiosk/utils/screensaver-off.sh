#!/bin/sh

xset s off
xset -dpms

sed -i "s/xset s.*/xset s off/" /home/kiosk/.xsession
sed -i "s/xset .dpms/xset -dpms/" /home/kiosk/.xsession
