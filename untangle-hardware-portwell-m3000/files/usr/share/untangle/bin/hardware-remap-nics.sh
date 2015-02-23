#!/bin/bash

# detect specific model of m3000
# the original m3000
# the new m3000 (the m3000b) uses E5-2620 CPUs
cpu_count=`grep "model name" /proc/cpuinfo | wc -l`
cpu_model=`grep -m1 "model name" /proc/cpuinfo | cut -f2 -d: | cut -c2-`
if [[ $cpu_count -eq 12 ]]; then
    is_m3000b=`echo $cpu_model | grep 'E5-2620' | wc -l`
    if [ $is_m3000b -gt 0 ]; then
        model='m3000b'
    else
        model='m3000'
    fi
fi

case $model in
    m3000)
        declare -a from=(eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9 eth0 eth1)
        declare -a   to=(eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9)
        ;;
    m3000b)
        declare -a from=(eth6 eth7 eth8 eth9 eth2 eth3 eth4 eth5 eth0 eth1)
        declare -a   to=(eth0 eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9)
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

