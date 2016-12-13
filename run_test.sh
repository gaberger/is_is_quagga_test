#!/bin/bash

set -e

export WORKING_DIR="`pwd`"
export CONFIG_FILE="$1"
export CMD="$2"

export LD_LIBRARY_PATH=/usr/local/lib


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
		create_config)
			echo -e "Creating config files ..."
			NAME="$2"
			NUMBER="$3"
                        CONF_DIR="state/$NAME"
			mkdir -p "$CONF_DIR"
			export ZEBRA_HOSTNAME="$NAME"
			IFS=', ' read -a INTERFACES <<< "`seq -s ', ' $NUMBER_NODES`"
			cat zebra.conf.tmpl | mo > $CONF_DIR/zebra.conf
			
			export IS_IS_HOSTNAME="$NAME"
			export IS_IS_LOGFILE="state/${NAME}/is_is.log"
			#net 49.{{IS_IS_DEAD_AREA}}.{{IS_IS_DEAD_ROUTER_ADDRESS}}.00
			printf -v DEAD_INTERFACE "eth%d" $NUMBER
			printf -v IS_IS_DEAD_AREA "%04d" $NUMBER
			printf -v IS_IS_DEAD_ROUTER_ADDRESS "1921.6810.%04d" $NUMBER
			#net 49.{{IS_IS_BEEF_AREA}}.{{IS_IS_BEEF_ROUTER_ADDRESS}}.00
			printf -v BEEF_INTERFACE "bbr%d" $NUMBER
			printf -v IS_IS_BEEF_AREA "%04d" $NUMBER
			printf -v IS_IS_BEEF_ROUTER_ADDRESS "1921.6810.%04d" $NUMBER
			cat is_is.conf.tmpl | mo > $CONF_DIR/is_is.conf
			;;
		start)
			NAME="$2"
			ZEBRA_PID_FILE="$WORKING_DIR/state/$NAME/zebra.pid"
			IS_IS_PID_FILE="$WORKING_DIR/state/$NAME/is_is.pid"
			ZEBRA_SOCKET_FILE="$WORKING_DIR/state/$NAME/zebra.socket"
			IS_IS_SOCKET_FILE="$WORKING_DIR/state/$NAME/is_is.socket"
			if [ ! -f $ZEBRA_PID_FILE ]; then
				echo -e "Starting zebra for $2 ..."
				zebra -d -u quagga -g quagga -i $ZEBRA_PID_FILE -z $ZEBRA_SOCKET_FILE
			fi
			if [ ! -f $IS_IS_PID_FILE ]; then
				echo -e "Starting isisd for $2 ..."
				isisd -d -u quagga -g quagga -i $IS_IS_PID_FILE -z $IS_IS_SOCKET_FILE
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
				kill -15 `cat $ZEBRA_PID_FILE`
				rm $ZEBRA_PID_FILE
			fi
			if [ ! -f $IS_IS_PID_FILE ]; then
				echo -e "Starting isisd for $2 ..."
				kill -15 `cat $IS_IS_PID_FILE`
				rm $IS_IS_PID_FILE
			fi
			;;
	esac
}
export -f action

cli_action(){
	case $1 in
		create)
			echo "Creating testing environment."
			
			echo "Creating bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action create_bridge "${BRIDGE_NAME_PATTERN}0"

			echo -e "Creating $NUMBER_NODES $BRIDGE_NAME_PATTERN bridges for nodes ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action create_bridge "${BRIDGE_NAME_PATTERN}${i}"
			done
			
			echo -e "Creating $NUMBER_NODES $EXTERNAL_NAME_PATTERN bridges for nodes ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action create_bridge "${EXTERNAL_NAME_PATTERN}${i}"
			done

			echo -e "Creating config files for agent ..."
			action create_config agent 0

			for i in $(seq 1 $NUMBER_NODES); do
				printf -v NODE_NAME "node%03d" $i
				echo -e "Creating config files for $NODE_NAME ..."
				action create_config $NODE_NAME $i
			done
			;;
		delete)
			echo "Deleting testing environment."

			echo "Deleteing bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action delete_bridge "${BRIDGE_NAME_PATTERN}0"

			echo -e "Deleting $NUMBER_NODES $BRIDGE_NAME_PATTERN bridges for nodes ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action delete_bridge "${BRIDGE_NAME_PATTERN}${i}"
			done

			echo -e "Deleting $NUMBER_NODES $EXTERNAL_NAME_PATTERN bridges for nodes ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action delete_bridge "${EXTERNAL_NAME_PATTERN}${i}"
			done
			echo -e "Deleting config files ...\n"
			rm -rf state/configs
			;;
		status)
			echo "Checking testing environment."
			echo "Checking bridge 0: ${BRIDGE_NAME_PATTERN}0."
                        action status_bridge "${BRIDGE_NAME_PATTERN}0"

			echo -e "Checking $NUMBER_NODES node $BRIDGE_NAME_PATTERN bridges ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action status_bridge "${BRIDGE_NAME_PATTERN}${i}"
			done
			
			echo -e "Checking $NUMBER_NODES node $EXTERNAL_NAME_PATTERN bridges ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action status_bridge "${EXTERNAL_NAME_PATTERN}${i}"
			done
			;;
		start)
			echo "Starting services."
			echo "Starting agent."
                        action start agent

			echo "Starting agent."
                        action start agent

			echo -e "Starting ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action status_bridge "${BRIDGE_NAME_PATTERN}${i}"
			done
			
			echo -e "Checking $NUMBER_NODES node $EXTERNAL_NAME_PATTERN bridges ...\n"
			for i in $(seq 1 $NUMBER_NODES); do
				action status_bridge "${EXTERNAL_NAME_PATTERN}${i}"
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

cli_action "$CMD"
echo -e "\n##### DONE, EXITING #####\n"
