#!/bin/sh

Xdialog --default-no --wrap --title "Recovery" --yesno "Are you sure want to run Recovery? It will stop Edgeguard services." 15 60

if [ $? -eq 0 ]; then
    xterm -e "sudo /usr/bin/edgeguard-restore"
else
    echo "No shutting down"
fi
