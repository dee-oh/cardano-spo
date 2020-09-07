#!/bin/bash

. /home/carldano/_scripts/shared.sh

############################################################
## The C.A.R.L. protocol                                  ##
## @date   : 2020-08-21                                   ##
## @version: 0.3.0                                        ##
## @author : loki@thorpool.de                             ##
############################################################

LOGGER_NAME="C.A.R.L"

RELAY="relay"
PRODUCER="producer"
MAX_LOG_CHANGE_DELAY=900

############################################################

restartNode()
{
#	log $LOGGER_NAME $LOG_INFO "RESTART NODE"
	
	type=$1
	home=$2
	port=$3
	
	if [ "$type" != "$RELAY" ] && [ "$type" != "$PRODUCER" ]; then
		log $LOGGER_NAME $LOG_ERROR "Invalid node type: $type"
		return 2
	fi
	
	if [ -z $home ]; then
		log $LOGGER_NAME $LOG_ERROR "Nodes's home is missing"
		return 2
	fi
	
	if [ -z $port ]; then
		log $LOGGER_NAME $LOG_ERROR "Nodes's port is missing"
		return 2
	fi
	
#	log $LOGGER_NAME $LOG_INFO "- node type [$type]"
#	log $LOGGER_NAME $LOG_INFO "- node home [$home]"
#	log $LOGGER_NAME $LOG_INFO "- node port [$port]"
	
	#
	
	log $LOGGER_NAME $LOG_WARNING "Restarting node on port [$port]..."
	
	# Backup existing log file
	
	mv "$home/logs/node.log" "$home/logs/node_$(date +'%Y%m%d_%H%M%S').log"
	
	# Restart process
	
	if [ $type == "$RELAY" ]; then
	
		nohup "$CARDANO_NODE_BIN" run \
			--topology "$home"/mainnet-topology.json \
			--database-path "$home"/db \
			--socket-path "$home"/db/node.socket \
			--port "$port" \
			--config "$home"/mainnet-config.json > "$home"/logs/node.log &
	
	else
	
		nohup "$CARDANO_NODE_BIN" run \
		--topology "$home"/mainnet-topology.json \
		--database-path "$home"/db \
		--socket-path "$home"/db/node.socket \
		--port "$port" \
		--config "$home"/mainnet-config.json \
		--shelley-kes-key "$home"/kes.skey \
		--shelley-vrf-key "$home"/vrf.skey \
		--shelley-operational-certificate "$home"/node.cert > "$home"/logs/node.log &
	
	fi
	
	# Remember restart timestamp
	
	date +'%s' > $home/node-restart
	
	return 0
}

checkHealth()
{
#	log $LOGGER_NAME $LOG_INFO "CHECK HEALTH"

	type=$1
	home=$2
	port=$3
	name=$4
	
	if [ "$type" != "$RELAY" ] && [ "$type" != "$PRODUCER" ]; then
		log $LOGGER_NAME $LOG_ERROR "Invalid node type: $type"
		return 2
	fi
	
	if [ -z $home ]; then
		log $LOGGER_NAME $LOG_ERROR "Nodes's home is missing"
		return 2
	fi
	
	if [ -z $port ]; then
		log $LOGGER_NAME $LOG_ERROR "Nodes's port is missing"
		return 2
	fi
	
#	log $LOGGER_NAME $LOG_INFO "- node type [$type]"
#	log $LOGGER_NAME $LOG_INFO "- node home [$home]"
#	log $LOGGER_NAME $LOG_INFO "- node port [$port]"
	
	# Get pid
	
	pid=$(ps -aef | grep $home | grep -v grep | awk '{print $2}')

	if [ -z $pid ]; then
	
		log $LOGGER_NAME $LOG_ERROR "PID not found"
		
		restartNode $type $home $port
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
		
			log $LOGGER_NAME $LOG_WARNING "Restart failed for relay on port [$port]"
			return 2
			
		fi
	
	fi

	#
	
	log $LOGGER_NAME $LOG_INFO "Checking health of [$name] on port [$port] ($type, $pid)..."
	
	# Check node's last log activity

	ts=$(date +'%s')
	tsLog=$(date -r $home/logs/node.log "+%s")
	
	if [ -z $tsLog ]; then
		log $LOGGER_NAME $LOG_ERROR "Log file not found [$home/logs/node.log]"
		
		log $LOGGER_NAME $LOG_WARNING "##### LOG ALARM!!! #####"
		log $LOGGER_NAME $LOG_INFO "[W]ant [T]o [H]ave [L]og protocol activated..."
		
		kill $pid
		
		return 2
	fi
	
	lastLogUpdate=$(expr $ts - $tsLog)

	log $LOGGER_NAME $LOG_INFO "Last activity of [$name] on port [$port]: $lastLogUpdate sec. ago"

	if [ $lastLogUpdate -gt $MAX_LOG_CHANGE_DELAY ]; then
		log $LOGGER_NAME $LOG_WARNING "##### ZOMBIE ALARM!!! #####"
		log $LOGGER_NAME $LOG_INFO "[K]illing [T]he [Z]ombie protocol activated..."
		
		kill $pid
		
		return 2
	else
		log $LOGGER_NAME $LOG_INFO "[$name] seems to be fine"
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
	echo "Carl is watching the nodes. Don't mess with him!"
	echo ""
}

