#! /bin/sh

CONFIG_PARTS_DIR=/etc/untangle/monit.d
CONFIG_FILE=/etc/untangle/monit.conf
RESTART_FILE=/etc/untangle/monit-to-restart

pid=foo

while true ; do
  if ! ps -p $1 > /dev/null ; then
    monit -c $CONFIG_FILE &
    pid=$!
  fi

  sleep 30
  if [ -f $RESTART_FILE ] ; then
    rm -f $RESTART_FILE
    pkill monit
    exit 0
  fi
done
