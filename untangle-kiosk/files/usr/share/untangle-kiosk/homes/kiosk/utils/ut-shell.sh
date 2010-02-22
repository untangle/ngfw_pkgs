#! /bin/bash

XTERM="urxvt"

if sudo grep -qE '^root:(\*|YKN4WuGxhHpIw|$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC\.|CHANGEME):' /etc/shadow ; then
  # set the password for the first time
  echo "Since this is the first time you are logging into the terminal, you"
  echo "will now be prompted to set a password for the super-user (root) account."
  echo "The system will prompt you to enter the password twice" 
  echo 
  echo "It will not echo your keystrokes to the screen for security."
  echo 
  sudo su root -c "${XTERM} -T 'Please choose a password' -e '/usr/bin/passwd'"
  if sudo grep -qE '^root:(\*|YKN4WuGxhHpIw|$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC\.|CHANGEME):' /etc/shadow ; then
    # password change failed, output a message and exit
    echo "Password change failed, exiting."
    sleep 4
    exit
  fi
else
  echo "Please enter the super-user password to proceed."
  echo
  echo "Note: this passord is not the same as the web interface admin password."
  echo "It was set the first time the Terminal button was pressed."
  echo
fi

${XTERM} -tn rxvt -T ${XTERM} -e su root &
