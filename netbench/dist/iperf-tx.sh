#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

ifconfig $src_netif $src_ip up
iperf -B $src_ip -c $dst_ip
ip addr flush dev $src_netif
