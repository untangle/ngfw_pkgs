# screensaver is off by default
xset s off
xset -dpms

# disable the middle button through a 3rd party app
xbindkeys &

# start fbpanel
fbpanel &

# automatically start the setup wizard if the license file isn't present
if [ -f /etc/default/untangle-vm ] ; then
    . /etc/default/untangle-vm

    UVM_AUTO_SCRIPT=${UVM_AUTO_SCRIPT:-/var/lib/untangle-windows-installer/init_uvm.rb}
    UVM_AUTO_CONFIG=${UVM_AUTO_CONFIG:-/mnt/hgfs/untangle/config.js}

    if [ -f ${UVM_AUTO_SCRIPT} -a -f ${UVM_AUTO_CONFIG} ]; then
        sudo mkdir -p /var/log/uvm/
        sudo sh -c "${UVM_AUTO_SCRIPT} ${UVM_AUTO_CONFIG} >> /var/log/uvm/auto_config.log 2>&1"
    fi

    ## Remove this afterwards to guarantee this stuff never runs again.
    sudo rm -f ${UVM_AUTO_SCRIPT} ${UVM_AUTO_CONFIG}

    ## Remove this after it is executed to guarantee it never runs again.
    UVM_PRE_UVM_SCRIPT=${UVM_PRE_UVM_SCRIPT:-/var/lib/untangle-windows-installer/pre_uvm.rb}
    sudo rm -f ${UVM_PRE_UVM_SCRIPT}

    [ ! -f $ACTIVATION_KEY_FILE ] && /usr/bin/untangle-client &
fi

# Here's where we launch the window manager. When this finishes we reboot!
x-session-manager
