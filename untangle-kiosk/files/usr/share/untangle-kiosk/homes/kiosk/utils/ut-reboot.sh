#! /bin/bash

# Force English US locale for GTK bug
LANG="en_US"

Xdialog --default-no --wrap --title "Reboot" --yesno "Are you sure you want to reboot the Server?" 15 60

if [ $? -eq 0 ]; then
        sudo /sbin/reboot
else
        echo "No shutting down"
fi
