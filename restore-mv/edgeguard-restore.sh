#!/bin/sh

echo " == Restore Edgeguard =="

reboot() {
    /sbin/shutdown -r now
}

trap reboot 6
trap reboot 15
trap reboot 2

if [ -x /etc/init.d/mvvm ] ; then
    /etc/init.d/mvvm stop
fi

while true ; do

    echo ""
    echo " Options: "
    echo " 1) Return to Factory Defaults "
    echo " 2) Restore saved configuration "
    echo " 3) Recover broken upgrade procedure (method 1) "
    echo " 4) Recover broken upgrade procedure (method 2) "
    echo " 5) Recover broken upgrade procedure (method 3) "
    echo " 6) Enable remote debugging (for technical support)"
    echo " 7) Disable remote debugging (for technical support)"
    echo " 8) Reboot "
    echo ""

    read -p " Please select an option: " CHOICE
    echo $CHOICE

    case "$CHOICE" in
        1)
            echo "Restoring Factory Defaults..."
            if [ -x /usr/bin/purgeprefs ] ; then
                /usr/bin/purgeprefs
            fi
            ;;
        2)
	    echo "Restoring previous configuration..."
            if [ -x /usr/bin/mvvmdb ] ; then
                /usr/bin/mvvmdb
            fi
            ;;
        3)
            echo "Attempting to Upgrade..."
            apt-get -o DPkg::Options::=--force-confnew --yes --force-yes --fix-broken upgrade
            ;;
        4)
            echo "Attempting to Upgrade..."
            dpkg --configure -a
            ;;
        6)
            echo "Enabling remote debugging..."
            /etc/init.d/ssh start
            update-rc.d ssh defaults > /dev/null
            ;;
        7)
            echo "Disabling remote debugging..."
            /etc/init.d/ssh stop
            mv /etc/init.d/ssh /etc/init.d/ssh.tmp
            update-rc.d ssh remove > /dev/null
            mv /etc/init.d/ssh.tmp /etc/init.d/ssh
            ;;
        8)
            reboot
            ;;
# We used to support uninstall here:
#	999)
#            echo "Uninstalling..."
#            apt-get remove --purge mvvm 
    esac

done

