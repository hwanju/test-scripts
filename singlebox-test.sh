#!/bin/bash

if [ $# -lt 4 ]; then
	echo "Usage: $0 <tx iface> <rx iface> <pin|nopin> <# of runs> [config ... ]"
	exit
fi
TX_IFACE=$1
RX_IFACE=$2
PIN=$3
NR_RUNS=$4
shift 4
CONF_LIST="$*"

NAME=${TX_IFACE}_to_${RX_IFACE}
if [ "$CONF_LIST" != "" ]; then
	CONF_NAME=`echo $CONF_LIST | sed 's/[[:blank:]]/_/g'`
	CONF_NAME=-$CONF_NAME
fi
OUT_FN=$NAME$CONF_NAME-$PIN

# Setup 
./singlebox-setup.sh $TX_IFACE $RX_IFACE $CONF_LIST > $OUT_FN.setup
killall -9 iperf 2>/dev/null	# make sure to clean

echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle

# Run benchmark
./iperf-test.sh $NAME$CONF_NAME $PIN $NR_RUNS
