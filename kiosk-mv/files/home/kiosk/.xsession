#!/bin/sh

xset s off
xset -dpms

# disable the middle button
xmodmap -e 'pointer = 1 2'

# Here's where we launch the window manager.  When this finishes we reboot!
x-session-manager
