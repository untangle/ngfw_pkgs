#! /bin/bash

/usr/bin/zenity \
    --question \
    --title "Recovery" \
    --text "Are you sure want to run Recovery? It will stop network services." 

if [ $? -eq 0 ]; then
    urxvt -T "Recovery" -e sudo /usr/share/untangle/bin/ut-restore-tool
else
    echo "No shutting down"
fi
