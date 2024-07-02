#!/bin/dash
SCRIPT_NAME=$(basename $0)
SCRIPT_NAME_NO_EXTENSION=${SCRIPT_NAME%.*}

# This script sets the link media for a given NIC

if [ $# != 3 ]; then
    echo "USAGE: $0 <nic> <mode>"
    echo "\t mode: auto|10-full-duplex|10-half-duplex|100-full-duplex|100-half-duplex|1000-full-duplex"
    exit 0
fi

## ethtool fails a lot, this just hides those errors.
run_ethtool()
{
    ethtool $* 2> /dev/null
}

ETHTOOL=ethtool
ETHTOOL=run_ethtool

is_media_unset()
{
    local t_nic=$1
    local t_speed=$2
    local t_duplex=$3

    ## Check if auto-negotiation is on and the speed and duplex setting match
    ${ETHTOOL} ${t_nic} | awk -v IGNORECASE=1 "/auto-negotiation: off/ { matches++ }; /speed: ${t_speed}m/ { matches++ } ; /duplex: ${t_duplex}/ { matches++ } ;  END { if ( matches == 3 ) exit 1 }"
}

# Some drivers do not handle EEE toggle properly and will cause a kernel panic.
# If the following file exists and contains the string to ignore from lspci, don't perform eee operations on the matching nic.
# For example:
# $ lspci
# ...
# 01:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller (rev 07)
# 02:00.0 Network controller: Intel Corporation Wireless 3160 (rev 83)
# 03:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller (rev 07
#
# Specifying the string "Realtek" would match those nics but not the Intel wireless nic. 
IS_IGNORE_EEE_VENDOR_FILENAME=/usr/share/untangle/conf/flags/${SCRIPT_NAME_NO_EXTENSION}--is_ignore_eee_vendor
is_ignore_eee_vendor()
{
    local t_nic=$1

    if [ -f $IS_IGNORE_EEE_VENDOR_FILENAME ] ; then
        # Vendor substring
        vendor_match=$(cat $IS_IGNORE_EEE_VENDOR_FILENAME)
        # nic's physical identifer in lspci (e.g.,01:00.0)
        physical_device_target=$(readlink /sys/class/net/${t_nic}/device)
        physical_device=${physical_device_target#*:}
	    lspci_match=$(lspci | grep "^${physical_device}")
        if [ -z "${lspci_match##*"$vendor_match"*}" ]; then
            # Substring match on vendor for this physical device
            return 0
        fi
    fi
    return 1

}

set_ethernet_media()
{
    local t_nic=$1
    local t_media=$2
    local t_eee=$3
    local t_speed
    local t_duplex

    if [ -z "${t_nic}" ]; then
        echo "$0 didn't specify nic."
        return 0
    fi

    if [ "${t_eee}" = "True" ] ; then
        t_eee=on
    else
        t_eee=off
    fi
    #echo "setting eee to ${t_eee}"
    is_ignore_eee_vendor ${t_nic}
    if [ $? -ne 0 ] ; then
        # Process
        ethtool --show-eee ${t_nic} && ethtool --set-eee ${t_nic} eee ${t_eee}
    fi

    case "${t_media}" in
        "10-full-duplex")
            t_speed="10"
            t_duplex="full"
            ;;

        "10-half-duplex")
            t_speed="10"
            t_duplex="half"
            ;;

        "100-full-duplex")
            t_speed="100"
            t_duplex="full"
            ;;

        "100-half-duplex")
            t_speed="100"
            t_duplex="half"
            ;;

        "1000-full-duplex")
            t_speed="1000"
            t_duplex="full"
            ;;

        "1000-half-duplex")
            t_speed="1000"
            t_duplex="half"
            ;;

        "10000-full-duplex")
            t_speed="10000"
            t_duplex="full"
            ;;

        "10000-half-duplex")
            t_speed="10000"
            t_duplex="half"
            ;;

        "auto")
            ${ETHTOOL} ${t_nic} | grep -qi 'auto-negotiation: on'
            if [ ! $? -eq 0 ] ; then
                echo "Setting ${t_nic} to auto-negotiation."
                ${ETHTOOL} -s ${t_nic} autoneg on
            fi
            return 0
            ;;
        "*")
            echo "Unable to determine link speed from '${t_media}'"
            return 0
            ;;
    esac

    ## Not auto, have to set the speed manually (first check if it is already set)
    is_media_unset ${t_nic} ${t_speed} ${t_duplex} 
    if [ $? -eq 0 ] ; then
        echo "Setting ${t_nic} to ${t_speed} ${t_duplex}."
        ${ETHTOOL} -s ${t_nic} autoneg off speed ${t_speed} duplex ${t_duplex}
    fi
}

set_ethernet_media $*
