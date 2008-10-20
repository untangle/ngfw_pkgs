# screensaver is off by default
xset s off
xset -dpms

# disable the middle button through a 3rd party app
xbindkeys &

update_status()
{
    local t_status=$1

    if [ -d `dirname ${UVM_STATUS_FILE}` ] ; then
        sudo sh -c "echo \"${t_status}\" > ${UVM_STATUS_FILE}"
    fi
}

# automatically start the setup wizard if the license file isn't present
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

    [ ! -f $ACTIVATION_KEY_FILE ] && /usr/bin/untangle-client &

    ## This will wait for the shutdown command for vmware.
    WIN_ACTION_HANDLER=${WIN_ACTION_HANDLER:-/usr/share/untangle-windows-installer/bin/action_handler.rb}
    [ -x ${WIN_ACTION_HANDLER} ] && sudo -b ${WIN_ACTION_HANDLER} 
fi

# start fbpanel
fbpanel &

# Here's where we launch the window manager. When this finishes we reboot!
x-session-manager
