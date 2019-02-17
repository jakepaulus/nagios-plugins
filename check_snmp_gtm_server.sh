#!/bin/bash
#
# This script is used to check GTM Server status - mainly 
# to see if one BigIP running GTM thinks other BigIPs are OK.

snmpstring=$1
bigip=$2
remotebigip=$3

export MIBS=ALL

result=`snmpwalk -v 2c -c $snmpstring $bigip F5-BIGIP-GLOBAL-MIB::gtmServerStatusAvailState 2>&1`

if [[ $? -ne 0 ]]; then
	echo "UNKNOWN - $result"
	exit 3 
fi

result=`echo $result | grep $remotebigip | sed 's/^.*INTEGER: //' | sed 's/(.)//'`

if [[ $result == 'green' ]]; then
	echo "OK - bigip health check of $remotebigip passed"
	exit 0
else
	echo "CRITICAL - bigip health check of $remotebigip failed"
	exit 2
fi
