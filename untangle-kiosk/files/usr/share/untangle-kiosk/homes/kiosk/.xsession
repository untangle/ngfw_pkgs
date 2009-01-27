# screensaver is off by default
xset s off
xset -dpms

if grep -q VMWARE /var/log/Xorg.0.log ; then
  xrandr -s $(xrandr | head -1 | perl -pe 's/.* maximum (\d+) x (\d+)/$1x$2/')
fi

# start fbpanel
fbpanel &

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

feh --bg-scale /usr/share/untangle-kiosk/desktop_background-1024x768.png

# Here's where we launch the window manager. When this finishes we reboot!
x-window-manager
