#!/bin/sh
/usr/bin/ruby -X /home/ken/work/pkgs/untangle-cli-client/files/ -- ./client.rb -t -h localhost -p 7777 -e $1%20snmp%20$2%20$3
