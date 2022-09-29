#! /bin/bash

/usr/bin/zenity \
    --question \
    --no-wrap \
    --title "Recovery" \
    --text "Are you sure want to run Recovery?\nIt will stop network services."

if [ $? -eq 0 ]; then
    urxvt -T "Recovery" -e sudo /usr/share/untangle/bin/ut-textui.py
else
    echo "No shutting down"
fi
