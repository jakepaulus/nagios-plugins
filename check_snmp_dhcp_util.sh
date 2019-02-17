#!/bin/bash
# Nagios check script for DHCP Utilization
#  last modified by Seth Martin 20081017
#
#
# Call this command as follows:
# check_snmp_dhcp_util.sh [servername] [snmp read community] [warn] [crit]
#
#       [warn] should be smaller than [crit]


print_usage() {
        echo ""
        echo "Please open this file in a text editor to read the documentation in the comments at the top."
        echo ""
        echo "Usage: $0 [servername] [snmp read community] [warn] [crit]"
        echo "where [warn] and [crit] are integer values denoting percentage used"
        echo ""
        exit 3
}
case "$1" in
        --help)
                print_usage
                ;;
        -h)
                print_usage
                ;;
esac

if [ "$#" -ne "4" ]; then
        print_usage
fi


HOST=$1
SNMPCOMM=$2
WARNING=$3
CRITICAL=$4


count=0
for i in `snmpbulkwalk -c $SNMPCOMM -v 2c $HOST 1.3.6.1.4.1.311.1.3.2.1.1.2 | sed 's/ /,/g'`; do
    ARRAYNETADDRESS[$count]=`echo $i | awk -F = '{ print $1 }' | awk -F . '{ octet1 = NF - 3; octet2 = NF - 2; octet3 = NF - 1; print $octet1"."$octet2"."$octet3"."$NF }' | sed 's/,//g'`
    ARRAYINUSE[$count]=`echo $i | awk -F , '{print $NF}'`
    ((count++))
done

count=0
for i in `snmpbulkwalk -c $SNMPCOMM -v 2c $HOST 1.3.6.1.4.1.311.1.3.2.1.1.3 | awk '{ print $NF }'`; do 
    ARRAYFREE[$count]=$i
    ((count++))
done

ELEMENTS=${#ARRAYINUSE[@]}

# echo each element in array 
# for loop
for (( i=0;i<$ELEMENTS;i++)); do
    FREE=${ARRAYFREE[${i}]}
    INUSE=${ARRAYINUSE[${i}]}
    TOTAL=$(($FREE+$INUSE))
	#Calculate the Utilization of the Scope
    UTIL=`echo "$INUSE *100 / $TOTAL" | bc`
	#Check it for thresholds and exit if violated
	if [ $UTIL -ge $CRITICAL ] ; then
	  echo "The scope for ${ARRAYNETADDRESS[$i]} is over $CRITICAL% Utilization"
	  exit 2
	fi
	if [ $UTIL -ge $WARNING ] ; then
	  echo "The scope for ${ARRAYNETADDRESS[$i]} is over $WARNING% Utilization"
	  exit 1
	fi
done


echo "DHCP Utilization OK"
exit 0

