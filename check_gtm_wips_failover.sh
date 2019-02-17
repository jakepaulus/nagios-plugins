#!/bin/bash
#
# This script compares the GTM Wide IP name's DNS result to 
# the lowest ordered IP address in the pool assigned to that 
# WIP. This script is only useful if you only use GTM for
# failover and not for load balancing.
#
# Last modified 20090306 by Jake Paulus
#
#-------------------------------------------------------------
# Config
#-------------------------------------------------------------

# You could also query the bigip directly but this will not
# reveal some problems like missing delegation, etc.
# I suppose you don't have a choice if you're using this
# on internal as well as external names
#
#208.67.222.222 is OpenDNS - i trust it
#checkdns="/usr/local/nagios/libexec/check_dns -s 208.67.222.222"

# Use this to check the BigIP directly instead of a third party resolver
checkdns="/usr/local/nagios/libexec/check_dns -s $2"

#-------------------------------------------------------------
# You shouldn't need to edit below this line
#-------------------------------------------------------------

if [[ $# -lt '2' ]] ; then
	echo "Usage: $0 <snmp community> <bigip hostname>"
	exit 3
fi
#------------------------------------------

community=$1
bigip=$2


export MIBS=ALL

# Find lowest order Member IP address in each GTM Pool
index=0
for i in `snmpbulkwalk -v 2c -c $community $bigip F5-BIGIP-GLOBAL-MIB::gtmPoolMbrOrder | sed s/F5-BIGIP-GLOBAL-MIB::gtmPoolMbrOrder.\"// | sed s/\".ipv4.\"/=/ | sed s/\".*INTEGER:./=/ | egrep -v ".*=1$"` ; do
    pool=`echo $i | awk -F = '{print $1}'`
    pools[$index]=$i
    ((index++))
done

# walk through each wide-ip and check it
index=0
errors=0
for i in `snmpbulkwalk -v 2c -c $community $bigip F5-BIGIP-GLOBAL-MIB::gtmWideipPoolPoolName | sed s/F5-BIGIP-GLOBAL-MIB::gtmWideipPoolPoolName.\"// | sed s/\".*STRING:./=/`; do
    wip=`echo $i | awk -F = '{print $1}'`
    pool=`echo $i | awk -F = '{print $2}'`


# the pool name might be the first in the list
    poolmemberip=`echo "${pools[@]}" | sed "s/.*\b$pool=\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)=.*/\1/"`

    testing=`$checkdns -H $wip -a $poolmemberip`
    if [[ $? -ne 0 ]] ; then
        multilineoutput[$errors]="$wip - $testing"
        ((errors++))
    fi

    ((index++))
done

if [[ $errors -gt 0 ]] ; then
    echo "Critical - $errors GTM Wide IPs have failed over - $index checked"
    for (( i=0; i<${#multilineoutput[@]}; i++)); do
      echo ${multilineoutput[$i]}
    done
    
    exit 2
else
    echo "$index Wide IPs are OK"
    exit 0
fi
