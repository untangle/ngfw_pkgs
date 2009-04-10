XORG_CONF_VESA=xorg-untangle-vesa.conf

cat >| /etc/X11/$XORG_CONF_VESA <<EOF
Section "Device"
Identifier "Configured Video Device"
Driver "vesa"
EndSection
EOF

if [ `tty` = "/dev/tty1" ] ; then
  while true ; do
    ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null
    START_TIME=$(date +%s)
    startx
    STOP_TIME=$(date +%s)
    if [ $(($STOP_TIME - $START_TIME)) -lt 60 ] ; then
      export XORGCONFIG=$XORG_CONF_VESA
      startx
      failures=$(($failures + 1))
      [ $failures -gt 5 ] && exit
    fi
  done
fi
