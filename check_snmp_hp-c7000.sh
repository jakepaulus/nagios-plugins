#!/bin/bash
#
# Last modified 20110603 by Jake Paulus
#
community=$1
host=$2

checkcommand="snmpget -v 2c -c $community $host"
message="Please see https://$host for more information"

# Check common status and report UNKNOWN if no response

#cpqRackMibCondition
globalstatus=`$checkcommand -t 2 1.3.6.1.4.1.232.22.1.3.0 2>&1`
if [[ $? -ne 0 ]]; then
	echo "Unknown: $globalstatus"
	exit 3
fi

globalstatus=`echo $globalstatus | awk '{print $NF}'`

if [[ $globalstatus -eq 2 ]]; then
	echo "OK"
	exit 0	
else
	#cpqRackCommonEnclosureCondition
	enclosurestatus=`$checkcommand 1.3.6.1.4.1.232.22.2.3.1.1.1.16.0 | awk '{print $NF}'`
	if [[ $enclosurestatus -eq 3 ]]; then
		echo "Warning: Problem detected with a fan, fuse, or temperature reading $message"
		exit 1	
	elif [[ $enclosurestatus -eq 4 ]]; then
		echo "Critical: Severe problem detected with fan, fuse, or temperature reading $message"
		exit 2
	fi

	#cpqRackPowerSupplyCondition
	powersupplystatus=`$checkcommand 1.3.6.1.4.1.232.22.2.5.1.1.1.17.0 | awk '{print $NF}'`
	if [[ $powersupplystatus -eq 3 ]]; then
		echo "Warning: Problem detected with power supply $message"
		exit 1
	elif [[ $powersupplystatus -eq 4 ]]; then
		echo "Critical: Severe problem detected with power supply $message"
		exit 2	
	fi
	
	#cpqRackCommonEnclosureManagerCondition
	onboardadministratorstatus=`$checkcommand 1.3.6.1.4.1.232.22.2.3.1.6.1.12.0 | awk '{print $NF}'`
	if [[ $onboardadministratorstatus -eq 3 ]]; then
		echo "Warning: Problem detected on redundant Onboard Administrator $message"
		echo 1
	elif [[ $onboardadministratorstatus -eq 4 ]]; then
		echo "Critical: Severe problem detected on Onboard Administrator $message"
		echo 2
	fi
fi
