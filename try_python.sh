#!/bin/bash

set -e

CONF_DIR="state/agent/"
IS_IS_HOSTNAME="DUMMY_HOSTNAME"
IS_IS_LOGFILE="DUMMY_LOGFILE"
IS_IS_ROUTER_ADDRESS="DUMMY_ROUTER_ADDRESS"
NUMBER_NODES=5

python render_template.py is_is_agent.conf.tmpl $CONF_DIR/isisd.conf \
	                    "{\"is_is_hostname\": \"${IS_IS_HOSTNAME}\", \"is_is_logfile\": \"${IS_IS_LOGFILE}\",
                      		\"num_areas\": ${NUMBER_NODES}, \"num_nodes\": ${NUMBER_NODES},
		                \"is_is_router_address\": \"${IS_IS_ROUTER_ADDRESS}\"}"
