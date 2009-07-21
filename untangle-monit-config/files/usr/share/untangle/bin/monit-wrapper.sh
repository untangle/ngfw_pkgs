#! /bin/sh

CONFIG_PARTS_DIR=/etc/untangle/monit.d
CONFIG_FILE=/etc/untangle/monit.conf
RESTART_FILE=/etc/untangle/monit-to-restart
TEMPLATE_EXTENSION=".template"
pid=foo

while true ; do

  for file in $CONFIG_PARTS_DIR/*$TEMPLATE_EXTENSION ; do
    perl -pe 's/`(.+)`/chop($foo = `$1`) ; $foo/e' $file >| ${file/$TEMPLATE_EXTENSION}
  done

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
