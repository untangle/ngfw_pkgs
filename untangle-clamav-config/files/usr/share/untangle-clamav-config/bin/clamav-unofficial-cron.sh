
#!/bin/sh

# Only run if clamd running
if [ ! -f /var/run/clamav/clamd.pid ] ; then
    exit 0
fi

/usr/share/untangle-clamav-config/bin/clamav-unofficial-cron.sh -c /etc/clamav/clamav-unofficial-sigs.conf >/var/log/clamav-unofficial-sigs.log 2>&1
