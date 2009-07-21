XORG_CONF_VESA=xorg-untangle-vesa.conf

sudo tee /etc/X11/$XORG_CONF_VESA <<EOF
Section "Device"
Identifier "Configured Video Device"
Driver "vesa"
EndSection

Section "Monitor"
Identifier "Monitor"
Option "PreferredMode" "1024x768"
EndSection

Section "Screen" 
Identifier "Default Screen"
DefaultDepth 24
SubSection "Display"
Depth 24
Modes "1024x768" "800x600"
Virtual 1024 768
EndSubSection
EndSection
EOF

if [ `tty` = "/dev/tty1" ] ; then
  while true ; do
    ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null
    START_TIME=$(date +%s)
    grep -q ut-video /proc/cmdline && export XORGCONFIG=$XORG_CONF_VESA
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
