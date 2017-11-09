## Variables

# location of "safe" X configuration file
XORG_CONF_SAFE=xorg-untangle-safe.conf

# use video-safe-mode xorg config only if we were passed
# "force-video-safe" via grub
if grep -q force-video-safe /proc/cmdline ; then
    export XORGCONFIG=$XORG_CONF_SAFE
fi

# on Stretch, do not pass -- vt7 to startx
if ! grep -qE '^9\.' /etc/debian_version ; then
    STARTX_OPTIONS="-- vt7"
fi

launch_x() {
    for i in $(seq 3) ; do
        # kill any running X processes
        ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null

        # Start X
        startx $STARTX_OPTIONS
        # If X returns, something has gone wrong

        # Print this warning to console to let the user know X is failing
        sudo /usr/share/untangle-kiosk/bin/display-x-error.sh
        sleep 5

        # If we have failed for 2 attempts already, try safe mode on the next try
        if [ $i -gt 2 ] ; then
            export XORGCONFIG=$XORG_CONF_SAFE
        fi
    done

    # At this point, we really could not start X in any mode: sleep
    # forever so that they do not automatically get a shell prompt.
    # You can easily ctrl-C this to get the bash shell
    while true; do
        sudo /usr/share/untangle-kiosk/bin/display-x-error.sh
        sleep 60
    done
}

## Main
if [ $(tty) = "/dev/tty1" ] ; then
    if grep -q text-administration /proc/cmdline ; then
        sudo /usr/share/untangle/bin/ut-textui.py
    else
        launch_x
    fi
fi
