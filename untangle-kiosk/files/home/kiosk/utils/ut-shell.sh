#!/bin/sh

if [ ! -z `sudo su -c 'grep "^root:\*:" /etc/shadow'` ] ; then
    # set the password for the first time
    sudo su root -c "xterm -T 'Please choose a password' -e '/usr/bin/passwd'"
fi

# Also check for the old default password
if [ ! -z `sudo su -c 'grep "^root:YKN4WuGxhHpIw:" /etc/shadow'` ] ; then
    # set the password for the first time
    sudo su root -c "xterm -T 'Please choose a password' -e '/usr/bin/passwd'"
fi

# Also check for the old default password
if [ ! -z `sudo su -c 'grep '^root:$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC.:' /etc/shadow'` ] ; then
    # set the password for the first time
    sudo su root -c "xterm -T 'Please choose a password' -e '/usr/bin/passwd'"
fi
    
xterm -T xterm -e su root