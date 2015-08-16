#!/bin/sh
#
#---------------------------------------------#
# check_snmp_cdp-neighbor.sh
# Last modified by Jake Paulus 20081004
#
# Usage:
# ./check_snmp_cdp-neighbors.sh [snmp community] [device hostname/IP] [neighbor name or 'list'] (count)
#
# The list argument is used list all cdp neighbors. The optional count parameters specifies how many
# physical links should exist between the host and the neighbor.


community=$1
host=$2
action=$3

if [[ $4 -lt '1' ]] ; then
  count='1'
else
  count=$4
fi

if [[ $# -lt '3' ]] ; then
  echo "Usage:"
  echo "$0 [snmp community] [device hostname/IP] [neighbor name or 'list'] (count)"
  echo ""
  echo "The list argument is used list all cdp neighbors. The optional count"
  echo "parameters specifies how many physical links should exist between"
  echo "the host and the neighbor."
  exit 3
fi

if [ $action == "list" ] ; then
  snmpbulkwalk -v 2c -c $community $host .1.3.6.1.4.1.9.9.23.1.2.1.1.6 | awk {' print $4 '}
  exit 3
fi

result=`snmpbulkwalk -v 2c -c $community $host .1.3.6.1.4.1.9.9.23.1.2.1.1.6 | grep -ic $action`

if [[ $result -eq $count ]] ; then
  # match was found
  echo "OK: $count link(s) up to $action"
  exit 0
elif [[ $result -gt '0' ]] ; then
  # One of multiple redundant links is down
  echo "Warning: $result links up - $count expected"
  exit 1
else
  # no neighbor matches description given
  echo "Critical: No link up to $action"
  exit 2
fi
