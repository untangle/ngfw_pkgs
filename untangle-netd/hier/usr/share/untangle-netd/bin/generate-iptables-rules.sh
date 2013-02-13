#!/bin/dash

#
# This script handles all the iptables rules
# It runs all the scripts in /etc/untangle-netd/iptables.rules.d
# It logs both to stdout and the logfile

LOGFILE="/var/log/uvm/iptables.log"

IPTABLES_DIRECTORY=/etc/untangle-netd/iptables-rules.d

#IPTABLES=/sbin/iptables
#IPTABLES="iptables_debug"
IPTABLES=iptables_debug_onerror

#EBTABLES=/sbin/ebtables
#EBTABLES=ebtables_debug
EBTABLES=ebtables_debug_onerror

LOCK_FILE=/tmp/generate-iptables-rules.lock

# switch stdout/stderr to tee for stdout and logfile
mkfifo ${LOGFILE}.pipe
tee < ${LOGFILE}.pipe $LOGFILE &
exec >> ${LOGFILE}.pipe 2>&1
rm ${LOGFILE}.pipe

iptables_debug()
{
   echo "[`date`] /sbin/iptables $@"
   /sbin/iptables "$@"
}

iptables_debug_onerror()
{
    # Ignore -N errors
    /sbin/iptables "$@" || {
        [ "${3}x" != "-Nx" ] && echo "[`date`] Failed: /sbin/iptables $@"
    }

    true
}

ebtables_debug()
{
    echo "[`date`] /sbin/ebtables $@"
    /sbin/ebtables "$@"
}

ebtables_debug_onerror()
{
    # Ignore -N errors
    /sbin/ebtables "$@" || {
        echo "[`date`] Failed: /sbin/ebtables $@"
    }

    true
}

get_ip_addresses()
{
    local t_intf=$1

    if [ -z "${t_intf}" ]; then return; fi

    ip -f inet addr show ${t_intf} 2>/dev/null | \
        awk '/inet/ { ip = $2 ; sub( /\/.*$/, "", ip ) ; print ip  }'
}

run_iptables_scripts()
{
    local t_script
    local t_ran_script=""

    if [ ! -d ${IPTABLES_DIRECTORY} ]; then
        echo "[`date`] ${IPTABLES_DIRECTORY} does not exist."
        return 0
    fi
    
    # Would use run-parts, but that doesn't maintain environment variables 
    # or the iptables_debug function.

    # Do not run any of the dpkg backup files.
    for t_script in `run-parts --list --lsbsysinit ${IPTABLES_DIRECTORY} | sort` ; do
        echo "[`date`] ${t_script} Running ..."
        START="`date +%s%N`"
        . ${t_script}
        RET=$?
        END="`date +%s%N`"
        TIME=$(( ($END-$START)/1000000 ))
        echo "[`date`] ${t_script} Complete: $RET (took $TIME msec)"
        t_ran_script="true"
    done
    
    if [ "${t_ran_script}x" != "truex" ]; then
        echo "[`date`] ${IPTABLES_DIRECTORY} is empty."
    fi
}

while true ; do
    if ( set -o noclobber; echo "$$" > "$LOCK_FILE" ) 2> /dev/null; then
      	trap 'rm -f "$LOCK_FILE"; exit $?' INT TERM EXIT
        
        # critical section
        echo "[`date`] Running ${IPTABLES_DIRECTORY} scripts [REASON: $1]" 
        run_iptables_scripts
        echo "[`date`] Running ${IPTABLES_DIRECTORY} scripts done." 
        
        rm -f "$LOCK_FILE"
        trap - INT TERM EXIT
        break
    else
        sleep .2
        
            # timeout
        t_count=$(($t_count+1))
        if [ $t_count -gt 1000 ] ; then 
            echo "[`date`] ERROR: Failed to acquire lock file after 1000 tries."
            echo "[`date`] ERROR: Removing \"stale\" lockfile..."
            rm -f "$LOCK_FILE" 
            continue;
        fi
    fi 
done


