auto_start_client()
{
    [ -x ${UVM_AUTO_SCRIPT} ] && [ -f ${UVM_AUTO_CONFIG} ] && {
        ${UVM_AUTO_SCRIPT} ${UVM_AUTO_CONFIG}
    } || {
        /usr/bin/untangle-client &
    }
}

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

    [ ! -f $ACTIVATION_KEY_FILE ] && auto_start_client

    ## Remove this afterwards to guarantee this stuff never runs again.
    rm -f ${UVM_AUTO_SCRIPT} ${UVM_AUTO_CONFIG}
fi

# Here's where we launch the window manager. When this finishes we reboot!
x-session-manager
