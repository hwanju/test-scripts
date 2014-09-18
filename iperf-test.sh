#!/bin/bash

PERF=/root/bin/perf

if [ "$1" = "-h" -o $# -lt 3 ]; then
	echo "Usage: $0 <output filename prefix> <pin|nopin> <# of runs> [iperf client args]"
	exit
fi

OUT_FN=$1-$2
PIN=$2
NR_RUNS=$3
if [ $NR_RUNS -gt 1 ]; then
	OUT_FN=${OUT_FN}-x$NR_RUNS
fi
shift 3
CLIENT_ARGS="$*"
SERVER_ARGS=
if [[ "$CLIENT_ARGS" =~ "-u" ]]; then
	SERVER_ARGS="-u"
fi

CLIENT_IP=11.0.0.1			# iface1: tx-side
SERVER_IP=12.0.0.1			# iface2: rx-side
SERVER_DUMMY_IP=12.0.0.2

# Server
SERVER_CMD="iperf -B $SERVER_IP -s $SERVER_ARGS"
if [ $PIN = "pin" ]; then
	SERVER_CMD="taskset 0x2 $SERVER_CMD"
fi
echo "# Server" > iperf-server.tmp
echo "# $SERVER_CMD" >> iperf-server.tmp
$SERVER_CMD >> iperf-server.tmp &
SERVER_PID=$!
echo "Server is running ..."
sleep 1

# Client
CLIENT_CMD="iperf -t 10 -B $CLIENT_IP -c $SERVER_DUMMY_IP $CLIENT_ARGS"
if [ $PIN = "pin" ]; then
	CLIENT_CMD="taskset 0x4 $CLIENT_CMD"
fi
echo "# Client" > $OUT_FN.log
echo "# $CLIENT_CMD" >> $OUT_FN.log

# Prolog: when # of runs is set to one, enable profiling
echo "Test start ..."
if [ $NR_RUNS -eq 1 ]; then
	if [ -e $PERF ]; then
		CLIENT_CMD="$PERF record -a $CLIENT_CMD"
	fi
fi
cat /proc/stat > $OUT_FN.stat

# Run benchmark
for i in `seq $NR_RUNS`; do
	$CLIENT_CMD >> $OUT_FN.log
	cat $OUT_FN.log
done

# Epilog
cat /proc/stat >> $OUT_FN.stat
if [ $NR_RUNS -eq 1 ]; then
	if [ -e $PERF ]; then
		$PERF report --showcpuutilization -n > $OUT_FN.perf
	fi
fi
kill -15 $SERVER_PID

cat iperf-server.tmp >> $OUT_FN.log
rm iperf-server.tmp

echo "$OUT_FN.* are generated"
