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
    for i in $(seq 3) ; do

        # kill any running X processes
        ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null

        #
        # Special handling for some video cards
        # This is used if we know our appliances (u50) don't support the default
        # We can force video-safe-mode
        #
        # n10=$(lspci | grep "Intel Corporation N10 Family Integrated Graphics Controller (rev 02)")
        # if [ -z "$n10" ] ; then
        #    export XORGCONFIG=$XORG_CONF_SAFE
        # fi

        #
        # Use video-safe-mode xorg config only if we were passed "force-video-safe" via grub
        # 
        forceVideoSafe=$(grep force-video-safe /proc/cmdline)
        if [ -n "$forceVideoSafe" ] ; then
            export XORGCONFIG=$XORG_CONF_SAFE
        fi

        # Start X
        startx

        # Print this warning to console to let the user know X is failing
        print_warning
        sleep 5

        # If we have failed for 2 attempts already, try safe mode on the next try
        if [ $i -gt 2 ] ; then
            export XORGCONFIG=$XORG_CONF_SAFE
        fi

    done
fi
