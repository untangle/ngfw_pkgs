#!/bin/bash

declare -A NAME_MACS=()
declare -A ALIAS_MACS=()
declare -A ALTNAME_MACS=()
declare -A NAME_STATES=()

NAME=
# Debug mode for messages and other output
DEBUG=false
WATCH=false

##
## Process command line arguments
##
while getopts "d:n:w:" flag; do
    case "${flag}" in
        d) DEBUG=${OPTARG} ;;
        n) NAME=${OPTARG} ;;
        w) WATCH=${OPTARG} ;;
    esac
done
shift $((OPTIND-1))

# The most recent version of the ip utilities includes the predictive name
# for a nic with the ip link command, such as:
#
# 4: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
#     link/ether 00:15:5d:19:bf:af brd ff:ff:ff:ff:ff:ff
#     alias blah
#     altname blah2
#     altname blah3
#
# It is much more preferable to access the netlink API directory for this
# (such as via Python and pyroute2), but the version we currently have
# installed in NGFW does not support querying for the altname.
#
# So we'll build these mappings by scraping the output of the ip link command.

# build_name_macs
#
# Build mapping of names to mac addresses.
# This creates mappings for alias and altnames too, so
# it is likely for several names to point to the same address.
#
function build_name_macs
{
	while read -r line; do
		# echo "[$line]"
       if [[ "$line" =~ ^([0-9]+): ]]; then
			# primary name, state
			# 4: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000]
			name=
			mac_address=
			state=
            name=$(echo "$line" | awk '{OFS=" "; print $2}' | cut -d: -f1)
            state=$(echo "$line" | awk '{OFS=" "; for (i=1;i<=NF;i++){if ($i ~ /state/) {print $(i+1)}}}')
			NAME_STATES[$name]=$state
            # printf "%15s %5s\n" $name $state
        elif [[ "$line" =~ ^link/ether ]]; then
			# mac address
			#     link/ether 00:15:5d:19:bf:af brd ff:ff:ff:ff:ff:ff
			mac_address=$(echo "$line" | awk '{OFS=" "; print $2}')
			# echo "$mac_address"
			NAME_MACS[$name]=$mac_address
        elif [[ "$line" =~ alias ]]; then
			# alias
			#     alias blah
			alias=$(echo "$line" | awk '{OFS=" "; print $2}')
			# echo "$alias"
			ALIAS_MACS[$alias]=$mac_address
        elif [[ "$line" =~ altname ]]; then
			# altname (kernel predictive name)
			#     altname blah
			altname=$(echo "$line" | awk '{OFS=" "; print $2}')
			# echo "$altname"
			ALTNAME_MACS[$altname]=$mac_address
		fi
	done < <(ip link)

}


if [ "$NAME" != "" ] ; then
	# Return mac address for name
	build_name_macs
	if [ "${NAME_MACS[$NAME]}" != "" ] ; then
		echo "${NAME_MACS[$NAME]}"
	elif [ "${ALIAS_MACS[$NAME]}" != "" ] ; then
		echo "${ALIAS_MACS[$NAME]}"
	elif [ "${ALTNAME_MACS[$NAME]}" != "" ] ; then
		echo "${ALTNAME_MACS[$NAME]}"
	else
		echo "unknown"
	fi
elif [ "$WATCH" != "" ]; then
	# Loop on status of nics, showing altname
	while true; do
		clear
		for name in "${!NAME_STATES[@]}"; do
			status="${NAME_STATES[$name]}"
			if [ "$status" != "UP" ] && [ "$status" != "DOWN" ] ; then
				# Don't care about interface is status is not up or down
				continue
			fi
        	if [[ "$name" =~ @ ]]; then
				# Don't care about virtual interfaces tied to others
				continue
			fi
			printf "%15s %-5s" $name $status
			mac_address=${NAME_MACS[$name]}
			for altname in "${!ALTNAME_MACS[@]}"; do
				if [ "${ALTNAME_MACS[$altname]}" = "$mac_address" ] ; then
					printf "%20s" $altname
				fi
			done
			printf "\n"
		done
		sleep .50
		build_name_macs
	done
fi
