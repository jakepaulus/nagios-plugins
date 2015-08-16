#!/bin/bash
# last modified by jpaulus 2011-12-19

if [ $# -lt 3 ]; then
	echo "Usage:"
	echo "$0 snmp_community host status [ sla_monitor_number ]"
	echo ''
	echo 'status is the status (WARNING or CRITICAL) you would like'
	echo 'the script to return if the SLA monitor is not ok'
	echo ''
	echo 'If you leave out the sla monitor number, the script will'
	echo 'check all SLA monitors that are configured on the host'
	echo 'and will return *status* if any are not ok.'
	echo ''
	exit 3
fi

SNMPCommunity=$1
Host=$2
Status=$3
SLA=$4

if [[ $Status == 'WARNING' ]]; then 
	exitstatus='1'
elif [[ $Status == 'CRITICAL' ]]; then
	exitstatus='2'
else
	echo "UNKNOWN: status must be WARNING or CRITICAL"
	exit 3
fi


#Constants
rttSense[0]='Other'
rttSense[1]='OK'
rttSense[2]='Disconnected'
rttSense[3]='Over Threshold'
rttSense[4]='Time Out'
rttSense[5]='Busy'
rttSense[6]='Not Connected'
rttSense[7]='Dropped'
rttSense[8]='Sequence Error'
rttSense[9]='Verify Error'
rttSense[10]='Application Specific'
rttSense[11]='DNS Server Time Out'
rttSense[12]='TCP Connect Time Out'
rttSense[13]='HTTP Transaction Time Out'
rttSense[14]='DNS Query Error'
rttSense[15]='HTTP Error'
rttSense[16]='Error'

rttType[1]='echo'
rttType[2]='pathEcho'
rttType[3]='fileIO'
rttType[4]='script'
rttType[5]='udpEcho'
rttType[6]='tcpConnect'
rttType[7]='http'
rttType[8]='dns'
rttType[9]='udp-jitter'
rttType[10]='dlsw'
rttType[11]='dhcp'
rttType[12]='ftp'
rttType[16]='icmp-jitter'

rttPrecision[1]='milliseconds'
rttPrecision[2]='microseconds'


# Checks begin here

rttMonLatestRttOperCompletionTime='1.3.6.1.4.1.9.9.42.1.2.10.1.1'
rttMonLatestRttOperSense='1.3.6.1.4.1.9.9.42.1.2.10.1.2'

# Needed to find out if CompletionTime is in milliseconds or microseconds
# if rttType is jitter and precision is microseconds, then Completion time
# is in microseconds, otherwise in milliseconds
rttMonCtrlAdminRttType='1.3.6.1.4.1.9.9.42.1.2.1.1.4'
rttMonEchoAdminPrecision='1.3.6.1.4.1.9.9.42.1.2.2.1.37'

if [[ $SLA ]]; then
	rttMonLatestRttOperCompletionTime="1.3.6.1.4.1.9.9.42.1.2.10.1.1.$SLA"
	QuickStatusCheck="$rttMonLatestRttOperSense.$SLA"
else
	QuickStatusCheck=$rttMonLatestRttOperSense
fi

testing=`snmpbulkwalk -v 2c -c $SNMPCommunity -On $Host $rttMonLatestRttOperSense`
if [ $? -ne 0 ]; then exit 3; fi

# First find out if everything is OK or not
problems=`snmpbulkwalk -v 2c -c $SNMPCommunity -On $Host $QuickStatusCheck | egrep -c -v 'INTEGER: 1$' 2>/dev/null`

if [ $problems ]; then
	if [ $problems -gt '0' ]; then
		echo "$Status: $problems SLA monitors found not OK"
	else
		echo "OK"
	fi
else
	echo "OK"
fi


for i in `snmpbulkwalk -v 2c -c $SNMPCommunity -On $Host $rttMonLatestRttOperCompletionTime | sed 's/\s//g'`; do
	slanumber=`echo $i | awk -F = '{print $1}' | awk -F . '{print $NF}'`
	slaresponsetime=`echo $i | awk -F : '{print $NF}'`
	slastatus=`snmpbulkwalk -v 2c -c $SNMPCommunity -On $Host $rttMonLatestRttOperSense.$slanumber | awk '{print $NF}'`
	slaprecision=`snmpbulkwalk -v 2c -c $SNMPCommunity -On $Host $rttMonEchoAdminPrecision.$slanumber | awk '{print $NF}'`
	slatype=`snmpbulkwalk -v 2c -c $SNMPCommunity -On $Host $rttMonCtrlAdminRttType.$slanumber | awk '{print $NF}'`
	echo "SLA Number $slanumber (${rttType[$slatype]}) is ${rttSense[$slastatus]} | $slaresponsetime ${rttPrecision[$slaprecision]}"
done

if [ $problems ]; then
	if [ $problems -gt '0' ]; then
		exit $exitstatus
	else
		exit 0
	fi
else
	exit 0
fi
