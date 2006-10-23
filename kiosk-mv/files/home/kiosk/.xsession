#!/bin/sh

xset s off
xset -dpms

# disable the middle button through a 3rd party app
xbindkeys &

# start fbpanel
fbpanel &

# Here's where we launch the window manager.  When this finishes we reboot!
x-session-manager
