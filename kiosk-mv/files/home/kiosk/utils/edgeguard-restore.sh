#!/bin/sh

Xdialog --default-no --wrap --title "Restore" --yesno "Are you sure want to run Restore? It will stop Edgeguard services." 15 60

if [ $? -eq 0 ]; then
    xterm -e "sudo /usr/bin/edgeguard-restore.sh"
else
    echo "No shutting down"
fi
