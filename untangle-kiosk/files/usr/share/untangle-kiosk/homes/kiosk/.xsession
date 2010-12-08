# Xorg starts with "-nolisten tcp" so this is a decent fix for #6670
xhost +

# screensaver is off by default
xset s off
xset -dpms

currentResolution=$(xrandr | head -1 | perl -pe 's/.*current (\d+) x (\d+).*/$1x$2/')

# resize screen on vmware by forcing it to 1024x768, since the default
# 800x600 is a bit ridiculous (we don't set it to what xrandr reports
# as the maximum available size anymore, since we now offer a way for
# the user to change his desktop resolution)
if grep -qE '^\(II\) VMWARE\(0\)' /var/log/Xorg.0.log && [ "$currentResolution" = 800x600 ] ; then
  xrandr -s 1024x768
fi

# resize screen on VESA by forcing it to 1024x768
if grep -qE '^\(II\) VESA\(0\)' /var/log/Xorg.0.log ; then
  xrandr -s 1024x768
fi

# always force 1024x768, *before* trying to restore a previously-saved
# resolution if any; this is to work around xorg erroneously trying to
# use resolutions that the monitor does not support
xrandr -s 1024x768

# restore user-set resolution if it's present
[ -f /home/kiosk/.ut-resolution ] && xrandr -s $(cat /home/kiosk/.ut-resolution)

# set a reasonable DPI value if the current one is grossly wrong (this
# does not seem to work on VMWare, but the issue we're fixing doesn't
# show up on VMWare anyway)
currentDPI=$(xdpyinfo | awk '/resolution/ { gsub(/x.+/, "", $2) ; print $2}')
[ "$currentDPI" -gt 400 ] && xrand --dpi 96

# set background picture, and start panel
/home/kiosk/utils/ut-desktop.sh

# do not recover a (potentially saved) previous session
find .mozilla -name sessionstore.js -exec /bin/rm {} \;

# automatically start the setup wizard if the registration file isn't present
if [ ! -f /usr/share/untangle/conf/registration.info ] ; then
    /usr/bin/untangle-client &
fi

# the window manager; when this exits, X stops, but it will restart
# automatically anyway, so it does not matter.
xfwm4
