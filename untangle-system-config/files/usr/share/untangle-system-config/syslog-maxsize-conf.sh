#!/bin/bash
##
## Parse and modify specified rsyslog configuration file to generate 
## outchannel configuration to handle maximum size limits.
##
## If passed with "revert" keyword, configuration is reversed
## from outchannel and back to files.
##
## If "# noalter" is found, the next line is left alone.
##
## Re-running on a converted configuration will re-write outchannel 
## configuration which is useful for changing the MAX_SIZE value.

##
## Maximum size is 500MB
##
MAX_SIZE=524288000

ROTATE_SCRIPT=/usr/share/untangle-system-config/syslog-maxsize-rotate.sh

revert=0
replace_conf=1

##
## Generate identifier from target path as
## "oc_" + $filename
## e.g., /var/log/syslog becomes "oc_syslog"
##
id=
target=
function get_id_from_target(){
    id=$target
        
    if [[ "$id" =~ ^.*\/(.*) ]]; then
        id=oc_${BASH_REMATCH[1]}
    fi
}

##
## Parse the specified file
##
revert_mode=0
function process_rsyslog_conf(){
    local conf=$1
    local outconf=$1.tmp
    
    if [ -f $outconf ] ; then
        rm -f $outconf
    fi
    
    noalter=0
    IFS=
    while read line
    do

        if [[ "$line" =~ ^[[:space:]]*\#[[:space:]]*noalter  ]] ; then
            ##
            ## Don't alter the following line
            ##
            noalter=1
            echo $line >> $outconf
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*\# ]]; then
            ##
            ## Ignore comments
            ##
            echo $line >> $outconf
            continue
        fi
        
        if [[ "$line" =~ ^[[:space:]]+$ ]]; then
            ##
            ## Ignore empty lines
            ##
            echo $line >> $outconf
            continue
        fi

        if [[ ! "$line" =~ ^(.+)[[:space:]]+(.+)$ ]]; then
            ##
            ## Look for a candidate configuration
            ## 
            echo $line >> $outconf
            continue
        fi
        
        if [ $noalter -eq 1 ] ; then
            ##
            ## Don't alter this configuration
            ##
            noalter=0
            echo $line >> $outconf
            continue
        fi

        selector=${BASH_REMATCH[1]}
        target=${BASH_REMATCH[2]}

        ##  See if references our script and if so, allow to override if
        ##  script matches
        if [[ $selector =~ ^\$outchannel ]]; then
            if [[ "$line" =~ ^(.+)[[:space:]]+(.+),(.+),(.+),(.+)[[:space:]]+(.+) ]]; then
                target_id=${BASH_REMATCH[2]}
                target_file=${BASH_REMATCH[3]}
                target_rotate_script=${BASH_REMATCH[5]}
                if [ "$target_rotate_script" = "$ROTATE_SCRIPT" ] ; then
                    if [ $revert -eq 1 ] ; then
                        revert_mode=1
                        line=
                    else
                        get_id_from_target
                        line="\$outchannel $id,$target,$MAX_SIZE,$ROTATE_SCRIPT $target"
                    fi
                fi
            fi
            if [ "$line" != "" ] ; then
                echo $line >> $outconf
            fi
            continue
        fi
        
        if [[ $selector =~ ^\$ ]]; then
            ##
            ## Either an rsyslog directive or possibly another $outchannel
            ## definition that we don't recognize.  Regardless, ignore.
            ## 
            echo $line >> $outconf
            continue
        fi
        ## Reading removes line continuations and changes ";\" to ";   "
        ## which causes a parse error.  Remove the spaces.
        selector=${selector//;[[:space:]]/;}

        if [[ $revert_mode -eq 1 && \
            $target =~ ^\:omfile\:\$$target_id ]]; then
            ##
            ## Non file destination
            ##
            echo "$selector $target_file" >> $outconf
            continue
        fi

        if [[ $target =~ ^\||\:|\&|stop|\~|\? ]]; then
            ##
            ## Non file destination
            ##
            echo "$selector $target" >> $outconf
            continue
        fi

        if [[ $target =~ ^\-(.*) ]]; then
            ##
            ## Strip leading "-"
            ## 
            target=${BASH_REMATCH[1]}
        fi
        
        get_id_from_target
    
        echo "\$outchannel $id,$target,$MAX_SIZE,$ROTATE_SCRIPT $target" >> $outconf
        echo "$selector :omfile:\$$id" >> $outconf

    done < $conf

    if [ $replace_conf -eq 1 ] ; then
        /usr/sbin/rsyslogd -N1 -f $outconf 2> /tmp/$id-output.txt
        if [ $? -eq 0 ] ; then
            rm -f $conf /tmp/$id-output.txt
            mv $outconf $conf
        else
            echo "rsyslogd does not like configuration for $outconf.  Moving to /tmp"
            mv $outconf /tmp
        fi
    fi
}


##
## Walk arguments as files to process
##
for conf in "$@"; do
    if [ ${conf: -5} != ".conf" ]; then
        continue
    fi

    if [ "$conf" = "revert" ] ; then
        ##
        ## Set conversion mode to revert to non-channel configuration
        ##
        revert=1
        continue
    fi
    
    if [ "$conf" = "dont_replace_conf" ] ; then
        ##
        ## Set conversion mode to revert to non-channel configuration
        ##
        replace_conf=0
        continue
    fi

    if [[ "$conf" == *snort* ]] ; then
      # FIXME: NGFW-11918
      echo "Skipping $conf"
    else
      echo "Processing $conf"
      process_rsyslog_conf $conf 
    fi
done

