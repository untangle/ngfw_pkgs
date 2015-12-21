#!/bin/bash

# detect specific model of m3000
# the original m3000
# the new m3000 (the m3000b) uses E5-2620 CPUs
cpu_count=`grep "model name" /proc/cpuinfo | wc -l`
cpu_model=`grep -m1 "model name" /proc/cpuinfo | cut -f2 -d: | cut -c2-`

declare -a from=(eth0 eth1 eth3 eth4 eth6 eth7 eth8 eth9 eth2 eth5)
declare -a   to=(eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9)

# and for each element, map to a temporary interface named new_ethx
udev_file='/etc/udev/rules.d/70-persistent-net.rules';
for (( i = 0 ; i < ${#from[@]} ; i++ )); do
    perl -i -pe "s/NAME\=\"${from[$i]}\"/NAME\=\"new_${to[$i]}\"/g" $udev_file
done
# then remove all the "new_".  We do the intermeidate step to avoid renaming collisions
perl -i -pe "s/new_//g" $udev_file 

echo "Remapped ports for $model appliance, changes take effect after reboot..."

