#! /bin/bash

XTERM="urxvt"

if [ ! -z `sudo su -c 'grep "^root:\*:" /etc/shadow'` ] || \
   [ ! -z `sudo su -c 'grep "^root:YKN4WuGxhHpIw:" /etc/shadow'` ] || \
   [ ! -z `sudo su -c 'grep '^root:$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC.:' /etc/shadow'` ] ; then
  # set the password for the first time
  sudo su root -c "${XTERM} -T 'Please choose a password' -e '/usr/bin/passwd'"
fi

${XTERM} -T ${XTERM} -e bash -c 'su root' &
