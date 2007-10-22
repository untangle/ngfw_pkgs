#!/bin/sh
/usr/bin/ruby -X /home/ken/work/pkgs/untangle-cli-client/files/ -- ./client.rb -t -h localhost -p 7777 -e webfilter%20snmp%20$1%20$2
