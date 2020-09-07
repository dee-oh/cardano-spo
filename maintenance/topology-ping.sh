#!/bin/bash

. /home/carldano/_scripts/shared.sh

############################################################
## T.O.P.I. - The topology ping tool                      ##
## @date   : 2020-08-21                                   ##
## @version: 0.2.0                                        ##
## @author : loki@thorpool.de                             ##
############################################################

LOGGER_NAME="T.O.P.I."

CNODE_VALENCY=2

############################################################

printHelp()
{
	echo ""
	echo "############################################################"
	echo "## T.O.P.I. - The topology ping tool                      ##"
	echo "############################################################"
	echo ""
	echo "Script to send some kind of i'm alive signal to https://api.clio.one/htopology/v1/"
	echo ""
	echo "Usage:"
	echo -e '	--relay-no  Number of the relay node to use (default=1, possible values: 1 or 2)'
	echo -e '	--host      Public IP address of the relay node'
	echo -e '	--h         Print this message and exit'
	echo ""
}

# Init defaults

relayNo=1
host=""

#

for i in "$@"
do
 case $i in
  --relay-no=*)
   relayNo="${i#*=}"
  ;;
  --host=*)
   host="${i#*=}"
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

if [ $relayNo -ne 1 ] && [ $relayNo -ne 2 ]; then
	log $LOGGER_NAME $LOG_ERROR "Invalid relay number [$relayNo]"
	exit 1
fi

############################################################

log $LOGGER_NAME $LOG_INFO "------------------------------------------------------------"
log $LOGGER_NAME $LOG_INFO "Init T.O.P.I. protocol"


relayPort=$CNODE_RELAY1_PORT
relayHome=$CNODE_RELAY1_HOME

if [ $relayNo -eq 2 ]; then
	relayPort=$CNODE_RELAY2_PORT
	relayHome=$CNODE_RELAY2_HOME
fi

log $LOGGER_NAME $LOG_INFO "Relay No. [$relayNo]"
log $LOGGER_NAME $LOG_INFO "Relay port [$relayPort]"
log $LOGGER_NAME $LOG_INFO "Relay's public IP address [$host]"

# Get network magic

networkMagic=$(jq -r .networkMagic < $relayHome/mainnet-shelley-genesis.json)

log $LOGGER_NAME $LOG_INFO "Network magic [$networkMagic]"

# Get current slot number

export CARDANO_NODE_SOCKET_PATH="$relayHome/db/node.socket"

blockNo=$(${CARDANO_CLI_BIN} shelley query tip --mainnet | jq -r .blockNo )

log $LOGGER_NAME $LOG_INFO "Current block number [$blockNo]"

# Prepare hostname/ip

if [ -z "$cnodeRelayIP" ]; then
	hostname=''
else
	hostname="&hostname=${cnodeRelayIP}"
fi

# Note:
# if you run your node in IPv4/IPv6 dual stack network configuration and want announced the
# IPv4 address only please add the -4 parameter to the curl command below  (curl -4 -s ...)
 
response=$(curl -s "https://api.clio.one/htopology/v1/?port=${relayPort}&blockNo=${blockNo}&valency=${CNODE_VALENCY}&magic=${networkMagic}${hostname}")
log $LOGGER_NAME $LOG_INFO "Response [$response]"

exit