# Init defaults

ret=0

relay1=0
relay1Name="U.R.O."
relay1Port=""
relay2=0
relay2Name="U.R.O."
relay2Port=""
producer=0
producerName="U.P.O."
producerPort=""

#

for i in "$@"
do
 case $i in
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

log $LOGGER_NAME $LOG_INFO "------------------------------------------------------------"
log $LOGGER_NAME $LOG_INFO "Init C.A.R.L. protocol"
log $LOGGER_NAME $LOG_INFO "Carl is looking for the others..."

# Get node infos

if [ -z $CNODE_RELAY1_HOME ]; then
	relay1=0;
else
	relay1=1;
fi

if [ -z $CNODE_RELAY2_HOME ]; then
	relay2=0;
else
	relay2=1;
fi

if [ -z $CNODE_PRODUCER_HOME ]; then
	producer=0;
else
	producer=1;
fi

#

if [ $relay1 -eq 1 ]; then

	relay1Name=$( jq -r .name < $CNODE_RELAY1_HOME/node-info )
	
	if [ -z $relay1Name ]; then
		log $LOGGER_NAME $LOG_WARNING "Relay 1 name not found, using [U.R.O.] (unkown relay object)"
	fi
	
	relay1Port=$( jq -r .port < $CNODE_RELAY1_HOME/node-info )
	
	if [ -z $relay1Port ]; then
		log $LOGGER_NAME $LOG_ERROR "Relay 1 port not found"
		exit 2
	fi

fi

if [ $relay2 -eq 1 ]; then

	relay2Name=$( jq -r .name < $CNODE_RELAY2_HOME/node-info )
	
	if [ -z $relay2Name ]; then
		log $LOGGER_NAME $LOG_WARNING "Relay 2 name not found, using [U.R.O.] (unkown relay object)"
	fi
	
	relay2Port=$( jq -r .port < $CNODE_RELAY2_HOME/node-info )
	
	if [ -z $relay2Port ]; then
		log $LOGGER_NAME $LOG_ERROR "Relay 2 port not found"
		exit 2
	fi
fi

if [ $producer -eq 1 ]; then

	producerName=$( jq -r .name < $CNODE_PRODUCER_HOME/node-info )
	
	if [ -z $producerName ]; then
		log $LOGGER_NAME $LOG_WARNING "Producer name not found, using [U.P.O.] (unkown producer object)"
	fi
	
	producerPort=$( jq -r .port < $CNODE_PRODUCER_HOME/node-info )
	
	if [ -z $producerPort ]; then
		log $LOGGER_NAME $LOG_ERROR "Producer port not found"
		exit 2
	fi
fi


## Check running processes

