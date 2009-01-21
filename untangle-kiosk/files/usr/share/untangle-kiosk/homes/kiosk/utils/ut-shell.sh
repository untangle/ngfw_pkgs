#! /bin/bash

XTERM="urxvt"

if sudo grep -qE '^root:(\*|YKN4WuGxhHpIw|$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC\.|CHANGEME):' /etc/shadow ; then
  # set the password for the first time
  sudo su root -c "${XTERM} -T 'Please choose a password' -e '/usr/bin/passwd'"
fi

${XTERM} -T "${XTERM} su root" &
