XORG_CONF_SAFE=xorg-untangle-safe.conf

launch_x() {
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
        startx -- vt7
        # If X returns, something has gone wrong

        # Print this warning to console to let the user know X is failing
        sudo /usr/share/untangle-kiosk/bin/display-x-error.sh
        sleep 5

        # If we have failed for 2 attempts already, try safe mode on the next try
        if [ $i -gt 2 ] ; then
            export XORGCONFIG=$XORG_CONF_SAFE
        fi

    done

    # 
    # Sleep forever so that they do not automatically get a shell prompt
    # You can easily ctrl-C this to get the bash shell
    #
    while true; do
        sudo /usr/share/untangle-kiosk/bin/display-x-error.sh
        sleep 60
    done
}

if [ `tty` = "/dev/tty1" ] ; then

    textAdmin=$(grep text-administration /proc/cmdline)
    if [ -n "$textAdmin" ] ; then
        sudo /usr/share/untangle/bin/ut-textui.py
    else
        launch_x
    fi


fi


