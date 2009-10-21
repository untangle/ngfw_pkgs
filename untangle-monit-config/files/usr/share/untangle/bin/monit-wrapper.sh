#! /bin/sh

CONFIG_PARTS_DIR=/etc/untangle/monit.d
CONFIG_FILE=/etc/untangle/monit.conf
RESTART_FILE=/etc/untangle/monit-to-restart
TEMPLATE_EXTENSION=".template"

echo 'INCLUDE "/etc/untangle/monit.d/*_all.conf"' >| $CONFIG_FILE
echo 'INCLUDE "/etc/untangle/monit.d/*_'$(dpkg-architecture -qDEB_BUILD_ARCH)'.conf"' >> $CONFIG_FILE
chmod 600 $CONFIG_FILE

is_monit_running()
{
   local t_pid_file="/var/run/monit.pid"
   local t_pid
   if [ ! -f "${t_pid_file}" ]; then
     return 1
   fi

   t_pid=`cat "${t_pid_file}"`

   if [ ! -f "/proc/${t_pid}/cmdline" ]; then
    return 2
   fi
 
   grep -q "^monit.-c.${CONFIG_FILE}.-v.\$" "/proc/${t_pid}/cmdline" || return 3

   echo "true"
   return 0
}

while true ; do

  for file in $CONFIG_PARTS_DIR/*$TEMPLATE_EXTENSION ; do
    perl -pe 's/`(.+)`/chop($foo = `$1`) ; $foo/e' $file >| ${file/$TEMPLATE_EXTENSION}
  done

  if ! is_monit_running ; then
    pkill '^monit$'

    sleep 2

    ## This is going to daemonize into another process, it doesn't need to background.
    monit -c $CONFIG_FILE -v
  
    sleep 2

    # monit remembers if it was in "unmonitor" mode the last time, so
    # force it back into "monitor" mode

    ## rbscott. Oct 09, 2009
    # This is forced back into monitor mode inside of the UVM wrapper
    # script.  In the off change the UVM script isn't running but it
    # is supposed to be, let them restart.
    ## monit -c $CONFIG_FILE monitor all
  fi

  sleep 30
  if [ -f $RESTART_FILE ] ; then
    rm -f $RESTART_FILE
    pkill '^monit$'
    exit 0
  fi
done
