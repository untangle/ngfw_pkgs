#!/bin/sh

xset s off
xset -dpms

sed -i "s/xset s.*/xset s off/" /home/kiosk/.xinitrc
sed -i "s/xset .dpms/xset -dpms/" /home/kiosk/.xinitrc
