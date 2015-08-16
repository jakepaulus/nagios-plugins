#!/bin/bash
#
# This script checks the lag time of snapvault mirrors configured
# on NetApp filers.
#
# Last modified 20120718 by Jake Paulus
#
if [[ $# -ne '4' && $3 != 'list' ]] ; then
	echo "Usage: $0 <snmp community> <filer hostname> <snapvault name from list> <max lag time in hours>"
	echo ""
	echo "Or: $0 <snmp community> <filer hostname> list"
	echo ""
	exit 3
fi
#------------------------------------------

community=$1
host=$2
svsource=$3
threshold=$4

index=0
for i in `snmpbulkwalk -v 2c -c $community -Ov -Oq $host 1.3.6.1.4.1.789.1.19.11.1.2 |  sed 's/\"//g'` ; do
	svsources[$index]="$i"
	((index++))
done

index=0
for i in `snmpbulkwalk -v 2c -c $community -Ov -Ot $host 1.3.6.1.4.1.789.1.19.11.1.6` ; do
	svlagtime=$(echo "$i / 100 / 60 / 60" | bc)
	svlagtimes[$index]=$svlagtime
	((index++))
done


listsnapvaults() {
	count=${#svlagtimes[@]}
	for (( i=0; i<${count}; i++ )); do
		echo "${svsources[$i]} is ${svlagtimes[$i]} hours behind"
	done
}

if [[ $3 == 'list' ]]; then
	listsnapvaults
	exit	
else
	matches=$(listsnapvaults | grep -c $svsource)
	if [[ $matches -ne 1 ]]; then 
		echo "Please give a more specific snapvault session name"
		exit 3
	fi
	match=$(listsnapvaults | grep $svsource)	
	name=$(echo $match | awk '{print $1}')
	hoursbehind=$(echo $match | awk '{print $3}')
	
	if [[ $hoursbehind -lt $threshold ]]; then
		echo "OK: $name is $hoursbehind hours behind"
		exit 0
	else
		echo "Warning: $name is $hoursbehind hours behind"
		exit 1
	fi
fi
