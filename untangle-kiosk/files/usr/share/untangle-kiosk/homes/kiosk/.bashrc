## Variables

# location of "safe" X configuration file
XORG_CONF_SAFE=xorg-kiosk-safe.conf

# use video-safe-mode xorg config only if we were passed
# "force-video-safe" via grub
if grep -q force-video-safe /proc/cmdline ; then
    export XORGCONFIG=$XORG_CONF_SAFE
fi

print_warning() {
    for i in $(seq 50) ; do echo ; done
    cat <<EOF
The server has failed to properly detect correct video and monitor settings.

There are several things to try:
1) Restarting the server and select a different video-mode boot option from the boot menu.
2) Use a different monitor. Restart the server after switching monitors.
3) Change the BIOS video card settings (if applicable).
4) Remove any KVM (keyboard-video-monitor) switch if in use.
5) Try a different video card (if applicable).

Alternatively, Restart and choose the "Text Administration" option.
Configure the network using text administration, then complete configuration the remotely using web administration.

EOF
    for i in $(seq 8) ; do echo ; done
}

launch_x() {
    for i in $(seq 3) ; do

        # start X
        startx
        # if startx returns, something has gone wrong

        # Print this warning to console to let the user know X is failing
        print_warning
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
        print_warning
        sleep 86400
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
