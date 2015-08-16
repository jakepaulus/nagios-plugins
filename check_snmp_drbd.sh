#! /bin/bash
#
#
# Nagios check script for drbd
#  last modified by Jake Paulus 20100330
#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Please add the following to your remote server's /etc/snmp/snmpd.conf and restart the snmpd daemon
#
# extend .1.3.6.1.4.1.6876.99999.2 drbd /usr/sbin/drbd-overview
#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

print_usage() {
	echo ""
	echo "Please open this file in a text editor to read the documentation in the comments at the top."
        echo ""
        echo "Usage: $0 [snmp read community] [devicename] [resource]"
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

if [ "$#" -ne "3" ] ; then
	print_usage
fi

community=$1
host=$2
resource=$3

fullstatus=`snmpwalk -v 2c -c $community $host .1.3.6.1.4.1.6876.99999.2 | grep "$resource"`

testing=`echo $fullstatus | egrep -c '[\n]'`
if [ $testing -ne 1 ] ; then
	echo "We didn't find exactly one result for that resource name. This could be a bug."
	exit 3
fi

fullstatus=`echo $fullstatus | awk -F '"' '{print $2}'`

testing=`echo $fullstatus | grep 'UpToDate/UpToDate'`
if [ $? -ne 0 ] ; then
	echo "Warning: $fullstatus"
	exit 1
else
	echo "OK: $fullstatus"
	exit 0
fi

