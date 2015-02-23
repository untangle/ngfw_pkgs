#!/bin/bash

# detect specific model of u500
# the original u500
# the new u500 (the u500b) uses has 8 cpus/cores
cpu_count=`grep "model name" /proc/cpuinfo | wc -l`
cpu_model=`grep -m1 "model name" /proc/cpuinfo | cut -f2 -d: | cut -c2-`
if [[ $cpu_count -eq 4 ]]; then
    model='u500'
fi
if [[ $cpu_count -eq 8 ]]; then
    model='u500b'
fi

# only the u500b needs NICs remapped
if [ $model != "u500b" ]; then
   exit 0
fi

case $model in
    u500b)
        declare -a from=(eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7)
        declare -a   to=(eth4 eth5 eth6 eth7 eth0 eth1 eth2 eth3)
        ;;
esac

# and for each element, map to a temporary interface named new_ethx
udev_file='/etc/udev/rules.d/70-persistent-net.rules';
for (( i = 0 ; i < ${#from[@]} ; i++ )); do
    perl -i -pe "s/NAME\=\"${from[$i]}\"/NAME\=\"new_${to[$i]}\"/g" $udev_file
done
# then remove all the "new_".  We do the intermeidate step to avoid renaming collisions
perl -i -pe "s/new_//g" $udev_file 

echo "Remapped ports for $model appliance, changes take effect after reboot..."
