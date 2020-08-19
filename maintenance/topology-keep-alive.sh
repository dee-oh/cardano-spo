#!/bin/bash

############################################################
## T.K.A.G. - The topology keep alive guard               ##
## @date   : 2020-08-16                                   ##
## @version: 0.1.0                                        ##
## @author : loki@thorpool.de                             ##
############################################################

export PATH="~/.local/bin:$PATH"
LOGGER_NAME="T.K.A.G."

## Log level

LOG_VERBOSE="[VRB]"
LOG_INFO="[INF]"
LOG_WARNING="[WRN]"
LOG_ERROR="[ERR]"

## Constant values

CARDANO_CLI_BIN="cardano-cli-1.18.0"
CNODE_RELAY_HOME="/home/ubuntu/relay"
CNODE_VALENCY=1   # optional for multi-IP hostnames

# Helper

log()
{
	logName=$1
	logLevel=$2
	logMsg=$3
	datetime=$(date +'%Y-%m-%d %H:%M:%S')
	echo "$datetime	[$logName]	$logLevel	$logMsg"
}

############################################################

printHelp()
{
	echo ""
	echo "############################################################"
	echo "## T.K.A.G. - The topology keep alive guard               ##"
	echo "############################################################"
	echo ""
	echo "Script to send keep alive signal to https://api.clio.one/htopology/v1/"
	echo ""
	echo "Usage:"
	echo -e '	--relay-port   	Port of the relay node'
	echo -e '	--relay-ip     	Public IP address of the relay node'
	echo -e '	--h            	Print this message and exit'
	echo ""
}

cnodeRelayPort=""
cnodeRelayIP=""

for i in "$@"
do
 case $i in
  --relay-port=*)
   cnodeRelayPort="${i#*=}"
  ;;
  --relay-ip=*)
   cnodeRelayIP="${i#*=}"
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

#if [ -z "$cnodeRelayIP" ]; then
#	log $LOGGER_NAME $LOG_ERROR "Relay IP is missing"
#	exit 1
#fi

############################################################

log $LOGGER_NAME $LOG_INFO "Relay port [$cnodeRelayPort]"
log $LOGGER_NAME $LOG_INFO "Relay's public IP address [$cnodeRelayIP]"

# Get network magic

networkMagic=$(jq -r .networkMagic < $CNODE_RELAY_HOME/mainnet-shelley-genesis.json)

log $LOGGER_NAME $LOG_INFO "Network magic [$networkMagic]"

# Get current slot number

export CARDANO_NODE_SOCKET_PATH="$CNODE_RELAY_HOME/db/node.socket"

blockNo=$(${CARDANO_CLI_BIN} shelley query tip --mainnet | jq -r .blockNo )

log $LOGGER_NAME $LOG_INFO "Current block number [$blockNo]"

# Send request

if [ -z "$cnodeRelayIP" ]; then
	hostname=''
else
	hostname="&hostname=${cnodeRelayIP}"
fi

# Note:
# if you run your node in IPv4/IPv6 dual stack network configuration and want announced the
# IPv4 address only please add the -4 parameter to the curl command below  (curl -4 -s ...)
 
response=$(curl -s "https://api.clio.one/htopology/v1/?port=${cnodeRelayPort}&blockNo=${blockNo}&valency=${CNODE_VALENCY}&magic=${networkMagic}${hostname}")
log $LOGGER_NAME $LOG_INFO "Response [$response]"

exit
