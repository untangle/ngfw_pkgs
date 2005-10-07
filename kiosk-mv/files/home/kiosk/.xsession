#!/bin/sh

xset s off
xset -dpms

# Here's where we launch the window manager.  When this finishes we reboot!
x-session-manager
