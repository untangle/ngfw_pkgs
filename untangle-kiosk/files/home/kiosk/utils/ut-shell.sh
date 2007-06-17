#!/bin/sh

if [ ! -z `sudo su -c 'grep "^root:\*:" /etc/shadow'` ] ; then
    # set the password for the first time
    sudo su root -c "xterm -T 'Please choose a password' -e '/usr/bin/passwd'"
fi
    
/usr/bin/xterm -T Password -e su root