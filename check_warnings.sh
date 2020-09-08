#!/bin/bash

countWarnings=$(/usr/local/nagios/bin/nagiostats | grep "Ok/Warn/Unk/Crit:" | sed 's/[[:space:]]//g' | cut -d"/" -f5)

if (($countWarnings<=5)); then
                echo "OK - $countWarnings services in Warning state"
                exit 0
        elif ((6<=$countWarnings && $countWarnings<=30)); then
				# This case makes no sense because it only adds one warning.
				# It is just to make an example on all possible exits.
                echo "WARNING - $countWarnings services in Warning state"
                exit 1
        elif ((30<=$countWarnings)); then
                echo "CRITICAL - $countWarnings services in Warning state"
                exit 2
        else
                echo "UNKNOWN - $countWarnings"
                exit 3
fi