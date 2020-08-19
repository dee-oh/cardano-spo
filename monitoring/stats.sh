#!/bin/bash

############################################################
## Get statistics script                                  ##
## @date   : 2020-08-16                                   ##
## @version: 0.1.0                                        ##
## @author : loki@thorpool.de                             ##
############################################################

export PATH="~/.local/bin:$PATH"
LOGGER_NAME="C.A.R.L"

## Log level

LOG_VERBOSE="[VRB]"
LOG_INFO="[INF]"
LOG_WARNING="[WRN]"
LOG_ERROR="[ERR]"

## Constant values

CARDANO_CLI_BIN="cardano-cli-1.18.0"
CARDANO_NODE_BIN="cardano-node-1.18.0"
CNODE_RELAY_HOME="/home/ubuntu/relay"

export CARDANO_NODE_SOCKET_PATH="$CNODE_RELAY_HOME/db/node.socket"

############################################################

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
	echo $(printf "%d hrs. %d min. %d sec." $h $m $s)
}

getPercentage()
{
	echo $(awk "BEGIN {printf \"%.2f\",(${1}/${2})*100}")
}

quote () { 
    local quoted=${1//\'/\'\\\'\'};
    printf "'%s'" "$quoted"
}

############################################################

curTime=$(date +'%s')

# Start JSON

json="{\"health\":{"

## System health

	created=$(date +'%Y-%m-%d %H:%M:%S')

	json="${json}\"created\":\"$created\""

	# Open system JSON
	
	json="${json},\"system\":{"

	# Uptime

	uptimeSinceUTC=$(uptime -s)
	uptimeSince=$(date -d "$uptimeSinceUTC" "+%s")
	uptime=$(expr $curTime - $uptimeSince)
	uptimeP=$(formatSec $uptime)

	json="${json}\"uptime\":${uptime},\"uptimePretty\":\"${uptimeP}\""
#	log $LOGGER_NAME $LOG_INFO "System uptime: $uptimeP"

	# CPU Load

	cpuLoad1=$(uptime | awk '{print $(NF-2)}')
	cpuLoad1=${cpuLoad1:0:-1}
	cpuLoad5=$(uptime | awk '{print $(NF-1)}')
	cpuLoad5=${cpuLoad5:0:-1}
	cpuLoad15=$(uptime | awk '{print $(NF)}')
	cpuLoad15=${cpuLoad15:0:-1}

	json="${json},"
	json="${json}\"cpuLoad\":${cpuLoad1},\"cpuLoad5\":${cpuLoad5},\"cpuLoad15\":${cpuLoad5}"

#	log $LOGGER_NAME $LOG_INFO "CPU load (last minute): $cpuLoad1"
#	log $LOGGER_NAME $LOG_INFO "CPU load (last 5 minutes): $cpuLoad5"
#	log $LOGGER_NAME $LOG_INFO "CPU load (last 15 minutes): $cpuLoad15"

	# Memory usage

	memTotal=$(free -b | awk 'NR==2{print $2}')
	memUsed=$(free -b | awk 'NR==2{print $3}')
	memUsedP=$(getPercentage $memUsed $memTotal)

	json="${json},"
	json="${json}\"memTotal\":${memTotal},\"memUsed\":${memUsed},\"memUsage\":${memUsedP}"
#	log $LOGGER_NAME $LOG_INFO "Memory usage: [$memUsed] of [$memTotal] ($memUsedP%)"

	# Disc usage

	discTotal=$(df | awk '$NF=="/" {print $2}')
	discUsed=$(df | awk '$NF=="/" {print $3}')
	discUsedP=$(getPercentage $discUsed $discTotal)

	json="${json},"
	json="${json}\"discTotal\":${discTotal},\"discUsed\":${discUsed},\"discUsage\":${discUsedP}"
#	log $LOGGER_NAME $LOG_INFO "Disc usage: [$discUsed] of [$discTotal] ($discUsedP%)"

	# Close system JSON
	
	json="${json}}"

	# Open network JSON
	
	json="${json},"
	json="${json}\"network\":{"
	
	networkId=$(cat ${CNODE_RELAY_HOME}/mainnet-shelley-genesis.json | grep networkId | awk '{print $2}')
	networkId=${networkId:1:-2}
	
	json="${json}\"networkId\":\"${networkId}\""
#	log $LOGGER_NAME $LOG_INFO "Network ID: [$networkId]"

	slotsPerEpoch=$(cat ${CNODE_RELAY_HOME}/mainnet-shelley-genesis.json | grep epochLength | awk '{print $2}')
	slotsPerEpoch=${slotsPerEpoch:0:-1}
	
	json="${json},"
	json="${json}\"slotsPerEpoch\":${slotsPerEpoch}"
#	log $LOGGER_NAME $LOG_INFO "Slots per epoch: [$slotsPerEpoch]"

	curSlot=$(${CARDANO_CLI_BIN} shelley query tip --mainnet | jq -r .slotNo )
	
	json="${json},"
	json="${json}\"curSlot\":${curSlot}"
#	log $LOGGER_NAME $LOG_INFO "Current slot: [$curSlot]"

	curBlock=$(${CARDANO_CLI_BIN} shelley query tip --mainnet | jq -r .blockNo )
	
	json="${json},"
	json="${json}\"curBlock\":${curBlock}"
#	log $LOGGER_NAME $LOG_INFO "Current block: [$curBlock]"

		# Open KES JSON
		
		json="${json},"
		json="${json}\"KES\":{"

		slotsPerKESPeriod=$(cat ${CNODE_RELAY_HOME}/mainnet-shelley-genesis.json | grep slotsPerKESPeriod | awk '{print $2}')
		slotsPerKESPeriod=${slotsPerKESPeriod:0:-1}

		json="${json}\"slotsPerKESPeriod\":${slotsPerKESPeriod}"
#		log $LOGGER_NAME $LOG_INFO "Slots per KES period: [$slotsPerKESPeriod]"

		maxKESEvolutions=$(cat ${CNODE_RELAY_HOME}/mainnet-shelley-genesis.json | grep maxKESEvolutions | awk '{print $2}')
		maxKESEvolutions=${maxKESEvolutions:0:-1}

		json="${json},"
		json="${json}\"maxKESEvolutions\":${maxKESEvolutions}"
#		log $LOGGER_NAME $LOG_INFO "Max KES evolutions: [$maxKESEvolutions]"

		curKESPeriod=$(expr ${curSlot} / ${slotsPerKESPeriod})

		json="${json},"
		json="${json}\"curKESPeriod\":${curKESPeriod}"
#		log $LOGGER_NAME $LOG_INFO "Current KES period: [$curKESPeriod]"

		# Close KES JSON
		
		json="${json}}"

	# Close network JSON
	
	json="${json}}"

###########################################################

# Get path of running nodes

	# Open nodes JSON
	
	json="${json},"
	json="${json}\"nodes\":["

	nodePaths=( $(ps -aef | grep cardano | grep -v grep | awk '{print $13}') )

	for idx in ${!nodePaths[@]}; do

#		log $LOGGER_NAME $LOG_INFO "## Node #$((idx+1)):"
		
		# Open node JSON
		
		if [ "$idx" -gt 0 ]; then
			json="${json},"
		fi
		
		json="${json}{"

			curNodePath=${nodePaths[idx]:0:-3}
			curNodeName=$(cat $curNodePath/node-name)
			
			json="${json}\"nodeName\":\"${curNodeName}\""
#			log $LOGGER_NAME $LOG_INFO "Node name: [$curNodeName]"
			
			lastRestart=$(cat $curNodePath/node-restart)
			lastRestartUTC=""

			if [ -z $lastRestart ]; then
				lastRestart=0
				nodeUpTime=0
			else
				nodeUpTime=$(expr $curTime - $lastRestart)
				lastRestartUTC=$(date -d@$lastRestart -u +"%Y-%m-%d %H:%M:%S")
			fi

			nodeUpTimeP=$(formatSec $nodeUpTime)
			
			json="${json},"
			json="${json}\"lastRestart\":${lastRestart},\"lastRestartPretty\":\"$lastRestartUTC\""
#			log $LOGGER_NAME $LOG_INFO "Last restart: [$lastRestart] [$lastRestartUTC]"

			json="${json},"
			json="${json}\"nodeUpTime\":${nodeUpTime}, \"nodeUpTimePretty\":\"${nodeUpTimeP}\""
#			log $LOGGER_NAME $LOG_INFO "Up time (node): [$nodeUpTime] [$nodeUpTimeP]"

			curLogTime=$(date -r $curNodePath/logs/node.log "+%s")
			lastLogUpdate=$(expr $curTime - $curLogTime)

			# Compare second and last log timestamp

			firstLineDateUTC=$(cat $curNodePath/logs/node.log | head -2 | tail -1 | awk '{print $2}')
			firstLineDateUTC=${firstLineDateUTC:1}
			firstLineTimeUTC=$(cat $curNodePath/logs/node.log | head -2 | tail -1 | awk '{print $3}')

			json="${json},"
			json="${json}\"nodeRunningSince\":\"$firstLineDateUTC $firstLineTimeUTC\""

			firstLineTime=$(date -d "$firstLineDateUTC $firstLineTimeUTC" +%s)

			lastLineDateUTC=$(cat $curNodePath/logs/node.log | tail -1 | awk '{print $2}')
			lastLineDateUTC=${lastLineDateUTC:1}
			lastLineTimeUTC=$(cat $curNodePath/logs/node.log | tail -1 | awk '{print $3}')

			lastLineTime=$(date -d "$lastLineDateUTC $lastLineTimeUTC" +%s)

			lastLogUpdate=$(expr $curTime - $lastLineTime)

			logUpTime=$(expr $lastLineTime - $firstLineTime)
			logUpTimeP=$(formatSec $logUpTime)

			json="${json},"
			json="${json}\"lastActivity\":$lastLineTime,\"lastActivityAgo\":$lastLogUpdate,\"lastActivityPretty\":\"$lastLineDateUTC $lastLineTimeUTC\",\"nodeUpTimeLog\":$logUpTime, \"nodeUpTimeLogPretty\":\"$logUpTimeP\""
#			log $LOGGER_NAME $LOG_INFO "Up time (log): [$lastLineTime] [$lastLineDateUTC $lastLineTimeUTC] [$logUpTime] [$logUpTimeP]"

			# Count Log entries

			logLinesTotal=$(cat $curNodePath/logs/node.log | wc -l)
			logLinesNotice=$(cat $curNodePath/logs/node.log | grep :Notice: | wc -l)
			logLinesInfo=$(cat $curNodePath/logs/node.log | grep :Info: | wc -l)
			logLinesWarning=$(cat $curNodePath/logs/node.log | grep :Warning: | wc -l)
			logLinesError=$(cat $curNodePath/logs/node.log | grep :Error: | wc -l)
			
			logLinesNoticeP=$(getPercentage $logLinesNotice $logLinesTotal)
			logLinesInfoP=$(getPercentage $logLinesInfo $logLinesTotal)
			logLinesWarningP=$(getPercentage $logLinesWarning $logLinesTotal)
			logLinesErrorP=$(getPercentage $logLinesError $logLinesTotal)
			
			json="${json},\"logLinesTotal\":$logLinesTotal"
			
			json="${json},\"logLinesNotice\":$logLinesNotice"
			json="${json},\"logLinesNoticeQuota\":\"$logLinesNoticeP\""
			
			json="${json},\"logLinesInfo\":$logLinesInfo"
			json="${json},\"logLinesInfoQuota\":\"$logLinesInfoP\""
			
			json="${json},\"logLinesWarning\":$logLinesWarning"
			json="${json},\"logLinesWarningQuota\":\"$logLinesWarningP\""
			
			json="${json},\"logLinesError\":$logLinesError"
			json="${json},\"logLinesErrorQuota\":\"$logLinesErrorP\""
			
			# Get last error
			
			lastError=$(cat relay/logs/node.log | grep :Error: | tail -1 | awk '{print $1}')
			lastError=${lastError:5:-4}
			
			lastErrorDate=$(cat relay/logs/node.log | grep :Error: | tail -1 | awk '{print $2}')
			lastErrorDate=${lastErrorDate:1}
			lastErrorTimeUTC=$(cat relay/logs/node.log | grep :Error: | tail -1 | awk '{print $3}')

			lastErrorTime=$(date -d "$lastErrorDate $lastErrorTimeUTC" +%s)
			lastErrorSeconds=$(expr $curTime - $lastErrorTime)
			lastErrorP=$(formatSec $lastErrorSeconds)
		
			json="${json},\"lastErrorTime\":$lastErrorTime"
			json="${json},\"lastErrorTimePretty\":\"$lastErrorDate $lastErrorTimeUTC\""
			json="${json},\"lastErrorAgo\":\"$lastErrorP\""
			json="${json},\"lastError\":\"$lastError\""
		
		# Close node JSON
		
		json="${json}}"
		
	done


	# Close network JSON
	
	json="${json}]"

# Close JSON

json="${json}}}"

echo $json
