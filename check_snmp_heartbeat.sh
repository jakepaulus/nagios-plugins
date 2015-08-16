#! /bin/bash
#
#
# Nagios check script for heartbeat
#  last modified by Jake Paulus 20101221
#
# We're really just looking for the active resource to be present on the primary node
# in this case, a virtual IP address


print_usage() {
	echo ""
        echo "Usage: $0 [snmp read community] [device] [virtual ip address]"
        echo ""
	echo "The virtual IP address is the resource we're checking the presence of" 
	echo "This should not be the IP that you check against"
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

if [ "$#" -ne "3" ] ; then
	print_usage
fi

community=$1
host=$2
ip=$3

status=`snmpwalk -v 2c -c $community $host .1.3.6.1.2.1.4.20.1.1 | grep $ip`

if [ $? -ne 0 ] ; then
	echo "Warning: The floating IP Address was not found on this server"
	exit 1
else
	echo "OK"
	exit 0
fi

