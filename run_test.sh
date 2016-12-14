#!/bin/bash

set -e

export WORKING_DIR="`pwd`"
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
		create_bridge)
			echo -e "Creating lxc network bridge: $2"
			lxc network create "$2" || true
			;;
		delete_bridge)
			echo -e "Deleting lxc network bridge: $2"
			lxc network delete "$2" || true
			;;
		status_bridge)
			echo -e "\nShowing lxc network bridge: $2"
			lxc network show "$2" || true
			echo ""
			;;
		create_config_agent)
			echo -e "Creating agent config files ..."
			NAME="agent"
			NUMBER=0
                        CONF_DIR="$WORKING_DIR/state/$NAME"
			mkdir -p "$CONF_DIR"
			export ZEBRA_HOSTNAME="$NAME"
			export ZEBRA_LOGFILE="$CONF_DIR/zebra.log"
			IFS=', ' read -a NODES <<< "`seq -s ', ' $NUMBER_NODES`"
			cat zebra_agent.conf.tmpl | mo > $CONF_DIR/zebra.conf
			
			export IS_IS_HOSTNAME="$NAME"
			export IS_IS_LOGFILE="$CONF_DIR/is_is.log"
			IFS=', ' read -a NODES <<< "`seq -f '%04g' -s ', ' $NUMBER_NODES`"
			printf -v IS_IS_ROUTER_ADDRESS "1921.6810.%04d" $NUMBER
			cat is_is_agent.conf.tmpl | mo > $CONF_DIR/is_is.conf
			
			touch $IS_IS_LOGFILE
			chmod o+rw -R "$WORKING_DIR/state"  
			;;
		create_config_node)
			NAME="$2"
			NUMBER="$3"
			echo -e "Creating $NAME config files ..."
                        CONF_DIR="$WORKING_DIR/state/$NAME"
			mkdir -p "$CONF_DIR"
			export ZEBRA_HOSTNAME="$NAME"
			export ZEBRA_LOGFILE="$CONF_DIR/zebra.log"
			export ETH_NUM="$NUMBER"
			export ADDRESS_NUM=$((10#${NUMBER}))
			cat zebra_node.conf.tmpl | mo > $CONF_DIR/zebra.conf
			
			export IS_IS_HOSTNAME="$NAME"
			export IS_IS_LOGFILE="$CONF_DIR/is_is.log"
			export NODE="$NUMBER"
			printf -v IS_IS_ROUTER_ADDRESS "1921.6810.%04d" $NUMBER
			cat is_is_node.conf.tmpl | mo > $CONF_DIR/is_is.conf
			
			touch $IS_IS_LOGFILE
			chmod o+rw -R "$WORKING_DIR/state"  
			;;
		start)
			NAME="$2"
			ZEBRA_CONFIG_FILE="$WORKING_DIR/state/$NAME/zebra.conf"
			IS_IS_CONFIG_FILE="$WORKING_DIR/state/$NAME/is_is.conf"
			ZEBRA_PID_FILE="$WORKING_DIR/state/$NAME/zebra.pid"
			IS_IS_PID_FILE="$WORKING_DIR/state/$NAME/is_is.pid"
			ZEBRA_SOCKET_FILE="$WORKING_DIR/state/$NAME/zebra.socket"
			IS_IS_SOCKET_FILE="$WORKING_DIR/state/$NAME/is_is.socket"

			if [ ! -f $ZEBRA_PID_FILE ]; then
				echo -e "Starting zebra for $2 ..."
				sudo LD_LIBRARY_PATH=/usr/local/lib zebra -d -u quagga -g quagga \
					-i $ZEBRA_PID_FILE -z $ZEBRA_SOCKET_FILE \
					-f $ZEBRA_CONFIG_FILE 
			fi
			if [ ! -f $IS_IS_PID_FILE ]; then
				echo -e "Starting isisd for $2 ..."
				sudo LD_LIBRARY_PATH=/usr/local/lib isisd -d -u quagga -g quagga \
					-i $IS_IS_PID_FILE -z $IS_IS_SOCKET_FILE \
					-f $IS_IS_CONFIG_FILE 
			fi
			;;
		stop)
			NAME="$2"
			ZEBRA_PID_FILE="$WORKING_DIR/state/$NAME/zebra.pid"
			IS_IS_PID_FILE="$WORKING_DIR/state/$NAME/is_is.pid"
			ZEBRA_SOCKET_FILE="$WORKING_DIR/state/$NAME/zebra.socket"
			IS_IS_SOCKET_FILE="$WORKING_DIR/state/$NAME/is_is.socket"
			if [ -f $ZEBRA_PID_FILE ]; then
				echo -e "Stopping zebra for $2 ..."
				sudo kill -15 `cat $ZEBRA_PID_FILE`
				sudo rm $ZEBRA_PID_FILE || true
			fi
			if [ -f $IS_IS_PID_FILE ]; then
				echo -e "Stopping isisd for $2 ..."
				sudo kill -2 `cat $IS_IS_PID_FILE`
				sudo rm $IS_IS_PID_FILE || true
			fi
			;;
	esac
}
export -f action

