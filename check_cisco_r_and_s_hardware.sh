#!/bin/bash

# Version 0.4
# Last modified 2015-08-04 by Jake Paulus
#
# Change log:
# Version 0.1 - * Initial version
#
# Version 0.2 - * Fixed a number of issues displaying sensor and module names
#
# Version 0.3 - * Improved timeout behavior for unresponsive/down hosts
#				* Refactored CiscoEnvMon tests
#				* Added voltage sensor test from the CiscoEnvMon MIB
#
# Version 0.4 - * Added quick exit for known unsupported devices
#
# Version 0.5 - * Added stack member state check
#
# RELEASE NOTES:
# There is a known issue that affects the accuracy of certain sensor readings for
# X2 or Xenpak transceivers. The issue lies in a software bug that Cisco is having
# a hard time owning up to. This script works around that issue by ignoring those
# specific readings. See http://thwack.solarwinds.com/thread/52904 for more info.

# expand the variable below as a space-separated list
# in the case of MSFC2, we do support the CatOS instance on the supervisor
unsupportedmodels="C1600 C1700 C2950 3500XL C3550 MSFC2"

if [[ $# -lt '2' ]]; then
	echo "Usage: ./$0 <snmp community> <host> [verbose]"
	echo ""
	echo "This script checks the hardware health of a cisco router or switch."
	echo "The verbose option will list each sensor or module found and its"
	echo "current status to stderr"
	echo ""
	exit 3
fi

function trimwhitespace(){
 echo $@ | sed -e 's/^ *//g' -e 's/ *$//g'
}

if [[ $3 == "verbose" ]]; then
	verbose='true'
	echo "Checking if device responds to SNMP"
fi

snmpwalkcmd="snmpbulkwalk -r 1 -v 2c -c $1 -Lo -On $2"
unsupportedmib='No Such|Unknown host'
exitcode='0'
entSensorData=''
entSensorCount='0'

description=$($snmpwalkcmd 1.3.6.1.2.1.1.1.0 2>&1)
if [[ $? -ne 0 ]]; then
	echo $description
	exit 3
fi

for i in $unsupportedmodels; do
	if [[ $(echo $description | grep -c $i) -ne 0 ]]; then
		echo "This device ($i) is not supported."
		exit 3
	fi
done

entSensorThresholdEvaluation="1.3.6.1.4.1.9.9.91.1.2.1.1.5" # 1:true/NOT OK, 2:false/ok

$snmpwalkcmd $entSensorThresholdEvaluation | egrep "$unsupportedmib" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then # This device supports CISCO-ENTITY-SENSOR-MIB
	if [[ "$verbose" == 'true' ]]; then
					echo "" 1>&2
					echo "Looking at data from CISCO-ENTITY-SENSOR-MIB" 1>&2
	fi
	dontuseENVMONMIB='true'
	entSensorType="1.3.6.1.4.1.9.9.91.1.1.1.1.1"
	SensorTypeText[1]="Unknown"
	SensorTypeText[2]="Unknown"
	SensorTypeText[3]="Power"
	SensorTypeText[4]="Power"
	SensorTypeText[5]="Power"
	SensorTypeText[6]="Power"
	SensorTypeText[7]="Power"
	SensorTypeText[8]="Temperature"
	SensorTypeText[9]="Humidity"
	SensorTypeText[10]="Fan Speed"
	SensorTypeText[11]="Air Flow"
	SensorTypeText[12]="Unknown"
	SensorTypeText[13]="Unknown"
	SensorTypeText[14]="Signal Strength"
	entPhysicalName="1.3.6.1.2.1.47.1.1.1.1.7"
	entSensorThresholdSeverity="1.3.6.1.4.1.9.9.91.1.2.1.1.2"
	SensorThresholdCode[1]='3'
	SensorThresholdCode[10]='1'
	SensorThresholdCode[20]='2'
	SensorThresholdCode[30]='2'

	for i in `$snmpwalkcmd $entSensorThresholdEvaluation | sed "s/.$entSensorThresholdEvaluation.//" | sed 's/ = INTEGER: /=/'`; do
		sensorid=`echo $i | awk -F = '{print $1'} | awk -F . '{print $1}'`
		sensoreval=`echo $i | awk -F = '{print $2'}`
		if [[ $sensoreval -eq '1' ]]; then
			sensoreval='NOT OK'
		else
			sensoreval='ok'
		fi

		let entSensorCount++

		if [[ "XX${sensoreval}XX" == "XXNOT OKXX" ]]; then # sensor says something is wrong
			sensorname=`echo $($snmpwalkcmd $entPhysicalName.$sensorid) | awk -F : '{print $2}'`
			sensorname=$(trimwhitespace "$sensorname")
			severity=`echo $($snmpwalkcmd $entSensorThresholdSeverity.$sensorid) | awk '{print $NF}'`
			thresholdcode=${SensorThresholdCode[$severity]}

			# A work-around for invalid voltage sensor readings for X2 or Xenpak transceivers
			# more info: http://thwack.solarwinds.com/thread/52904
			istransceiversensor=`echo $sensorname | egrep 'Te.+Bias|Te.+Power|transceiver.+Bias|transceiver.+Power'`
			if [[ $? -eq '0' ]]; then
				sensoreval='NOT OK most likely IOS bug'
			else
				if [[ $exitcode -lt $thresholdcode ]]; then # we exit with the worst status found
					exitcode=$thresholdcode
				fi
				echo -n "$sensorname NOT OK "
			fi
		fi

		if [[ "$verbose" == 'true' ]]; then
			if [[ "XX${sensoreval}XX" == "XXokXX" ]]; then # we don't have data for sensor types or names yet
				sensorname=`echo $($snmpwalkcmd $entPhysicalName.$sensorid) | awk -F : '{print $2}'`
				sensorname=$(trimwhitespace "$sensorname")
				sensortype=`echo $($snmpwalkcmd $entSensorType.$sensorid) | awk '{print $NF}'`
				sensortype=${SensorTypeText[$sensortype]}
			fi
			echo "$sensorname of type $sensortype is $sensoreval: will exit $exitcode" 1>&2
		fi
	done
	entSensorData="checked $entSensorCount sensors"
elif [[ "$verbose" == 'true' ]]; then
	echo "" 1>&2
	echo "This device doesn't support the CISCO-ENTITY-SENSOR-MIB" 1>&2
fi

if [[ "$verbose" == 'true' ]]; then
	echo "" 1>&2
	echo "Looking at data from CISCO-ENVMON-MIB" 1>&2
fi

EnvMonStateCode[1]='0'
EnvMonStateText[1]="normal"
EnvMonStateCode[2]='1'
EnvMonStateText[2]="warning"
EnvMonStateCode[3]='2'
EnvMonStateText[3]="critical"
EnvMonStateCode[4]='2'
EnvMonStateText[4]="shutdown"
EnvMonStateCode[5]='0' # not present might be ok or not. i've decided its ok
EnvMonStateText[5]="notPresent"
EnvMonStateCode[6]='3'
EnvMonStateText[6]="notFunctioning"

# Start index at 1 to do less math in for loops later
SensorType[1]="Voltage"
SensorState[1]="1.3.6.1.4.1.9.9.13.1.2.1.7"						 #ciscoEnvMonVoltageState
SensorDescription[1]="1.3.6.1.4.1.9.9.13.1.2.1.2"			 #ciscoEnvMonVoltageStatusDescr

SensorType[2]="Temperature"
SensorState[2]="1.3.6.1.4.1.9.9.13.1.3.1.6"						 #ciscoEnvMonTemperatureState
SensorDescription[2]="1.3.6.1.4.1.9.9.13.1.3.1.2"			 #ciscoEnvMonTemperatureStatusDescr

SensorType[3]="Fan"
SensorState[3]="1.3.6.1.4.1.9.9.13.1.4.1.3"						 #ciscoEnvMonFanState
SensorDescription[3]="1.3.6.1.4.1.9.9.13.1.4.1.2"			 #ciscoEnvMonFanStatusDescr

SensorType[4]="Power Supply"
SensorState[4]="1.3.6.1.4.1.9.9.13.1.5.1.3"						 #ciscoEnvMonSupplyState
SensorDescription[4]="1.3.6.1.4.1.9.9.13.1.5.1.2"			 #ciscoEnvMonSupplyStatusDescr


for sensortable in $(seq 1 ${#SensorState[@]}) ; do
	sensorcount='0'
	# Even devices that support this MIB don't always have all types of sensors present

	$snmpwalkcmd ${SensorState[$sensortable]} | egrep "$unsupportedmib" > /dev/null 2>&1
	if [[ $? -eq '0' ]]; then
		if [[ "$verbose" == 'true' ]]; then
			echo "${SensorType[$sensortable]} sensors are not supported by this device" 1>&2
		fi
	else
		for sensor in `$snmpwalkcmd ${SensorState[$sensortable]} | sed "s/.${SensorState[$sensortable]}.//" | sed 's/ = INTEGER: /=/'`; do
			sensorid=`echo $sensor | awk -F = '{print $1}'`
			sensorstatus=`echo $sensor | awk -F = '{print $2}'`
			let sensorcount++

			if [[ ${EnvMonStateCode[$sensorstatus]} -ne '0' ]]; then #there's a problem
				sensorname=`echo $($snmpwalkcmd ${SensorDescription[$sensortable]}.$sensorid) | awk -F \" '{print $2}'`
				sensorname=$(trimwhitespace "$sensorname")
				if [[ "$exitcode" -lt "${EnvMonStateCode[$sensorstatus]}" ]]; then
					exitcode=${EnvMonStateCode[$sensorstatus]}
				fi
				echo -n "$sensorname is ${EnvMonStateText[$sensorstatus]} "
			fi

			if [[ "$verbose" == 'true' ]]; then
				if [[ ${EnvMonStateCode[$sensorstatus]} -eq '0' ]]; then # We don't know the sensor name yet
					sensorname=`echo $($snmpwalkcmd ${SensorDescription[$sensortable]}.$sensorid) | awk -F \" '{print $2}'`
					sensorname=$(trimwhitespace "$sensorname")
				fi
				echo "$sensorname ${SensorType[$sensortable]} sensor reported status of"\
					 "${EnvMonStateText[$sensorstatus]}: will exit $exitcode" 1>&2
			fi
		done
	fi
	envSensorCount[$sensortable]=$sensorcount
done

EnvMonData="checked"
for i in $(seq 1 ${#SensorState[@]}); do
		if [[ ${envSensorCount[$i]} -ne 0 ]]; then
			EnvMonData="$EnvMonData ${envSensorCount[$i]} ${SensorType[$i]}"
		fi
done
EnvMonData="$EnvMonData probes"

# Check modules/cards
entPhysicalModelName="1.3.6.1.2.1.47.1.1.1.1.13"
moduledata=''
modulecount='0'
cefcModuleOperStatus="1.3.6.1.4.1.9.9.117.1.2.1.1.2"
ModuleStatusText[1]='unknown'
ModuleStatusCode[1]='3'
ModuleStatusText[2]='ok'
ModuleStatusCode[2]='0'
ModuleStatusText[3]='disabled'
ModuleStatusCode[3]='0'
ModuleStatusText[4]='okButDiagFailed'
ModuleStatusCode[4]='1'
ModuleStatusText[5]='boot'
ModuleStatusCode[5]='3'
ModuleStatusText[6]='selfTest'
ModuleStatusCode[6]='3'
ModuleStatusText[7]='failed'
ModuleStatusCode[7]='2'
ModuleStatusText[8]='missing'
ModuleStatusCode[8]='0'
ModuleStatusText[9]='mismatchWithParent'
ModuleStatusCode[9]='1'
ModuleStatusText[10]='mismatchConfig'
ModuleStatusCode[10]='1'
ModuleStatusText[11]='diagFailed'
ModuleStatusCode[11]='2'
ModuleStatusText[12]='dormant'
ModuleStatusCode[12]='0'
ModuleStatusText[13]='outOfServiceAdmin'
ModuleStatusCode[13]='0'
ModuleStatusText[14]='outOfServiceEnvTemp'
ModuleStatusCode[14]='2'
ModuleStatusText[15]='poweredDown'			# Cisco calls this a failure state
ModuleStatusCode[15]='0'					# But I disagree
ModuleStatusText[16]='poweredUp'
ModuleStatusCode[16]='1'
ModuleStatusText[17]='powerDenied'
ModuleStatusCode[17]='1'
ModuleStatusText[18]='powerCycled'
ModuleStatusCode[18]='3'
ModuleStatusText[19]='okButPowerOverWarning'
ModuleStatusCode[19]='1'
ModuleStatusText[20]='okButPowerOverCritical'
ModuleStatusCode[20]='2'
ModuleStatusText[21]='syncInProgress'
ModuleStatusCode[21]='0'
ModuleStatusText[22]='upgrading'
ModuleStatusCode[22]='0'
ModuleStatusText[23]='okButAuthFailed'
ModuleStatusCode[23]='1'

$snmpwalkcmd $cefcModuleOperStatus | egrep "$unsupportedmib" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then # this is a modular device

	if [[ "$verbose" == 'true' ]]; then
		echo "" 1>&2
		echo "Looking at data from CISCO-ENTITY-FRU-CONTROL-MIB" 1>&2
	fi

	for i in `$snmpwalkcmd $cefcModuleOperStatus | sed "s/.$cefcModuleOperStatus.//" | sed 's/ = INTEGER: /=/'`; do
		moduleid=`echo $i | awk -F = '{print $1}'`
		modulestatus=`echo $i | awk -F = '{print $2}'`
		moduletype=`echo $($snmpwalkcmd $entPhysicalModelName.$moduleid) | awk -F : '{print $2}'`
		moduletype=$(trimwhitespace "$moduletype")
		let modulecount++

		if [[ ${ModuleStatusCode[$modulestatus]} -ne '0' ]]; then
			if [[ $exitcode -lt ${ModuleStatusCode[$modulestatus]} ]]; then
				exitcode=${ModuleStatusCode[$modulestatus]}
			fi
			echo -n "$moduletype is ${ModuleStatusText[$modulestatus]} "
		fi

		if [[ "$verbose" == 'true' ]]; then
			echo "Module $moduletype is ${ModuleStatusText[$modulestatus]}: will exit $exitcode" 1>&2
		fi
	done
	moduledata="checked $modulecount modules"
elif [[ "$verbose" == 'true' ]]; then
	echo "" 1>&2
	echo "This device does not support the CISCO-ENTITY-FRU-CONTROL-MIB" 1>&2
fi

cswSwitchState='1.3.6.1.4.1.9.9.500.1.2.1.1.6'
$snmpwalkcmd $cswSwitchState | egrep "$unsupportedmib" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then # This device supports CISCO-STACKWISE-MIB

	if [[ "$verbose" == 'true' ]]; then
		echo "" 1>&2
		echo "Looking at data from CISCO-STACKWISE-MIB" 1>&2
	fi	
	SwitchStateText[1]='waiting'
	SwitchStateCode[1]='1' # warning
	SwitchStateText[2]='progressing'
	SwitchStateCode[2]='2' # warning
	SwitchStateText[3]='added'
	SwitchStateCode[3]='1' # warning
	SwitchStateText[4]='ready'
	SwitchStateCode[4]='0' # OK
	SwitchStateText[5]='sdmMismatch'
	SwitchStateCode[5]='1' # warning
	SwitchStateText[6]='verMismatch'
	SwitchStateCode[6]='1' # warning
	SwitchStateText[7]='featureMismatch'
	SwitchStateCode[7]='1' # warning
	SwitchStateText[8]='newMasterInit'
	SwitchStateCode[8]='1' # warning
	SwitchStateText[9]='provisioned'
	SwitchStateCode[9]='0' # OK
	SwitchStateText[10]='invalid'
	SwitchStateCode[10]='1' # warning
	SwitchStateText[11]='removed'
	SwitchStateCode[11]='2' # critical
	
	stackmembercount=0
	for i in `$snmpwalkcmd $cswSwitchState | sed "s/.$cswSwitchState.//" | sed 's/ = INTEGER: /=/'`; do
		let stackmembercount++
		statusresult=`echo $i | awk -F = '{print $NF}'`
		
		if [[ ${SwitchStateCode[$statusresult]} -ne '0' || $verbose == 'true' ]]; then
			cswSwitchNumCurrent='1.3.6.1.4.1.9.9.500.1.2.1.1.1'
			
			if [[ $exitcode -lt ${SwitchStateCode[$statusresult]} ]]; then
				exitcode=${SwitchStateCode[$statusresult]}
			fi
			
			switchindex=$(echo $i | awk -F = '{print $1}' )
			switchid=$($snmpwalkcmd $cswSwitchNumCurrent.$switchindex | awk '{print $NF}')
			
			if [[ "$verbose" == 'true' ]]; then
				echo "Switch $switchid is ${SwitchStateText[$statusresult]}: will exit $exitcode" 1>&2
			else
				echo -n "Switch $switchid is ${SwitchStateText[$statusresult]} "
			fi
		fi
		
	done
	stackdata="checked $stackmembercount switches"
		
elif [[ "$verbose" == 'true' ]]; then
	echo "" 1>&2
	echo "This device does not support the CISCO-STACKWISE-MIB" 1>&2
fi


# Output final status message
finalmessage=""

if [ $entSensorCount -gt 0 ]; then
	finalmessage=$entSensorData
fi

if [[ ! ${envSensorCount[@]} =~ '^[0 ]*$' ]]; then # at least CISCO-ENV-MIB sensors detected
	finalmessage="$finalmessage $EnvMonData"
fi

if [[ ! -z "$moduledata" ]]; then
	finalmessage="$finalmessage $moduledata"
fi

if [[ ! -z "$stackdata" ]]; then
	finalmessage="$finalmessage $stackdata"
fi

if [[ "#${finalmessage}#" == "# checked probes#" ]]; then
	echo "We couldn't collect any data from this host. Please verify the host and your configuration"
	exit 3
fi

# Blank line between verbose output and the normal output
if [[ "$verbose" == 'true' ]]; then
        echo ""
fi

echo "$finalmessage"

exit $exitcode
