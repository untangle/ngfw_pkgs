XORG_CONF_VESA=xorg-untangle-vesa.conf
sudo tee /etc/X11/$XORG_CONF_VESA <<EOF
Section "Device"
Identifier "Configured Video Device"
Driver "vesa"
EndSection

Section "Monitor"
Identifier "Configure Monitor"
  VertRefresh  60
EndSection

Section "Screen" 
Identifier "Default Screen"
Monitor "Configured Monitor"
Device "Configured Video Device"
DefaultDepth 24
SubSection "Display"
Depth 24
Modes "1024x768" 
EndSubSection
EndSection
EOF

abort() {
echo <<EOF
Untangle has failed to properly detect the video & monitor settings for
this server. 

Try restarting the server and selecting "Video Safe Mode" from the
boot menu, or go to http://wiki.untangle.com/index.php/Video_Issues to
read about other options.
EOF
}

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
      [ $failures -gt 5 ] && abort && exit
    fi
  done
fi
