#! /bin/bash

#Force US English Locale due to Xdialog/GTK font bug.
LANG="en_US"
XTERM="urxvt"
DIALOG="Xdialog"
COMMON_OPTS="--left"
OEM_NAME="Untangle"

if [ -f /etc/untangle/oem/oem.sh ] ; then
    source /etc/untangle/oem/oem.sh
fi

if sudo grep -qE '^root:(\*|YKN4WuGxhHpIw|$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC\.|CHANGEME):' /etc/shadow ; then
  tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
  trap "rm -f $tempfile" 0 1 2 5 15  
  # set the password for the first time
  $DIALOG $COMMON_OPTS --password --password --title "Set a password" --2inputsbox "Since this is the first time you are logging into the terminal, you will
need to set a password for the super-user (root) account.\n\n
You need to enter the same password twice to set the new password.\n
\n
Please choose a password that is not easily guessed, especially if you\n
have already, or plan on enabling ssh access to the system.\n" 0 0 "New Password" "" "Confirm Password" "" 2> $tempfile
  case $? in
    0)
      #Ok pressed
      password1=`cat $tempfile | cut -f1 -d/`
      password2=`cat $tempfile | cut -f2 -d/`
      if [ "$password1" == "" ] ; then
        $DIALOG $COMMON_OPTS --title "No Password set" --msgbox "The password can not be blank." 0 0
        exit
      fi
      if [ "$password1" != "$password2" ] ;  then
        $DIALOG $COMMON_OPTS --title "Password set failed" --msgbox "You did not enter the same password twice." 0 0
        exit
      else
        sudo usermod -p `echo $password1 | openssl passwd -crypt -stdin -salt '$1'` root
      fi ;;
    1)
      #Cancel Pressed
      $DIALOG $COMMON_OPTS --title "Cancelled" --msgbox "The setting of the password was cancelled." 0 0
      exit ;;
    255)
      #ESC Pressed
      $DIALOG $COMMON_OPTS --title "Cancelled" --msgbox "The setting of the password was cancelled." 0 0
      exit ;;
  esac
  password1=`cat $tempfile | cut -f1 -d/`
  password2=`cat $tempfile | cut -f2 -d/`
  if [ "$password1" == "" ] ; then
    $DIALOG $COMMON_OPTS --title "No Password set" --msgbox "The password can not be blank." 0 0
    exit
  fi
  if [ "$password1" != "$password2" ] ;  then
    # password change failed, output a message and exit
    $DIALOG $COMMON_OPTS --title "Password set failed" --msgbox "You did not enter the same password twice." 0 0
    exit
  else
    sudo usermod -p `echo $password1 | openssl passwd -crypt -stdin -salt '$1'` root
  fi
fi
$DIALOG $COMMON_OPTS --title "Shell Use Warning" --msgbox "You will be prompted to enter the super-user password to proceed.\n
\n
Note: this password is not the same as the web interface admin password.\n
It was set the first time the Terminal button was pressed.\n
\n
Additionally, changes made at the command line are not supported by $OEM_NAME and\n
can severely limit your support options.\n
\n
This feature is for advanced users only.\n" 0 0

${XTERM} -tn rxvt -T ${XTERM} -e su root &
