#!/bin/bash
#
# This is a crappy plugin to check the amount of CPU used
# on a unix system via the UCD-SNMP-MIB::ssCpuIdle.0 value.
# The goal is just to output a simple text value that can
# be easily graphed.
#
# Last modified by Jake Paulus 20080709

print_usage() {
        echo ""
        echo "This plugin checks %CPU used via the UCD-SNMP-MIB::ssCpuIdle.0"
        echo "value on Unix systems."
        echo ""
        echo "Usage: $0 <snmp community> <hostname> <warning> <critical>"
        echo ""
        exit 3
}

if [ $# -ne 4 ] ; then
        print_usage
fi


IdlePercent=`snmpwalk -v 1 -c $1 $2 .1.3.6.1.4.1.2021.11.11.0`
if [[ $? -ne 0 ]] ; then
	echo "Unknown: Check host+nagios config"
	exit 3
fi

IdlePercent=`echo $IdlePercent | awk '{ print $4 }'`
Active=`echo "100-$IdlePercent" | bc`

if [[ $Active -lt 0 ]] ; then
	echo "Unknown: Check host+nagios config"
	exit 3
elif [[ $Active -lt $3 ]] ; then
	echo "CPU_Time_Used:$Active%"
	exit 0
elif [[ $Active -lt $4 ]] ; then
	echo "CPU_Time_Used:$Active%"
	exit 1
else 
	echo "CPU_Time_Used:$Active%"
	exit 2
fi
