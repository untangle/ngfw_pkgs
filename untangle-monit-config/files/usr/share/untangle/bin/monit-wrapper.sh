#! /bin/sh

CONFIG_PARTS_DIR=/etc/untangle/monit.d
CONFIG_FILE=/etc/untangle/monit.conf
RESTART_FILE=/etc/untangle/monit-to-restart
TEMPLATE_EXTENSION=".template"
pid=foo

echo 'INCLUDE "/etc/untangle/monit.d/*_all.conf"' >| $CONFIG_FILE
echo 'INCLUDE "/etc/untangle/monit.d/*_'$(dpkg-architecture -qDEB_BUILD_ARCH)'.conf"' >> $CONFIG_FILE
chmod 600 $CONFIG_FILE

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
