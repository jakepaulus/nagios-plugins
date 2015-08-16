#!/bin/bash
#
print_usage() {
    echo ""
    echo "Usage: $0 [snmp v2c community] [host] [interface] [threshold] "
    echo ""
    echo "Interface should be the exact name given by running with the list option shown below"
    echo "The threshold should be the minimum number of EIGRP neighbors on that interface"
    echo ""
    echo "Usage: $0 [snmp v2c community] [host] list"
    echo ""
    echo "Examples:"
    echo "$0 public myrouter list"
    echo "$0 public myrouter GigabitEthernet0/0 3"
    echo "$0 public mylayer3switch Vlan20"
    exit 3
}

check_compatibility() {
    testing=`snmpwalk -On -v 2c -c $1 $2 1.3.6.1.4.1.9.9.449.1.1.1.1.2.0 | grep 'Default-IP-Routing-Table'`
    if [ $? -ne 0 ]; then
        echo ""
        echo "It appears the device you are checking doesn't support the CISCO-EIGRP-MIB SNMP MIB"
        echo "Please use this tool to see how you might get support:"
        echo "http://tools.cisco.com/ITDIT/MIBS/AdvancedSearch?MibSel=250356"
        echo ""
	exit 3
    fi
}

list_interfaces_with_neighbors() {
    UniqueInterfaceIndexes=`snmpwalk -v 2c -c $1 $2 .1.3.6.1.4.1.9.9.449.1.4.1.1.4 | awk '{ print $NF }' | sort -u`    
    for i in $UniqueInterfaceIndexes; do
        InterfaceNames[$i]=`snmpwalk -On -v 2c -c $1 $2 .1.3.6.1.2.1.2.2.1.2.$i | awk '{ print $NF }'`
    done
    echo "I found EIGRP neighbors on the following interfaces: ${InterfaceNames[@]}"
}

peer_count() {
    InterfaceIndex=`snmpwalk -On -v 2c -c $1 $2 .1.3.6.1.2.1.2.2.1.2 | grep "$3" | awk '{ print $1 '} | awk -F . '{ print $NF }'`
    Matches=`snmpwalk -v 2c -c $1 $2 .1.3.6.1.4.1.9.9.449.1.4.1.1.4 | egrep -c "INTEGER: $InterfaceIndex\$"`
    if [ $Matches -lt $4 ]; then
        echo "CRITICAL: $Matches EIGRP neighbors found < $4"
        exit 2
    else
        echo "OK: $Matches EIGRP neighbors found"
        exit 0
    fi
}

if [ "$#" -lt '3' ]; then
    print_usage
fi

case "$3" in
    list)
        check_compatibility $1 $2
        list_interfaces_with_neighbors $1 $2 $3 
        ;;
    *)
        check_compatibility $1 $2
        peer_count $1 $2 $3 $4
        ;;
esac
