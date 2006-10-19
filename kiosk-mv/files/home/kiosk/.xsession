#!/bin/sh

xset s off
xset -dpms

# disable the middle button through a 3rd party app
xbindkeys &

# the mighty xfce panel
xfce4-panel &

# Here's where we launch the window manager.  When this finishes we reboot!
x-session-manager
