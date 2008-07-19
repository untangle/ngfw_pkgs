#! /bin/bash

Xdialog --default-no --wrap --title "Reboot" --yesno "Are you sure you want to reboot the Untangle Server?" 15 60

if [ $? -eq 0 ]; then
        sudo /sbin/reboot
else
        echo "No shutting down"
fi
