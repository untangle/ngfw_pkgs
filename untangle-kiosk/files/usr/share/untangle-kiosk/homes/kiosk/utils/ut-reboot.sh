#! /bin/bash

/usr/bin/zenity \
    --question \
    --title "Reboot" \
    --text "Are you sure you want to reboot the Server?"

if [ $? -eq 0 ]; then
        sudo /sbin/reboot
else
        echo "No shutting down"
fi
