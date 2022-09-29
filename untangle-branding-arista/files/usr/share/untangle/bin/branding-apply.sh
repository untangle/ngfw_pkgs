#! /bin/bash

#
# NOTE: This is added as a way to provide only Arista-specific branding to
# already released NFGW version 16.5.2.  All of this branding is incorporated
# into the subsequent release so all of this should be removed 
#(or never merged into main trunk)
#

# apply files
rsync -Ha /usr/share/untangle-branding-*/ /

# Kiosk updates
KIOSK_HOME=/home/kiosk
rsync -Ha /usr/share/untangle-kiosk/homes/kiosk/ ${KIOSK_HOME}/
chown -R kiosk:kiosk ${KIOSK_HOME}

# rename grub titles
if [ -f /boot/grub/menu.lst ] ; then
    sed -i 's|^\(title.*\)Debian GNU/Linux, kernel|\1Kernel|' /boot/grub/menu.lst
    sed -i 's|^\(title.*\)-arista|\1|' /boot/grub/menu.lst
fi

# change startup messages
sed -i 's|OEM_NAME=.*|OEM_NAME=\"ARISTA\"|' /etc/init.d/untangle-vm

exit 0
