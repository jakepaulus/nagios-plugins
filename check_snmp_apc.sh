#!/bin/bash
#
# This script checks the status of APC battery backups using snmp data provided
# by the APC network management card.
#
# Last modified 20090514 by Jake Paulus

print_usage() {
        echo ""
        echo "Usage:"
        echo "$0 \$community \$host \$testname"
        echo ""
        echo "Where community is the snmp version 1 community, host is the hostname"
        echo "or IP address, and testname is one of the following (case sensitive):"
        echo ""
        echo "generalstatus"
        echo "batterystatus"
        echo "load"
        echo ""
        echo "Please be aware that the three tests above do not overlap in functionality"
        echo "by very much so it's worth running them all."
        echo ""
        exit 3
}


if [ $# -lt 3 ] ; then
        print_usage
fi


mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.4.1.1.0 2>&1`
if [[ $? -ne 0 ]] ; then
        echo "Unknown - $mytest Please see http://$2/ for more information."
        exit 3
fi

if [ $3 = 'generalstatus' ] ; then
        #possible statuses - with a filler value for 0 which is never expected
        statuses=( filler Unknown Online OnBattery OnSmartBoost TimedSleeping SoftwareBypass Off Rebooting SwitchedBypass HardwareFailureBypass SleepingUntilPowerReturns OnSmartTrim )

        #APC UPS :: Basic Output Status (On-line)
        mytest=`echo $mytest | awk '{print $NF}'`
        if [[ $mytest -eq 2 ]] ; then
                echo "OK - ${statuses[$mytest]} Please see http://$2/ for more information."
                exit 0
        elif [[ $mytest -eq 1 ]] ; then
                echo "Unknown - Status unknown Please see http://$2/ for more information."
                exit 3
        else
                echo "Critical - ${statuses[$mytest]} Please see http://$2/ for more information."
                exit 2
        fi
elif [ $3 = 'batterystatus' ] ; then
    warnings=0
    criticals=0
    unknowns=0

        #APC UPS :: Advanced Battery Capacity
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.2.2.1.0 | awk '{print $NF}'`
        if [[ $mytest -gt 85 ]] ; then
                notices="$mytest% capacity remaining "
        else
                notices="$mytest% capacity remaining which is less than 85% "
                ((warnings++))
        fi

        # APC UPS :: Battery Status
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.2.1.1.0 | awk '{print $NF}'`
        if [[ $mytest -eq 2 ]] ; then
                notices=$notices"Battery status OK "
        elif [[ $mytest -eq 3 ]] ; then
                notices=$notices"Battery low "
                ((warnings++))
        else
                notices=$notices"Battery status unknown "
                ((unknowns++))
        fi

        # APC UPS :: Replace Battery
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.2.2.4.0 | awk '{print $NF}'`
        if [[ $mytest -eq 1 ]] ; then
                notices=$notices"Battery health is good "
        else
                notices=$notices"Battery needs to be replaced "
                ((criticals++))
        fi

    if [[ $criticals -gt 0 ]] ; then
        echo "Critical - "$notices"Please see http://$2/ for more information."
        exit 2
    elif [[ $warnings -gt 0 ]] ; then
        echo "Warning - "$notices"Please see http://$2/ for more information."
        exit 1
    elif [[ $unknowns -gt 0 ]] ; then
        echo "Unknown - "$notices"Please see http://$2/ for more information."
        exit 3
    else
        echo "OK - $notices""Please see http://$2/ for more information."
        exit 0
    fi

elif [ $3 = 'load' ] ; then
    warnings=0

        #APC UPS :: Advanced Output Load
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.4.2.3.0 | awk '{print $NF}'`
        if [[ $mytest -lt 50 ]] ; then
                echo "OK - Load is $mytest% which is less than 50% Please see http://$2/ for more information."
                exit 0
        else
                echo "Warning - Load is $mytest% which is greater than 50% Please see http://$2/ for more information."
                exit 1
        fi
else
    print_usage
    exit 3
fi