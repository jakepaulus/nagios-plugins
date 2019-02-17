#!/bin/bash
# This script aims to check the status of dell hardware with the Dell Open Manage
# agents installed and provide somewhat detailed information to assist in
# troubleshooting.
#
# This work is in the Public Domain
# http://creativecommons.org/licenses/publicdomain/
#
# Last Modified by Jake Paulus 20080712


print_usage() {
        echo ""
        echo "This plugin checks a current hardware state of servers with Dell Open Manage Agents"
        echo "installed using snmp version 2c."
        echo ""
        echo "Usage: $0 <snmp community> <hostname>"
        echo ""
        exit 3
}

if [ $# -ne 2 ] ; then
        print_usage
fi


MoreInfo="-- https://$2:1311"

GlobalSystemStatus=`snmpget -v 2c -c $1 $2 1.3.6.1.4.1.674.10892.1.200.10.1.2.1`

SNMPStatus=`echo $GlobalSystemStatus | grep "INTEGER"`

if [[ $? -ne 0 ]] ; then # Management Agent or SNMP problem
        echo "Unknown: Check SNMP+Agents"
        exit 3
fi

# Dell Global System Status
GlobalSystemStatus=`echo $GlobalSystemStatus | grep "INTEGER: 3"`
if [[ $? -ne 0 ]] ; then # System Health is not good

FailureDetected=1

# This is really annoying because the storage controller battery affects the
# global system status even though all values under the system health tree are
# in a good state. 

	# Check battery but avoid warning about annoying recharge cycle - here we're
	# assuming Reconditioning, Charging, and Learning are OK statuses to have 
        BatteryStatus=`snmpwalk -v 2c -c $1 $2 1.3.6.1.4.1.674.10893.1.20.130.15.1.4`
	BatteryTest=`echo $BatteryStatus | egrep "INTEGER: 7"\|"INTEGER: 12"\|"INTEGER: 36"`
	if [[ $? -eq 0 ]] ; then # Battery going through learning cycle
				 # This is slightly risky - but false alerts are riskier if your
				 # admins ignore them
		echo "OK: Storage controller battery in learning cycle"
		exit 0
	fi

        # Check Power Supplies
        PowerSupplyStatus=`snmpget -v 2c -c $1 $2 1.3.6.1.4.1.674.10892.1.200.10.1.9.1 | grep "INTEGER: 3"`
        if [[ $? -ne 0 ]] ; then # Power Supply Problem
                echo "Critical: Power Supply Problem Detected $MoreInfo"
                exit 2
        fi

        # Check Fans
        FanStatus=`snmpget -v 2c -c $1 $2 1.3.6.1.4.1.674.10892.1.200.10.1.21.1 | grep "INTEGER: 3"`
        if [[ $? -ne 0 ]] ; then # Fan Problem
                echo "Critical: System Fan Problem Detected $MoreInfo"
                exit 2
        fi

        # Check Memory
        MemoryStatus=`snmpget -v 2c -c $1 $2 1.3.6.1.4.1.674.10892.1.200.10.1.27.1 | grep "INTEGER: 3"`
        if [[ $? -ne 0 ]] ; then # Memory Problem
                echo "Critical: Memory Problem Detected $MoreInfo"
                exit 2
        fi

fi

# Dell Global Storage Status
GlobalStorageStatus=`snmpget -v 2c -c $1 $2 1.3.6.1.4.1.674.10893.1.20.2.1 | grep "INTEGER: 3"`
if [[ $? -ne 0 ]] ; then # Storage Health is not good
FailureDetected=1

	BatteryTest=`echo $BatteryStatus | egrep "INTEGER: 1$"`
	if [[ $? -ne 0 ]] ; then # Bad Battery
		BatteryState=`echo $BatteryStatus | awk '{print $4}'`
		if [[ $BatteryState -eq 2 ]] ; then
			echo "Critical: Storage Controller Battery Failed $MoreInfo"
			exit 2
		elif [[ $BatteryState -eq 0 ]] ; then
			echo "Warning: Storage Controller Battery Status Unknown $MoreInfo"
			exit 3
		elif [[ $BatteryState -eq 6 ]] ; then
			echo "Warning: Storage Controller Battery Degraded $MoreInfo"
			exit 1
		elif [[ $BatteryState -eq 10 ]] ; then
			echo "Warning: Storage Controller Battery Low $MoreInfo"
			exit 1
		fi
	fi

        # Check Disks
        DiskStatus=`snmpwalk -v 2c -c $1 $2 1.3.6.1.4.1.674.10893.1.20.130.4.1.4 | grep -v "INTEGER: 3"`
        if [[ $? -eq 0 ]] ; then # Bad disk
                echo "Critical: Disk Failure Detected $MoreInfo"
                exit 2
        fi
fi

if [[ $FailureDetected -eq 1 ]] ; then

        # Some undetected problem exists
        echo "Critical: Undetermined Health Problem $MoreInfo"
        exit 2

fi


# If we made it here, everything is okay!
echo "OK"
exit 0
