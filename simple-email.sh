#!/bin/sh
#
# HTML email notification script for Nagios - optomized for mobile client reading (short messages)
#
# Do edit the message the bottom of this script to fit your organization
#
# Last modified by Jake Paulus - 20111213

# Do not use a trailing slash
tmpfolder="/tmp/nagios"
logging='false' # 'true' or 'false'
logfile='/tmp/nagios/jaketest.log'


#---------------------------------------
# Figure out what to output
#---------------------------------------
case $1 in
    'service')
        STATE="$NAGIOS_SERVICESTATE"
        MAIL_SUBJECT="$NAGIOS_HOSTNAME/$NAGIOS_SERVICEDESC"
        ACK_COMMENT="$NAGIOS_SERVICEACKCOMMENT - $NAGIOS_SERVICEACKAUTHOR"
        case $STATE in
            'OK')
		if [ -f $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC ]; then
			downtime=`cat $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC | grep downtime | awk '{print $2}'`
			mtime=`cat $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC | grep mtime | awk '{print $2}'`
			timedifference=`echo "$NAGIOS_TIMET - $mtime" | bc`
			downtime=`echo "($downtime + $timedifference) / 60" | bc`
		else
			downtime="UNKNOWN-$NAGIOS_LASTSERVICEPROBLEMID"
			if [[ $logging == 'true' ]]; then
				echo "$(date) - Recovery UNKNOWN $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC \
				for $NAGIOS_HOSTNAME" >> $logfile
			fi

		fi	
                TIME_MESSAGE="The service was $NAGIOS_LASTSERVICESTATE for $downtime minutes"
            ;;
            *)
		echo "# This is a state file used to calculate service \
		      outage" > $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC
		echo "# lengths for recovery notifications" >> $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC
		echo "downtime: $NAGIOS_SERVICEDURATIONSEC" >> $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC
		echo "mtime: $NAGIOS_TIMET" >> $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC
		if [[ $logging == 'true' ]]; then
			echo "$(date) - Updated $tmpfolder/state_$NAGIOS_HOSTNAME:$NAGIOS_SERVICEDESC for \
			$NAGIOS_HOSTNAME/$NAGIOS_SERVICEDESC" >> $logfile
		fi
                TIME_MESSAGE="This problem has been ongoing for $NAGIOS_SERVICEDURATION"
            ;;
        esac
    ;;
    'host')
        STATE="$NAGIOS_HOSTSTATE"
        MAIL_SUBJECT="$NAGIOS_HOSTNAME"
        ACK_COMMENT="$NAGIOS_HOSTACKCOMMENT - $NAGIOS_HOSTACKAUTHOR"
        case $STATE in
            'UP')
                if [ -f $tmpfolder/state_$NAGIOS_HOSTNAME ]; then
			downtime=`cat $tmpfolder/state_$NAGIOS_HOSTNAME | grep downtime | awk '{print $2}'`
			mtime=`cat $tmpfolder/state_$NAGIOS_HOSTNAME | grep mtime | awk '{print $2}'`
			timedifference=`echo "$NAGIOS_TIMET - $mtime" | bc`
			downtime=`echo "($downtime + $timedifference) / 60" | bc`
		else
			if [[ $logging == 'true' ]]; then
				echo "$(date) - Recovery UNKNOWN $tmpfolder/state_$NAGIOS_HOSTNAME \
				for $NAGIOS_HOSTNAME" >> $logfile
			fi
			downtime="UNKNOWN-$NAGIOS_LASTHOSTPROBLEMID"
		fi
                TIME_MESSAGE="The host was $NAGIOS_LASTHOSTSTATE for $downtime minutes"
            ;;
            *)
		echo "# This is a state file used to calculate host outage" > $tmpfolder/state_$NAGIOS_HOSTNAME
		echo "# lengths for recovery notifications" >> $tmpfolder/state_$NAGIOS_HOSTNAME
		echo "downtime: $NAGIOS_HOSTDURATIONSEC" >> $tmpfolder/state_$NAGIOS_HOSTNAME
		echo "mtime: $NAGIOS_TIMET" >> $tmpfolder/state_$NAGIOS_HOSTNAME
		if [[ $logging == 'true' ]]; then
			echo "$(date) - Updated $tmpfolder/state_$NAGIOS_HOSTNAME for \
			$NAGIOS_HOSTNAME" >> $logfile
		fi	
                TIME_MESSAGE="This problem has been ongoing for $NAGIOS_HOSTDURATION"
            ;;
        esac
    ;;
    *) exit 1;;
esac

if [[ $NAGIOS_NOTIFICATIONTYPE == "RECOVERY" ]] ; then
    MAIL_SUBJECT="$MAIL_SUBJECT RECOVERY after $downtime mins"
else
    MAIL_SUBJECT="$MAIL_SUBJECT is $STATE"
fi

#---------------------------------------
# Compose and send the email
#---------------------------------------

# itsupport is this helpdesk contact. This tells the helpdesk that the alert was for NetworkAdmins for example
supportgroup=`echo $NAGIOS_NOTIFICATIONRECIPIENTS | sed 's/itsupport//' | sed 's/,//'`

(
    echo "From: nagios@myserver.example.com"
    echo "To: $NAGIOS_CONTACTEMAIL"
    echo "Subject: $MAIL_SUBJECT"
    echo "Mime-Version: 1.0"
    echo "Content-type: text/html"
    echo "<html>"
    echo "<body>"
    echo "<p>Alert Type: $NAGIOS_NOTIFICATIONTYPE<br />"
    echo "Host description: $NAGIOS_HOSTALIAS<br />"
    echo "$TIME_MESSAGE</p>"

    if [[ $NAGIOS_NOTIFICATIONTYPE == "ACKNOWLEDGEMENT" ]] ; then 
        echo "<p>Acknowledgement: $ACK_COMMENT</p>"
    fi
    
    if [[ $1 == 'service' ]] ; then
        echo "<p>Detail:<br />"
        echo "$NAGIOS_SERVICEOUTPUT<br />"
	echo "$NAGIOS_LONGSERVICEOUTPUT</p>"
    fi

    echo "<p>This event should probably be handled by $supportgroup</p>"

    echo "Notification sent: $NAGIOS_LONGDATETIME</p>"
    echo "</body>"
    echo "</html>"

) | /usr/sbin/sendmail -f nagios@myserver.example.com -t 
