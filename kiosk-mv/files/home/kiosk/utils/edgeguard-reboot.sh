#!/bin/sh

Xdialog --default-no --wrap --title "Reboot" --yesno "Are you sure you want to reboot Metavize EdgeGuard?" 15 60

if [ $? -eq 0 ]; then
        sudo shutdown -h now
else
        echo "No shutting down"
fi
