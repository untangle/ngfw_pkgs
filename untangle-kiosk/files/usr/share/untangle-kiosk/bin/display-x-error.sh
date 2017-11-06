#!/bin/bash

print_warning() {
    for i in $(seq 50) ; do echo >> $1 ; done
    cat <<EOF >> $1
The server has failed to properly detect correct video and monitor settings.

There are several things to try:
1) Restarting the server and select a different video-mode boot option from the boot menu.
2) Use a different monitor. Restart the server after switching monitors.
3) Change the BIOS video card settings (if applicable).
4) Remove any KVM (keyboard-video-monitor) switch if in use.
5) Try a different video card (if applicable).

EOF
    for i in $(seq 10) ; do echo >> $1 ; done
}

print_warning /dev/tty1
print_warning /dev/tty7
