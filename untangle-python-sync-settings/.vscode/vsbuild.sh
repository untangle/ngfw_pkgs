#!/bin/bash
##
## Compile sync-settings and install if no errors.
##
TARGET=$1

if [ -d /etc/untangle ]; then
    ##
    ## Building on ngfw system.
    ##
    dpkg-buildpackage -b -rfakeroot -us -uc

    if [ $? -eq 0 ] ; then
        dpkg -i ..//untangle-python3-sync-settings*deb
    fi
else
    ##
    ## mfw.
    ##
    rsync -r -a -v -e "ssh -i /root/.ssh/untangle.openssh.rsa" bin root@$TARGET:/usr
    rsync -r -a -v -e "ssh -i /root/.ssh/untangle.openssh.rsa" sync/* root@$TARGET:/usr/lib/python3.6/site-packages/sync
fi
