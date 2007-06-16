#!/bin/sh

if [ ! -f /etc/password-set ] ; then
    # set the password for the first time
    sudo su root -c "xterm -T 'Please choose a password' -e '/usr/bin/passwd'"

    # if successful set a flag so we won't set the password next time
    if [ $? -eq 0 ] ; then
        sudo su root -c "touch /etc/password-set"
    fi
fi
    
/usr/bin/xterm -T Password -e su root