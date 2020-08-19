#!/bin/bash

############################################################
## The C.A.R.L. protocol                                  ##
## @date   : 2020-08-16                                   ##
## @version: 0.2.0                                        ##
## @author : loki@thorpool.de                             ##
############################################################

export PATH=~/.local/bin:~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

#export PATH="~/.local/bin:$PATH"
LOGGER_NAME="C.A.R.L"

## Log level

LOG_VERBOSE="[VRB]"
LOG_INFO="[INF]"
LOG_WARNING="[WRN]"
LOG_ERROR="[ERR]"

## Node types

RELAY="relay"
PRODUCER="producer"

## Constant values

CARDANO_BIN="cardano-node-1.18.0"

CNODE_RELAY_HOME="/home/ubuntu/relay"
CNODE_PRODUCER_HOME="/home/ubuntu/producer"

MAX_LOG_CHANGE_DELAY=900

# Default values

skipProducer=1

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
	return $(printf "%02d:%02d:%05.2f\n" $h $m $s)
}

restartRelay()
{
	port=$1
	
	if [ -z "$port" ]; then
		log $LOGGER_NAME $LOG_ERROR "Port is missing"
		return 2
	fi
	
	log $LOGGER_NAME $LOG_WARNING "Restarting [$RELAY] node on port [$port]..."
	
	# Backup existing log file
	mv "$CNODE_RELAY_HOME/logs/node.log" "$CNODE_RELAY_HOME/logs/node_$(date +'%Y%m%d_%H%M%S').log"
	
	# Restart process
	nohup "$CARDANO_BIN" run \
		--topology "$CNODE_RELAY_HOME"/mainnet-topology.json \
		--database-path "$CNODE_RELAY_HOME"/db \
		--socket-path "$CNODE_RELAY_HOME"/db/node.socket \
		--port "$port" \
		--config "$CNODE_RELAY_HOME"/mainnet-config.json > "$CNODE_RELAY_HOME"/logs/node.log &
		
	# Remember restart timestamp
	date +'%s' > $CNODE_RELAY_HOME/node-restart
	
	return 0
}

restartProducer()
{
	port=$1
	
	if [ -z "$port" ]; then
		log $LOGGER_NAME $LOG_ERROR "Port is missing."
		return 2
	fi
	
	log $LOGGER_NAME $LOG_WARNING "Restarting [$PRODUCER] node on port [$port]..."
	
	# Backup existing log file
	mv "$CNODE_PRODUCER_HOME/logs/node.log" "$CNODE_PRODUCER_HOME/logs/node_$(date +'%Y%m%d_%H%M%S').log"
	
	# Restart process
	nohup "$CARDANO_BIN" run \
	--topology "$CNODE_PRODUCER_HOME"/mainnet-topology.json \
	--database-path "$CNODE_PRODUCER_HOME"/db \
	--socket-path "$CNODE_PRODUCER_HOME"/db/node.socket \
	--port "$port" \
	--config "$CNODE_PRODUCER_HOME"/mainnet-config.json \
	--shelley-kes-key "$CNODE_PRODUCER_HOME"/kes.skey \
	--shelley-vrf-key "$CNODE_PRODUCER_HOME"/vrf.skey \
	--shelley-operational-certificate "$CNODE_PRODUCER_HOME"/node.cert > "$CNODE_PRODUCER_HOME"/logs/node.log &
	
	# Remember restart timestamp
	date +'%s' > $CNODE_RELAY_HOME/node-restart
	
	return 0
}

checkHealth()
{
	curNodeType=$1
	
	if [ "$curNodeType" == "$RELAY" ]; then
		curNodePath=$CNODE_RELAY_HOME
	elif [ "$curNodeType" == "$PRODUCER" ]; then
		curNodePath=$CNODE_PRODUCER_HOME
	else
		log $LOGGER_NAME $LOG_ERROR "Invalid node type: $1"
		return 2
	fi
	
	curNodePort=$2
	
	if [ -z "$curNodePort" ]; then
		log $LOGGER_NAME $LOG_ERROR "Port is missing"
		return 2
	fi
	
	# Get node name
	
	curNodeName=$(cat $curNodePath/node-name)
	
	if [ -z "$curNodeName" ]; then
		log $LOGGER_NAME $LOG_WARNING "Node name not found, using [U.N.O.] (unkown node object)"
		curNodeName="U.N.O."
	fi
	
	# Get pid
	
	curPID=$(ps -aef | grep $curNodePath | grep -v grep | awk '{print $2}')

	if [ -z "$curPID" ]; then
		log $LOGGER_NAME $LOG_ERROR "PID not found"
		
		return 2
	fi

	#
	
	log $LOGGER_NAME $LOG_INFO "Checking health of [$curNodeName] on port [$curNodePort] ($curNodeType, $curPID)..."
	
	# Check node's last log activity

	curTS=$(date +'%s')

	curTSLog=$(date -r $curNodePath/logs/node.log "+%s")
	
	if [ -z "$curTSLog" ]; then
		log $LOGGER_NAME $LOG_ERROR "Log file not found [$curNodePath/logs/node.log]"
		
		log $LOGGER_NAME $LOG_WARNING "##### LOG ALARM!!! #####"
		log $LOGGER_NAME $LOG_INFO "[W]ant [T]o [H]ave [L]og protocol activated..."
		
		kill $curPID
		
		return 2
	fi
	
	lastLogUpdate=$(expr $curTS - $curTSLog)

	log $LOGGER_NAME $LOG_INFO "Last activity of [$curNodeName] on port [$curNodePort]: $lastLogUpdate secconds ago"

	if [ $lastLogUpdate -gt $MAX_LOG_CHANGE_DELAY ]; then
		log $LOGGER_NAME $LOG_WARNING "##### ZOMBIE ALARM!!! #####"
		log $LOGGER_NAME $LOG_INFO "[K]illing [T]he [Z]ombie protocol activated..."
		
		kill $curPID
		
		return 2
	else
		log $LOGGER_NAME $LOG_INFO "[$curNodeName] seems to be fine"
	fi
	
	return 0
}