#nodePIDs=( $(ps -C ${CARDANO_NODE_BIN} -o pid=) )
nodePIDs=( $( ps -aef | grep ${CARDANO_NODE_BIN} | grep -v "grep" | awk '{print $2}' ) )
nodeCount=${#nodePIDs[@]}

# Check if at least one process is running

if [ $nodeCount -lt 1 ]; then

	log $LOGGER_NAME $LOG_WARNING "Everybody seems to sleep!"
	
	# TODO: Check CPU and RAM
	
	
	#
	
	log $LOGGER_NAME $LOG_INFO "[W]ake [U]p [A]larm protocol activated..."

	if [ $relay1 -eq 1 ]; then
	
		# Start relay 1
		
		restartNode $RELAY $CNODE_RELAY1_HOME $relay1Port
		ret=$?
		
		if [ $ret -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for relay 1 on port [$relay1Port]"
			log $LOGGER_NAME $LOG_INFO "W.U.A. protocol failed...i'm sad"
			return $ret
		fi
	
	fi
	
	if [ $relay2 -eq 1 ]; then
	
		# Start relay 2
		
		restartNode $RELAY $CNODE_RELAY2_HOME $relay2Port
		ret=$?
		
		if [ $ret -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for relay 2 on port [$relay2Port]"
			log $LOGGER_NAME $LOG_INFO "W.U.A. protocol failed...i'm sad"
			return $ret
		fi
	
	fi
	
	if [ $producers -eq 1 ]; then
	
		# Start producer
		
		restartNode $PRODUCER $CNODE_PRODUCER_HOME $producerPort
		ret=$?
		
		if [ $ret -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for producer on port [$producerPort]"
			log $LOGGER_NAME $LOG_INFO "W.U.A. protocol failed...i'm sad"
			return $ret
		fi
	
	fi
	
	log $LOGGER_NAME $LOG_INFO "W.U.A. protocol executed successfully (done)."
	
	exit
	
else

	log $LOGGER_NAME $LOG_INFO "Activities detected: $nodeCount"
	
	for idx in ${!nodePIDs[@]}; do
		log $LOGGER_NAME $LOG_INFO "- PID: ${nodePIDs[idx]}"
	done
	
fi

## Check health

#log $LOGGER_NAME $LOG_INFO "Checking health..."

# Check health of relay 1

if [ $relay1 -eq 1 ]; then

#	log $LOGGER_NAME $LOG_INFO "[relay 1]"

	checkHealth $RELAY $CNODE_RELAY1_HOME $relay1Port $relay1Name
	ret=$?
	
	if [ $ret -eq "2" ]; then
	
		log $LOGGER_NAME $LOG_WARNING "Health check failed for relay 1 on port [$relay1Port]"
		
		# Check CPU and RAM
		
		
		#
		
		restartNode $RELAY $CNODE_RELAY1_HOME $relay1Port
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for relay 1 on port [$relay1Port]"
		fi
	
	fi
	
fi

# Check health of relay 2

if [ $relay2 -eq 1 ]; then

#	log $LOGGER_NAME $LOG_INFO "[relay 2]"

	checkHealth $RELAY $CNODE_RELAY2_HOME $relay2Port $relay2Name
	ret=$?
	
	if [ "$ret" -eq "2" ]; then
	
		log $LOGGER_NAME $LOG_WARNING "Health check failed for relay 2 on port [$relay2Port]"
		
		# Check CPU and RAM
		
		
		#
		
		restartNode $RELAY $CNODE_RELAY2_HOME $relay2Port
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for relay 2 on port [$relay2Port]"
		fi
	
	fi
	
fi

# Check health of producer 

if [ $producer -eq 1 ]; then

#	log $LOGGER_NAME $LOG_INFO "[producer]"
	
	checkHealth $PRODUCER $CNODE_PRODUCER_HOME $producerPort $producerName
	ret=$?
	
	if [ "$ret" -eq "2" ]; then
	
		log $LOGGER_NAME $LOG_WARNING "Health check failed for producer on port [$producerPort]"
		
		# Check CPU and RAM
		
		
		#
		
		restartNode $PRODUCER $CNODE_PRODUCER_HOME $producerPort
		ret=$?
		
		if [ "$ret" -eq "2" ]; then
			log $LOGGER_NAME $LOG_WARNING "Restart failed for producer on port [$producerPort]"
		fi
	fi
	
fi

# Done

log $LOGGER_NAME $LOG_INFO "mic drop (done)."

