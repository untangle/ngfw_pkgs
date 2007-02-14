#!/bin/sh

xset s off
xset -dpms

# disable the middle button through a 3rd party app
xbindkeys &

# start fbpanel
fbpanel &

# automatically start the setup wizard if the license file isn't present
LICENSE_FILE="/usr/share/metavize/activation.key"
[ ! -f $LICENSE_FILE ] && /usr/bin/untangle-client &

# Here's where we launch the window manager.  When this finishes we reboot!
x-session-manager