############################################################

printHelp()
{
	echo ""
	echo "############################################################"
	echo "## The C.A.R.L. protocol                                  ##"
	echo "############################################################"
	echo ""
	echo "Script to check health of cardano nodes and restart them "
	echo "automatically if required."
	echo ""
	echo "Usage:"
	echo -e '	--relay-port   	Port of the relay node'
	echo -e '	--producer-port	Port of the producer node'
	echo -e '	--h            	Print this message and exit'
	echo ""
}

cnodeRelayPort=""
cnodeProducerPort=""
ret=0

for i in "$@"
do
 case $i in
  --relay-port=*)
   cnodeRelayPort="${i#*=}"
  ;;
  --producer-port=*)
   cnodeProducerPort="${i#*=}"
  ;;
  --h|--help)
   printHelp
   exit
  ;;
  *)
   echo "unknown option";
   exit
  ;;
esac
done

if [ -z "$cnodeRelayPort" ]; then
	log $LOGGER_NAME $LOG_ERROR "Relay port is missing"
	exit 1
fi

if [ -z "$cnodeProducerPort" ]; then
	skipProducer=1
else
	skipProducer=0
fi


##### Entry point

log $LOGGER_NAME $LOG_INFO "------------------------------------------------------------"
log $LOGGER_NAME $LOG_INFO "Init C.A.R.L. protocol"

if [ "$skipProducer" -eq 1 ]; then
	log $LOGGER_NAME $LOG_INFO "Mode: Check relay only"
else
	log $LOGGER_NAME $LOG_INFO "Mode: Check relay and producer"
	
fi

##

log $LOGGER_NAME $LOG_INFO "C.A.R.L. is looking for the others..."

# Get process id(s)

nodePIDs=( $(ps -C ${CARDANO_BIN} -o pid=) )

# Amount of running processes

nodeCount=${#nodePIDs[@]}

# Check if at least one process is running

if [ $nodeCount -lt 1 ]; then
	log $LOGGER_NAME $LOG_WARNING "##### Everybody is sleeping! #####"
	log $LOGGER_NAME $LOG_INFO "[W]ake [U]p [A]larm protocol activated..."
	
	if [ "$skipProducer" -eq 1 ]; then
		restartRelay $cnodeRelayPort
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for [$RELAY] on port [$cnodeRelayPort]"
		fi
	else
		restartRelay $cnodeRelayPort
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for [$RELAY] on port [$cnodeRelayPort]"
		fi
		
		restartProducer $cnodeProducerPort
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for [$PRODUCER] on port [$cnodeProducerPort]"
		fi
		
	fi
	
	log $LOGGER_NAME $LOG_INFO "W.U.A. protocol executed"
	
	exit
else
	log $LOGGER_NAME $LOG_INFO "Activities detected: $nodeCount"
	
	for idx in ${!nodePIDs[@]}; do
		log $LOGGER_NAME $LOG_INFO "- PID: ${nodePIDs[idx]}"
	done
fi

# Check relay health

log $LOGGER_NAME $LOG_INFO "Checking relay health..."

checkHealth $RELAY $cnodeRelayPort
ret=$?

if [ "$ret" -eq "2" ]; then
	log $LOGGER_NAME $LOG_WARNING "Health check failed for [$RELAY] on port [$cnodeRelayPort]"
	
	restartRelay $cnodeRelayPort
	ret=$?
	
	if [ "$ret" -eq "2" ]; then
		log $LOGGER_NAME $LOG_WARNING "Restart failed for [$RELAY] on port [$cnodeRelayPort]"
	fi
fi

# Check producer health

if [ "$skipProducer" -ne 1 ]; then

	log $LOGGER_NAME $LOG_INFO "Checking producer health..."
	
	checkHealth $PRODUCER $cnodeProducerPort
	ret=$?
	
	if [ "$ret" -eq "2" ]; then
		log $LOGGER_NAME $LOG_WARNING "Health check failed for [$PRODUCER] on port [$cnodeProducerPort]"
		
		restartProducer $cnodeProducerPort
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for [$PRODUCER] on port [$cnodeProducerPort]"
		fi
	fi
fi

# Done

log $LOGGER_NAME $LOG_INFO "mic drop (done)"