cli_action(){
	case $1 in
		create)
			echo "Creating testing environment."
			echo "Creating user & group quagga."
			sudo useradd quagga || true
			sudo groupadd quagga || true
			
			echo "Creating bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action create_bridge "${BRIDGE_NAME_PATTERN}0"

			echo -e "Creating $NUMBER_NODES $BRIDGE_NAME_PATTERN bridges for nodes ...\n"
			for i in $NODE_NUM_SEQ; do
				action create_bridge "${BRIDGE_NAME_PATTERN}${i}"
			done
			
			echo -e "Creating $NUMBER_NODES $EXTERNAL_NAME_PATTERN bridges for nodes ...\n"
			for i in $NODE_NUM_SEQ; do
				action create_bridge "${EXTERNAL_NAME_PATTERN}${i}"
			done

			echo -e "Creating config files for agent ..."
			action create_config_agent

			for i in $NODE_NUM_SEQ; do
				printf -v NODE_NAME "node%03d" $i
				echo -e "Creating config files for $NODE_NAME ..."
				action create_config_node $NODE_NAME $i
			done
			;;
		delete)
			echo "Deleting testing environment."

			echo "Deleteing bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action delete_bridge "${BRIDGE_NAME_PATTERN}0"

			echo -e "Deleting $NUMBER_NODES $BRIDGE_NAME_PATTERN bridges for nodes ...\n"
			for i in $NODE_NUM_SEQ; do
				action delete_bridge "${BRIDGE_NAME_PATTERN}${i}"
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

			#for i in $NODE_NUM_SEQ; do
				#NODE_ZEBRA_PID=$(ps -p `cat $WORKING_DIR/state/node$i/zebra.pid` -o pid=)
				#NODE_IS_IS_PID=$(ps -p `cat $WORKING_DIR/state/node$i/is_is.pid` -o pid=)
				#if $NODE_ZEBRA_PID; then
				#else
				#fi 
				#echo -e "Checking node$i node $EXTERNAL_NAME_PATTERN bridges ...\n"
			#done
			;;
		start)
			echo "Starting services."
			echo "Starting agent."
                        action start agent

			for i in $NODE_NUM_SEQ; do
				printf -v NODE_NAME "node%03d" $i
				echo -e "Starting $NODE_NAME ...\n"
				action start $NODE_NAME
			done
			;;
		stop)
			echo "Stopping services."
			echo "Stopping agent."
                        action stop agent

			for i in $NODE_NUM_SEQ; do
				printf -v NODE_NAME "node%03d" $i
				echo -e "Stopping $NODE_NAME ...\n"
				action stop $NODE_NAME
			done
			;;
		install)
			echo "Installing quagga..."
			sudo apt-get install -y g++ libreadline6 libreadline6-dev build-essential texinfo
			wget http://download.savannah.gnu.org/releases/quagga/quagga-1.1.0.tar.gz
			tar xzf quagga-1.1.0.tar.gz
			cd quagga-1.1.0
			sudo -E ./configure
			sudo -E make
			sudo -E make install
			rm -rf quagga-1.1.0
			;;
		*)
			echo -e "Action \"${1}\" isn't a valid option!"
			;;
	esac

}

echo -e "\n###### IS-IS TESTER ######\n"
action load_config "$CONFIG_FILE"
action load_mustache

export NODE_NUM_SEQ="`seq -f '%04g' -s ' ' 1 $NUMBER_NODES`"

cli_action "$CMD"
echo -e "\n##### DONE, EXITING #####\n"
