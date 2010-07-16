#! /bin/bash

# Force English US locale for GTK bug
LANG="en_US"

Xdialog --default-no --wrap --title "Power off" --yesno "Are you sure you want to shut down the Server?" 15 60

if [ $? -eq 0 ]; then
        sudo shutdown -h now
else
        echo "No shutting down"
fi
