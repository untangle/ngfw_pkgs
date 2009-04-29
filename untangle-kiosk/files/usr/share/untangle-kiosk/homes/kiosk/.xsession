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
if [ -f /etc/default/untangle-vm ] ; then
    . /etc/default/untangle-vm
    UVM_AUTO_SCRIPT=${UVM_AUTO_SCRIPT:-/var/lib/untangle-windows-installer/init_uvm.rb}
    UVM_AUTO_CONFIG=${UVM_AUTO_CONFIG:-/mnt/hgfs/untangle/config.js}
    UVM_STATUS_FILE=${UVM_STATUS_FILE:-/mnt/hgfs/untangle/status}

    if [ -f ${UVM_AUTO_SCRIPT} -a -f ${UVM_AUTO_CONFIG} ]; then
        sudo mkdir -p /var/log/uvm/
        update_status "Installing"
        sudo sh -c "${UVM_AUTO_SCRIPT} ${UVM_AUTO_CONFIG} >> /var/log/uvm/auto_config.log 2>&1"
        update_status "Running"
    fi

    ## Remove this afterwards to guarantee this stuff never runs again.
    sudo rm -f ${UVM_AUTO_SCRIPT} ${UVM_AUTO_CONFIG}

    ## Remove this after it is executed to guarantee it never runs again.
    UVM_PRE_UVM_SCRIPT=${UVM_PRE_UVM_SCRIPT:-/var/lib/untangle-windows-installer/pre_uvm.rb}
    sudo rm -f ${UVM_PRE_UVM_SCRIPT}

    [ ! -f $REGISTRATION_INFO_FILE ] && /usr/bin/untangle-client &

    ## This will wait for the shutdown command for vmware.
    WIN_ACTION_HANDLER=${WIN_ACTION_HANDLER:-/usr/share/untangle-windows-installer/bin/action_handler.rb}
    [ -x ${WIN_ACTION_HANDLER} ] && sudo -b ${WIN_ACTION_HANDLER} 
fi

# the window manager; when this exits, X stops, but it will restart
# automatically anyway, so it does not matter.
xfwm4
