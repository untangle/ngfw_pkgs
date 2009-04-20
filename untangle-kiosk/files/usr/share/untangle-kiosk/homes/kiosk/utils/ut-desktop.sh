#! /bin/sh

# panel
pkill fbpanel
fbpanel &

# background
feh --bg-scale /usr/share/untangle-kiosk/desktop_background-1024x768.png
