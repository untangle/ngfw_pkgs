#!/bin/bash
if [ ${#UVM_ROOT} != 0 ] ; then
    NUCLI_ROOT=${UVM_ROOT}/../../pkgs/untangle-cli-client/files
else
    NUCLI_ROOT=""
fi
/usr/bin/ruby -X ${NUCLI_ROOT}/usr/share/untangle-cli-client/src -- ./client.rb -h localhost -c $1%20snmp%20$2%20$3
