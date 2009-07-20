#! /bin/sh

CONFIG_PARTS_DIR=/etc/untangle/monit.d
CONFIG_FILE=/etc/untangle/monit.conf
RESTART_FILE=/etc/untangle/monit-to-restart

monit -c $CONFIG_FILE &

while true ; do
  sleep 30
  if [ -f $RESTART_FILE ] ; then
    rm -f $RESTART_FILE
    pkill monit
    exit 0
  fi
done
