#!/bin/bash
#
# This script checks the status of APC battery backups using snmp data provided
# by the APC network management card.
#
# Last modified 20160322 by Jake Paulus

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
        echo "temperature \$warning \$critical"
        echo ""
        echo "Please be aware that the tests above do not overlap in functionality"
        echo "by very much so it's worth running them all."
        echo ""
        echo "The temperature test is in degrees Fahrenheit"
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
                echo "OK"
                exit 0
        elif [[ $mytest -eq 1 ]] ; then
                echo "Unknown - Status unknown. See http://$2/"
                exit 3
        else
                echo "Critical - ${statuses[$mytest]} See http://$2/"
                exit 2
        fi
elif [ $3 = 'batterystatus' ] ; then
    warnings=0
    criticals=0
    unknowns=0

        #APC UPS :: Advanced Battery Capacity
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.2.2.1.0 | awk '{print $NF}'`
        perfdata="Capacity=$mytest%;85;85;0;100"
        if [[ $mytest -lt 85 ]] ; then
                notices="$mytest% capacity remaining (<85%) "
                ((warnings++))
        fi

        # APC UPS :: Battery Status
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.2.1.1.0 | awk '{print $NF}'`
        if [[ $mytest -eq 3 ]] ; then
                notices=$notices"Battery low "
                ((warnings++))
        elif [[ $mytest -ne 2 ]]; then
                notices=$notices"Battery status unknown "
                ((unknowns++))
        fi

        # APC UPS :: Replace Battery
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.2.2.4.0 | awk '{print $NF}'`
        if [[ $mytest -ne 1 ]] ; then
                notices=$notices"Battery needs to be replaced "
                ((criticals++))
        fi

    if [[ $criticals -gt 0 ]] ; then
        echo "Critical - "$notices"Please see http://$2/ for more information|$perfdata"
        exit 2
    elif [[ $warnings -gt 0 ]] ; then
        echo "Warning - "$notices"Please see http://$2/ for more information|$perfdata"
        exit 1
    elif [[ $unknowns -gt 0 ]] ; then
        echo "Unknown - "$notices"Please see http://$2/ for more information|$perfdata"
        exit 3
    else
        echo "OK|$perfdata"
        exit 0
    fi

elif [ $3 = 'load' ] ; then
    warnings=0

        #APC UPS :: Advanced Output Load
        mytest=`snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.1.4.2.3.0 | awk '{print $NF}'`
        perfdata="Load=$mytest%;50;50;0;100"
        if [[ $mytest -lt 50 ]] ; then
                echo "OK - Load is $mytest% (<50%)|$perfdata"
                exit 0
        else
                echo "Warning - Load is $mytest% (>50%) See http://$2/|$perfdata"
                exit 1
        fi
elif [ $3 = 'temperature' ]; then
        if [[ $# -ne 5 ]]; then
                print_usage
                exit 3
        fi
        if [[ $4 -gt $5 ]]; then
                echo "The warning threshold must be >= the critical threshold."
                exit 3
        fi

        mytest=$(snmpwalk -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.10.2.3.2.1.4 | wc -l)
        if [[ $mytest -lt 1 ]]; then
                echo "Unknown: No temperature sensors detected"
                exit 3
        fi


        warnings=0
        criticals=0
        perfdata=""
        while read rawdata; do
                sensorindex=$(echo $rawdata | awk -F . '{print $NF}' | awk '{print $1}')
                sensorname=$(snmpget -r 3 -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.10.2.3.2.1.2.$sensorindex | awk -F \" '{print $2}')
                temperature=$(echo $rawdata | awk '{print $NF}')
                perfdata="$sensorname=${temperature};$4;$5;0;113"
                if [[ $temperature -gt $5 ]]; then
                        ((criticals++))
                        notices="$sensorname reads ${temperature}F $notices"
                elif [[ $temperature -gt $4 ]]; then
                        ((warnings++))
                        notices="$sensorname reads ${temperature}F $notices"
                fi
        done < <(snmpwalk -v 1 -c $1 $2 1.3.6.1.4.1.318.1.1.10.2.3.2.1.4)

        if [[ $criticals -gt 0 ]]; then
                echo "Critical: $notices|$perfdata"
                exit 2
        elif [[ $warnings -gt 0 ]]; then
                echo "Warning: $notices|$perfdata"
                exit 1
        else
                echo "OK|$perfdata"
                exit 0
        fi
else
    print_usage
    exit 3
fi
