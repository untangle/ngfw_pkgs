#! /bin/bash

XTERM="urxvt"
DIALOG="/usr/bin/zenity"
OEM_NAME="Untangle"

if [ -f /etc/untangle/oem/oem.sh ] ; then
    source /etc/untangle/oem/oem.sh
fi

$DIALOG \
    --info \
    --title "Terminal Use Warning" \
    --no-wrap \
    --text \
"You will be prompted to enter the admin/root password to proceed.

WARNING:
Changes made via the command line are NOT supported and can seriously interfere with the proper operation of $OEM_NAME.
Changes made via the command line are NOT supported by $OEM_NAME and can severely limit your support options.
It is recommended to disable upgrades if any changes are made.

This feature is for advanced users only." 

${XTERM} -tn rxvt -T ${XTERM} -e su root &
