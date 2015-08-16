#!/bin/bash
#
# This script requires the HP System Management Agents as well as the System Management Homepage application to be installed on each server.
# Due to the reliance on the Integrated Management Log, you must also have an SNMP READ+WRITE community setup on the server (BUT NOT USED 
# FOR THIS SCRIPT) so that the System Management Homepage application can be used to clear errors or mark them as repaired to return cpqHeMibCondition.0 to 
# an OK status.
#
# If you're really cool and your server is running linux, do the following in /etc/snmp/snmpd.conf to make things easy
#
# rocommunity <my read-only community>
# rwcommunity <my super-secret read+write community> 127.0.0.1
# 
# see the documentation for HP's System Management Homepage for more information on that application
# see 
#
# last modified by Jake Paulus on 20110505


print_usage() {
        echo ""
        echo "This plugin checks a current hardware state of servers with HP Insight System Management Agents"
		echo "installed using snmp version 2c."
		echo ""
        echo "Usage: $0 <snmp community> <hostname>"
        echo ""
        exit 3
}


if [ $# -lt 2 ] ; then
	print_usage
fi

# CPQHLTH-MIB::cpqHeMibCondition.0
ServerHealth=`snmpget -r 3 -v 2c -c $1 $2 .1.3.6.1.4.1.232.6.1.3.0`
if [[ $? -ne 0 ]] ; then
# The snmpget will return the error we echo out.
	exit 3
fi

testing=`echo $ServerHealth | grep "No Such Object available on this agent at this OID"`
if [[ $? -eq 0 ]] ; then
	echo "Unknown: Check SNMP + Server Health Agents"
	exit 3
fi

testing=`echo $ServerHealth | grep "No Such Instance currently exists at this OID"`
if [[ $? -eq 0 ]] ; then
	echo "Unknown: Check Server Health Agents"
	exit 3
fi

errors=0
ServerHealth=`echo "$ServerHealth" | grep  "INTEGER: 2"`
if [[ $? -ne '0' ]] ; then
errors=1
  # CPQHLTH-MIB::cpqHeAsrCondition.0
  ASRHealth=`snmpget -v 2c -c $1 $2 .1.3.6.1.4.1.232.6.2.5.17.0 | grep "INTEGER: 2"`
	if [[ $? -ne 0 ]] ; then
	  echo "Hardware Problem Detected: ASR event - Please visit  https://$2:2381 for more information."
	  exit 2
	fi

  # CPQHLTH-MIB::cpqHeThermalCondition.0
  ThermalHealth=`snmpget -v 2c -c $1 $2 .1.3.6.1.4.1.232.6.2.6.1.0 | grep "INTEGER: 2"`
	if [[ $? -ne 0 ]] ; then
	  echo "Hardware Problem Detected: Thermal Event - Please visit  https://$2:2381 for more information."
	  exit 2
	fi
  # CPQHLTH-MIB::cpqHeResilientMemCondition.0
  MemoryHealth=`snmpget -v 2c -c $1 $2 .1.3.6.1.4.1.232.6.2.14.4.0 | grep "INTEGER: 2"`
	if [[ $? -ne 0 ]] ; then
	  echo "Hardware Problem Detected: Memory Errors found - Please visit  https://$2:2381 for more information."
	  exit 2
	fi
  # CPQHLTH-MIB::cpqHeFltTolPwrSupplyCondition.0
  # This will be INTEGER: 1 for devices without PSU's like blades
  PSUHealth=`snmpget -v 2c -c $1 $2 .1.3.6.1.4.1.232.6.2.9.1.0 | awk '{print $NF}'`
	if [[ $PSUHealth -eq '3' || $PSUHealth -eq '4' ]] ; then
	  echo "Hardware Problem Detected: Power Supply Problem - Please visit  https://$2:2381 for more information."
	  exit 2
	fi
fi

#  CPQIDA-MIB::cpqDaMibCondition.0
StorageHealth=`snmpget -v 2c -c $1 $2 .1.3.6.1.4.1.232.3.1.3.0 | grep "INTEGER: 2"`
if [[ $? -ne 0 ]] ; then
	
	# CPQIDA-MIB::cpqDaPhyDrvStatus
	numberoffaileddrives=`snmpbulkwalk -v 2c -c $1 $2 .1.3.6.1.4.1.232.3.2.5.1.1.6 | awk -F : '{ print $NF }' | grep -v 2 | wc -l`
	if [[ $numberoffaileddrives -ne 0 ]] ; then
	  echo "Disk Drive Failure Detected - Please visit https://$2:2381 for more information."
	  exit 2
  	fi

	# CPQIDA-MIB::cpqDaAccelBattery
	failedbattery=`snmpwalk -v 2c -c $1 $2 1.3.6.1.4.1.232.3.2.2.2.1.6 | egrep -c '1$|4$|5$'`
	if [[ $failedbattery -ne 0 ]]; then
	  echo "Hardware Problem Detected: Array Accelerator Battery failure - Please visit https://$2:2381 for more information."
	  exit 2
	fi

	# If we get here - we don't have a straight answer  
	echo "Hardware Problem Detected: Storage Problem - Please visit  https://$2:2381 for more information."
	exit 2
fi

if [[ $errors -eq 1 ]] ; then
  # CPQHLTH-MIB::cpqHeEventLogErrorDesc
  guess=`snmpwalk -v 2c -c $1 $2 1.3.6.1.4.1.232.6.2.11.3.1.8` 
  BestGuess=`echo $guess | tail -n 1 | awk -F STRING: '{ print $NF }'`
  echo "Hardware Problem Detected: Best Guess - $BestGuess - Please visit  https://$2:2381 for more information."
  exit 2
else
  echo "Hardware OK"
  exit 0
fi
