#!/bin/bash

############################################################
## T.O.P.U. - The topology updater                        ##
## @date   : 2020-08-16                                   ##
## @version: 0.1.0                                        ##
## @author : loki@thorpool.de                             ##
############################################################

export PATH="~/.local/bin:$PATH"
LOGGER_NAME="T.O.P.U."

## Log level

LOG_VERBOSE="[VRB]"
LOG_INFO="[INF]"
LOG_WARNING="[WRN]"
LOG_ERROR="[ERR]"

## Constant values

CNODE_RELAY_HOME="/home/ubuntu/relay"

############################################################

log()
{
	logName=$1
	logLevel=$2
	logMsg=$3
	datetime=$(date +'%Y-%m-%d %H:%M:%S')
	echo "$datetime	[$logName]	$logLevel	$logMsg"
}

############################################################

log $LOGGER_NAME $LOG_INFO "Request current topology"

sudo curl -s -o $CNODE_RELAY_HOME/mainnet-topology.json.gen "https://api.clio.one/htopology/v1/fetch/?max=15&customPeers=172.26.11.49:3002:2|172.26.11.184:3501:2|relays-new.cardano-mainnet.iohk.io:3001:2|relay1.tap-ada.at:3001:1"

log $LOGGER_NAME $LOG_INFO "done"

