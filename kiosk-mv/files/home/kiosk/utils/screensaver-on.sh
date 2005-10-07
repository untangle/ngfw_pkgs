#!/bin/sh

xset s on
xset +dpms

sed -i "s/xset s.*/xset s on/" /home/kiosk/.xsession
sed -i "s/xset .dpms/xset +dpms/" /home/kiosk/.xsession
