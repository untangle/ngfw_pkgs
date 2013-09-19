XORG_CONF_SAFE=xorg-untangle-safe.conf

print_warning() {
for i in $(seq 50) ; do echo ; done
cat <<EOF
The server has failed to properly detect the video & monitor settings.

Try restarting the server and selecting a different video-mode boot
option from the boot menu.
EOF
for i in $(seq 10) ; do echo ; done
}

if [ `tty` = "/dev/tty1" ] ; then
  while true ; do
    ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null

    START_TIME=$(date +%s)

    forceVideoSafe=$(grep force-video-safe /proc/cmdline)
    n10=$(lspci | grep "Intel Corporation N10 Family Integrated Graphics Controller (rev 02)")

    # use safe xorg config only if we were passed "force-video-safe" via grub, *and* we're
    # not on the same graphics controller as the u50
    [ -n "$forceVideoSafe" ] && [ -z "$n10" ] && export XORGCONFIG=$XORG_CONF_SAFE
    startx

    STOP_TIME=$(date +%s)

    failures=0
    if [ $(($STOP_TIME - $START_TIME)) -lt 60 ] ; then
      export XORGCONFIG=$XORG_CONF_SAFE
      startx
      print_warning
      failures=$(($failures + 1))
      if [ $failures -gt 2 ] ; then
          print_warning
          exit
      fi
    fi
  done
fi
