#!/bin/bash
##
## Compile sync-settings and install if no errors.
##

dpkg-buildpackage -b -rfakeroot -us -uc

if [ $? -eq 0 ] ; then
    dpkg -i ..//untangle-python3-sync-settings*deb
fi
