#!/bin/sh
[ "$arg" != "" ] || arg="-t"
[ "$trace_file" != "" ] || trace_file=iperf-tcpreplay.trace
if [ ! -e "$trace_file" ]; then
	echo "trace file($trace_file) is not found. specify 'trace_file' env var"
	exit
fi

if [ $# -lt 1 ]; then
	echo "Usage: $0 <netif> [# of packet]"
	exit
fi
netif=$1
nr_pkt=1000
[ $# -ge 2 ] && nr_pkt=$2

tcpreplay $arg -i $netif -L $nr_pkt $trace_file
