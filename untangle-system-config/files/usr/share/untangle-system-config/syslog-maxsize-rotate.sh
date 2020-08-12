#!/bin/bash
##
## Dynamic log rotation script used for maximum size limit detection by rsyslog 
##

LOG=$1
if [[ $LOG =~ ^.*\/(.*) ]]; then
    LOGFILENAME=oc_${BASH_REMATCH[1]}
else
    LOGFILENAME=temp
fi
TEMPCONFIG=/tmp/logrotate.$LOGFILENAME.tmp

##
## Generate a dynamic logrotate script
##
echo "
$LOG {
        weekly
        maxsize 4096
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 640 root adm
        sharedscripts
}" > $TEMPCONFIG

logrotate $TEMPCONFIG
# rm $TEMPCONFIG
