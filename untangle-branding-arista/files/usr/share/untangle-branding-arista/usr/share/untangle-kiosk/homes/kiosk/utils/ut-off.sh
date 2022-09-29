#! /bin/bash

/usr/bin/zenity \
    --question \
    --no-wrap \
    --title "Power off" \
    --text "Are you sure you want to shut down the Server?"

if [ $? -eq 0 ]; then
        sudo shutdown -h now
else
        echo "No shutting down"
fi
