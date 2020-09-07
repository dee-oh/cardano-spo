#!/bin/bash

. /home/carldano/.bashrc

## Log level

LOG_VERBOSE="[VRB]"
LOG_INFO="[INF]"
LOG_WARNING="[WRN]"
LOG_ERROR="[ERR]"

# Helper

log()
{
	logName=$1
	logLevel=$2
	logMsg=$3
	datetime=$(date +'%Y-%m-%d %H:%M:%S')
	echo "$datetime	[$logName]	$logLevel	$logMsg"
}

formatSec()
{
	h=$(bc <<< "${1}/3600")
	m=$(bc <<< "(${1}%3600)/60")
	s=$(bc <<< "${1}%60")
	return $(printf "%02d:%02d:%05.2f\n" $h $m $s)
}

