# cardano-spo
Some shell scripts to make life easier when setting up and operating Cardano stake pool nodes.

## Overview

## How to setup

### Structure

    ~/logs
    
    ~/producer
    ~/producer/db/
    ~/producer/logs/
    
    ~/relay1
    ~/relay1/db/
    ~/relay1/logs/
    
    ~/relay2
    ~/relay2/db/
    ~/relay2/logs/

### Environment parameters

Add the following parameters to your home folders `.bashrc` file.

    export CARDANO_CLI_BIN=cardano-cli-1.19.1
    export CARDANO_NODE_BIN=cardano-node-1.19.1
    export CNODE_RELAY1_HOME=/home/<user>/relay1
    export CNODE_RELAY2_HOME=/home/<user>/relay2
    export CNODE_PRODUCER_HOME=/home/<user>/producer

### Crontab entries

    58 * * * * /home/carldano/_scripts/topology-ping.sh --host=<ip_address> >> /home/<user>/logs/main.log
    * * * * * /home/carldano/_scripts/carl-protocol.sh >> /home/<user>/logs/main.log
 
 