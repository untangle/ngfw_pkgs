#!/bin/sh

Xdialog --default-no --wrap --title "Power off" --yesno "Are you sure you want to turn off Metavize EdgeGuard?" 15 60

if [ $? -eq 0 ]; then
        sudo shutdown -h now
else
        echo "No shutting down"
fi
