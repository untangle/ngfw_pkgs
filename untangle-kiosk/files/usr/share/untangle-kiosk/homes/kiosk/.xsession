# screensaver is off by default
xset s off
xset -dpms

# disable the middle button through a 3rd party app
xbindkeys &

# start fbpanel
fbpanel &

# automatically start the setup wizard if the license file isn't present
if [ -f /etc/default/untangle-vm ] ; then
    . /etc/default/untangle-vm
    [ ! -f $ACTIVATION_KEY_FILE ] && /usr/bin/untangle-client &
fi

# Here's where we launch the window manager. When this finishes we reboot!
x-session-manager
