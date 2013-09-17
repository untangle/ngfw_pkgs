# Xorg starts with "-nolisten tcp" so this is a decent fix for #6670
xhost +

# screensaver is off by default
xset s off
xset -dpms

# If we're in VESA always resize screen on to 1024x768
if grep -qE '^\(II\) VESA\(0\)' /var/log/Xorg.0.log ; then
    xrandr -s 1024x768
fi

# If we're in < 1024x768, attempt switching to 1024x768
# currentResolution=$(xrandr | head -1 | perl -pe 's/.*current (\d+) x (\d+).*/$1x$2/')
currentResolutionX=$(xrandr | head -1 | perl -pe 's/.*current (\d+) x (\d+).*/$1/')
if [ "$currentResolutionX" -lt "1024" ] ; then
    xrandr -s 1024x768
fi

# If we're still in 800x600 or 640x480 go ahead and warn the user with a pop-up
currentResolutionX=$(xrandr | head -1 | perl -pe 's/.*current (\d+) x (\d+).*/$1/')
if [ "$currentResolutionX" -lt "1024" ] ; then
    Xdialog --left --title "Warning" --msgbox "The system is unable to configure the minimum required resolution (1024x768). Try another video boot option or video card/monitor configuration." 0 0 &
fi

# set a reasonable DPI value if the current one is grossly wrong (this
# does not seem to work on VMWare, but the issue we're fixing doesn't
# show up on VMWare anyway)
currentDPI=$(xdpyinfo | awk '/resolution/ { gsub(/x.+/, "", $2) ; print $2}')
[ "$currentDPI" -gt 400 ] && xrand --dpi 96

# start fbpanel
pkill fbpanel
fbpanel &

# set the background
if [ -f /usr/share/untangle-kiosk/desktop_background-4x3.png ] ; then
    feh --bg-scale /usr/share/untangle-kiosk/desktop_background-4x3.png
fi

# do not recover a (potentially saved) previous session
find .mozilla -name sessionstore.js -exec /bin/rm {} \;

# Launch appliance imaging script if present

if [ -x /usr/share/untangle/bin/appliance_imaging_script.sh ] ; then
    sudo xterm /usr/share/untangle/bin/appliance_imaging_script.sh 
fi

# automatically start the setup wizard if it hasn't been completed
if [ ! -f /usr/share/untangle/conf/wizard-complete-flag ] ; then
    /usr/bin/untangle-client &
fi

# the window manager; when this exits, X stops, but it will restart
# automatically anyway, so it does not matter.
xfwm4
