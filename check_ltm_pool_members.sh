#!/bin/bash
#
# This script checks members of an LTM pool to see if any are marked down
# last modified 20090305 by Jake Paulus

if [[ $# -lt '2' ]] ; then
        echo "Usage: $0 <snmp community> <bigip hostname>"
        exit 3
fi

community=$1
bigip=$2

export MIBS=ALL

# Map pool to pool member IP to status like this:
# <pool>=<member ip>=<status>
index=0
problemsindex=0
for i in `snmpbulkwalk -v 2c -c $community $bigip F5-BIGIP-LOCAL-MIB::ltmPoolMemberMonitorState | sed s/F5-BIGIP-LOCAL-MIB::ltmPoolMemberMonitorState.\"// | sed s/\".ipv4.\"/=/ | sed s/\".*INTEGER:./=/ | sed s/\(.*//`; do
    pools[$index]=`echo $i | awk -F = '{print $1}'`
    memberip[$index]=`echo $i | awk -F = '{print $2}'`
    memberstatus[$index]=`echo $i | awk -F = '{print $3}'`
    ((index++))
done

index=0
for i in ${pools[@]}; do
    if [ ${memberstatus[$index]} != up ] ; then
        problems[$problemsindex]="${memberip[$index]} in ${pools[$index]} is ${memberstatus[$index]}"
	((problemsindex++))
    fi
    ((index++))
done

# Did we detect any problems?
if [[ ${#problems[@]} -gt 0 ]]; then
    echo "LTM Warning - ${#problems[@]} out of ${#memberip[@]} pool nodes are not OK"
    for (( i=0; i<${#problems[@]}; i++)); do
        echo ${problems[$i]}
    done
    exit 1
else
    echo "LTM OK - ${#memberip[@]} pool nodes are OK"
    exit 0
fi
