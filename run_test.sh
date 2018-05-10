#!/bin/bash

#Copyright (c) 2016, BROCADE COMMUNICATIONS SYSTEMS, INC All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:
#Redistributions of source code must retain the above copyright notice, this
#list of conditions and the following disclaimer.
#Redistributions in binary form must reproduce the above copyright notice,
#this list of conditions and the following disclaimer
#in the documentation and/or other materials provided with the distribution.
#Neither the name of Brocade nor the names of its contributors may be used
#to endorse or promote products derived from this software without specific prior
#written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
#OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
#OF THE POSSIBILITY OF SUCH DAMAGE.

set -e

#export WORKING_DIR="`pwd`"

export WORKING_DIR="/tmp"
export CONFIG_FILE="$1"
export CMD="$2"

echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

action(){
    case $1 in
        load_config)
            echo -e "Sourcing config file from: $2\n"
            source "$2"
            ;;
        load_mustache)
            echo -e "Sourcing mo (Mustache renderer) file: mo\n"
            . ./mo
            ;;
        create_state)
            mkdir $WORKING_DIR/state
            ;;
        create_bridge)
            echo -e "Creating lxc network bridge: $2"
            lxc network create "$2" || true
            ;;
        create_agent_profile)
            echo -e "Creating agent profile "
            lxc profile copy default agent || true
            ;;
        create_agent_interfaces)
            INTERFACE="eth$((10#$2 * 1))"
            echo -e "Create agent profile interface $INTERFACE parent br-n-$2"
            lxc profile device add agent $INTERFACE nic nictype=bridged parent="br-n-$2"
            ;;
        create_profile)
            echo -e "Creating network profile for $2 br1 $3 br2 $4"
            lxc profile copy default $2 || true
            lxc profile device add $2 eth1 nic nictype=bridged parent=$3 || true
            lxc profile device add $2 eth2 nic nictype=bridged parent=$4 || true
            ;;
        delete_bridge)
            echo -e "Deleting lxc network bridge: $2"
            lxc network delete "$2" || true
            ;;
        delete_container)
            echo -e "Deleting lxc container $2"
            lxc delete --force "$2" || true
                        ;;
        delete_profile)
            echo -e "Deleting lxc profile $2"
            lxc profile delete "$2" || true
                        ;;
        status_bridge)
            echo -e "\nShowing lxc network bridge: $2"
            lxc network show "$2" || true
            echo ""
            ;;
        start_node)
            echo -e "Starting node $2"
            lxc start $2 || true
            ;;
        stop_node)
            echo -e "Stopping node $2"
            lxc stop $2
            ;;
        start_quagga)
            echo -e "Starting quagga on node $2"
            lxc exec $2 -- service quagga start || true
            ;;
        stop_quagga)
            echo -e "Stopping quagga on node $2"
            lxc exec $2 -- service quagga stop || true
            ;;
        create_container)
            echo -e "\nCreating lxc container: $2"
            lxc launch ubuntu:16.04 $2 || true
            lxc exec $2 wget https://github.com/FRRouting/frr/releases/download/frr-4.0/frr_4.0-1.ubuntu16.04.1_amd64.deb
            lxc exec $2 wget https://github.com/FRRouting/frr/releases/download/frr-4.0/frr-dbg_4.0-1.ubuntu16.04.1_arm64.deb
            lxc exec $2 wget https://github.com/FRRouting/frr/releases/download/frr-4.0/frr-pythontools_4.0-1.ubuntu16.04.1_all.deb
            lxc exec $2 dpkg --install frr_4.0-1.ubuntu16.04.1_amd64.deb
            lxc exec $2 dpkg --install frr-dbg_4.0-1.ubuntu16.04.1_arm64.deb
            lxc exec $2 dpkg --install frr-pythontools_4.0-1.ubuntu16.04.1_all.deb
            lxc profile apply $2 $2 || true
            ;;
        create_config_agent)
            echo -e "Creating agent config files ..."
            NAME="agent"
            NUMBER=0
            CONF_DIR="$WORKING_DIR/state/$NAME"
            LXC_DIR="/usr/local/etc"
            lxc exec agent -- mkdir -p $CONF_DIR || true
            mkdir -p $CONF_DIR
            export ZEBRA_HOSTNAME="$NAME"
            export ZEBRA_LOGFILE="/var/log/zebra.log"
            export IS_IS_LOGFILE="/var/log/isisd.log"
            lxc exec agent -- touch $ZEBRA_LOGFILE
            lxc exec agent -- chown quagga:quagga $ZEBRA_LOGFILE
            lxc exec agent -- touch $IS_IS_LOGFILE
            lxc exec agent -- chown quagga:quagga $IS_IS_LOGFILE
            IFS=', ' read -a NODES <<< "`seq -s ', ' $NUMBER_NODES`"

            cat zebra_agent.conf.tmpl | mo > $CONF_DIR/zebra.conf
            lxc file push $CONF_DIR/zebra.conf agent/$LXC_DIR/zebra.conf

            cat zebra_vtysh.conf.tmpl | mo > $CONF_DIR/vtysh.conf
            lxc file push $CONF_DIR/vtysh.conf agent/$LXC_DIR/vtysh.conf

            export IS_IS_HOSTNAME="$NAME"

            IFS=', ' read -a AREAS <<< "`seq -f '%04g' -s ', ' $NUMBER_NODES`"

            IFS=', ' read -a NODES <<< "`seq -f '%04g' -s ', ' $NUMBER_NODES`"

            printf -v IS_IS_ROUTER_ADDRESS "1921.6810.%04d" $NUMBER

             python render_template.py is_is_agent.conf.tmpl $CONF_DIR/isisd.conf \
             "{\"is_is_hostname\": \"${IS_IS_HOSTNAME}\", \"is_is_logfile\": \"${IS_IS_LOGFILE}\",
                   \"num_areas\": ${NUMBER_NODES}, \"num_nodes\": ${NUMBER_NODES},
                   \"is_is_router_address\": \"${IS_IS_ROUTER_ADDRESS}\"}"

            #cat is_is_agent.conf.tmpl | mo > $CONF_DIR/isisd.conf

            echo -e "Pushing config file"
            lxc file push --verbose $CONF_DIR/isisd.conf agent/$LXC_DIR/isisd.conf

            for i in $NODE_NUM_SEQ; do
                ADDRESS_NUM=$((10#${i}))
                INTERFACE_ETH="eth$ADDRESS_NUM"
                echo -e "Setting agent interface $ADDRESS_NUM.$ADDRESS_NUM.$ADDRESS_NUM.1/24 on $INTERFACE_ETH" 
                lxc exec agent -- ip address add "$ADDRESS_NUM.$ADDRESS_NUM.$ADDRESS_NUM.1/24" dev $INTERFACE_ETH || true
                lxc exec agent -- ip link set $INTERFACE_ETH up || true
            done

                #touch $IS_IS_LOGFILE
            #chmod o+rw -R "$WORKING_DIR/state"
            ;;
        create_config_node)
            NAME="$2"
            NUMBER=$3
            echo -e "Creating $NAME config files ..."
            CONF_DIR="$WORKING_DIR/state/$NAME"
            LXC_DIR="/usr/local/etc"
            lxc exec $2 -- mkdir -p "$WORKING_DIR/state"
            mkdir -p "$CONF_DIR"
            export ZEBRA_HOSTNAME="$NAME"
            export ZEBRA_LOGFILE="/var/log/zebra.log"
            export IS_IS_LOGFILE="/var/log/isisd.log"
            export ADDRESS_NUM=$NUMBER
            export ADDRESS_ETH1=$NUMBER
            export ADDRESS_ETH2=$((10#$ADDRESS_ETH1 * 10 +1 ))
            lxc exec $2 -- touch $ZEBRA_LOGFILE
            lxc exec $2 -- chown quagga:quagga $ZEBRA_LOGFILE
            lxc exec $2 -- touch $IS_IS_LOGFILE
            lxc exec $2 -- chown quagga:quagga $IS_IS_LOGFILE
            export ETH_NUM="$NUMBER"

            cat zebra_node.conf.tmpl | mo > $CONF_DIR/zebra.conf
            lxc file push $CONF_DIR/zebra.conf $2/$LXC_DIR/zebra.conf

            cat zebra_vtysh.conf.tmpl | mo > $CONF_DIR/vtysh.conf
            lxc file push $CONF_DIR/vtysh.conf $2/$LXC_DIR/vtysh.conf

            export IS_IS_HOSTNAME="$NAME"
            export AREA=$NUMBER
            export ISIS1=$NUMBER
            # export ETH2=$(($NUMBER + 1000))
            printf -v IS_IS_ROUTER_ADDRESS "1921.6810.%04d" $((10#$NUMBER))
            cat is_is_node.conf.tmpl | mo > $CONF_DIR/isisd.conf
            lxc file push $CONF_DIR/isisd.conf $2/$LXC_DIR/isisd.conf

            export ADDRESS_NUM=$((10#${NUMBER}))
            export ADDRESS_ETH1=$((10#${NUMBER}))
            export ADDRESS_ETH2=$(( $((10#$NUMBER)) * 10 +1 ))
            echo -e "Setting node interface eth1 address $ADDRESS_ETH1.$ADDRESS_NUM.$ADDRESS_NUM.2/24"
            echo -e "Setting node interface eth2 address $ADDRESS_ETH2.$ADDRESS_NUM.$ADDRESS_NUM.1/24"
            lxc exec $2 -- ip address add "$ADDRESS_ETH1.$ADDRESS_NUM.$ADDRESS_NUM.2/24" dev eth1 || true
            lxc exec $2 -- ip address add "$ADDRESS_ETH2.$ADDRESS_NUM.$ADDRESS_NUM.1/24" dev eth2 || true
            lxc exec $2 -- ip link set eth1 up || true
            lxc exec $2 -- ip link set eth2 up || true


            #lxc exec $2 -- touch $IS_IS_LOGFILE
            ;;
        # start)
        #     NAME="$2"
        #     for i in $NODE_NUM_SEQ; do
        #         name=$((10#${i}))
        #         INTERFACE_ETH="eth$ADDRESS_NUM"
        #         lxc exec agent -- ip address add "$ADDRESS_NUM.$ADDRESS_NUM.$ADDRESS_NUM.1/24" dev $INTERFACE_ETH
        #         lxc exec agent -- ip link set $INTERFACE_ETH up
        #     done
        #     ;;
        # stop)
        #     NAME="$2"
            # ;;
    esac
}
export -f action

cli_action(){
    case $1 in
        create)
            echo "Creating testing environment."

            echo "Creating State dir"
            action create_state

            echo "Creating bridge 0: ${BRIDGE_NAME_PATTERN}0."
            action create_bridge "${BRIDGE_NAME_PATTERN}0"

            echo "Create agent profile..."
            action create_agent_profile

            echo -e "Creating agent interfaces"
            for i in $NODE_NUM_SEQ; do
                action create_agent_interfaces $i
            done

            echo -e "Creating $NUMBER_NODES $BRIDGE_NAME_PATTERN bridges for nodes ...\n"
            for i in $NODE_NUM_SEQ; do
                action create_bridge "${BRIDGE_NAME_PATTERN}${i}"
            done

            echo -e "Creating $NUMBER_NODES $EXTERNAL_NAME_PATTERN bridges for nodes ...\n"
            for i in $NODE_NUM_SEQ; do
                action create_bridge "${EXTERNAL_NAME_PATTERN}${i}"
            done

            echo -e "Create agent..."
            action create_container agent

            echo -e "Creating network interfaces and joining to bridges..."

            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%03g" $i
                action create_profile $NODE_NAME "${BRIDGE_NAME_PATTERN}${i}" "${EXTERNAL_NAME_PATTERN}${i}"
            done

            echo -e "Creating containers for agent ..."

            for i in $NODE_NUM_SEQ; do
                    printf -v NODE_NAME "node%03g" $i
                    echo -e "Creating container for $NODE_NAME ..."
                    action create_container $NODE_NAME
            done
            ;;
        config)
            echo -e "Creating config files for agent ..."
            action create_config_agent

            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%03g" $i
                echo -e "Creating config files for $NODE_NAME ..."
                action create_config_node $NODE_NAME $i
            done
            ;;
        delete)
            echo "Deleting testing environment."

            echo "Deleteing agent container"
            action delete_container agent

            echo "Delete agent profile"
            action delete_profile "agent"

            echo "Deleting network containers"
            for i in $NODE_NUM_SEQ; do
                                echo -e $i
                                printf -v NODE_NAME "node%03g" $i
                                echo -e "Deleting container for $NODE_NAME ..."
                                action delete_container $NODE_NAME
                        done

            echo "Deleteing bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action delete_bridge "${BRIDGE_NAME_PATTERN}0"

            echo -e "Deleting $NUMBER_NODES $BRIDGE_NAME_PATTERN bridges for nodes ...\n"
            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%03g" $i
                action delete_bridge "${BRIDGE_NAME_PATTERN}${i}"
            done

            echo -e "Deleting profile...\n"
                        for i in $NODE_NUM_SEQ; do
                                printf -v NODE_NAME "node%03g" $i
                                action delete_profile $NODE_NAME
                        done

            echo -e "Deleting $NUMBER_NODES $EXTERNAL_NAME_PATTERN bridges for nodes ...\n"
            for i in $NODE_NUM_SEQ; do
                action delete_bridge "${EXTERNAL_NAME_PATTERN}${i}"
            done
            echo -e "Deleting config files ...\n"
            sudo rm -rf $WORKING_DIR/state
            ;;
        status)
            echo "Checking testing environment."
            echo "Checking bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action status_bridge "${BRIDGE_NAME_PATTERN}0"

            echo -e "Checking $NUMBER_NODES node $BRIDGE_NAME_PATTERN bridges ...\n"
            for i in $NODE_NUM_SEQ; do
                action status_bridge "${BRIDGE_NAME_PATTERN}${i}"
            done

            echo -e "Checking $NUMBER_NODES node $EXTERNAL_NAME_PATTERN bridges ...\n"
            for i in $NODE_NUM_SEQ; do
                action status_bridge "${EXTERNAL_NAME_PATTERN}${i}"
            done
            ;;
        start)
            echo "Starting agent."
            action start_node "agent"

            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%03d" $i
                action start_node $NODE_NAME
            done
            ;;
        stop)
            echo "Stopping agent."
            action stop_node "agent"

            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%-03d" $i
                echo -e "Stopping $NODE_NAME ...\n"
                action stop_node $NODE_NAME
            done
            ;;
        startservice)
            echo "Starting services."
            action start_quagga "agent"

            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%03d" $((10#$i))
                action start_quagga $NODE_NAME
            done
            ;;
        stopservice)
            echo "Stopping services."
            action stop_quagga "agent"

            for i in $NODE_NUM_SEQ; do
                printf -v NODE_NAME "node%-03d" $i
                action stop_quagga $NODE_NAME
            done
            ;;
        *)
            echo -e "Action \"${1}\" isn't a valid option!"
            ;;
    esac

}

echo -e "\n###### IS-IS TESTER ######\n"
action load_config "$CONFIG_FILE"
action load_mustache

export NODE_NUM_SEQ="`seq -f '%03g' -s ' ' 1 $NUMBER_NODES`"

cli_action "$CMD"
echo -e "\n##### DONE, EXITING #####\n"

