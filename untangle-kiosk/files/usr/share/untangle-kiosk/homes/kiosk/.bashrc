XORG_CONF_VESA_STND=xorg-untangle-vesa.conf
cat > $XORG_CONF_VESA_STND <<EOF
Section "Device"
Identifier "Configured Video Device"
Driver "vesa"
EndSection

Section "Monitor"
Identifier "Monitor"
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

XORG_CONF_VESA_WIDE=xorg-untangle-vesa-wide.conf
cat > $XORG_CONF_VESA_WIDE <<EOF
Section "Device"
Identifier "Configured Video Device"
Driver "vesa"
EndSection

Section "Monitor"
Identifier "Monitor"
EndSection

Section "Screen" 
Identifier "Default Screen"
Monitor "Configured Monitor"
Device "Configured Video Device"
DefaultDepth 24
SubSection "Display"
Depth 24
Modes "1280x800"
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
    grep -q ut-video-stnd /proc/cmdline && export XORGCONFIG=$XORG_CONF_VESA_STND
    grep -q ut-video-wide /proc/cmdline && export XORGCONFIG=$XORG_CONF_VESA_WIDE
    startx
    STOP_TIME=$(date +%s)
    if [ $(($STOP_TIME - $START_TIME)) -lt 60 ] ; then
      export XORGCONFIG=$XORG_CONF_VESA_STND
      startx
      failures=$(($failures + 1))
      [ $failures -gt 5 ] && abort && exit
    fi
  done
fi
