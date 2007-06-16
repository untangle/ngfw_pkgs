#!/bin/sh

if [ ! -f /etc/password-set ] ; then
    sudo su root -c "xterm -T 'Please choose a password' -e '/usr/bin/passwd'"
    sudo su root -c "touch /etc/password-set"
fi
    
/usr/bin/xterm -T Password -e su root